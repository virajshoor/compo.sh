import Foundation

/// Retain the chosen layout when it fits; otherwise try rows, columns, and grids with learned size limits.
public enum FittingLayout {
    public static func frames(preferred: [CGRect], minimums: [CGSize], in bounds: CGRect, gap: CGFloat) -> [CGRect]? {
        guard preferred.count == minimums.count, preferred.allSatisfy(WindowPlacement.isValid),
              WindowPlacement.isValid(bounds), gap.isFinite,
              minimums.allSatisfy({ $0.width.isFinite && $0.height.isFinite && $0.width >= 0 && $0.height >= 0 }) else { return nil }
        guard !preferred.isEmpty else { return [] }
        let gap = max(0, min(gap, min(bounds.width, bounds.height) / 8))
        let area = bounds.insetBy(dx: gap, dy: gap)
        func fits(_ frames: [CGRect]) -> Bool {
            frames.enumerated().allSatisfy { i, frame in
                WindowPlacement.isValid(frame) && area.insetBy(dx: -0.01, dy: -0.01).contains(frame)
                    && frame.width + 0.01 >= minimums[i].width && frame.height + 0.01 >= minimums[i].height
                    && frames.dropFirst(i + 1).allSatisfy { other in
                        frame.maxX <= other.minX + 0.01 || other.maxX <= frame.minX + 0.01
                            || frame.maxY <= other.minY + 0.01 || other.maxY <= frame.minY + 0.01
                    }
            }
        }
        if fits(preferred) { return preferred }
        var candidates: [[CGRect]] = []
        for columns in 1...preferred.count {
            let rows = (preferred.count + columns - 1) / columns
            var widths = Array(repeating: CGFloat(1), count: columns)
            var heights = Array(repeating: CGFloat(1), count: rows)
            var desiredWidths = widths, desiredHeights = heights
            for i in preferred.indices {
                widths[i % columns] = max(widths[i % columns], minimums[i].width)
                heights[i / columns] = max(heights[i / columns], minimums[i].height)
                desiredWidths[i % columns] = max(desiredWidths[i % columns], preferred[i].width)
                desiredHeights[i / columns] = max(desiredHeights[i / columns], preferred[i].height)
            }
            guard let w = allocate(widths, preferred: desiredWidths, length: area.width, gap: gap),
                  let h = allocate(heights, preferred: desiredHeights, length: area.height, gap: gap) else { continue }
            let frames = preferred.indices.map { i in
                CGRect(x: area.minX + w.prefix(i % columns).reduce(0, +) + CGFloat(i % columns) * gap,
                       y: area.minY + h.prefix(i / columns).reduce(0, +) + CGFloat(i / columns) * gap,
                       width: w[i % columns], height: h[i / columns])
            }
            if fits(frames) { candidates.append(frames) }
        }
        func distance(_ frames: [CGRect]) -> CGFloat {
            zip(frames, preferred).reduce(0) { sum, pair in
                let (frame, original) = pair
                return sum + abs(frame.midX - original.midX) + abs(frame.midY - original.midY)
                    + abs(frame.width - original.width) + abs(frame.height - original.height)
            }
        }
        if let grid = candidates.min(by: { distance($0) < distance($1) }) { return grid }
        return partition(preferred: preferred, minimums: minimums, area: area, gap: gap)
    }

    private indirect enum Partition {
        case window(Int, CGSize)
        case split(Bool, CGSize, Partition, Partition)

        var size: CGSize {
            switch self {
            case .window(_, let size), .split(_, let size, _, _): return size
            }
        }

        func place(in bounds: CGRect, gap: CGFloat, into frames: inout [CGRect]) {
            switch self {
            case .window(let index, _): frames[index] = bounds
            case .split(let horizontal, _, let first, let second):
                let available = (horizontal ? bounds.width : bounds.height) - gap
                let a = horizontal ? first.size.width : first.size.height
                let b = horizontal ? second.size.width : second.size.height
                let length = a + (available - a - b) / 2
                var left = bounds, right = bounds
                if horizontal {
                    left.size.width = length; right.origin.x += length + gap; right.size.width -= length + gap
                } else {
                    left.size.height = length; right.origin.y += length + gap; right.size.height -= length + gap
                }
                first.place(in: left, gap: gap, into: &frames)
                second.place(in: right, gap: gap, into: &frames)
            }
        }
    }

    private static func partition(preferred: [CGRect], minimums: [CGSize], area: CGRect, gap: CGFloat) -> [CGRect]? {
        // shortcut: ordered slicing layouts, not exhaustive rectangle packing; expand if valid layouts remain rejected.
        var plans: [Range<Int>: [Partition]] = [:]
        for i in minimums.indices {
            plans[i..<i+1] = [.window(i, CGSize(width: max(1, minimums[i].width), height: max(1, minimums[i].height)))]
        }
        guard minimums.count > 1 else { return nil }
        for length in 2...minimums.count {
            for start in 0...(minimums.count - length) {
                let end = start + length
                var choices: [Partition] = []
                for split in (start+1)..<end {
                    for first in plans[start..<split] ?? [] {
                        for second in plans[split..<end] ?? [] {
                            for horizontal in [true, false] {
                                let size = CGSize(width: horizontal ? first.size.width + gap + second.size.width : max(first.size.width, second.size.width),
                                                  height: horizontal ? max(first.size.height, second.size.height) : first.size.height + gap + second.size.height)
                                guard size.width <= area.width, size.height <= area.height,
                                      !choices.contains(where: { $0.size.width <= size.width && $0.size.height <= size.height }) else { continue }
                                choices.removeAll { $0.size.width >= size.width && $0.size.height >= size.height }
                                choices.append(.split(horizontal, size, first, second))
                            }
                        }
                    }
                }
                plans[start..<end] = choices
            }
        }
        guard let plan = plans[0..<minimums.count]?.min(by: { $0.size.width * $0.size.height < $1.size.width * $1.size.height }) else { return nil }
        var frames = preferred
        plan.place(in: area, gap: gap, into: &frames)
        return frames
    }

    private static func allocate(_ minimums: [CGFloat], preferred: [CGFloat], length: CGFloat, gap: CGFloat) -> [CGFloat]? {
        let available = length - CGFloat(minimums.count - 1) * gap
        let remaining = available - minimums.reduce(0, +)
        guard remaining >= 0 else { return nil }
        let weights = zip(preferred, minimums).map { max(0, $0 - $1) }
        let total = weights.reduce(0, +)
        return minimums.indices.map { i in
            minimums[i] + remaining * (total > 0 ? weights[i] / total : 1 / CGFloat(minimums.count))
        }
    }
}
