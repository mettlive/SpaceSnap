import CoreGraphics
import Foundation

@MainActor
final class CursorRouter {
    private static let restoreDelay: Duration = .milliseconds(80)

    private var restoreTask: Task<Void, Never>?
    private var originalLocation: CGPoint?

    func route(toDisplay displayID: String?, during action: () -> Void) {
        guard let displayID,
              let current = CGEvent(source: nil)?.location,
              DisplayLocator.displayIDUnderCursor() != displayID,
              let bounds = DisplayLocator.bounds(ofDisplayID: displayID)
        else {
            action()
            return
        }

        let original = originalLocation ?? current
        originalLocation = original
        warp(to: CGPoint(x: bounds.midX, y: bounds.midY))
        action()

        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: Self.restoreDelay)
            guard let self, !Task.isCancelled else { return }
            self.warp(to: original)
            self.originalLocation = nil
        }
    }

    private func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
