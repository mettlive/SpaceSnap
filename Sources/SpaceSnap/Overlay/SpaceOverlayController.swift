import AppKit
import SwiftUI
import SpaceSnapCore

@MainActor
final class SpaceOverlayController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<SpaceOverlayView>
    private var hideTask: Task<Void, Never>?

    init() {
        let hostingView = NSHostingView(rootView: SpaceOverlayView(displaySpaces: nil))
        hostingView.frame = NSRect(x: 0, y: 0, width: 180, height: 120)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = hostingView
        panel.alphaValue = 0

        self.panel = panel
        self.hostingView = hostingView
    }

    func show(_ landing: DisplaySpaces) {
        hideTask?.cancel()
        hostingView.rootView = SpaceOverlayView(displaySpaces: landing)

        if let screen = DisplayLocator.screen(forDisplayID: landing.displayID) {
            center(on: screen)
        }

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.panel.animator().alphaValue = 0
            }
        }
    }

    private func center(on screen: NSScreen) {
        let frame = panel.frame
        let origin = CGPoint(
            x: screen.frame.midX - frame.width / 2,
            y: screen.frame.midY - frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
