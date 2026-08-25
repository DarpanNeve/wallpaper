import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Screen Saver Plugin", systemImage: "play.rectangle.on.rectangle") {
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
                    SettingsCaption("After installing: System Settings → Screen Saver → select LiveSpace → enable \"Show as wallpaper\". Then System Settings → Lock Screen → enable \"Show screen saver\" for lock screen live wallpaper.")
                    Button("Open System Settings") { state.openSystemSettings() }
                }

                SettingsSection("Lock Screen", systemImage: "lock.display") {
                    Toggle("Sync playlist to lock screen", isOn: $state.lockScreenEnabled)
                        .onChange(of: state.lockScreenEnabled) { _, _ in state.lockScreenToggled() }
                    Text(state.lockScreenStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsCaption("Experimental — uses an undocumented macOS mechanism (replaces a downloaded Apple Aerial wallpaper's video file). Could break on a future macOS update. Requires selecting an Apple Aerial as your Screen Saver first, with \"Show screen saver on lock screen\" enabled in System Settings.")
                    Button("Restore Original Lock Screen") { state.restoreOriginalLockScreen() }
                        .font(.caption)
                }
            }
            .padding(24)
        }
    }
}
