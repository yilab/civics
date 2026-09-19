//
//  CivicsUITests.swift
//  CivicsUITests
//
//  Created by Yi Wang on 9/6/26.
//

#if os(iOS)
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

    /// Drives a practice test: start, answer Q1, grade it, and confirm the test
    /// advances with the score recorded.
    @MainActor
    func testPracticeTestFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US"]
        app.launch()

        // Open the Test tab and start a test.
        app.tabBars.buttons["Test"].tap()
        let start = app.buttons["Start practice test"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        // Q1 speaks; reveal the answer, then the grade buttons appear.
        let reveal = app.buttons["Hear the answer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10))
        reveal.tap()
        XCTAssertTrue(app.staticTexts["ACCEPTABLE ANSWER"].waitForExistence(timeout: 10))
        let gotIt = app.buttons["I got it"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 10))

        // Grade correct: score goes to 1 and the next question begins.
        gotIt.tap()
        XCTAssertTrue(app.staticTexts["Question 2 of 20"].waitForExistence(timeout: 10))
    }
}
#endif
