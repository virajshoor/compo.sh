import XCTest
@testable import CompoCore

final class FeatureTests: XCTestCase {
    func testUndoPreservesGeometryAndDropsClosedOrOffSpaceWindows() {
        let frame = CGRect(x: -500, y: 50, width: 500, height: 800)
        let snapshot = ArrangementSnapshot(frames: [(1, frame), (2, frame), (3, CGRect.zero)], floating: [1, 2], zoomed: 2)
        let restored = snapshot.surviving(in: [1, 3], equal: ==)
        XCTAssertEqual(restored.frames.count, 1)
        XCTAssertEqual(restored.frames[0].0, 1)
        XCTAssertEqual(restored.frames[0].1, frame)
        XCTAssertEqual(restored.floating, [1])
        XCTAssertNil(restored.zoomed)
        XCTAssertTrue(snapshot.surviving(in: [], equal: ==).frames.isEmpty)
    }

    func testOverlapWaitsForStableFramesAndOnlyRetriesOnce() {
        let first = CGRect(x: 0, y: 0, width: 600, height: 500)
        let second = CGRect(x: 500, y: 0, width: 600, height: 500)
        var recovery = OverlapRecovery()
        XCTAssertEqual(recovery.observe([first, second], at: 0), .waiting)
        XCTAssertEqual(recovery.observe([first, second], at: 0.1), .waiting)
        XCTAssertEqual(recovery.observe([first, second], at: 0.3), .retry)
        XCTAssertEqual(recovery.observe([first, second], at: 0.6), .waiting)
        XCTAssertEqual(recovery.observe([first, second], at: 0.9), .blocked)
        XCTAssertEqual(recovery.observe([first, second.offsetBy(dx: 200, dy: 0)], at: 1), .clear)
        // A temporarily successful placement does not grant an endless retry budget.
        XCTAssertEqual(recovery.observe([first, second], at: 1.1), .waiting)
        XCTAssertEqual(recovery.observe([first, second], at: 1.4), .blocked)
    }

    func testChangingOverlapDoesNotCountAsSettledAndEdgesMayTouch() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        var recovery = OverlapRecovery()
        XCTAssertEqual(recovery.observe([frame, frame.offsetBy(dx: 70, dy: 0)], at: 0), .waiting)
        XCTAssertEqual(recovery.observe([frame, frame.offsetBy(dx: 80, dy: 0)], at: 1), .waiting)
        XCTAssertEqual(recovery.observe([frame, frame.offsetBy(dx: 100, dy: 0)], at: 2), .clear)
    }

    func testWorkspaceRemapsByDisplayIdentityThenFallsBackWhenDisconnected() throws {
        let screen = CGRect(x: -1200, y: 40, width: 1200, height: 800)
        let frame = CGRect(x: -1200, y: 40, width: 600, height: 800)
        let pane = Workspace.Pane(bundle: "com.apple.Safari", ordinal: 0, display: "external", fallbackDisplay: 1,
                                  rect: Workspace.normalized(frame, in: screen), floating: false)
        let workspace = Workspace(name: "Work", windows: [pane])
        try workspace.validate()
        let restored = Workspace.restored(pane, screens: [("external", screen), ("built-in", CGRect(x: 0, y: 0, width: 900, height: 600))])
        XCTAssertEqual(restored, frame)
        XCTAssertEqual(Workspace.restored(pane, screens: [("built-in", CGRect(x: 0, y: 0, width: 900, height: 600))]), CGRect(x: 0, y: 0, width: 450, height: 600))
        XCTAssertNil(Workspace.restored(pane, screens: []))
        let decoded = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
        XCTAssertEqual(decoded.id, workspace.id)
        XCTAssertEqual(decoded.windows[0].rect, pane.rect)
    }

    func testWorkspaceRejectsInvalidAndDuplicatePanes() {
        let pane = Workspace.Pane(bundle: "app", ordinal: 0, display: "screen", fallbackDisplay: 0,
                                  rect: CGRect(x: 0, y: 0, width: 1, height: 1), floating: false)
        XCTAssertThrowsError(try Workspace(name: " ", windows: [pane]).validate())
        XCTAssertThrowsError(try Workspace(name: "Work", windows: [pane, pane]).validate())
        var bad = pane; bad.rect.origin.x = -1
        XCTAssertThrowsError(try Workspace(name: "Work", windows: [bad]).validate())
        bad.rect = CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 1)
        XCTAssertNil(Workspace.restored(bad, screens: [("screen", CGRect(x: 0, y: 0, width: 900, height: 600))]))
    }

    func testShortcutsValidateDuplicatesMissingActionsAndModifiers() throws {
        try ShortcutBinding.validate(ShortcutBinding.defaults)
        var bindings = ShortcutBinding.defaults
        bindings[1].key = bindings[0].key; bindings[1].modifiers = bindings[0].modifiers.reversed()
        XCTAssertThrowsError(try ShortcutBinding.validate(bindings))
        bindings[1].enabled = false
        try ShortcutBinding.validate(bindings)
        bindings.removeLast()
        XCTAssertThrowsError(try ShortcutBinding.validate(bindings))
        bindings = ShortcutBinding.defaults; bindings[0].modifiers = ["shift"]
        XCTAssertThrowsError(try ShortcutBinding.validate(bindings))
        bindings = ShortcutBinding.defaults; bindings[0].key = "unknown"
        XCTAssertThrowsError(try ShortcutBinding.validate(bindings))
    }

    func testShortcutsRoundTripAndFormat() throws {
        let bindings = try JSONDecoder().decode([ShortcutBinding].self, from: JSONEncoder().encode(ShortcutBinding.defaults))
        XCTAssertEqual(bindings, ShortcutBinding.defaults)
        XCTAssertEqual(bindings.first { $0.action == "desktop.right" }?.display, "⌃⌥⌘ →")
    }

    func testDiagnosticsBoundedAndOnlyContainAllowedMetadata() throws {
        var log = DiagnosticLog()
        for index in 0..<250 { log.record(.rejectedWrite, at: Double(index), window: 2) }
        log.record(.moved, at: .infinity)
        XCTAssertEqual(log.entries.count, 200)
        XCTAssertEqual(log.entries.first?.uptime, 50)
        let data = try JSONEncoder().encode(log.entries)
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(Set(objects[0].keys), ["kind", "uptime", "window"])
    }
}
