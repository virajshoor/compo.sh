import XCTest
import CoreGraphics
@testable import CompoCore

final class SnapZoneTests: XCTestCase {
    let screen = CGRect(x: -1440, y: 40, width: 1440, height: 900)
    func testCornersWinOverEdgesAndCenterDoesNotSnap() {
        XCTAssertEqual(SnapZone.detect(point: CGPoint(x: -1438, y: 42), screen: screen, threshold: 24), .topLeft)
        XCTAssertEqual(SnapZone.detect(point: CGPoint(x: -2, y: 938), screen: screen, threshold: 24), .bottomRight)
        XCTAssertEqual(SnapZone.detect(point: CGPoint(x: -720, y: 42), screen: screen, threshold: 24), .top)
        XCTAssertNil(SnapZone.detect(point: CGPoint(x: -720, y: 400), screen: screen, threshold: 24))
        XCTAssertNil(SnapZone.detect(point: CGPoint(x: 100, y: 400), screen: screen, threshold: 24))
    }
    func testEverySnapFitsAndRemainderDoesNotOverlap() {
        for zone in SnapZone.allCases {
            let frame = zone.frame(in: screen, gap: 12)
            XCTAssertTrue(screen.contains(frame))
            XCTAssertGreaterThan(frame.width, 0)
            XCTAssertGreaterThan(frame.height, 0)
            if let rest = zone.remainder(in: screen, gap: 12) {
                XCTAssertTrue(screen.contains(rest))
                XCTAssertTrue(frame.intersection(rest).isNull)
                XCTAssertGreaterThan(rest.width, 0)
                XCTAssertGreaterThan(rest.height, 0)
            }
        }
        XCTAssertNil(SnapZone.top.remainder(in: screen, gap: 12))
    }
}
