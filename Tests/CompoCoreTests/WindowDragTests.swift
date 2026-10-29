import XCTest
@testable import CompoCore

final class WindowDragTests: XCTestCase {
    func testOnlyActualWindowDragCanPlaceWindows() {
        let original = CGRect(x: 0, y: 0, width: 600, height: 800)
        let moved = original.offsetBy(dx: 100, dy: 0)
        let start = CGPoint(x: 200, y: 100)
        let end = CGPoint(x: 300, y: 100)
        // Activation can change a frame between mouse-down and mouse-up.
        XCTAssertFalse(WindowDrag.isMove(original: original, current: moved,
            pointerStart: start, pointer: end, hasDragged: false))
        XCTAssertFalse(WindowDrag.isMove(original: original, current: moved,
            pointerStart: start, pointer: start, hasDragged: true))
        XCTAssertFalse(WindowDrag.isMove(original: original, current: original,
            pointerStart: start, pointer: end, hasDragged: true))
        XCTAssertFalse(WindowDrag.isMove(original: original, current: CGRect(x: 100, y: 0, width: 650, height: 800),
            pointerStart: start, pointer: end, hasDragged: true))
        XCTAssertTrue(WindowDrag.isMove(original: original, current: moved,
            pointerStart: start, pointer: end, hasDragged: true))
    }
}
