//
//  ScreenshotMacTests.swift
//  CivicsUITests
//
//  Mac App Store screenshot capture. Mirrors ScreenshotTests (iOS) but clicks
//  instead of taps and screenshots the app window; the capture script crops
//  the title bar so the content is exactly 1280 × 800 pt (2560 × 1600 px).
//  Built only for macOS — the iOS files in this target are #if-guarded.
//

#if os(macOS)
import XCTest

final class ScreenshotMacTests: XCTestCase {

    /// Same merged-language behavior as iOS: Chinese mode switches all chrome.
    struct Labels {
        let tabs: [String]
        let speakingCaption: String
        let stop: String
        let tapToReveal: String
        let testQuestion2: String

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
        try capture(languageArgs: ["-language", "zh-Hans"], labels: .chinese,
                    prefix: "zh", highlightDelay: 2.6)
    }

    @MainActor
    private func capture(languageArgs: [String], labels: Labels, prefix: String,
                         highlightDelay: TimeInterval) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US",
                               "-known", "(\"1\", \"3\", \"5\")"] + languageArgs
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))

        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: window.screenshot())
            attachment.name = "\(prefix)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        // TabView chrome varies on macOS (toolbar tabs / segmented control);
        // try the control types in order of likelihood.
        func openTab(_ index: Int) {
            let name = labels.tabs[index]
            for query in [app.radioButtons, app.buttons, app.checkBoxes] {
                let element = query[name].firstMatch
                if element.waitForExistence(timeout: 3) {
                    element.click()
                    return
                }
            }
            XCTFail("tab not found: \(name)")
        }

        // 1 — Listen, mid-question with the karaoke word highlighted.
        app.buttons["primaryAction"].click()
        XCTAssertTrue(app.staticTexts[labels.speakingCaption].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: highlightDelay)
        shot("01-listen")
        // Stop playback: the engine is shared across tabs, and the Test screen
        // only shows its start view while the engine is idle.
        app.buttons[labels.stop].click()
        Thread.sleep(forTimeInterval: 0.5)

        // 2 — Flashcards, flipped to the answer.
        openTab(1)
        let hint = app.staticTexts[labels.tapToReveal]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        hint.click()
        Thread.sleep(forTimeInterval: 0.8)
        shot("02-flashcards")

        // 3 — Questions, known checkmarks pre-seeded via -known.
        openTab(2)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Q1 ·"))
            .firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        shot("03-questions")

        // 4 — Practice test: grade Q1 correct, capture Q2 mid-speech with score.
        openTab(3)
        app.buttons["startTest"].click()
        let reveal = app.buttons["revealAnswer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10))
        reveal.click()
        let gotIt = app.buttons["gradeCorrect"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 10))
        gotIt.click()
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
