import AppKit
import Foundation
import Sparkle

@MainActor
private final class ModalUpdatePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class TextShotUpdateUserDriver: SPUStandardUserDriver {
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

        TextShotUpToDateWindow.present(version: version)
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
enum TextShotUpToDateWindow {
    static func present(version: String) {
        NSApp.activate(ignoringOtherApps: true)

        let window = ModalUpdatePanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .modalPanel
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.center()

        let root = NSVisualEffectView(frame: window.contentView?.bounds ?? .zero)
        root.autoresizingMask = [.width, .height]
        root.material = .hudWindow
        root.state = .active
        root.blendingMode = .withinWindow
        root.wantsLayer = true
        root.layer?.cornerRadius = 26
        root.layer?.masksToBounds = true

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        content.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72)
        ])

        let titleLabel = NSTextField(wrappingLabelWithString: "You're up to date!")
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping

        let messageLabel = NSTextField(
            wrappingLabelWithString: "Text Shot \(version) is currently the newest version available."
        )
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .left
        messageLabel.maximumNumberOfLines = 3
        messageLabel.lineBreakMode = .byWordWrapping

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        final class ActionTarget: NSObject {
            let handler: () -> Void

            init(handler: @escaping () -> Void) {
                self.handler = handler
            }

            @objc func performAction(_ sender: Any?) {
                handler()
            }
        }

        var target: ActionTarget?
        let button = NSButton(title: "OK", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 17, weight: .semibold)
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 18
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 52),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])

        content.addArrangedSubview(iconView)
        content.addArrangedSubview(titleLabel)
        content.addArrangedSubview(messageLabel)
        content.addArrangedSubview(spacer)
        content.addArrangedSubview(button)

        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])

        window.contentView = root

        target = ActionTarget {
            NSApp.stopModal()
            window.orderOut(nil)
            target = nil
        }

        button.target = target
        button.action = #selector(ActionTarget.performAction(_:))
        window.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: window)
    }
}
