import Foundation

public enum WindowDrag {
    public static func isMove(original: CGRect, current: CGRect, pointerStart: CGPoint,
                              pointer: CGPoint, hasDragged: Bool) -> Bool {
        hasDragged
            && hypot(pointer.x - pointerStart.x, pointer.y - pointerStart.y) > 5
            && abs(current.width - original.width) < 4
            && abs(current.height - original.height) < 4
            && hypot(current.minX - original.minX, current.minY - original.minY) > 5
            // Restored/activated windows can move during a content drag without following the pointer.
            && hypot((current.minX - original.minX) - (pointer.x - pointerStart.x),
                     (current.minY - original.minY) - (pointer.y - pointerStart.y)) <= 32
    }
}
