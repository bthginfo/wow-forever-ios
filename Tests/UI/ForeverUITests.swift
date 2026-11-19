// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

final class ForeverUITests: XCTestCase {
    @MainActor
    func testLauncherAndTouchControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--check-input"]
        app.launch()

        select("forever.region", option: "Europe", in: app)
        select("forever.resolution", option: "720p", in: app)
        select("forever.language", option: "Deutsch", in: app)
        let play = element("forever.primary", in: app)
        XCTAssertTrue(play.waitForExistence(timeout: 12))
        XCTAssertTrue(play.label.localizedCaseInsensitiveContains("spielen"))
        play.tap()

        let bags = element("forever.shortcut.bags", in: app)
        XCTAssertTrue(bags.waitForExistence(timeout: 12))
        XCTAssertEqual(bags.label, "Taschen")
        tap("forever.toolbar.collapse", in: app)
        XCTAssertFalse(bags.exists)
        tap("forever.toolbar.expand", in: app)
        XCTAssertTrue(bags.exists)

        tap("forever.shortcut.chat", in: app)
        let chat = app.textFields["Chat"]
        XCTAssertTrue(chat.waitForExistence(timeout: 8))
        chat.tap()
        chat.typeText("Forever test")
        XCTAssertEqual(chat.value as? String, "Forever test")
        app.buttons["Done"].tap()

        let camera = element("forever.control.camera", in: app)
        let movement = element("forever.control.movement", in: app)
        XCTAssertTrue(camera.exists)
        XCTAssertTrue(movement.exists)
        let original = camera.frame
        XCTAssertLessThan(movement.frame.midX, app.frame.midX)
        XCTAssertGreaterThan(original.midX, app.frame.midX)
        drag(movement, dx: 0, dy: -65)
        drag(camera, dx: -50, dy: -40)
        let input = app.staticTexts["forever.preview.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        for event in ["key-down-87", "key-up-87", "camera-down", "camera-move", "camera-up"] {
            XCTAssertTrue(input.label.contains(event), "Missing \(event) in \(input.label)")
        }

        tap("forever.more", in: app)
        tap("Steuerung anpassen", in: app)
        drag(camera, dx: -70, dy: -100)
        let edited = camera.frame
        XCTAssertLessThan(edited.midY, original.midY - 40)
        tap("Speichern", in: app)
        XCTAssertEqual(camera.frame.midY, edited.midY, accuracy: 4)

        app.terminate()
        app.launchArguments = ["--hud"]
        app.launch()
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        XCTAssertEqual(camera.frame.midX, edited.midX, accuracy: 4)
        XCTAssertEqual(camera.frame.midY, edited.midY, accuracy: 4)
        XCTAssertEqual(bags.label, "Taschen")

        let snapshot = XCTAttachment(screenshot: app.screenshot())
        snapshot.name = "Saved HUD on \(XCUIDevice.shared.model)"
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = element(identifier, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing \(identifier)")
        button.tap()
    }

    @MainActor
    private func select(_ identifier: String, option: String, in app: XCUIApplication) {
        tap(identifier, in: app)
        tap(option, in: app)
    }

    @MainActor
    private func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))
    }
}
