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
                    Capsule().fill(selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15))
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.accentColor : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A minimal wrapping row so five language chips fit on narrow screens.
private struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
