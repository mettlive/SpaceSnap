import CoreGraphics
import Foundation

@MainActor
final class CursorRouter {
    private static let restoreDelay: Duration = .milliseconds(150)
    private static let movedTolerance: CGFloat = 2

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
        let parked = CGPoint(x: bounds.midX, y: bounds.midY)
        originalLocation = original
        warp(to: parked)
        action()

        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: Self.restoreDelay)
            guard let self, !Task.isCancelled else { return }
            self.originalLocation = nil
            guard let now = CGEvent(source: nil)?.location,
                  abs(now.x - parked.x) <= Self.movedTolerance,
                  abs(now.y - parked.y) <= Self.movedTolerance
            else { return }
            self.warp(to: original)
        }
    }

    private func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
