import Foundation
import SwiftUI

struct SettingsScreen: View {
    let settings: StudySettings
    let onChange: ((StudySettings) -> StudySettings) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("settings.language") {
                    Text(L10n.t("settings.uiLanguage"))
                        .font(.body)
                    FlowRow(spacing: 8) {
                        Chip(
                            label: L10n.t("ui.system"),
                            selected: settings.language == nil,
                            action: { onChange { $0.copy(language: .some(nil)) } }
                        )
                        ForEach(SpeechLanguage.allCases, id: \.self) { lang in
                            Chip(
                                label: lang.displayName,
                                selected: settings.language == lang,
                                action: { onChange { $0.copy(language: .some(lang)) } }
                            )
                        }
                    }
                }

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
