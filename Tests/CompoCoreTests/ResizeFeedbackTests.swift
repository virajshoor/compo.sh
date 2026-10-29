import XCTest
@testable import CompoCore

final class ResizeFeedbackTests: XCTestCase {
    private let target = CGRect(x: 10, y: 40, width: 500, height: 400)

    func testLearnsOnlyAfterDelayAndTwoStableSamples() {
        var feedback = ResizeFeedback(target: target, issuedAt: 10)
        let actual = CGRect(x: 10, y: 40, width: 700, height: 400)
        XCTAssertNil(feedback.minimum(actual: actual, now: 10.1, previous: .zero))
        XCTAssertNil(feedback.minimum(actual: actual, now: 10.3, previous: .zero))
        XCTAssertNil(feedback.minimum(actual: actual, now: 10.31, previous: .zero))
        XCTAssertFalse(feedback.finished)
        XCTAssertEqual(feedback.minimum(actual: actual, now: 10.6, previous: .zero), CGSize(width: 700, height: 0))
        XCTAssertTrue(feedback.finished)
    }

    func testLaterActivationOrUserResizeCannotInflateLearnedMinimum() {
        var feedback = ResizeFeedback(target: target, issuedAt: 0)
        XCTAssertNil(feedback.minimum(actual: target, now: 0.3, previous: .zero))
        XCTAssertEqual(feedback.minimum(actual: target, now: 0.6, previous: .zero), .zero)
        let enlarged = CGRect(x: 10, y: 40, width: 1800, height: 1000)
        XCTAssertNil(feedback.minimum(actual: enlarged, now: 1, previous: .zero))
        XCTAssertNil(feedback.minimum(actual: enlarged, now: 1.3, previous: .zero))
    }

    func testAsyncResizeMustStopChangingBeforeTeachingMinimum() {
        var feedback = ResizeFeedback(target: target, issuedAt: 0)
        for (time, width) in [(0.3, 1100.0), (0.6, 900.0), (0.9, 700.0)] {
            let actual = CGRect(x: 10, y: 40, width: width, height: 400)
            XCTAssertNil(feedback.minimum(actual: actual, now: time, previous: .zero))
        }
        let settled = CGRect(x: 10, y: 40, width: 700, height: 400)
        XCTAssertEqual(feedback.minimum(actual: settled, now: 1.2, previous: .zero), CGSize(width: 700, height: 0))
    }

    func testMovedAndExpiredRequestsCannotTeachFalseMinimums() {
        var moved = ResizeFeedback(target: target, issuedAt: 0)
        let actual = CGRect(x: 400, y: 40, width: 1100, height: 900)
        XCTAssertNil(moved.minimum(actual: actual, now: 0.3, previous: .zero))
        XCTAssertNil(moved.minimum(actual: actual, now: 0.6, previous: .zero))
        XCTAssertTrue(moved.finished)
        var expired = ResizeFeedback(target: target, issuedAt: 0)
        XCTAssertNil(expired.minimum(actual: actual, now: 3, previous: .zero))
        XCTAssertTrue(expired.finished)
    }

    func testSixWindowPlacementLearnsConstraintsThenConverges() throws {
        let bounds = CGRect(x: 0, y: 30, width: 2000, height: 1200)
        let minimums = [CGSize(width: 1100, height: 700), CGSize(width: 850, height: 400),
                        CGSize(width: 850, height: 280), CGSize(width: 600, height: 450),
                        CGSize(width: 600, height: 450), CGSize(width: 600, height: 450)]
        let preferred = Layout.columns.frames(count: 6, in: bounds, gap: 10, ratio: 0.58)
        var actual = Array(repeating: bounds, count: 6)
        var learned = Array(repeating: CGSize.zero, count: 6)
        for i in preferred.indices {
            WindowPlacement.apply(preferred[i], read: { actual[i] }, resize: { size in
                actual[i].size = CGSize(width: max(size.width, minimums[i].width), height: max(size.height, minimums[i].height))
                return true
            }, move: { point in actual[i].origin = point; return true })
            var feedback = ResizeFeedback(target: preferred[i], issuedAt: 0)
            XCTAssertNil(feedback.minimum(actual: actual[i], now: 0.3, previous: .zero))
            learned[i] = try XCTUnwrap(feedback.minimum(actual: actual[i], now: 0.6, previous: .zero))
        }
        var fitted = preferred
        // Width fitting can expose height limits that the first tall-column request never exercised.
        for _ in 0..<3 {
            fitted = try XCTUnwrap(FittingLayout.frames(preferred: preferred, minimums: learned, in: bounds, gap: 10))
            for i in fitted.indices {
                WindowPlacement.apply(fitted[i], read: { actual[i] }, resize: { size in
                    actual[i].size = CGSize(width: max(size.width, minimums[i].width), height: max(size.height, minimums[i].height))
                    return true
                }, move: { point in actual[i].origin = point; return true })
                var feedback = ResizeFeedback(target: fitted[i], issuedAt: 0)
                XCTAssertNil(feedback.minimum(actual: actual[i], now: 0.3, previous: learned[i]))
                learned[i] = try XCTUnwrap(feedback.minimum(actual: actual[i], now: 0.6, previous: learned[i]))
            }
        }
        for i in fitted.indices {
            XCTAssertTrue(WindowPlacement.matches(actual[i], fitted[i]))
            for j in 0..<i { XCTAssertTrue(actual[i].intersection(actual[j]).isNull) }
        }
    }
}
