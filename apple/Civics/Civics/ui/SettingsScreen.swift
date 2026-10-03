import Foundation
import SwiftUI

struct SettingsScreen: View {
    let settings: StudySettings
    let officials: OfficialsData
    let onChange: ((StudySettings) -> StudySettings) -> Void
    var onResetStats: () -> Void = {}

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

                locationSection

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
                    SwitchRow(
                        label: L10n.t("settings.reviewFocus"),
                        checked: settings.reviewFocus,
                        onChange: { v in onChange { $0.copy(reviewFocus: v) } }
                    )
                    HStack(spacing: 12) {
                        Button(L10n.t("settings.clearKnown")) {
                            onChange { $0.copy(known: []) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(L10n.t("settings.resetStats")) {
                            onResetStats()
                        }
                        .buttonStyle(.bordered)
                    }
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

    private var locationSection: some View {
        let place = officials.places.first { $0.code == settings.jurisdiction }
        let districts = officials.districtOptions(placeCode: place?.code, today: OfficialsData.today())
        return SettingsSection("settings.location") {
            Text(L10n.t("settings.yourState"))
                .font(.body)
            Menu {
                Button(L10n.t("settings.notSet")) {
                    onChange { $0.copy(jurisdiction: .some(nil), district: .some(nil)) }
                }
                ForEach(officials.places, id: \.code) { p in
                    Button(p.name(language: settings.spokenLanguage)) {
                        onChange { $0.copy(jurisdiction: .some(p.code), district: .some(nil)) }
                    }
                }
            } label: {
                pickerLabel(place?.name(language: settings.spokenLanguage) ?? L10n.t("settings.notSet"))
            }
            if let place, place.seats > 1 {
                Text(L10n.t("settings.district"))
                    .font(.body)
                Menu {
                    Button(L10n.t("settings.notSet")) {
                        onChange { $0.copy(district: .some(nil)) }
                    }
                    ForEach(districts, id: \.district) { option in
                        Button(districtLabel(option.district, option.name)) {
                            onChange { $0.copy(district: .some(option.district)) }
                        }
                    }
                } label: {
                    pickerLabel(
                        settings.district.map { d in
                            districtLabel(d, districts.first { $0.district == d }?.name)
                        } ?? L10n.t("settings.notSet")
                    )
                }
                Link(L10n.t("settings.findDistrict"),
                     destination: URL(string: "https://www.house.gov/representatives/find-your-representative")!)
                    .font(.callout)
            }
            Text(L10n.t("settings.locationHint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func districtLabel(_ district: Int, _ name: String?) -> String {
        L10n.t("settings.district") + " \(district)" + (name.map { " · \($0)" } ?? "")
    }

    private func pickerLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
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
