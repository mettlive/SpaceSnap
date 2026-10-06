import SwiftUI
import Carbon.HIToolbox
import SpaceSnapCore

struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    let onRecordingChange: (Bool) -> Void
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(label)
                .frame(minWidth: 110)
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return "Press shortcut…" }
        guard let combo else { return "None" }
        return KeyComboFormatter.string(for: combo)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            process(event)
            return nil
        }
    }

    private func process(_ event: NSEvent) {
        let keyCode = event.keyCode
        if keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let modifierFlags = event.modifierFlags.intersection(NSEventModifierMapping.relevantFlags)
        if modifierFlags.isEmpty, keyCode == UInt16(kVK_Delete) || keyCode == UInt16(kVK_ForwardDelete) {
            combo = nil
            stopRecording()
            return
        }

        let modifiers = NSEventModifierMapping.keyModifiers(from: modifierFlags)
        guard modifiers.contains(.control) || modifiers.contains(.option) || modifiers.contains(.command) else {
            return
        }

        combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        stopRecording()
    }

    private func stopRecording() {
        guard isRecording else { return }
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        onRecordingChange(false)
    }
}
