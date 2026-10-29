import XCTest
@testable import CompoCore

final class HotkeyPressTests: XCTestCase {
    func testHoldingShortcutSwitchesOnlyOnceDespiteRepeats() {
        var press = HotkeyPress()
        let accepted = (0..<100).filter { _ in press.update(id: 1, isPressed: true) }
        XCTAssertEqual(accepted.count, 1)
    }

    func testReleaseAllowsAnotherDeliberatePress() {
        var press = HotkeyPress()
        for _ in 0..<5 {
            XCTAssertTrue(press.update(id: 1, isPressed: true))
            XCTAssertFalse(press.update(id: 1, isPressed: true))
            XCTAssertFalse(press.update(id: 1, isPressed: false))
        }
    }

    func testOtherShortcutAndUnmatchedReleasesDoNotUnlockHeldKey() {
        var press = HotkeyPress()
        XCTAssertFalse(press.update(id: 2, isPressed: false))
        XCTAssertTrue(press.update(id: 1, isPressed: true))
        XCTAssertTrue(press.update(id: 2, isPressed: true))
        XCTAssertFalse(press.update(id: 2, isPressed: false))
        XCTAssertFalse(press.update(id: 1, isPressed: true))
        XCTAssertTrue(press.update(id: 2, isPressed: true))
    }
}
