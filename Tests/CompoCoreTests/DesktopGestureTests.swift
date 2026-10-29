import XCTest
import CoreGraphics
@testable import CompoCore

final class DesktopGestureTests: XCTestCase {
    private func version(_ major: Int, _ minor: Int = 0) -> OperatingSystemVersion {
        OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0)
    }
    private func field(_ value: UInt32) -> CGEventField { unsafeBitCast(value, to: CGEventField.self) }

    func testUnsupportedVersionsNeverBuildBlankLandingGestures() {
        for os in [version(13), version(26), version(26, 5)] {
            XCTAssertFalse(DesktopGesture.supported(os))
            XCTAssertNil(DesktopGesture.events(right: true, version: os, naturalScrolling: true))
        }
        XCTAssertTrue(DesktopGesture.supported(version(26, 6)))
        XCTAssertTrue(DesktopGesture.supported(version(27, 2)))
    }

    func testDesktopBoundariesNeverWrapOrRubberBand() {
        XCTAssertNil(DesktopGesture.targetIndex(current: 0, count: 2, right: false))
        XCTAssertNil(DesktopGesture.targetIndex(current: 1, count: 2, right: true))
        XCTAssertNil(DesktopGesture.targetIndex(current: 0, count: 0, right: true))
        XCTAssertNil(DesktopGesture.targetIndex(current: -1, count: 2, right: true))
        XCTAssertEqual(DesktopGesture.targetIndex(current: 0, count: 2, right: true), 1)
        XCTAssertEqual(DesktopGesture.targetIndex(current: 1, count: 2, right: false), 0)
    }

    func testMacOS26HasCompleteNearZeroTravelGesture() throws {
        for right in [true, false] {
            let events = try XCTUnwrap(DesktopGesture.events(right: right, version: version(26, 6), naturalScrolling: true))
            XCTAssertEqual(events.count, 3)
            XCTAssertEqual(events.map { $0.getIntegerValueField(field(132)) }, [1, 2, 4])
            for event in events {
                XCTAssertEqual(event.getIntegerValueField(field(55)), 30)
                XCTAssertEqual(event.getDoubleValueField(field(124)), right ? 0.0001 : -0.0001, accuracy: 0.000001)
                XCTAssertEqual(event.getDoubleValueField(field(129)), right ? 2000 : -2000)
            }
        }
    }

    func testMacOS27PairsEventsAndEncodesRawPayloadForBothScrollDirections() throws {
        for right in [true, false] {
            for natural in [true, false] {
                let events = try XCTUnwrap(DesktopGesture.events(right: right, version: version(27, 2), naturalScrolling: natural))
                XCTAssertEqual(events.count, 6)
                let sign: Double = (right ? -1 : 1) * (natural ? 1 : -1)
                for i in 0..<3 {
                    let event = events[i * 2]
                    XCTAssertEqual(event.getIntegerValueField(field(55)), 30)
                    XCTAssertEqual(event.getIntegerValueField(field(132)), [Int64(1), 2, 4][i])
                    XCTAssertEqual(events[i * 2 + 1].getIntegerValueField(field(55)), 29)
                    XCTAssertEqual(event.getDoubleValueField(field(124)), sign * 0.0001, accuracy: 0.000001)
                    XCTAssertEqual(event.getDoubleValueField(field(129)), i == 2 ? sign * 9999 : 0)
                    let bytes = [UInt8](try XCTUnwrap(event.data) as Data)
                    // Serialized event includes field 4205 with 68-byte or 96-byte IOHID payload.
                    let size: UInt8 = i == 2 ? 96 : 68
                    XCTAssertTrue(bytes.indices.dropLast(3).contains { j in
                        Array(bytes[j...j+3]) == [0, size, 0x10, 0x6D]
                    })
                }
            }
        }
    }
}
