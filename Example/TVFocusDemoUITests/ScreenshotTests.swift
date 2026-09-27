import XCTest

/// Captures the README screenshots. Run with `Scripts/screenshots.sh`.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times {
            XCUIRemote.shared.press(button)
            usleep(400_000)
        }
    }

    @MainActor
    func capture(_ name: String) {
        sleep(1) // let focus animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testShelves() {
        let app = XCUIApplication()
        app.launchArguments = ["-showcase"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["Northern Lights"].waitForExistence(timeout: 10))
        press(.right, times: 2)
        press(.down)
        press(.right)
        capture("shelves")
    }

    @MainActor
    func testDebugOverlay() {
        let app = XCUIApplication()
        app.launchArguments = ["-showcase", "-debugOverlay"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["Northern Lights"].waitForExistence(timeout: 10))
        press(.right)
        press(.down)
        press(.left, times: 2) // the second press is blocked at the first item
        capture("debug-overlay")
    }
}
