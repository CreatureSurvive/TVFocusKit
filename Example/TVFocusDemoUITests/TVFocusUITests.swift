import XCTest

/// Drives the demo with the Siri Remote on the tvOS simulator.
final class TVFocusUITests: XCTestCase {
    @MainActor var remote: XCUIRemote { XCUIRemote.shared }

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    @MainActor
    func focusedID(_ app: XCUIApplication) -> String {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        return focused.exists ? focused.identifier : "<none>"
    }

    @MainActor
    func press(_ buttons: XCUIRemote.Button..., times: Int = 1) {
        for _ in 0..<times {
            for button in buttons {
                remote.press(button)
                usleep(350_000)
            }
        }
    }

    @MainActor
    func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(element(app, "r0i0").waitForExistence(timeout: 10))
        return app
    }

    /// Moving back up to a row returns to the item focused there before,
    /// even when a different item is geometrically closer.
    @MainActor
    func testShelvesRememberFocus() {
        let app = launch()
        press(.down) // from the header buttons into row 0
        XCTAssertEqual(focusedID(app), "r0i0")
        press(.right, times: 2)
        XCTAssertEqual(focusedID(app), "r0i2")
        press(.down)
        XCTAssertEqual(focusedID(app), "r1i2", "first entry into a row uses the nearest item")
        press(.right, times: 3)
        XCTAssertEqual(focusedID(app), "r1i5")
        press(.up)
        XCTAssertEqual(focusedID(app), "r0i2", "row 0 should restore its remembered item, not the nearest one")
        press(.down)
        XCTAssertEqual(focusedID(app), "r1i5", "row 1 should restore its remembered item")
    }

    /// For comparison: plain SwiftUI rows pick the geometrically nearest item.
    @MainActor
    func testPlainRowsForgetFocus() {
        let app = launch(["-plain"])
        XCTAssertEqual(focusedID(app), "r0i0")
        press(.right, times: 2)
        press(.down)
        press(.right, times: 3)
        press(.up)
        let result = focusedID(app)
        XCTContext.runActivity(named: "plain SwiftUI returned to \(result)") { _ in }
        XCTAssertNotEqual(result, "r0i2", "if plain SwiftUI remembers focus, this test's premise no longer holds")
    }

    /// Menu from a visible row, and from partway along the first row.
    @MainActor
    func testMenuFromNearbyRows() {
        let app = launch()
        press(.down)
        press(.right, times: 3)
        press(.down)
        XCTAssertEqual(focusedID(app), "r1i3")
        press(.menu)
        XCTAssertEqual(focusedID(app), "r0i0")
        press(.right, times: 4)
        XCTAssertEqual(focusedID(app), "r0i4")
        press(.menu)
        XCTAssertEqual(focusedID(app), "r0i0", "Menu partway along the first row returns to its start")
    }

    /// Menu returns to the start of the first shelf, then exits.
    @MainActor
    func testMenuReturnsToStartThenExits() {
        let app = launch()
        press(.down)
        press(.right, times: 3)
        press(.down, times: 3)
        XCTAssertTrue(focusedID(app).hasPrefix("r3"), "got \(focusedID(app))")
        press(.menu)
        XCTAssertEqual(focusedID(app), "r0i0")
        press(.menu)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5), "a second Menu press should leave the app")
    }

    /// Focus requested for content that loads later lands once it exists.
    @MainActor
    func testRequestFocusAfterAsyncLoad() {
        let app = launch()
        XCTAssertEqual(focusedID(app), "loadLate")
        press(.select)
        XCTAssertTrue(element(app, "r9i3").waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "hasFocus == true")
        expectation(for: predicate, evaluatedWith: element(app, "r9i3"))
        waitForExpectations(timeout: 3)
    }

    /// The focus monitor reports movements that the focus engine blocks.
    @MainActor
    func testMonitorReportsBlockedMovement() {
        let app = launch(["-debugOverlay"])
        press(.down)
        XCTAssertEqual(focusedID(app), "r0i0")
        let log = element(app, "focusLog")
        press(.left) // nothing to the left of the first item
        let blocked = NSPredicate(format: "label CONTAINS 'blocked'")
        expectation(for: blocked, evaluatedWith: log)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(log.label.contains("left"), log.label)
        press(.right)
        let moved = NSPredicate(format: "label CONTAINS '→'")
        expectation(for: moved, evaluatedWith: log)
        waitForExpectations(timeout: 3)
    }
}
