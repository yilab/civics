import Foundation
import SwiftUI

struct SettingsScreen: View {
    let settings: StudySettings
    let onChange: ((StudySettings) -> StudySettings) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Voice") {
                    Text(String(format: "Speech rate: %.2f×", settings.speechRate))
                        .font(.body)
                    Slider(
                        value: Binding(
                            get: { settings.speechRate },
                            set: { v in onChange { $0.copy(speechRate: Float((v * 20).rounded() / 20)) } }
                        ),
                        in: 0.75...1.5
                    )
                    SwitchRow(
                        label: "Announce question number",
                        checked: settings.announceMeta,
                        onChange: { v in onChange { $0.copy(announceMeta: v) } }
                    )
                }

                SettingsSection("Playback") {
                    Text("Pause before revealing the answer")
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
                        label: "Auto-advance after the answer",
                        checked: settings.autoAdvance,
                        onChange: { v in onChange { $0.copy(autoAdvance: v) } }
                    )
                }

                SettingsSection("Deck") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Categories.values, id: \.self) { cat in
                            Chip(
                                label: cat == Categories.all ? "All 128 questions" : cat,
                                selected: settings.category == cat,
                                action: { onChange { $0.copy(category: cat) } }
                            )
                        }
                    }
                    SwitchRow(
                        label: "Shuffle",
                        checked: settings.shuffle,
                        onChange: { v in onChange { $0.copy(shuffle: v) } }
                    )
                }

                SettingsSection("Progress") {
                    Text("\(settings.known.count) of 128 marked as known")
                        .font(.body)
                    Button("Clear known marks") {
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
            (StudySettings.thinkWaitForPress, "Wait"),
            (0, "None"),
            (3, "3s"),
            (5, "5s"),
            (10, "10s"),
        ]
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
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
