import AppKit
import KeyboardShortcuts
import Testing
@testable import TextShotSettings

private final class StubHotkeyController: HotkeyManaging, HotkeyRecorderBindingProviding {
    var onHotkeyPressed: (() -> Void)?
    var onShortcutChanged: ((AppHotkeyShortcut?) -> Void)?
    var activeShortcut: AppHotkeyShortcut?
    let recorderName: KeyboardShortcuts.Name = .globalCaptureHotkey
    var recorderAvailabilityIssue: String?

    @discardableResult
    func apply(shortcut: AppHotkeyShortcut?) throws -> AppHotkeyShortcut? {
        try validateForRecorder(shortcut)
        activeShortcut = shortcut
        onShortcutChanged?(shortcut)
        return shortcut
    }

    @discardableResult
    func resetToDefault() throws -> AppHotkeyShortcut {
        activeShortcut = HotkeyManager.defaultShortcut
        onShortcutChanged?(activeShortcut)
        return HotkeyManager.defaultShortcut
    }

    func validateForRecorder(_ shortcut: AppHotkeyShortcut?) throws {
        try HotkeyManager.validateNoModifierRule(shortcut)
    }
}

@MainActor
private final class StubUpdateManager: UpdateManaging {
    var canCheckForUpdates: Bool
    var canConfigureAutomaticChecks: Bool
    var automaticallyChecksForUpdates: Bool
    var statusDescription: String
    private(set) var checkCallCount = 0

    init(
        canCheckForUpdates: Bool = false,
        canConfigureAutomaticChecks: Bool = false,
        automaticallyChecksForUpdates: Bool = false,
        statusDescription: String = "Updates unavailable"
    ) {
        self.canCheckForUpdates = canCheckForUpdates
        self.canConfigureAutomaticChecks = canConfigureAutomaticChecks
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.statusDescription = statusDescription
    }

    func configure(checkForUpdatesMenuItem: NSMenuItem) {
        checkForUpdatesMenuItem.isEnabled = canCheckForUpdates
    }

    func checkForUpdates() {
        checkCallCount += 1
    }
}

@MainActor
@Test
func launchToggleAppliesImmediatelyWhenSaveSucceeds() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: StubUpdateManager(),
        onApplySettings: { editable in .success(editable) }
    )

    model.launchAtLoginBinding.wrappedValue = true

    #expect(model.settings.launchAtLogin)
    #expect(model.errorMessage.isEmpty)
}

@MainActor
@Test
func launchToggleRollsBackWhenSaveFails() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: StubUpdateManager(),
        onApplySettings: { _ in .failure(.message("Failed to save settings")) }
    )

    model.launchAtLoginBinding.wrappedValue = true

    #expect(model.settings.launchAtLogin == AppSettingsV2.defaults.launchAtLogin)
    #expect(model.errorMessage == "Failed to save settings")
}

@MainActor
@Test
func syncHotkeyDisplayUpdatesHotkeyText() {
    let hotkeyController = StubHotkeyController()
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: StubUpdateManager(),
        onApplySettings: { editable in .success(editable) }
    )

    let shortcut = AppHotkeyShortcut(.k, modifiers: [.control, .option])
    model.syncHotkeyDisplay(with: shortcut)

    #expect(model.settings.hotkey == HotkeyManager.displayString(for: shortcut))
}

@MainActor
@Test
func recorderAvailabilityIssuePassesThroughController() {
    let hotkeyController = StubHotkeyController()
    hotkeyController.recorderAvailabilityIssue = "Missing recorder assets"

    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: StubUpdateManager(),
        onApplySettings: { editable in .success(editable) }
    )

    #expect(model.recorderAvailabilityIssue == "Missing recorder assets")
}

@MainActor
@Test
func updateStatusPassesThroughManager() {
    let hotkeyController = StubHotkeyController()
    let updateManager = StubUpdateManager(
        canCheckForUpdates: true,
        canConfigureAutomaticChecks: true,
        automaticallyChecksForUpdates: true,
        statusDescription: "Updates are available in this build."
    )

    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: updateManager,
        onApplySettings: { editable in .success(editable) }
    )

    #expect(model.canCheckForUpdates)
    #expect(model.canOpenUpdateInterface)
    #expect(model.canConfigureAutomaticUpdateChecks)
    #expect(model.automaticallyChecksForUpdates)
    #expect(model.updateStatusMessage == "Updates are available in this build.")
}

@MainActor
@Test
func updateInterfaceRemainsAvailableWhenSparkleIsConfigured() {
    let hotkeyController = StubHotkeyController()
    let updateManager = StubUpdateManager(
        canCheckForUpdates: false,
        canConfigureAutomaticChecks: true,
        automaticallyChecksForUpdates: true,
        statusDescription: "Updates are available in this build."
    )

    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: updateManager,
        onApplySettings: { editable in .success(editable) }
    )

    #expect(model.canOpenUpdateInterface)
}

@MainActor
@Test
func checkForUpdatesDelegatesToUpdateManager() {
    let hotkeyController = StubHotkeyController()
    let updateManager = StubUpdateManager(canCheckForUpdates: true)
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: updateManager,
        onApplySettings: { editable in .success(editable) }
    )

    model.checkForUpdates()

    #expect(updateManager.checkCallCount == 1)
}

@MainActor
@Test
func automaticUpdateChecksBindingUpdatesManagerImmediately() {
    let hotkeyController = StubHotkeyController()
    let updateManager = StubUpdateManager(
        canConfigureAutomaticChecks: true,
        automaticallyChecksForUpdates: true,
        statusDescription: "Updates are available in this build."
    )
    let model = SettingsViewModel(
        initialSettings: AppSettingsV2.defaults.editable,
        hotkeyController: hotkeyController,
        updateManager: updateManager,
        onApplySettings: { editable in .success(editable) }
    )

    model.automaticUpdateChecksBinding.wrappedValue = false

    #expect(updateManager.automaticallyChecksForUpdates == false)
    #expect(model.automaticallyChecksForUpdates == false)
}
