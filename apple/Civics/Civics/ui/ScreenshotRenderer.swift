//
//  ScreenshotRenderer.swift
//  Civics
//
//  DEBUG-only Mac App Store screenshot renderer. Launch the macOS build with
//
//      Civics -renderScreenshots /tmp/civics-mac-shots
//
//  and the app renders its five screens — the real screen composables inside
//  the real chrome — offscreen at 1280 × 800 pt, scale 2 → 2560 × 1600 px
//  PNGs under <dir>/{en,zh-Hans}/, next to the live window. Used because the
//  XCUITest/unit-test paths need Accessibility/testmanagerd grants that
//  headless shells can't get; apple/tools/capture-screenshots-mac.sh drives
//  this. Compiled out of release builds.
//

#if DEBUG && os(macOS)
import SwiftUI

enum ScreenshotRenderer {

    static func trace(_ s: String) {
        FileHandle.standardError.write(Data("ScreenshotRenderer: \(s)\n".utf8))
    }

    @MainActor
    static func renderIfRequested(model: AppModel) {
        let requested = ProcessInfo.processInfo.environment["RENDER_SCREENSHOTS"]
            ?? UserDefaults.standard.string(forKey: "renderScreenshots")
        guard let requested else { return }
        // The capture script re-signs the debug build without the sandbox so
        // the requested path (e.g. /tmp/...) is writable from inside the app.
        let out = URL(fileURLWithPath: requested)
        // Called from AppModel.init, before the app is active — defer the
        // work until after launch so windows can become key and paint their
        // active appearance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate()
            renderAll(model: model, to: out)
        }
    }

    @MainActor
    private static func renderAll(model: AppModel, to out: URL) {
        let repo = model.questionRepo
        let q1 = repo.questions[0]
        let q47 = repo.questions.first { $0.n == 47 } ?? q1
        let known: Set<Int> = [1, 3, 5]
        let originalLanguage = model.settingsRepo.settings.language
        defer { L10n.apply(originalLanguage) }

        for (locale, language) in [("en", nil as SpeechLanguage?), ("zh-Hans", .chineseSimplified)] {
            L10n.apply(language)
            let lang = language ?? .english
            let translationPrimary = lang != .english
            let settings = StudySettings(known: known, language: language)

            // 1 — Listen, mid-question with the karaoke word highlighted.
            let listenState = StudyState(
                phase: .speakingQuestion,
                deck: repo.questions,
                current: q1,
                highlight: highlight(q1, word: "government"),
                known: known
            )
            render(chrome(.listen) {
                ListenScreen(state: listenState, ttsAvailable: true, language: lang,
                             translationPrimary: translationPrimary, knownFilter: .all,
                             onPrimary: {}, onPause: {}, onNext: {}, onPrevious: {},
                             onToggleKnown: { _ in }, onFilterChange: { _ in })
            }, to: out, locale: locale, name: "01-listen")

            // 2 — Flashcards, front face (the flipped state is view-local).
            render(chrome(.flashcards) {
                FlashcardsScreen(questions: repo.questions, known: known, language: lang,
                                 translationPrimary: translationPrimary, onToggleKnown: { _ in })
            }, to: out, locale: locale, name: "02-flashcards")

            // 3 — Questions, known checkmarks + playing indicator.
            render(chrome(.questions) {
                QuestionsScreen(questions: repo.questions, known: known, currentNumber: 1,
                                language: lang, translationPrimary: translationPrimary,
                                onJump: { _ in }, onToggleKnown: { _ in })
            }, to: out, locale: locale, name: "03-questions")

            // 4 — Practice test mid-run: "Question 2 of 20", score, karaoke.
            let testState = StudyState(
                phase: .speakingQuestion,
                deck: [q47],
                current: q47,
                highlight: highlight(q47, word: "Cabinet"),
                known: known,
                mode: .test,
                testIndex: 1,
                testCorrect: 1
            )
            render(chrome(.test) {
                TestScreen(state: testState, history: [], language: lang,
                           translationPrimary: translationPrimary,
                           onStart: {}, onReveal: {}, onGrade: { _ in }, onBackToStudy: {})
            }, to: out, locale: locale, name: "04-test")

            // 5 — Settings (language grid, speech rate, think pause).
            render(chrome(.settings) {
                SettingsScreen(settings: settings, onChange: { _ in })
            }, to: out, locale: locale, name: "05-settings")
        }
        print("ScreenshotRenderer: wrote 10 PNGs to \(out.path)")
    }

    /// A question-block English highlight on the given word, like the engine
    /// emits while speaking (English is always spoken before the translation).
    private static func highlight(_ q: Question, word: String) -> SpokenHighlight? {
        guard var h = SpokenHighlight(utteranceID: "q-\(q.n)", text: q.question),
              let r = q.question.range(of: word) else { return nil }
        let ns = NSRange(r, in: q.question)
        h.range = ns.location..<(ns.location + ns.length)
        return h
    }

    /// The app's real chrome: logo row + TabView with the real tab items,
    /// selection pinned to the destination being captured (RootView binds its
    /// selection to view-local state, so it can't be pinned from outside).
    @ViewBuilder
    private static func chrome<Content: View>(_ dest: AppDestination,
                                              @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.vertical, 7)
                .opacity(0.9)
                .accessibilityHidden(true)
            TabView(selection: .constant(dest)) {
                ForEach([AppDestination.listen, .flashcards, .questions, .test, .settings],
                        id: \.self) { d in
                    Tab(L10n.t(d.labelKey), systemImage: d.icon, value: d) {
                        if d == dest { content() }
                    }
                }
            }
        }
    }

    private static func render<V: View>(_ view: V, to out: URL, locale: String, name: String) {
        trace("render begin \(locale)/\(name)")
        let dir = out.appendingPathComponent(locale)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(name).png")

        // Snapshot the content in a real (offscreen) titled window: SwiftUI
        // then puts the TabView tabs in the toolbar, just like the app's
        // window, and controls render in their active appearance. The outer
        // size is converged to exactly 1280 × 800 pt (2560 × 1600 px).
        let view = view.environment(\.colorScheme, .light)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Civics"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        // Light appearance for the whole window (incl. title bar), and key
        // status so accent-styled controls (e.g. .borderedProminent) paint
        // in their active look rather than the washed-out inactive one.
        window.appearance = NSAppearance(named: .aqua)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        guard let frameView = window.contentView?.superview else {
            trace("render failed \(locale)/\(name): no frame view")
            return
        }

        var contentHeight: CGFloat = 800
        var rep: NSBitmapImageRep?
        for _ in 0..<4 {
            window.setContentSize(NSSize(width: 1280, height: contentHeight))
            hosting.layout()
            window.display()
            let bounds = frameView.bounds
            let candidate = frameView.bitmapImageRepForCachingDisplay(in: bounds)
            frameView.cacheDisplay(in: bounds, to: candidate!)
            let totalPt = bounds.height
            if abs(totalPt - 800) < 0.5 {
                rep = candidate
                break
            }
            contentHeight += 800 - totalPt
            rep = candidate
        }
        guard let rep,
              rep.pixelsWide == 2560, rep.pixelsHigh == 1600,
              let png = rep.representation(using: .png, properties: [:]) else {
            trace("render failed \(locale)/\(name) size \(rep?.pixelsWide ?? 0)x\(rep?.pixelsHigh ?? 0)")
            return
        }
        trace("rendered \(name)")
        do {
            try png.write(to: file)
        } catch {
            trace("write failed \(locale)/\(name): \(error)")
        }
    }
}
#endif
