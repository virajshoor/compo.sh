import XCTest
@testable import CompoCore

final class FittingLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 32, width: 2056, height: 1297)

    private func assertFits(_ frames: [CGRect], minimums: [CGSize], in bounds: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(frames.count, minimums.count, file: file, line: line)
        for (i, frame) in frames.enumerated() {
            XCTAssertTrue(bounds.contains(frame), file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.width + 0.01, minimums[i].width, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.height + 0.01, minimums[i].height, file: file, line: line)
            for other in frames.dropFirst(i + 1) {
                let overlap = frame.intersection(other)
                XCTAssertTrue(overlap.isNull || overlap.width * overlap.height < 0.01, file: file, line: line)
            }
        }
    }

    func testPreferredLayoutAndManualSwapsStayUnchangedWhenTheyFit() throws {
        let frames = AppAwareLayout.frames(roles: [.browser, .terminal], in: screen, gap: 12, fallback: .stack, ratio: 0.58)
        for preferred in [frames, Array(frames.reversed())] {
            XCTAssertEqual(try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: [.zero, .zero], in: screen, gap: 12)), preferred)
        }
    }

    func testMusicSizedMinimumDoesNotOverlapBrowser() throws {
        let preferred = Layout.columns.frames(count: 2, in: screen, gap: 12, ratio: 0.6)
        let minimums = [CGSize(width: 800, height: 400), CGSize(width: 1100, height: 600)]
        let frames = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: minimums, in: screen, gap: 12))
        assertFits(frames, minimums: minimums, in: screen)
        XCTAssertLessThanOrEqual(frames[0].maxX, frames[1].minX)
    }

    func testRowsReplaceImpossibleNarrowColumns() throws {
        let bounds = CGRect(x: -1440, y: -900, width: 1440, height: 900)
        let preferred = Layout.columns.frames(count: 2, in: bounds, gap: 12, ratio: 0.6)
        let minimums = Array(repeating: CGSize(width: 900, height: 350), count: 2)
        let frames = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: minimums, in: bounds, gap: 12))
        assertFits(frames, minimums: minimums, in: bounds)
        XCTAssertLessThan(frames[0].maxY, frames[1].minY)
    }

    func testGridFitsFourLargeWindowsAndRepairsOverlappingManualFrames() throws {
        let preferred = Array(repeating: screen.insetBy(dx: 12, dy: 12), count: 4)
        let minimums = Array(repeating: CGSize(width: 900, height: 500), count: 4)
        let frames = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: minimums, in: screen, gap: 12))
        assertFits(frames, minimums: minimums, in: screen)
    }

    func testImpossibleAndMalformedLayoutsFailRatherThanEmitOverlaps() {
        let preferred = [screen, screen]
        XCTAssertNil(FittingLayout.frames(preferred: preferred, minimums: Array(repeating: CGSize(width: 2000, height: 1200), count: 2), in: screen, gap: 12))
        XCTAssertNil(FittingLayout.frames(preferred: preferred, minimums: [], in: screen, gap: 12))
        XCTAssertNil(FittingLayout.frames(preferred: preferred, minimums: [.zero, .zero], in: screen, gap: .nan))
        XCTAssertNil(FittingLayout.frames(preferred: [screen], minimums: [CGSize(width: -1, height: 0)], in: screen, gap: 12))
        XCTAssertEqual(FittingLayout.frames(preferred: [], minimums: [], in: screen, gap: 12), [])
    }

    func testSimulatedAppConstraintsConvergeAndActivationWritesNothing() throws {
        var actual = Layout.columns.frames(count: 2, in: screen, gap: 12, ratio: 0.6)
        let preferred = actual
        let appMinimums = [CGSize(width: 700, height: 400), CGSize(width: 1100, height: 500)]
        // Start with a window enlarged by activation, with no drag involved.
        actual[1].size.width = 1200
        var learned = [CGSize.zero, .zero]
        var writes = 0
        for _ in 0..<3 {
            let frames = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: learned, in: screen, gap: 12))
            for i in frames.indices {
                XCTAssertTrue(WindowPlacement.apply(frames[i], read: { actual[i] }, resize: { size in
                    writes += 1
                    actual[i].size = CGSize(width: max(size.width, appMinimums[i].width), height: max(size.height, appMinimums[i].height))
                    actual[i].origin.x -= 20
                    return true
                }, move: { point in writes += 1; actual[i].origin = point; return true }))
                learned[i] = WindowPlacement.minimumSize(requested: frames[i], actual: actual[i], previous: learned[i])
            }
        }
        assertFits(actual, minimums: appMinimums, in: screen)
        let settledWrites = writes
        let frames = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: learned, in: screen, gap: 12))
        for i in frames.indices {
            XCTAssertTrue(WindowPlacement.apply(frames[i], read: { actual[i] },
                resize: { _ in writes += 1; return true }, move: { _ in writes += 1; return true }))
        }
        XCTAssertEqual(writes, settledWrites)
    }

    func testManyDisplaySizesCountsAndMinimumsNeverProduceOverlap() {
        for bounds in [screen, CGRect(x: -1440, y: 40, width: 1440, height: 900), CGRect(x: 0, y: 0, width: 3440, height: 1440)] {
            for count in 1...10 {
                for layout in Layout.allCases {
                    let preferred = layout.frames(count: count, in: bounds, gap: 12, ratio: 0.6)
                    let minimums = (0..<count).map { CGSize(width: 300 + ($0 % 3) * 100, height: 200 + ($0 % 2) * 100) }
                    if let frames = FittingLayout.frames(preferred: preferred, minimums: minimums, in: bounds, gap: 12) {
                        assertFits(frames, minimums: minimums, in: bounds)
                    }
                }
            }
        }
    }
}
