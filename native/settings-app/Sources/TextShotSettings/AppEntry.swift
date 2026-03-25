import AppKit
import SwiftUI

private enum Bootstrap {
    @MainActor
    static func appController(updateManager: UpdateManaging) -> AppController {
        let migrator = SettingsMigrator()
        let store = (try? migrator.prepareStore()) ?? SettingsStoreV2(fileURL: fallbackSettingsURL())
        return AppController(settingsStore: store, updateManager: updateManager)
    }

    @MainActor
    static func updateManager() -> UpdateManaging {
        UpdateManagerFactory.make()
    }

    private static func fallbackSettingsURL() -> URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Text Shot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("settings-v3.json")
    }
}

@MainActor
enum StatusMenuBuilder {
    static let checkForUpdatesTitle = "Check for Updates..."

    private static func menuSymbolImage(systemName: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: description
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    static func makeMenu(
        target: AnyObject,
        updateManager: UpdateManaging,
        captureAction: Selector,
        openSettingsAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()
        menu.showsStateColumn = false

        let captureItem = NSMenuItem(title: "Capture Text", action: captureAction, keyEquivalent: "")
        captureItem.target = target
        menu.addItem(captureItem)
        menu.addItem(.separator())

        let checkForUpdatesItem = NSMenuItem(title: checkForUpdatesTitle, action: nil, keyEquivalent: "")
        checkForUpdatesItem.image = menuSymbolImage(
            systemName: "arrow.triangle.2.circlepath",
            description: checkForUpdatesTitle
        )
        updateManager.configure(checkForUpdatesMenuItem: checkForUpdatesItem)
        menu.addItem(checkForUpdatesItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: openSettingsAction, keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.image = nil
        settingsItem.target = target
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var updateManager = Bootstrap.updateManager()
    private lazy var controller = Bootstrap.appController(updateManager: updateManager)
    private let appRelocator = AppRelocator()
    private var statusItem: NSStatusItem?
    private var willTerminateObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CaptureTempStore.shared.prepareForLaunch()
        willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            CaptureTempStore.shared.cleanupTrackedFiles()
        }
        setupStatusItem()
        appRelocator.promptToMoveIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "TS"

        let menu = StatusMenuBuilder.makeMenu(
            target: self,
            updateManager: updateManager,
            captureAction: #selector(captureText),
            openSettingsAction: #selector(openSettings),
            quitAction: #selector(quitApp)
        )
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func captureText() {
        controller.captureNow()
    }

    @objc private func openSettings() {
        controller.openSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

@main
struct TextShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
