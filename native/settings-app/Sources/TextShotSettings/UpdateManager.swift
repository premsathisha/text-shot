import AppKit
import Foundation
import Sparkle

@MainActor
protocol UpdateManaging: AnyObject {
    var canCheckForUpdates: Bool { get }
    var canConfigureAutomaticChecks: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var statusDescription: String { get }

    func configure(checkForUpdatesMenuItem: NSMenuItem)
    func checkForUpdates()
}

struct UpdateConfiguration: Equatable {
    let feedURL: URL?
    let publicEDKey: String?

    var isEnabled: Bool {
        feedURL != nil && publicEDKey != nil
    }

    static func from(bundle: Bundle) -> UpdateConfiguration {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func from(infoDictionary: [String: Any]) -> UpdateConfiguration {
        let feedURL = (infoDictionary["SUFeedURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let publicEDKey = (infoDictionary["SUPublicEDKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return UpdateConfiguration(
            feedURL: feedURL.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            publicEDKey: publicEDKey.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

@MainActor
enum UpdateManagerFactory {
    static func make(bundle: Bundle = .main) -> UpdateManaging {
        let configuration = UpdateConfiguration.from(bundle: bundle)
        guard configuration.isEnabled else {
            return DisabledUpdateManager(configuration: configuration)
        }

        return SparkleUpdateManager()
    }
}

@MainActor
final class DisabledUpdateManager: UpdateManaging {
    let canCheckForUpdates = false
    let canConfigureAutomaticChecks = false
    let statusDescription: String

    init(configuration: UpdateConfiguration? = nil) {
        if let configuration {
            if configuration.feedURL == nil && configuration.publicEDKey == nil {
                statusDescription = "Updates are unavailable in this build. The app was built without a Sparkle feed URL or public update key."
            } else if configuration.feedURL == nil {
                statusDescription = "Updates are unavailable in this build. The app is missing a Sparkle feed URL."
            } else {
                statusDescription = "Updates are unavailable in this build. The app is missing the Sparkle public update key."
            }
        } else {
            statusDescription = "Updates are unavailable in this build."
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get { false }
        set {}
    }

    func configure(checkForUpdatesMenuItem: NSMenuItem) {
        checkForUpdatesMenuItem.target = nil
        checkForUpdatesMenuItem.action = nil
        checkForUpdatesMenuItem.isEnabled = false
        checkForUpdatesMenuItem.toolTip = statusDescription
    }

    func checkForUpdates() {
    }
}

@MainActor
final class SparkleUpdateManager: NSObject, UpdateManaging, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private lazy var userDriver = TextShotUpdateUserDriver(hostBundle: .main, delegate: self)
    private lazy var updater: SPUUpdater = {
        SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: userDriver,
            delegate: self
        )
    }()
    let canConfigureAutomaticChecks = true
    let statusDescription = "Updates are available in this build."

    override init() {
        super.init()
        startUpdater()
        synchronizeAutomaticUpdatePreferencesIfNeeded()
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            updater.automaticallyChecksForUpdates = newValue
            updater.automaticallyDownloadsUpdates = newValue
        }
    }

    func configure(checkForUpdatesMenuItem: NSMenuItem) {
        checkForUpdatesMenuItem.target = self
        checkForUpdatesMenuItem.action = #selector(checkForUpdatesFromMenu(_:))
        checkForUpdatesMenuItem.isEnabled = true
        checkForUpdatesMenuItem.toolTip = nil
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    private func synchronizeAutomaticUpdatePreferencesIfNeeded() {
        if updater.automaticallyChecksForUpdates && !updater.automaticallyDownloadsUpdates {
            updater.automaticallyDownloadsUpdates = true
        }
    }

    private func startUpdater() {
        do {
            try updater.start()
            _ = updater.clearFeedURLFromUserDefaults()
        } catch {
            let description = (error as NSError).localizedDescription
            NSLog("Sparkle updater failed to start: %@", description)
        }
    }

    @objc private func checkForUpdatesFromMenu(_ sender: Any?) {
        checkForUpdates()
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        guard updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates else {
            return false
        }

        DispatchQueue.main.async {
            immediateInstallHandler()
        }
        return true
    }

    nonisolated func standardUserDriverShouldShowVersionHistory(for item: SUAppcastItem) -> Bool {
        false
    }
}
