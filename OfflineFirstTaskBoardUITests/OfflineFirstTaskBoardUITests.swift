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


    // TODO:
//    @MainActor
//    func testAddTaskAppearsInToDo() throws {
//        let app = XCUIApplication()
//        app.launch()
//
//        XCTAssertTrue(app.navigationBars["Board"].waitForExistence(timeout: 10))
//        app.buttons["To Do"].tap()
//        app.buttons["Add"].tap()
//
//        let title = "UITest \(Int(Date().timeIntervalSince1970))"
//        let titleField = app.textFields["Title"]
//        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
//        titleField.tap()
//        titleField.typeText(title)
//
//        let save = app.buttons["Save"]
//        XCTAssertTrue(save.waitForExistence(timeout: 3))
//        XCTAssertTrue(save.isEnabled)
//        save.tap()
//
//        XCTAssertTrue(
//            app.navigationBars["New task"].waitForNonExistence(timeout: 20),
//            "Editor should dismiss after save"
//        )
//
//        let card = app.descendants(matching: .any)[title]
//        XCTAssertTrue(card.waitForExistence(timeout: 10), "Created card should appear in To Do")
//    }

    /// Opens the editor and cancels, so nothing is written to the shared board.
    @MainActor
    func testEditorExposesSubtaskDetailField() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Board"].waitForExistence(timeout: 10))
        app.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 5))

        let subtaskTitle = app.textFields["New subtask"]
        XCTAssertTrue(subtaskTitle.waitForExistence(timeout: 5))
        let subtaskDetail = app.textFields["New subtask detail"]
        XCTAssertTrue(subtaskDetail.exists, "Subtask detail field should be in the editor")

        subtaskTitle.tap()
        subtaskTitle.typeText("Draft subtask")
        subtaskDetail.tap()
        subtaskDetail.typeText("Draft detail")
        app.buttons["Add"].firstMatch.tap()

        // The added draft keeps its detail in an editable row.
        XCTAssertTrue(app.textFields["Draft detail"].waitForExistence(timeout: 5))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func banner(in app: XCUIApplication) -> XCUIElement {
        let titles = ["Last synced", "Syncing", "Sync failed", "Sync", "Offline"]
        for title in titles {
            let button = app.buttons[title]
            if button.exists { return button }
        }
        return app.buttons["Last synced"]
    }
}
