import AppKit
import Foundation

@MainActor
final class AppRelocator {
    typealias OpenApplicationHandler = @MainActor (URL, NSWorkspace.OpenConfiguration, @escaping @Sendable (NSRunningApplication?, Error?) -> Void) -> Void

    private let fm: FileManager
    private let openApplication: OpenApplicationHandler

    init(
        fileManager: FileManager = .default,
        openApplication: @escaping OpenApplicationHandler = { url, configuration, completion in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: completion)
        }
    ) {
        self.fm = fileManager
        self.openApplication = openApplication
    }

    @discardableResult
    func promptToMoveIfNeeded() -> Bool {
        guard shouldPromptForMove() else { return false }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Move Text Shot to Applications?"
        alert.informativeText = "Installing Text Shot in Applications keeps it available after updates and prevents running from a temporary location."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Keep Here")

        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return moveAndRelaunch()
    }

    private func shouldPromptForMove() -> Bool {
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let path = bundleURL.path

        if path.hasPrefix("/Applications/") {
            return false
        }

        let userApplications = NSHomeDirectory() + "/Applications/"
        if path.hasPrefix(userApplications) {
            return false
        }

        return Bundle.main.bundlePath.hasSuffix(".app")
    }

    private func moveAndRelaunch() -> Bool {
        let sourceURL = Bundle.main.bundleURL
        let destinationURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(sourceURL.lastPathComponent)

        do {
            let finalURL = try relocateAppBundle(from: sourceURL, to: destinationURL)

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            openApplication(finalURL, config) { _, _ in
                Task { @MainActor in
                    NSApp.terminate(nil)
                }
            }
            return true
        } catch {
            let errorAlert = NSAlert()
            errorAlert.alertStyle = .warning
            errorAlert.messageText = "Could not move Text Shot"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.runModal()
            return false
        }
    }

    @discardableResult
    func relocateAppBundle(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        let stagingURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).staged")
        let backupName = ".\(destinationURL.lastPathComponent).backup"
        let backupURL = destinationURL.deletingLastPathComponent().appendingPathComponent(backupName)

        try? fm.removeItem(at: stagingURL)
        try? fm.removeItem(at: backupURL)

        do {
            try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: sourceURL, to: stagingURL)

            if fm.fileExists(atPath: destinationURL.path) {
                let resultingURL = try fm.replaceItemAt(
                    destinationURL,
                    withItemAt: stagingURL,
                    backupItemName: backupName,
                    options: []
                )
                try? fm.removeItem(at: backupURL)
                return resultingURL ?? destinationURL
            }

            try fm.moveItem(at: stagingURL, to: destinationURL)
            return destinationURL
        } catch {
            try? fm.removeItem(at: stagingURL)
            throw error
        }
    }
}
