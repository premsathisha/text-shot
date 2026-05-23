import AppKit
import KeyboardShortcuts
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
    private static let menuBarIconHeight: CGFloat = 18
    private static let menuBarIconWidth: CGFloat = 22
    private static let menuBarItemHorizontalPadding: CGFloat = 2
    private static let bundledMenuBarIconCandidates: [(name: String, ext: String)] = [
        ("text-shot-menubar-template", "pdf"),
        ("text-shot-menubar-template", "png")
    ]

    private lazy var updateManager = Bootstrap.updateManager()
    private lazy var controller = Bootstrap.appController(updateManager: updateManager)
    private var statusItem: NSStatusItem?
    private var didWakeObserver: NSObjectProtocol?
    private var willTerminateObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CaptureTempStore.shared.prepareForLaunch()
        _ = controller
        didWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Carbon hotkey registrations go stale after sleep; force re-registration.
            KeyboardShortcuts.isEnabled = false
            KeyboardShortcuts.isEnabled = true
        }
        willTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            CaptureTempStore.shared.cleanupTrackedFiles()
        }
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let icon = loadMenuBarIcon()
        let statusItem = NSStatusBar.system.statusItem(withLength: menuBarItemLength(for: icon))
        if let button = statusItem.button {
            button.title = ""
            button.imageScaling = .scaleNone
            if let icon {
                button.image = icon
                button.imagePosition = .imageOnly
            } else {
                button.image = nil
                button.title = "TS"
            }
        }

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

    private func loadMenuBarIcon() -> NSImage? {
        let resourceBundle = appResourceBundle(named: "TextShotSettings_TextShotSettings")
        for candidate in Self.bundledMenuBarIconCandidates {
            let image: NSImage?
            if candidate.ext == "png" {
                image = resourceBundle?.image(forResource: candidate.name)
            } else if let url = resourceBundle?.url(forResource: candidate.name, withExtension: candidate.ext) {
                image = NSImage(contentsOf: url)
            } else {
                image = nil
            }
            guard let image else { continue }
            return configuredMenuBarIcon(from: image)
        }
        return nil
    }

    private func configuredMenuBarIcon(from image: NSImage) -> NSImage {
        image.isTemplate = true
        image.accessibilityDescription = "Text Shot"
        if image.size == .zero {
            image.size = NSSize(width: Self.menuBarIconWidth, height: Self.menuBarIconHeight)
        }
        return image
    }

    private func menuBarItemLength(for icon: NSImage?) -> CGFloat {
        guard let icon else { return NSStatusItem.squareLength }
        return max(
            NSStatusBar.system.thickness,
            ceil(icon.size.width + Self.menuBarItemHorizontalPadding)
        )
    }

    private func appResourceBundle(named name: String) -> Bundle? {
        let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("\(name).bundle")
        guard let bundleURL else { return nil }
        return Bundle(url: bundleURL)
    }

    @objc private func captureText() {
        controller.captureNow()
    }

    func openSettingsFromCommand() {
        controller.openSettings()
    }

    @objc private func openSettings() {
        openSettingsFromCommand()
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
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    delegate.openSettingsFromCommand()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
