import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Wallpaper Folder") {
                    HStack {
                        Text(state.folderPath)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { state.chooseFolder() }
                    }
                    Text("\(state.videoCount) video\(state.videoCount == 1 ? "" : "s") found (.mp4, .mov, .m4v)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Create Folder If Missing") { state.createFolderIfNeeded() }
                        .font(.caption)
                }

                section("Rotation") {
                    HStack(spacing: 12) {
                        Text("Change every")
                        Slider(value: $state.intervalMinutes, in: 1...180, step: 1)
                            .onChange(of: state.intervalMinutes) { _, _ in state.intervalChanged() }
                        Text("\(Int(state.intervalMinutes)) min")
                            .frame(width: 56, alignment: .trailing)
                            .monospacedDigit()
                    }

                    if !state.videoFileNames.isEmpty {
                        HStack(spacing: 12) {
                            Text("Now playing")
                            Picker("", selection: $state.currentVideoIndex) {
                                ForEach(Array(state.videoFileNames.enumerated()), id: \.offset) { index, name in
                                    Text(name).tag(index)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: state.currentVideoIndex) { _, newValue in
                                state.jumpToVideo(index: newValue)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Text("Start each video at")
                        Slider(value: $state.startOffsetPercent, in: 0...90, step: 5)
                            .onChange(of: state.startOffsetPercent) { _, _ in state.startOffsetChanged() }
                        Text("\(Int(state.startOffsetPercent))%")
                            .frame(width: 56, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                section("Screen Saver Plugin") {
                    HStack {
                        Circle()
                            .fill(state.installStatus == "Installed" ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(state.installStatus)
                        Spacer()
                        Button("Uninstall") { state.uninstallSaver() }
                            .disabled(state.installStatus != "Installed")
                        Button("Install") { state.installSaver() }
                    }
                    caption("After installing: System Settings → Screen Saver → select LiveSpace → enable \"Show as wallpaper\". Then System Settings → Lock Screen → enable \"Show screen saver\" for lock screen live wallpaper.")
                    Button("Open System Settings") { state.openSystemSettings() }
                }

                section("Lock Screen (experimental)") {
                    Toggle("Sync playlist to lock screen", isOn: $state.lockScreenEnabled)
                        .onChange(of: state.lockScreenEnabled) { _, _ in state.lockScreenToggled() }
                    Text(state.lockScreenStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    caption("Uses an undocumented macOS mechanism (replaces a downloaded Apple Aerial wallpaper's video file). Could break on a future macOS update. Requires selecting an Apple Aerial as your Screen Saver first, with \"Show screen saver on lock screen\" enabled in System Settings.")
                    Button("Restore Original Lock Screen") { state.restoreOriginalLockScreen() }
                        .font(.caption)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 560, minHeight: 520, idealHeight: 620)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
