import Foundation
import CoreGraphics

public enum SnapZone: CaseIterable {
    case left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight

    public static func detect(point: CGPoint, screen: CGRect, threshold: CGFloat) -> SnapZone? {
        guard screen.insetBy(dx: -1, dy: -1).contains(point) else { return nil }
        let distance = max(4, min(threshold, min(screen.width, screen.height) / 4))
        let left = point.x < screen.minX + distance, right = point.x > screen.maxX - distance
        let top = point.y < screen.minY + distance, bottom = point.y > screen.maxY - distance
        if top && left { return .topLeft }
        if top && right { return .topRight }
        if bottom && left { return .bottomLeft }
        if bottom && right { return .bottomRight }
        if left { return .left }; if right { return .right }
        if top { return .top }; if bottom { return .bottom }
        return nil
    }

    public func frame(in screen: CGRect, gap: CGFloat) -> CGRect {
        let gap = max(0, min(gap, min(screen.width, screen.height) / 8))
        let area = screen.insetBy(dx: gap, dy: gap)
        let w = (area.width - gap) / 2, h = (area.height - gap) / 2
        switch self {
        case .top: return area
        case .left: return CGRect(x: area.minX, y: area.minY, width: w, height: area.height)
        case .right: return CGRect(x: area.maxX - w, y: area.minY, width: w, height: area.height)
        case .bottom: return CGRect(x: area.minX, y: area.maxY - h, width: area.width, height: h)
        case .topLeft: return CGRect(x: area.minX, y: area.minY, width: w, height: h)
        case .topRight: return CGRect(x: area.maxX - w, y: area.minY, width: w, height: h)
        case .bottomLeft: return CGRect(x: area.minX, y: area.maxY - h, width: w, height: h)
        case .bottomRight: return CGRect(x: area.maxX - w, y: area.maxY - h, width: w, height: h)
        }
    }

    /// Largest adjacent rectangle; quarter snaps leave one quarter free rather than overlap.
    public func remainder(in screen: CGRect, gap: CGFloat) -> CGRect? {
        let own = frame(in: screen, gap: gap)
        let area = screen.insetBy(dx: gap, dy: gap)
        switch self {
        case .top: return nil
        case .left, .topLeft, .bottomLeft:
            return CGRect(x: own.maxX + gap, y: area.minY, width: area.maxX - own.maxX - gap, height: area.height)
        case .right, .topRight, .bottomRight:
            return CGRect(x: area.minX, y: area.minY, width: own.minX - area.minX - gap, height: area.height)
        case .bottom:
            return CGRect(x: area.minX, y: area.minY, width: area.width, height: own.minY - area.minY - gap)
        }
    }
}
