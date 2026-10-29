public struct DesktopSwitchQueue {
    private var pending: [Bool] = []
    private var readyAt: Double = 0

    public init() {}

    public var isEmpty: Bool { pending.isEmpty }

    public mutating func append(right: Bool) { pending.append(right) }

    public func delay(at now: Double) -> Double { max(0, readyAt - now) }

    public mutating func take(at now: Double) -> Bool? {
        guard !pending.isEmpty, now >= readyAt else { return nil }
        // Dock needs time to commit its Space metadata before the next gesture.
        readyAt = now + 0.45
        return pending.removeFirst()
    }
}
