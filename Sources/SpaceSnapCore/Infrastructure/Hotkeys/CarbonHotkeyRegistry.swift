import Carbon.HIToolbox

@MainActor
public final class CarbonHotkeyRegistry {
    private struct Registration {
        let reference: EventHotKeyRef
        let target: SwitchTarget
    }

    private static let signature: OSType = 0x5350_534E

    private let onHotkey: @MainActor (SwitchTarget) -> Void
    private var handler: EventHandlerRef?
    private var registrations: [UInt32: Registration] = [:]

    public init(onHotkey: @escaping @MainActor (SwitchTarget) -> Void) {
        self.onHotkey = onHotkey
    }

    public func register(_ actions: [KeyCombo: SwitchTarget]) -> Set<KeyCombo> {
        installHandlerIfNeeded()
        unregisterAll()
        var failed = Set<KeyCombo>()
        for (offset, (combo, target)) in actions.enumerated() {
            let id = UInt32(offset + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(combo.keyCode),
                Self.carbonModifiers(combo.modifiers),
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                registrations[id] = Registration(reference: reference, target: target)
            } else {
                failed.insert(combo)
            }
        }
        return failed
    }

    public func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.reference)
        }
        registrations.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let registry = Unmanaged<CarbonHotkeyRegistry>.fromOpaque(userData).takeUnretainedValue()
                let identifier = hotKeyID.id
                return MainActor.assumeIsolated { registry.dispatch(identifier) }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    private func dispatch(_ identifier: UInt32) -> OSStatus {
        guard let registration = registrations[identifier] else { return OSStatus(eventNotHandledErr) }
        onHotkey(registration.target)
        return noErr
    }

    private static func carbonModifiers(_ modifiers: KeyModifiers) -> UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }
}
