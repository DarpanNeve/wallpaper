import SwiftUI

struct DisplaysSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Displays", systemImage: "display.2", tint: .blue) {
                    if state.displayRows.isEmpty {
                        SettingsCaption("No displays detected.")
                    } else {
                        ForEach(Array(state.displayRows.enumerated()), id: \.element.id) { offset, display in
                            DisplayRowView(display: display)
                            if offset < state.displayRows.count - 1 {
                                Divider()
                            }
                        }
                    }
                    SettingsCaption("Every display uses the Playlist tab's defaults unless customized here.")
                }
            }
            .padding(24)
        }
    }
}

/// One row in the Displays tab. A dedicated view (rather than a `@ViewBuilder` function) so
/// `isExpanded` survives the parent's periodic `refreshDisplays()` re-renders.
private struct DisplayRowView: View {
    @EnvironmentObject var state: AppState
    let display: DisplayRowState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(display.name)
                            .font(.subheadline.bold())
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(display.videoCount) video\(display.videoCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if display.hasOverride {
                        HStack {
                            Spacer()
                            Button("Reset to Default") { state.resetToDefault(for: display.id) }
                                .font(.caption)
                        }
                    }

                    LabeledSegmentedPicker("Fill Style", selection: Binding(
                        get: { display.renderPattern },
                        set: { state.setRenderPattern($0, for: display.id) }
                    )) {
                        ForEach(VideoRenderPattern.allCases) { pattern in
                            Text(pattern.label).tag(pattern)
                        }
                    }

                    LabeledSegmentedPicker("Order", selection: Binding(
                        get: { display.orderPattern },
                        set: { state.setOrderPattern($0, for: display.id) }
                    )) {
                        ForEach(PlaybackOrderPattern.allCases) { pattern in
                            Text(pattern.label).tag(pattern)
                        }
                    }

                    Toggle("Use a different video folder for this display", isOn: Binding(
                        get: { display.isCustomFolder },
                        set: { state.setCustomFolder($0, for: display.id) }
                    ))
                    .font(.caption)

                    if display.isCustomFolder {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(display.folderPath)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Choose…") { state.chooseFolder(for: display.id) }
                            }

                            if display.orderPattern != .static {
                                LabeledSegmentedPicker("Switch", selection: Binding(
                                    get: { display.rotateOnVideoEnd },
                                    set: { state.setScreenRotateOnVideoEnd($0, for: display.id) }
                                )) {
                                    Text("On a Timer").tag(false)
                                    Text("Video Ends").tag(true)
                                }

                                if !display.rotateOnVideoEnd {
                                    HStack(spacing: 12) {
                                        Text("Every")
                                            .frame(width: 90, alignment: .leading)
                                        Slider(
                                            value: Binding(
                                                get: { display.intervalMinutes },
                                                set: { state.setScreenInterval($0, for: display.id) }
                                            ),
                                            in: 1...180, step: 1
                                        )
                                        Text("\(Int(display.intervalMinutes)) min")
                                            .frame(width: 56, alignment: .trailing)
                                            .monospacedDigit()
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                Text("Start at")
                                    .frame(width: 90, alignment: .leading)
                                Slider(
                                    value: Binding(
                                        get: { display.startOffsetPercent },
                                        set: { state.setScreenStartOffset($0, for: display.id) }
                                    ),
                                    in: 0...90, step: 5
                                )
                                Text("\(Int(display.startOffsetPercent))%")
                                    .frame(width: 56, alignment: .trailing)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 18)
            }
        }
    }

    private var summary: String {
        [
            display.renderPattern.label,
            display.orderPattern.label,
            display.isCustomFolder ? "Custom folder" : "Default playlist"
        ].joined(separator: " · ")
    }
}
