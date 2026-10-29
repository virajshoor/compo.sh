import Foundation

/// Event-triggered discovery: fast startup samples, then bounded retries for slow app launches.
public struct DiscoveryRetry {
    private var began: TimeInterval?

    public init() {}

    public mutating func begin(at now: TimeInterval) { began = now }

    public func nextDelay(at now: TimeInterval) -> TimeInterval? {
        guard let began, now >= began else { return nil }
        let elapsed = now - began
        guard elapsed < 60 else { return nil }
        return min(elapsed < 2 ? 0.25 : 1, 60 - elapsed)
    }
}
