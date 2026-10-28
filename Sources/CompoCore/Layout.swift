import Foundation
import CoreGraphics

public enum Layout: String, CaseIterable, Identifiable {
    case stack = "Stack", columns = "Columns", rows = "Rows"
    public var id: String { rawValue }

    public func frames(count: Int, in bounds: CGRect, gap: CGFloat, ratio: CGFloat) -> [CGRect] {
        guard count > 0, bounds.width > 0, bounds.height > 0 else { return [] }
        let gap = max(0, min(gap, min(bounds.width, bounds.height) / 8))
        let area = bounds.insetBy(dx: gap, dy: gap)
        if count == 1 { return [area] }
        switch self {
        case .columns: return Self.split(area, count: count, gap: gap, horizontal: true)
        case .rows: return Self.split(area, count: count, gap: gap, horizontal: false)
        case .stack:
            let width = (area.width - gap) * max(0.25, min(ratio, 0.75))
            let master = CGRect(x: area.minX, y: area.minY, width: width, height: area.height)
            let stack = CGRect(x: master.maxX + gap, y: area.minY,
                               width: area.width - width - gap, height: area.height)
            return [master] + Self.split(stack, count: count - 1, gap: gap, horizontal: false)
        }
    }

    private static func split(_ area: CGRect, count: Int, gap: CGFloat, horizontal: Bool) -> [CGRect] {
        let length = horizontal ? area.width : area.height
        // Keep frames valid even when more windows fit than the requested gaps allow.
        let spacing = min(gap, length / CGFloat(count * 2))
        let size = (length - CGFloat(count - 1) * spacing) / CGFloat(count)
        return (0..<count).map { index in
            let offset = CGFloat(index) * (size + spacing)
            return horizontal
                ? CGRect(x: area.minX + offset, y: area.minY, width: size, height: area.height)
                : CGRect(x: area.minX, y: area.minY + offset, width: area.width, height: size)
        }
    }
}

public enum Direction: Equatable {
    case left, right, up, down

    public func neighbor(from source: CGRect, among frames: [CGRect]) -> Int? {
        frames.enumerated().compactMap { index, frame -> (Int, CGFloat)? in
            let dx = frame.midX - source.midX, dy = frame.midY - source.midY
            let forward: CGFloat
            let sideways: CGFloat
            switch self {
            case .left: (forward, sideways) = (-dx, abs(dy))
            case .right: (forward, sideways) = (dx, abs(dy))
            case .up: (forward, sideways) = (-dy, abs(dx))
            case .down: (forward, sideways) = (dy, abs(dx))
            }
            guard forward > 1 else { return nil }
            return (index, forward + sideways * 2)
        }.min { $0.1 < $1.1 }?.0
    }
}
