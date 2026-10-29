import XCTest
@testable import CompoCore

final class WindowPlacementTests: XCTestCase {
    private let target = CGRect(x: 800, y: 40, width: 600, height: 800)

    func testUnchangedFrameDoesNotWriteOrRestartAppLayout() {
        var writes = 0
        XCTAssertTrue(WindowPlacement.apply(target, read: { self.target.offsetBy(dx: 0.5, dy: 0) },
            resize: { _ in writes += 1; return true }, move: { _ in writes += 1; return true }))
        XCTAssertEqual(writes, 0)
    }

    func testResizeOriginShiftAndMinimumSizeAreCorrectedWithoutRepeatedResize() {
        var actual = CGRect(x: 0, y: 40, width: 1100, height: 800)
        var sizes = 0, positions = 0
        XCTAssertTrue(WindowPlacement.apply(target, read: { actual }, resize: { size in
            sizes += 1
            actual.size = CGSize(width: max(1000, size.width), height: size.height)
            actual.origin.x = 400 // Simulate an app anchoring its right edge during resize.
            return true
        }, move: { point in positions += 1; actual.origin = point; return true }))
        XCTAssertEqual(actual.origin, target.origin)
        XCTAssertEqual(actual.width, 1000)
        XCTAssertEqual(sizes, 1)
        XCTAssertEqual(positions, 1)
        XCTAssertEqual(WindowPlacement.minimumSize(requested: target, actual: actual), CGSize(width: 1000, height: 0))
    }

    func testDisplayCrossingRetriesSizeAndCorrectsFinalOrigin() {
        var actual = CGRect(x: 0, y: 40, width: 1100, height: 800)
        var sizes = 0, positions = 0
        XCTAssertTrue(WindowPlacement.apply(target, read: { actual }, resize: { size in
            sizes += 1; actual.size = size
            if sizes == 2 { actual.origin.x -= 50 }
            return true
        }, move: { point in
            positions += 1; actual.origin = point
            if positions == 1 { actual.size.width = 900 }
            return true
        }))
        XCTAssertEqual(actual, target)
        XCTAssertEqual(sizes, 2)
        XCTAssertEqual(positions, 2)
    }

    func testRefusedWritesAndMissingReadsFailWithBoundedWork() {
        let actual = CGRect(x: 0, y: 0, width: 1100, height: 900)
        var writes = 0
        XCTAssertFalse(WindowPlacement.apply(target, read: { actual },
            resize: { _ in writes += 1; return false }, move: { _ in writes += 1; return false }))
        XCTAssertLessThanOrEqual(writes, 3)
        XCTAssertFalse(WindowPlacement.apply(target, read: { nil },
            resize: { _ in XCTFail("Unexpected resize"); return true }, move: { _ in XCTFail("Unexpected move"); return true }))
    }

    func testInvalidFramesNeverReachAccessibilityWrites() {
        for frame in [CGRect.zero, CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
                      CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100)] {
            XCTAssertFalse(WindowPlacement.apply(frame, read: { self.target },
                resize: { _ in XCTFail("Unexpected resize"); return true }, move: { _ in XCTFail("Unexpected move"); return true }))
        }
    }

    func testVisibilitySurvivesAXWindowServerFrameRaceWithoutMatchingOtherSpaces() {
        let old = CGRect(x: -1400, y: 40, width: 1000, height: 800)
        XCTAssertTrue(WindowPlacement.visible(target, previous: old, among: [old]))
        XCTAssertTrue(WindowPlacement.visible(old, previous: nil, targets: [target], among: [target]))
        XCTAssertFalse(WindowPlacement.visible(old, previous: nil, among: [target]))
        XCTAssertFalse(WindowPlacement.visible(target, previous: old, among: []))
    }

    func testDisplaySelectionHandlesNegativeOriginsAndDisconnectedScreens() {
        let screens = [CGRect(x: -1440, y: 0, width: 1440, height: 900),
                       CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        XCTAssertEqual(WindowPlacement.displayIndex(for: CGRect(x: -1300, y: 40, width: 800, height: 600), in: screens), 0)
        XCTAssertEqual(WindowPlacement.displayIndex(for: CGRect(x: -100, y: 40, width: 800, height: 600), in: screens), 1)
        XCTAssertEqual(WindowPlacement.displayIndex(for: CGRect(x: -2400, y: 40, width: 800, height: 600), in: screens), 0)
        XCTAssertNil(WindowPlacement.displayIndex(for: target, in: []))
    }
}
