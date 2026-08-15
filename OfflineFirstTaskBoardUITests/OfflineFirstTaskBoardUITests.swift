////
//  OfflineFirstTaskBoardUITests.swift
//  OfflineFirstTaskBoard
//
//  Created on 14.08.26.
//


import XCTest

final class OfflineFirstTaskBoardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBoardChromeAndBanner() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Board"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["To Do"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["In Progress"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(app.buttons["Add"].exists)
        XCTAssertTrue(banner(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testAddTaskAppearsInToDo() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Board"].waitForExistence(timeout: 10))
        app.buttons["To Do"].tap()
        app.buttons["Add"].tap()

        let title = "UITest \(Int(Date().timeIntervalSince1970))"
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(
            app.navigationBars["New task"].waitForNonExistence(timeout: 20),
            "Editor should dismiss after save"
        )

        let card = app.descendants(matching: .any)[title]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Created card should appear in To Do")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    private func banner(in app: XCUIApplication) -> XCUIElement {
        let titles = ["Last synced", "Syncing", "Sync failed", "Sync Now", "Offline"]
        for title in titles {
            let button = app.buttons[title]
            if button.exists { return button }
        }
        return app.buttons["Last synced"]
    }
}
