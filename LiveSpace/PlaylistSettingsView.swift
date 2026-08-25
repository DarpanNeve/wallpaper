import SwiftUI

struct PlaylistSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Now Playing", systemImage: "play.circle") {
                    if state.videoFileNames.isEmpty {
                        SettingsCaption("No videos found yet — add some to your video folder below.")
                    } else {
                        HStack(spacing: 12) {
                            Picker("", selection: $state.currentVideoIndex) {
                                ForEach(Array(state.videoFileNames.enumerated()), id: \.offset) { index, name in
                                    Text(name).tag(index)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: state.currentVideoIndex) { _, newValue in
                                state.jumpToVideo(index: newValue)
                            }
                            Button("Next Video") { state.nextVideo() }
                        }
                    }
                }

                SettingsSection("Video Folder", systemImage: "folder") {
                    HStack {
                        Text(state.folderPath)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { state.chooseFolder() }
                    }
                    SettingsCaption("\(state.videoCount) video\(state.videoCount == 1 ? "" : "s") found (.mp4, .mov, .m4v)")
                    Button("Create Folder If Missing") { state.createFolderIfNeeded() }
                        .font(.caption)
                }

                SettingsSection("Rotation", systemImage: "arrow.triangle.2.circlepath") {
                    LabeledSegmentedPicker("Order", selection: $state.orderPattern) {
                        ForEach(PlaybackOrderPattern.allCases) { pattern in
                            Text(pattern.label).tag(pattern)
                        }
                    }
                    .onChange(of: state.orderPattern) { _, _ in state.orderPatternChanged() }
                    SettingsCaption(state.orderPattern.explanation)

                    if state.orderPattern != .static {
                        LabeledSegmentedPicker("Switch", selection: timingSelection) {
                            Text("On a Timer").tag(false)
                            Text("Video Ends").tag(true)
                        }

                        if !state.rotateOnVideoEnd {
                            HStack(spacing: 12) {
                                Text("Every")
                                    .frame(width: 90, alignment: .leading)
                                Slider(value: $state.intervalMinutes, in: 1...180, step: 1)
                                    .onChange(of: state.intervalMinutes) { _, _ in state.intervalChanged() }
                                Text("\(Int(state.intervalMinutes)) min")
                                    .frame(width: 56, alignment: .trailing)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                SettingsSection("Appearance", systemImage: "rectangle.compress.vertical") {
                    LabeledSegmentedPicker("Fill Style", selection: $state.renderPattern) {
                        ForEach(VideoRenderPattern.allCases) { pattern in
                            Text(pattern.label).tag(pattern)
                        }
                    }
                    .onChange(of: state.renderPattern) { _, _ in state.renderPatternChanged() }
                    SettingsCaption("Fill crops to cover the screen, Fit letterboxes, Stretch distorts to fill exactly.")

                    HStack(spacing: 12) {
                        Text("Start at")
                            .frame(width: 90, alignment: .leading)
                        Slider(value: $state.startOffsetPercent, in: 0...90, step: 5)
                            .onChange(of: state.startOffsetPercent) { _, _ in state.startOffsetChanged() }
                        Text("\(Int(state.startOffsetPercent))%")
                            .frame(width: 56, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                SettingsCaption("These are the defaults every display uses. Give a specific monitor its own look or order in the Displays tab.")
            }
            .padding(24)
        }
    }

    private var timingSelection: Binding<Bool> {
        Binding(
            get: { state.rotateOnVideoEnd },
            set: { state.rotateOnVideoEnd = $0; state.rotateOnVideoEndToggled() }
        )
    }
}
