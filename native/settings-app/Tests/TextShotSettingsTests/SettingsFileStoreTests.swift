import Foundation
import Testing
@testable import TextShotSettings

@Test
func settingsStoreRoundTripPreservesCurrentFields() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    let store = SettingsStoreV2(fileURL: fileURL)

    var initial = AppSettingsV2.defaults
    initial.lastPermissionPromptAt = 111
    _ = try store.save(initial)

    let saved = try store.update { settings in
        settings.hotkey = "Control+Alt+K"
        settings.launchAtLogin = true
        settings.showConfirmation = false
    }

    #expect(saved.hotkey == "Control+Alt+K")
    #expect(saved.launchAtLogin)
    #expect(saved.showConfirmation == false)
    #expect(saved.lastPermissionPromptAt == 111)
    #expect(saved.schemaVersion == AppSettingsV2.schemaVersionValue)

    let reread = store.load()
    #expect(reread == saved)
}

@Test
func settingsStoreLoadMissingFileReturnsDefaults() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    let store = SettingsStoreV2(fileURL: fileURL)

    #expect(store.load() == AppSettingsV2.defaults)
}

@Test
func settingsStoreSaveBlankHotkeyNormalizesToDefault() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    let store = SettingsStoreV2(fileURL: fileURL)

    var settings = AppSettingsV2.defaults
    settings.hotkey = "   "

    let saved = try store.save(settings)

    #expect(saved.hotkey == AppSettingsV2.defaults.hotkey)
    #expect(store.load().hotkey == AppSettingsV2.defaults.hotkey)
}

@Test
func settingsStoreLoadCorruptFileReturnsDefaults() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let fileURL = tempDir.appendingPathComponent("settings-v3.json")
    try Data("not-json".utf8).write(to: fileURL)

    let store = SettingsStoreV2(fileURL: fileURL)

    #expect(store.load() == AppSettingsV2.defaults)
}
