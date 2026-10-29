import Foundation

/// One resize request can teach a minimum once; later user/app resizing cannot change that result.
public struct ResizeFeedback {
    public let target: CGRect
    private let issuedAt: TimeInterval
    private var sample: CGRect?
    private var sampledAt: TimeInterval?
    public private(set) var finished = false

    public init(target: CGRect, issuedAt: TimeInterval) {
        self.target = target
        self.issuedAt = issuedAt
    }

    public mutating func minimum(actual: CGRect, now: TimeInterval, previous: CGSize) -> CGSize? {
        guard !finished, now - issuedAt >= 0.25 else { return nil }
        if now - issuedAt > 2 { finished = true; return nil }
        guard WindowPlacement.isValid(actual) else { return nil }
        if let sampledAt, now - sampledAt < 0.2 { return nil }
        defer { sample = actual; sampledAt = now }
        guard let sample, WindowPlacement.matches(sample, actual) else { return nil }
        finished = true
        // A moved window is no longer a reliable response to our resize request.
        guard abs(actual.minX - target.minX) <= 2, abs(actual.minY - target.minY) <= 2 else { return nil }
        return WindowPlacement.minimumSize(requested: target, actual: actual, previous: previous)
    }
}
