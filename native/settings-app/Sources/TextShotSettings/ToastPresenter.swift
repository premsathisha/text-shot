import AppKit
import Foundation
import QuartzCore

@MainActor
protocol ToastPresenting {
    func show(_ message: String)
}

@MainActor
final class ToastPresenter {
    private let panel: NSPanel
    private let messageLabel = NSTextField(labelWithString: "")

    private var hideWorkItem: DispatchWorkItem?
    private var isVisible = false

    private let width: CGFloat = 250
    private let height: CGFloat = 92
    private let holdDuration: TimeInterval = 2.0
    private let enterDuration: TimeInterval = 0.14
    private let exitDuration: TimeInterval = 0.22
    private let cornerRadius: CGFloat = 14

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let root = makeRootView(frame: panel.contentView?.bounds ?? .zero)
        root.autoresizingMask = [.width, .height]

        messageLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.alignment = .center
        messageLabel.textColor = .labelColor
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentView: NSView
        if #available(macOS 26.0, *), let glassView = root as? NSGlassEffectView {
            contentView = NSView(frame: root.bounds)
            contentView.autoresizingMask = [.width, .height]
            glassView.contentView = contentView
        } else {
            contentView = root
        }

        contentView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        panel.contentView = root
        panel.alphaValue = 0
    }

    func show(_ message: String) {
        hideWorkItem?.cancel()

        messageLabel.stringValue = message
        positionPanel()

        panel.orderFrontRegardless()

        let targetFrame = panel.frame
        let startFrame = targetFrame.offsetBy(dx: 0, dy: -10)
        panel.setFrame(startFrame, display: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = enterDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }

        isVisible = true
        let hideItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = hideItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: hideItem)
    }

    private func hide() {
        guard isVisible else { return }
        let targetFrame = panel.frame.offsetBy(dx: 0, dy: 8)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = exitDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.panel.orderOut(nil)
                self.isVisible = false
            }
        }
    }

    private func positionPanel() {
        let display = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let frame = display?.visibleFrame else { return }

        let origin = NSPoint(
            x: frame.midX - (width / 2),
            y: frame.midY - (height / 2)
        )

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }

    private func makeRootView(frame: NSRect) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: frame)
            glassView.cornerRadius = cornerRadius
            glassView.style = .regular
            return glassView
        }

        let effectView = NSVisualEffectView(frame: frame)
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .withinWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        return effectView
    }
}

extension ToastPresenter: ToastPresenting {}
