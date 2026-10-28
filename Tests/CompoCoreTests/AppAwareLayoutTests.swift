import XCTest
import CoreGraphics
@testable import CompoCore

final class AppAwareLayoutTests: XCTestCase {
    private let bounds = CGRect(x: -1440, y: 40, width: 1440, height: 900)
    private func frames(_ roles: [AppRole]) -> [CGRect] {
        AppAwareLayout.frames(roles: roles, in: bounds, gap: 12, fallback: .stack, ratio: 0.58)
    }
    func testBrowserGetsMoreRoomThanTerminalInEitherOrder() {
        for roles: [AppRole] in [[.browser, .terminal], [.terminal, .browser]] {
            let result = frames(roles)
            let browser = result[roles.firstIndex(of: .browser)!]
            let terminal = result[roles.firstIndex(of: .terminal)!]
            XCTAssertGreaterThan(browser.width, terminal.width)
            XCTAssertEqual(browser.height, terminal.height)
            XCTAssertEqual(browser.minY, terminal.minY)
        }
    }
    func testTwoBrowsersUseWideRowsAndWordUsesTallColumns() {
        let browsers = frames([.browser, .browser])
        XCTAssertEqual(browsers[0].width, bounds.width - 24)
        XCTAssertLessThan(browsers[0].maxY, browsers[1].minY)
        let word = frames([.document, .browser])
        XCTAssertEqual(word[0].height, bounds.height - 24)
        XCTAssertEqual(word[0].width, word[1].width)
        XCTAssertLessThan(word[0].maxX, word[1].minX)
    }
    func testMixedGroupsStayInsideScreenWithoutOverlap() {
        for roles: [AppRole] in [[.browser, .terminal, .browser, .document],
                                [.terminal, .document, .other], [.browser], []] {
            let result = frames(roles)
            XCTAssertEqual(result.count, roles.count)
            for (i, rect) in result.enumerated() {
                XCTAssertTrue(bounds.contains(rect))
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertGreaterThan(rect.height, 0)
                for next in result.dropFirst(i + 1) { XCTAssertTrue(rect.intersection(next).isNull) }
            }
        }
    }
    func testFourWindowsAvoidNarrowCompanionColumnsOnLaptop() {
        let result = frames([.other, .terminal, .browser, .browser])
        XCTAssertEqual(result[0].width, result[1].width)
        XCTAssertEqual(result[1].width, result[2].width)
        XCTAssertGreaterThan(result[1].width, 600)
        XCTAssertEqual(result[0].minX, result[1].minX)
        XCTAssertLessThan(result[0].maxY, result[1].minY)
        XCTAssertEqual(result[2].minX, result[3].minX)
        XCTAssertLessThan(result[2].maxY, result[3].minY)
    }
    func testUltrawideKeepsCompanionsTall() {
        let result = AppAwareLayout.frames(roles: [.other, .terminal, .browser, .browser],
            in: CGRect(x: 0, y: 0, width: 3440, height: 1440), gap: 12, fallback: .stack, ratio: 0.58)
        XCTAssertEqual(result[0].height, 1416)
        XCTAssertEqual(result[1].height, 1416)
        XCTAssertGreaterThan(result[1].width, 420)
        XCTAssertLessThan(result[0].maxX, result[1].minX)
    }
    func testRolesAndCustomRoleDecoding() throws {
        XCTAssertEqual(AppRole.classify(bundleIdentifier: "com.google.Chrome.beta", name: "Chrome"), .browser)
        XCTAssertEqual(AppRole.classify(bundleIdentifier: "new.browser", name: "New", handlesWebURLs: true), .browser)
        XCTAssertEqual(AppRole.classify(bundleIdentifier: "anything", name: "terax"), .terminal)
        XCTAssertEqual(AppRole.classify(bundleIdentifier: "com.microsoft.Word", name: "Word"), .document)
        XCTAssertEqual(try JSONDecoder().decode(AppRole.self, from: Data("\"terminal\"".utf8)), .terminal)
        XCTAssertThrowsError(try JSONDecoder().decode(AppRole.self, from: Data("\"unknown\"".utf8)))
    }
}
