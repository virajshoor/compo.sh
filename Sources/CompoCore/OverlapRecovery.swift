import Foundation

/// Wait for two settled observations, then permit one recovery per arrangement.
public struct OverlapRecovery {
    public enum Decision: Equatable { case clear, waiting, retry, blocked }
    private var sample: [CGRect] = []
    private var sampledAt: TimeInterval = 0
    private var retried = false
    public init() {}

    public mutating func observe(_ frames: [CGRect], at now: TimeInterval) -> Decision {
        let overlaps = frames.indices.contains { i in
            frames.indices.contains { j in
                guard j > i else { return false }
                let intersection = frames[i].intersection(frames[j])
                return !intersection.isNull && intersection.width > 2 && intersection.height > 2
            }
        }
        guard overlaps else { sample = []; return .clear }
        guard frames.count == sample.count,
              zip(frames, sample).allSatisfy({ WindowPlacement.matches($0, $1) }) else {
            sample = frames; sampledAt = now; return .waiting
        }
        guard now - sampledAt >= 0.2 else { return .waiting }
        guard !retried else { return .blocked }
        retried = true
        sample = []
        return .retry
    }
}
