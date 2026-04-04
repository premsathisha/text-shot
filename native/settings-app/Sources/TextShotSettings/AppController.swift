import AppKit
import Foundation
import KeyboardShortcuts
import SwiftUI

@MainActor
private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: @MainActor () -> Void

    init(rootView: AnyView, onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose

        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 430, height: 360))
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

@MainActor
final class AppController {
    typealias SettingsWindowControllerFactory = @MainActor (SettingsViewModel, @escaping @MainActor () -> Void) -> NSWindowController

    private let settingsStore: SettingsStoreV2
    private let hotkeyManager: any HotkeyManaging & HotkeyRecorderBindingProviding
    private let captureService: CaptureServing
    private let ocrService: OCRServing
    private let clipboardService: ClipboardWriting
    private let launchAtLoginService: LaunchAtLoginApplying
    private let toastPresenter: ToastPresenting
    private let screenCapturePermissionService: ScreenCapturePermissionChecking
    private let updateManager: UpdateManaging
    private let settingsWindowControllerFactory: SettingsWindowControllerFactory
    private let captureActivationDelayNanoseconds: UInt64
    private let captureRetryActivationDelayNanoseconds: UInt64

    private var settingsWindowController: NSWindowController?
    private var settingsViewModel: SettingsViewModel?
    private var currentSettings: AppSettingsV2
    private var lastCopiedText = ""
    private var isCaptureInFlight = false
    private var hasCompletedInitialCaptureAttempt = false

    init(
        settingsStore: SettingsStoreV2,
        hotkeyManager: any HotkeyManaging & HotkeyRecorderBindingProviding = HotkeyBindingController(),
        captureService: CaptureServing = CaptureService(),
        ocrService: OCRServing = OCRService(),
        clipboardService: ClipboardWriting = ClipboardService(),
        launchAtLoginService: LaunchAtLoginApplying = LaunchAtLoginService(),
        toastPresenter: ToastPresenting? = nil,
        screenCapturePermissionService: ScreenCapturePermissionChecking = ScreenCapturePermissionService(),
        updateManager: UpdateManaging? = nil,
        installStartupStateOnInit: Bool = true,
        captureActivationDelayNanoseconds: UInt64 = 150_000_000,
        captureRetryActivationDelayNanoseconds: UInt64 = 300_000_000,
        settingsWindowControllerFactory: @escaping SettingsWindowControllerFactory = AppController.makeSettingsWindowController
    ) {
        self.settingsStore = settingsStore
        self.hotkeyManager = hotkeyManager
        self.captureService = captureService
        self.ocrService = ocrService
        self.clipboardService = clipboardService
        self.launchAtLoginService = launchAtLoginService
        self.toastPresenter = toastPresenter ?? ToastPresenter()
        self.screenCapturePermissionService = screenCapturePermissionService
        self.updateManager = updateManager ?? UpdateManagerFactory.make()
        self.settingsWindowControllerFactory = settingsWindowControllerFactory
        self.captureActivationDelayNanoseconds = captureActivationDelayNanoseconds
        self.captureRetryActivationDelayNanoseconds = captureRetryActivationDelayNanoseconds
        self.currentSettings = settingsStore.load()

        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.runCaptureFlow()
            }
        }

        hotkeyManager.onShortcutChanged = { [weak self] shortcut in
            Task { @MainActor [weak self] in
                self?.syncHotkeyMirror(to: shortcut)
                self?.settingsViewModel?.syncHotkeyDisplay(with: shortcut)
            }
        }

        if installStartupStateOnInit {
            installStartupState()
        }
    }

    func openSettings() {
        if let existingWindow = settingsWindowController?.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = SettingsViewModel(
            initialSettings: currentSettings.editable,
            hotkeyController: hotkeyManager,
            updateManager: updateManager,
            onApplySettings: { [weak self] editable in
                guard let self else { return .failure(.message("Settings unavailable")) }
                return self.saveSettings(editable)
            }
        )
        settingsViewModel = model

        let controller = settingsWindowControllerFactory(model) { [weak self] in
            guard let self else { return }
            self.settingsWindowController = nil
            self.settingsViewModel = nil
        }
        settingsWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func captureNow() {
        Task { @MainActor in
            await runCaptureFlow()
        }
    }

    @discardableResult
    func applyShortcutForTesting(_ shortcut: AppHotkeyShortcut?) -> Result<AppHotkeyShortcut?, SettingsActionError> {
        applyHotkeyFromSettings(shortcut)
    }

    func isSettingsWindowOpenForTesting() -> Bool {
        settingsWindowController != nil
    }

    private func installStartupState() {
        launchAtLoginService.apply(enabled: currentSettings.launchAtLogin)

        if case .none = hotkeyManager.activeShortcut {
            _ = try? hotkeyManager.resetToDefault()
        }

        syncHotkeyMirrorToActiveShortcut()
    }

    private func activeShortcutOrDefault() -> AppHotkeyShortcut {
        hotkeyManager.activeShortcut ?? HotkeyManager.defaultShortcut
    }

    private func syncHotkeyMirrorToActiveShortcut() {
        syncHotkeyMirror(to: activeShortcutOrDefault())
    }

    private func syncHotkeyMirror(to shortcut: AppHotkeyShortcut?) {
        let display = HotkeyManager.displayString(for: shortcut)
        if currentSettings.hotkey == display {
            return
        }

        currentSettings.hotkey = display
        _ = try? settingsStore.save(currentSettings)
    }

    private func applyHotkeyFromSettings(_ shortcut: AppHotkeyShortcut?) -> Result<AppHotkeyShortcut?, SettingsActionError> {
        do {
            let active = try hotkeyManager.apply(shortcut: shortcut)
            syncHotkeyMirror(to: active)
            return .success(active)
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    private func saveSettings(_ editable: EditableSettings) -> Result<EditableSettings, SettingsActionError> {
        var next = currentSettings
        next.apply(editable)

        do {
            currentSettings = try settingsStore.save(next)
            launchAtLoginService.apply(enabled: currentSettings.launchAtLogin)
            return .success(currentSettings.editable)
        } catch {
            return .failure(.message("Failed to save settings: \(error.localizedDescription)"))
        }
    }

    private func showToastIfEnabled(_ message: String) {
        if currentSettings.showConfirmation {
            toastPresenter.show(message)
        }
    }

    private func showScreenRecordingPromptIfNeeded() {
        // macOS already shows the system Screen Recording permission dialog.
    }

    func runCaptureFlow() async {
        guard !isCaptureInFlight else { return }
        isCaptureInFlight = true
        defer { isCaptureInFlight = false }

        let hasScreenCaptureAccess = await screenCapturePermissionService.ensureAuthorized()

        guard hasScreenCaptureAccess else {
            showScreenRecordingPromptIfNeeded()
            return
        }

        let isInitialCaptureAttempt = !hasCompletedInitialCaptureAttempt
        defer { hasCompletedInitialCaptureAttempt = true }

        await prepareForInteractiveCapture(delayNanoseconds: captureActivationDelayNanoseconds)
        var capture = await captureService.captureRegion()

        if shouldRetryCapture(result: capture, isInitialCaptureAttempt: isInitialCaptureAttempt) {
            await prepareForInteractiveCapture(delayNanoseconds: captureRetryActivationDelayNanoseconds)
            capture = await captureService.captureRegion()
        }

        if capture.canceled {
            return
        }

        guard let path = capture.path else {
            if capture.failureReason == .permissionDenied {
                showScreenRecordingPromptIfNeeded()
            } else {
                showToastIfEnabled("Capture failed")
            }
            return
        }

        defer {
            CaptureTempStore.shared.removeCaptureFile(atPath: path)
        }

        do {
            guard let text = try ocrService.runOcrWithRetry(imagePath: path), !text.isEmpty else {
                showToastIfEnabled("No text")
                return
            }

            if text == lastCopiedText {
                clipboardService.write(text)
                return
            }

            clipboardService.write(text)
            lastCopiedText = text
            showToastIfEnabled("Copied!")
        } catch {
            showToastIfEnabled("Error")
        }
    }

    private func prepareForInteractiveCapture(delayNanoseconds: UInt64) async {
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
    }

    private func shouldRetryCapture(result: CaptureResult, isInitialCaptureAttempt: Bool) -> Bool {
        guard isInitialCaptureAttempt, !result.canceled, result.path == nil else {
            return false
        }

        switch result.failureReason {
        case .permissionDenied:
            return false
        case .toolFailed(let message):
            let normalized = message.lowercased()
            return normalized.contains("failed to create image")
        case .unexpected(let message):
            return message.contains("exit code 2")
        case nil:
            return false
        }
    }

    private static func makeSettingsWindowController(
        model: SettingsViewModel,
        onClose: @escaping @MainActor () -> Void
    ) -> NSWindowController {
        SettingsWindowController(
            rootView: AnyView(SettingsView().environmentObject(model)),
            onClose: onClose
        )
    }
}
