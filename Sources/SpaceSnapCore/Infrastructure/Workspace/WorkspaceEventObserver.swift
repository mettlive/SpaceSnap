import AppKit

@MainActor
public final class WorkspaceEventObserver {
    private let center = NSWorkspace.shared.notificationCenter
    private var observers: [NSObjectProtocol] = []

    public init(
        onSpaceChange: @escaping @MainActor () -> Void,
        onAppActivation: @escaping @MainActor (pid_t?) -> Void
    ) {
        observers = [
            center.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                MainActor.assumeIsolated { onSpaceChange() }
            },
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: nil
            ) { notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let processID = app?.processIdentifier
                MainActor.assumeIsolated { onAppActivation(processID) }
            },
        ]
    }

    isolated deinit {
        observers.forEach(center.removeObserver)
    }
}
