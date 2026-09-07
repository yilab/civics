import Foundation
import SwiftUI

struct SettingsScreen: View {
    let settings: StudySettings
    let onChange: ((StudySettings) -> StudySettings) -> Void

    private var zhPrimary: Bool { settings.uiLanguage == .chinese }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("settings.voice") {
                    Text(L10n.t("settings.speechRate", String(format: "%.2f", settings.speechRate)))
                        .font(.body)
                    Slider(
                        value: Binding(
                            get: { settings.speechRate },
                            set: { v in onChange { $0.copy(speechRate: Float((v * 20).rounded() / 20)) } }
                        ),
                        in: 0.75...1.5
                    )
                    SwitchRow(
                        label: L10n.t("settings.announceMeta"),
                        checked: settings.announceMeta,
                        onChange: { v in onChange { $0.copy(announceMeta: v) } }
                    )
                    Text(L10n.t("settings.speechLanguage"))
                        .font(.body)
                    HStack(spacing: 8) {
                        ForEach(SpeechMode.allCases, id: \.self) { mode in
                            Chip(
                                label: modeLabel(mode),
                                selected: settings.speechMode == mode,
                                action: { onChange { $0.copy(speechMode: mode) } }
                            )
                        }
                    }
                }

                SettingsSection("settings.language") {
                    Text(L10n.t("settings.uiLanguage"))
                        .font(.body)
                    HStack(spacing: 8) {
                        ForEach(UiLanguage.allCases, id: \.self) { lang in
                            Chip(
                                label: uiLanguageLabel(lang),
                                selected: settings.uiLanguage == lang,
                                action: { onChange { $0.copy(uiLanguage: lang) } }
                            )
                        }
                    }
                }

                SettingsSection("settings.playback") {
                    Text(L10n.t("settings.thinkPause"))
                        .font(.body)
                    HStack(spacing: 8) {
                        ForEach(thinkOptions, id: \.seconds) { option in
                            Chip(
                                label: option.label,
                                selected: settings.thinkSeconds == option.seconds,
                                action: { onChange { $0.copy(thinkSeconds: option.seconds) } }
                            )
                        }
                    }
                    SwitchRow(
                        label: L10n.t("settings.autoAdvance"),
                        checked: settings.autoAdvance,
                        onChange: { v in onChange { $0.copy(autoAdvance: v) } }
                    )
                }

                SettingsSection("settings.deck") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Categories.values, id: \.self) { cat in
                            Chip(
                                label: CategoriesL10n.name(cat),
                                selected: settings.category == cat,
                                action: { onChange { $0.copy(category: cat) } }
                            )
                        }
                    }
                    SwitchRow(
                        label: L10n.t("settings.shuffle"),
                        checked: settings.shuffle,
                        onChange: { v in onChange { $0.copy(shuffle: v) } }
                    )
                }

                SettingsSection("settings.progressSection") {
                    Text(L10n.t("settings.knownProgress", settings.known.count))
                        .font(.body)
                    Button(L10n.t("settings.clearKnown")) {
                        onChange { $0.copy(known: []) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func modeLabel(_ mode: SpeechMode) -> String {
        switch mode {
        case .english: L10n.t("mode.english")
        case .bilingual: L10n.t("mode.bilingual")
        case .chinese: L10n.t("mode.chinese")
        }
    }

    private func uiLanguageLabel(_ lang: UiLanguage) -> String {
        switch lang {
        case .system: L10n.t("ui.system")
        case .english: L10n.t("ui.english")
        case .chinese: L10n.t("ui.chinese")
        }
    }

    private var thinkOptions: [(seconds: Int, label: String)] {
        [
            (StudySettings.thinkWaitForPress, L10n.t("think.wait")),
            (0, L10n.t("think.none")),
            (3, L10n.t("think.seconds", 3)),
            (5, L10n.t("think.seconds", 5)),
            (10, L10n.t("think.seconds", 10)),
        ]
    }
}

private struct SettingsSection<Content: View>: View {
    let titleKey: String
    @ViewBuilder let content: Content

    init(_ titleKey: String, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(titleKey).uppercased())
                .font(.footnote.weight(.medium))
                .foregroundStyle(.tint)
            content
        }
    }
}

private struct SwitchRow: View {
    let label: String
    let checked: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { checked }, set: onChange)) {
            Text(label)
                .font(.body)
        }
        .toggleStyle(.switch)
    }
}

private struct Chip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .background(
                    Capsule().fill(selected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.accentColor : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}
