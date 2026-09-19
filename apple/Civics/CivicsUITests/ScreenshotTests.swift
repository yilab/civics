//
//  ScreenshotTests.swift
//  CivicsUITests
//
//  App Store screenshot capture. Drives the five tabs in English and in
//  Chinese and attaches named screenshots (kept on success); the
//  apple/tools/capture-screenshots.sh script exports them from the result
//  bundle into assets/screenshots/apple/.
//

#if os(iOS)
import XCTest

final class ScreenshotTests: XCTestCase {

    /// Labels differ per UI language: the merged language setting switches the
    /// whole app chrome, so Chinese-mode captures need zh-Hans labels.
    struct Labels {
        let tabs: [String]          // in AppDestination order
        let speakingCaption: String
        let stop: String
        let tapToReveal: String
        let testQuestion2: String   // progress caption after grading Q1

        static let english = Labels(
            tabs: ["Listen", "Flashcards", "Questions", "Test", "Settings"],
            speakingCaption: "Speaking the question — press to hear the answer",
            stop: "Stop",
            tapToReveal: "Tap to reveal",
            testQuestion2: "Question 2 of 20"
        )
        static let chinese = Labels(
            tabs: ["听题", "抽认卡", "题库", "测试", "设置"],
            speakingCaption: "正在读题——按一下听答案",
            stop: "停止",
            tapToReveal: "点击显示答案",
            testQuestion2: "第 2 题 / 共 20 题"
        )
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureEnglish() throws {
        try capture(languageArgs: [], labels: .english, prefix: "en", highlightDelay: 1.8)
    }

    @MainActor
    func testCaptureChinese() throws {
        // Chinese mode speaks English first, then the translation — wait a
        // little longer so the karaoke highlight reaches the primary line.
        try capture(languageArgs: ["-language", "zh-Hans"], labels: .chinese,
                    prefix: "zh", highlightDelay: 2.6)
    }

    @MainActor
    private func capture(languageArgs: [String], labels: Labels, prefix: String,
                         highlightDelay: TimeInterval) throws {
        let app = XCUIApplication()
        // -known primes the known set through the UserDefaults argument domain
        // (plist-style array of strings) so lists show checkmarks at launch.
        app.launchArguments = ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US",
                               "-known", "(\"1\", \"3\", \"5\")"] + languageArgs
        app.launch()

        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(prefix)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func openTab(_ index: Int) {
            let byIndex = app.tabBars.buttons.element(boundBy: index)
            if byIndex.waitForExistence(timeout: 5) {
                byIndex.tap()
            } else {
                // iPadOS may render tabs outside a classic tab bar.
                app.buttons[labels.tabs[index]].firstMatch.tap()
            }
        }

        // 1 — Listen, mid-question with the karaoke word highlighted.
        app.buttons["primaryAction"].tap()
        XCTAssertTrue(app.staticTexts[labels.speakingCaption].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: highlightDelay)
        shot("01-listen")
        // Stop playback: the engine is shared across tabs, and the Test screen
        // only shows its start view while the engine is idle.
        app.buttons[labels.stop].tap()
        Thread.sleep(forTimeInterval: 0.5)

        // 2 — Flashcards, flipped to the answer.
        openTab(1)
        let hint = app.staticTexts[labels.tapToReveal]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        hint.tap()
        Thread.sleep(forTimeInterval: 0.8) // flip animation
        shot("02-flashcards")

        // 3 — Questions, known checkmarks pre-seeded via -known.
        openTab(2)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Q1 ·"))
            .firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        shot("03-questions")

        // 4 — Practice test: grade Q1 correct, capture Q2 mid-speech with score.
        openTab(3)
        app.buttons["startTest"].tap()
        let reveal = app.buttons["revealAnswer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10))
        reveal.tap()
        let gotIt = app.buttons["gradeCorrect"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 10))
        gotIt.tap()
        XCTAssertTrue(app.staticTexts[labels.testQuestion2].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: highlightDelay)
        shot("04-test")

        // 5 — Settings (language grid, speech rate, think pause).
        openTab(4)
        Thread.sleep(forTimeInterval: 0.8)
        shot("05-settings")
    }
}
#endif
