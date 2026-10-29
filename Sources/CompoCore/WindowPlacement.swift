import Foundation
import CoreGraphics

public enum WindowPlacement {
    public static func isValid(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0
    }

    public static func matches(_ first: CGRect, _ second: CGRect, tolerance: CGFloat = 2) -> Bool {
        isValid(first) && isValid(second)
            && abs(first.minX - second.minX) <= tolerance && abs(first.minY - second.minY) <= tolerance
            && abs(first.width - second.width) <= tolerance && abs(first.height - second.height) <= tolerance
    }

    /// Bounded writes: skip unchanged frames and correct origin shifts caused by resizing.
    @discardableResult
    public static func apply(_ target: CGRect, read: () -> CGRect?,
                             resize: (CGSize) -> Bool, move: (CGPoint) -> Bool) -> Bool {
        guard isValid(target), let initial = read(), isValid(initial) else { return false }
        if matches(initial, target) { return true }
        var succeeded = true
        let needsResize = abs(initial.width - target.width) > 2 || abs(initial.height - target.height) > 2
        if needsResize { succeeded = resize(target.size) && succeeded }
        guard let resized = read(), isValid(resized) else { return false }
        if abs(resized.minX - target.minX) > 2 || abs(resized.minY - target.minY) > 2 {
            succeeded = move(target.origin) && succeeded
        }
        guard let moved = read(), isValid(moved) else { return false }
        // A display crossing can change size limits. Do not repeatedly request a rejected minimum size.
        if moved.size != resized.size && (abs(moved.width - target.width) > 2 || abs(moved.height - target.height) > 2) {
            succeeded = resize(target.size) && succeeded
        }
        guard let final = read(), isValid(final) else { return false }
        if abs(final.minX - target.minX) > 2 || abs(final.minY - target.minY) > 2 {
            succeeded = move(target.origin) && succeeded
        }
        return succeeded
    }

    public static func minimumSize(requested: CGRect, actual: CGRect, previous: CGSize = .zero) -> CGSize {
        guard isValid(requested), isValid(actual) else { return previous }
        return CGSize(width: actual.width > requested.width + 2 ? max(previous.width, actual.width) : previous.width,
                      height: actual.height > requested.height + 2 ? max(previous.height, actual.height) : previous.height)
    }

    public static func visible(_ current: CGRect, previous: CGRect?, targets: [CGRect] = [], among frames: [CGRect]) -> Bool {
        ([current] + (previous.map { [$0] } ?? []) + targets).contains { candidate in
            frames.contains { matches(candidate, $0, tolerance: 3) }
        }
    }

    public static func displayIndex(for frame: CGRect, in screens: [CGRect]) -> Int? {
        guard isValid(frame), !screens.isEmpty else { return nil }
        var best: Int?
        var bestArea: CGFloat = -1
        var bestDistance = CGFloat.infinity
        for (index, screen) in screens.enumerated() where isValid(screen) {
            let intersection = screen.intersection(frame)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            let dx = frame.midX - min(max(frame.midX, screen.minX), screen.maxX)
            let dy = frame.midY - min(max(frame.midY, screen.minY), screen.maxY)
            let distance = hypot(dx, dy)
            if area > bestArea || (area == bestArea && distance < bestDistance) {
                best = index; bestArea = area; bestDistance = distance
            }
        }
        return best
    }
}
