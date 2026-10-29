import XCTest
@testable import CompoCore

final class DesktopSwitchQueueTests: XCTestCase {
    func testRapidTapsPreserveOrderWithModifiersHeld() {
        var press = HotkeyPress()
        var queue = DesktopSwitchQueue()
        let taps: [UInt32] = [1, 2, 1, 1, 2]
        for id in taps {
            if press.update(id: id, isPressed: true) { queue.append(right: id == 1) }
            XCTAssertFalse(press.update(id: id, isPressed: false))
        }
        XCTAssertEqual(queue.take(at: 0), true)
        XCTAssertNil(queue.take(at: 0.1))
        XCTAssertEqual(queue.delay(at: 0.1), 0.35, accuracy: 0.0001)
        XCTAssertEqual(queue.take(at: 0.5), false)
        XCTAssertEqual(queue.take(at: 1), true)
        XCTAssertEqual(queue.take(at: 1.5), true)
        XCTAssertEqual(queue.take(at: 2), false)
        XCTAssertTrue(queue.isEmpty)
    }

    func testHoldingKeyDoesNotEnqueueRepeatsButTappingSameKeyDoes() {
        var press = HotkeyPress()
        var queue = DesktopSwitchQueue()
        for _ in 0..<100 {
            if press.update(id: 1, isPressed: true) { queue.append(right: true) }
        }
        XCTAssertEqual(queue.take(at: 0), true)
        XCTAssertTrue(queue.isEmpty)
        for _ in 0..<3 {
            _ = press.update(id: 1, isPressed: false)
            if press.update(id: 1, isPressed: true) { queue.append(right: true) }
        }
        for time in [0.5, 1.0, 1.5] { XCTAssertEqual(queue.take(at: time), true) }
        XCTAssertTrue(queue.isEmpty)
    }

    func testDelayedDispatchDoesNotBurstQueuedGestures() {
        var queue = DesktopSwitchQueue()
        for _ in 0..<3 { queue.append(right: true) }
        XCTAssertEqual(queue.take(at: 0), true)
        XCTAssertEqual(queue.take(at: 10), true)
        XCTAssertNil(queue.take(at: 10))
        XCTAssertEqual(queue.take(at: 10.5), true)
        XCTAssertNil(queue.take(at: 11))
    }
}
