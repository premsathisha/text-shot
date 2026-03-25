import AppKit
import Testing
@testable import TextShotSettings

private final class StubMenuTarget: NSObject {
    @objc func capture() {}
    @objc func settings() {}
    @objc func quit() {}
}

@MainActor
private final class FakeUpdateManager: NSObject, UpdateManaging {
    let canCheckForUpdates = true
    let canConfigureAutomaticChecks = true
    let statusDescription = "Updates are available in this build."
    let updateTarget = NSObject()
    private(set) var configuredMenuItem: NSMenuItem?
    private(set) var checkCallCount = 0
    var automaticallyChecksForUpdates = true

    func configure(checkForUpdatesMenuItem: NSMenuItem) {
        configuredMenuItem = checkForUpdatesMenuItem
        checkForUpdatesMenuItem.target = updateTarget
        checkForUpdatesMenuItem.action = #selector(NSObject.description)
        checkForUpdatesMenuItem.isEnabled = true
    }

    func checkForUpdates() {
        checkCallCount += 1
    }
}

private func makeInfoDictionary(feedURL: String? = nil, publicEDKey: String? = nil) -> [String: Any] {
    var info: [String: Any] = [:]
    if let feedURL {
        info["SUFeedURL"] = feedURL
    }
    if let publicEDKey {
        info["SUPublicEDKey"] = publicEDKey
    }
    return info
}

@Test
func updateConfigurationRequiresFeedAndPublicKey() {
    #expect(!UpdateConfiguration.from(infoDictionary: makeInfoDictionary()).isEnabled)
    #expect(!UpdateConfiguration.from(infoDictionary: makeInfoDictionary(feedURL: "https://premsathisha.github.io/text-shot/dist-appcast/appcast.xml")).isEnabled)
    #expect(!UpdateConfiguration.from(infoDictionary: makeInfoDictionary(publicEDKey: "public-key")).isEnabled)
    #expect(UpdateConfiguration.from(infoDictionary: makeInfoDictionary(feedURL: "https://premsathisha.github.io/text-shot/dist-appcast/appcast.xml", publicEDKey: "public-key")).isEnabled)
}

@MainActor
@Test
func disabledUpdateManagerDisablesMenuItem() {
    let menuItem = NSMenuItem(title: StatusMenuBuilder.checkForUpdatesTitle, action: nil, keyEquivalent: "")

    let manager = DisabledUpdateManager(configuration: UpdateConfiguration(feedURL: nil, publicEDKey: nil))
    manager.configure(checkForUpdatesMenuItem: menuItem)

    #expect(menuItem.target == nil)
    #expect(menuItem.action == nil)
    #expect(menuItem.isEnabled == false)
    #expect(manager.canConfigureAutomaticChecks == false)
    #expect(manager.automaticallyChecksForUpdates == false)
    #expect(manager.statusDescription.contains("unavailable"))
}

@MainActor
@Test
func statusMenuBuilderLeavesUpdateMenuTargetOwnedByUpdateManager() {
    let target = StubMenuTarget()
    let updateManager = FakeUpdateManager()

    let menu = StatusMenuBuilder.makeMenu(
        target: target,
        updateManager: updateManager,
        captureAction: #selector(StubMenuTarget.capture),
        openSettingsAction: #selector(StubMenuTarget.settings),
        quitAction: #selector(StubMenuTarget.quit)
    )

    let titles = menu.items.map(\.title)
    #expect(titles.contains(StatusMenuBuilder.checkForUpdatesTitle))

    guard let updateItem = menu.items.first(where: { $0.title == StatusMenuBuilder.checkForUpdatesTitle }) else {
        Issue.record("Missing Check for Updates menu item")
        return
    }

    #expect(updateItem.target === updateManager.updateTarget)
    #expect(updateManager.configuredMenuItem === updateItem)
    #expect(updateItem.image != nil)
}
