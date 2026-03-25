import AppKit
import Foundation
import Sparkle

@MainActor
final class TextShotUpdateUserDriver: SPUStandardUserDriver {
    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    }

    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        let reason = noUpdateReason(from: nsError)

        guard reason == .onLatestVersion || reason == .onNewerThanLatestVersion else {
            super.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
            return
        }

        let latestAppcastItem = nsError.userInfo[SPULatestAppcastItemFoundKey] as? SUAppcastItem
        let displayedVersion = latestAppcastItem?.displayVersionString.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let version = displayedVersion.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackVersion ?? "Unknown"

        TextShotUpToDateAlert.present(version: version)
        acknowledgement()
    }

    private func noUpdateReason(from error: NSError) -> SPUNoUpdateFoundReason? {
        guard let rawReason = error.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber else {
            return nil
        }

        return SPUNoUpdateFoundReason(rawValue: rawReason.int32Value)
    }
}

@MainActor
enum TextShotUpToDateAlert {
    static func present(version: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "You're up to date!"
        alert.informativeText = "Text Shot \(version) is currently the newest version available."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
