import Foundation

/// Deliberately accepts only fixed event names and numeric window indexes, never window content.
public struct DiagnosticLog {
    public enum Kind: String, Codable { case moved, resized, discovery, rejectedWrite, overlapRetry, overlapBlocked }
    public struct Entry: Codable {
        public let kind: Kind
        public let uptime: TimeInterval
        public let window: Int?
    }
    public private(set) var entries: [Entry] = []
    public init() {}
    public mutating func record(_ kind: Kind, at uptime: TimeInterval, window: Int? = nil) {
        guard uptime.isFinite else { return }
        entries.append(Entry(kind: kind, uptime: uptime, window: window))
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
    }
}
