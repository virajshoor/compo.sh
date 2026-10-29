import Foundation

public enum WindowDrag {
    public static func isMove(original: CGRect, current: CGRect, pointerStart: CGPoint,
                              pointer: CGPoint, hasDragged: Bool) -> Bool {
        hasDragged
            && hypot(pointer.x - pointerStart.x, pointer.y - pointerStart.y) > 5
            && abs(current.width - original.width) < 4
            && abs(current.height - original.height) < 4
            && hypot(current.minX - original.minX, current.minY - original.minY) > 5
    }
}
