import Foundation
import CoreGraphics

/// Undocumented Dock swipe protocol, adapted from noswoosh (MIT); see THIRD_PARTY_NOTICES.md.
public enum DesktopGesture {
    public static func supported(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion >= 27 || (version.majorVersion == 26 && version.minorVersion >= 6)
    }

    public static func targetIndex(current: Int, count: Int, right: Bool) -> Int? {
        guard current >= 0, current < count else { return nil }
        let target = current + (right ? 1 : -1)
        return target >= 0 && target < count ? target : nil
    }

    /// Build the complete sequence before posting anything: partial gestures can leave Dock mid-transition.
    public static func events(right: Bool, version: OperatingSystemVersion, naturalScrolling: Bool) -> [CGEvent]? {
        guard supported(version) else { return nil }
        let augmented = version.majorVersion >= 27
        let sign: Double = augmented ? (right ? -1 : 1) * (naturalScrolling ? 1 : -1) : (right ? 1 : -1)
        var events: [CGEvent] = []
        for phase: Int64 in [1, 2, 4] {
            guard let event = CGEvent(source: nil) else { return nil }
            let progress = sign * 0.0001
            let velocity = augmented ? (phase == 4 ? sign * 9999 : 0) : sign * 2000
            event.setIntegerValueField(field(55), value: 30)
            event.setIntegerValueField(field(110), value: 23)
            event.setIntegerValueField(field(123), value: 1)
            event.setIntegerValueField(field(132), value: phase)
            event.setDoubleValueField(field(124), value: progress)
            event.setDoubleValueField(field(129), value: velocity)
            if augmented {
                event.setDoubleValueField(field(125), value: 0.1)
                guard let data = event.data else { return nil }
                var bytes = [UInt8](data as Data)
                guard bytes.starts(with: [0, 0, 0, 2]) else { return nil }
                let payload = payload(timestamp: event.timestamp, phase: phase, progress: progress, velocity: velocity)
                bytes += [UInt8(payload.count >> 8), UInt8(payload.count & 255), 0x10, 0x6D]
                bytes += payload
                guard let dock = CGEvent(withDataAllocator: nil, data: Data(bytes) as CFData),
                      let companion = CGEvent(source: nil) else { return nil }
                companion.setIntegerValueField(field(55), value: 29)
                events += [dock, companion]
            } else {
                event.setDoubleValueField(field(130), value: velocity)
                events.append(event)
            }
        }
        return events
    }

    private static func field(_ raw: UInt32) -> CGEventField { unsafeBitCast(raw, to: CGEventField.self) }

    private static func payload(timestamp: UInt64, phase: Int64, progress: Double, velocity: Double) -> [UInt8] {
        var bytes: [UInt8] = []
        func put<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        func fixed(_ value: Double) -> Int32 {
            let result = Int32(value * 65536)
            return result == 0 && value != 0 ? (value > 0 ? 1 : -1) : result
        }
        let hasVelocity = velocity != 0 || phase == 4
        // Serialized IOHID queue header, fluid-touch record, optional velocity record.
        put(timestamp == 0 ? mach_absolute_time() : timestamp)
        put(UInt64(0)); put(UInt32(0)); put(UInt32(0)); put(UInt32(hasVelocity ? 2 : 1))
        put(UInt32(40)); put(UInt32(23)); put(UInt32(phase) << 24); put(UInt32(0))
        put(fixed(0.1)); put(Int32(0)); put(Int32(0)); put(UInt32(0))
        put(UInt16(1)); put(UInt16(3)); put(fixed(progress))
        if hasVelocity {
            put(UInt32(28)); put(UInt32(9)); put(UInt32(0)); put(UInt32(1))
            put(fixed(velocity)); put(Int32(0)); put(Int32(0))
        }
        return bytes
    }
}
