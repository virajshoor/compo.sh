import XCTest
import CoreGraphics
@testable import CompoCore

final class LayoutTests: XCTestCase {
    let screen = CGRect(x: -1440, y: 80, width: 1440, height: 900)

    func testLayoutsStayInsideDisplayAndDoNotOverlap() {
        for layout in Layout.allCases {
            for count in [1, 2, 3, 10, 100] {
                let frames = layout.frames(count: count, in: screen, gap: 12, ratio: 0.58)
                XCTAssertEqual(frames.count, count)
                for (index, frame) in frames.enumerated() {
                    XCTAssertGreaterThan(frame.width, 0)
                    XCTAssertGreaterThan(frame.height, 0)
                    XCTAssertTrue(screen.insetBy(dx: -0.001, dy: -0.001).contains(frame))
                    for other in frames.dropFirst(index + 1) {
                        let intersection = frame.intersection(other)
                        XCTAssertTrue(intersection.isNull || intersection.width < 0.001 || intersection.height < 0.001)
                    }
                }
            }
        }
    }

    func testEmptyAndSingleWindow() {
        XCTAssertTrue(Layout.stack.frames(count: 0, in: screen, gap: 12, ratio: 0.5).isEmpty)
        XCTAssertEqual(Layout.stack.frames(count: 1, in: screen, gap: 12, ratio: 0.5),
                       [screen.insetBy(dx: 12, dy: 12)])
    }

    func testDirectionalFocusUsesAXCoordinates() {
        let source = CGRect(x: 100, y: 100, width: 100, height: 100)
        let frames = [source, source.offsetBy(dx: 120, dy: 0), source.offsetBy(dx: 0, dy: -120)]
        XCTAssertEqual(Direction.right.neighbor(from: source, among: frames), 1)
        XCTAssertEqual(Direction.up.neighbor(from: source, among: frames), 2)
        XCTAssertNil(Direction.left.neighbor(from: source, among: frames))
    }
}
