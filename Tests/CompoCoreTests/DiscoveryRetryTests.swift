import XCTest
@testable import CompoCore

final class DiscoveryRetryTests: XCTestCase {
    func testDiscoveryStartsFastAndCoversSlowSpotlightLaunches() {
        var retry = DiscoveryRetry()
        XCTAssertNil(retry.nextDelay(at: 100))
        retry.begin(at: 100)
        XCTAssertEqual(retry.nextDelay(at: 100), 0.25)
        XCTAssertEqual(retry.nextDelay(at: 101.75), 0.25)
        XCTAssertEqual(retry.nextDelay(at: 102), 1)
        XCTAssertEqual(retry.nextDelay(at: 140), 1)
        XCTAssertEqual(retry.nextDelay(at: 159.75), 0.25)
        XCTAssertNil(retry.nextDelay(at: 160))
        XCTAssertNil(retry.nextDelay(at: 200))
    }

    func testNewActivationRearmsExpiredDiscovery() {
        var retry = DiscoveryRetry()
        retry.begin(at: 10)
        XCTAssertNil(retry.nextDelay(at: 70))
        retry.begin(at: 80)
        XCTAssertEqual(retry.nextDelay(at: 80), 0.25)
        XCTAssertNil(retry.nextDelay(at: 79))
    }
}
