//
//  CivicsUITests.swift
//  CivicsUITests
//
//  Created by Yi Wang on 9/6/26.
//

import XCTest

final class CivicsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Drives the study loop end to end: start -> question speaks -> reveal the
    /// answer -> next question. Verifies the engine and UI stay in lockstep.
    @MainActor
    func testStudyLoop() throws {
        let app = XCUIApplication()
        // The runner may launch the app with a zh locale on this machine; force
        // English so assertions don't depend on host/simulator language state.
        app.launchArguments = ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US"]
        app.launch()

        // Fresh launch shows the onboarding card and the start button.
        XCTAssertTrue(app.staticTexts["Civics Audio Prep"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Start listening"].exists)

        // Start: the engine begins speaking Q1 — the primary button flips label.
        let primary = app.buttons["primaryAction"]
        primary.tap()
        let hearAnswer = app.buttons["Hear the answer"]
        XCTAssertTrue(hearAnswer.waitForExistence(timeout: 10))

        // Reveal the answer: the card shows the acceptable answer immediately.
        hearAnswer.tap()
        XCTAssertTrue(app.staticTexts["ACCEPTABLE ANSWER"].waitForExistence(timeout: 10))

        // Next question: the card hides the answer again and shows Q2.
        let nextQuestion = app.buttons["Next question"].firstMatch
        XCTAssertTrue(nextQuestion.waitForExistence(timeout: 10))
        nextQuestion.tap()
        XCTAssertTrue(app.staticTexts["Q2"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["ACCEPTABLE ANSWER"].exists)
    }
}
