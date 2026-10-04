import CoreGraphics
import Darwin
import Foundation

enum IOHIDSwipePayload {
    private static let payloadFieldTag = 0x106D
    private static let serializedFormatVersion: [UInt8] = [0, 0, 0, 2]
    private static let fluidTouchGestureType: UInt32 = 23
    private static let velocityEventType: UInt32 = 9
    private static let dockPrimaryFlavor: UInt16 = 3

    static func attach(to event: CGEvent) -> CGEvent? {
        guard let serialized = event.data else { return nil }
        var bytes = [UInt8](serialized as Data)
        guard bytes.starts(with: serializedFormatVersion) else { return nil }
        let payload = build(for: event)
        bytes.append(contentsOf: bigEndianBytes(UInt16(payload.count)))
        bytes.append(contentsOf: bigEndianBytes(UInt16(payloadFieldTag)))
        bytes.append(contentsOf: payload)
        return CGEvent(withDataAllocator: nil, data: Data(bytes) as CFData)
    }

    private static func build(for event: CGEvent) -> [UInt8] {
        let phase = event.getIntegerValueField(DockSwipeEvent.phase)
        let velocityX = event.getDoubleValueField(DockSwipeEvent.swipeVelocityX)
        let velocityY = event.getDoubleValueField(DockSwipeEvent.swipeVelocityY)
        let includesVelocity = velocityX != 0 || velocityY != 0 || phase == DockSwipeEvent.Phase.ended.rawValue
        let timestamp = event.timestamp != 0 ? event.timestamp : mach_absolute_time()

        var writer = LittleEndianWriter()
        writer.write(timestamp)
        writer.write(UInt64(0))
        writer.write(UInt32(0))
        writer.write(UInt32(0))
        writer.write(UInt32(includesVelocity ? 2 : 1))

        writer.write(UInt32(40))
        writer.write(fluidTouchGestureType)
        writer.write((UInt32(truncatingIfNeeded: phase) & 0xFF) << 24)
        writer.write(UInt32(0))
        writer.write(fixed16_16(event.getDoubleValueField(DockSwipeEvent.swipePositionX)))
        writer.write(fixed16_16(event.getDoubleValueField(DockSwipeEvent.swipePositionY)))
        writer.write(Int32(0))
        writer.write(UInt32(truncatingIfNeeded: event.getIntegerValueField(DockSwipeEvent.swipeMask)))
        writer.write(UInt16(truncatingIfNeeded: event.getIntegerValueField(DockSwipeEvent.swipeMotion)))
        writer.write(dockPrimaryFlavor)
        writer.write(fixed16_16(event.getDoubleValueField(DockSwipeEvent.swipeProgress)))

        if includesVelocity {
            writer.write(UInt32(28))
            writer.write(velocityEventType)
            writer.write(UInt32(0))
            writer.write(UInt32(1))
            writer.write(fixed16_16(velocityX))
            writer.write(fixed16_16(velocityY))
            writer.write(Int32(0))
        }
        return writer.bytes
    }

    private static func fixed16_16(_ value: Double) -> Int32 {
        let fixed = Int32(truncatingIfNeeded: Int64(value * 65536))
        guard fixed == 0, value != 0 else { return fixed }
        return value > 0 ? 1 : -1
    }

    private static func bigEndianBytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0xFF)]
    }
}

private struct LittleEndianWriter {
    private(set) var bytes: [UInt8] = []

    mutating func write<Value: FixedWidthInteger>(_ value: Value) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }
}
