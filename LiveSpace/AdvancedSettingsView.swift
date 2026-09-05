import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Appearance", systemImage: "circle.lefthalf.filled", tint: .black) {
                    LabeledSegmentedPicker("App Theme", selection: $state.appearanceMode) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .onChange(of: state.appearanceMode) { _, _ in state.appearanceModeChanged() }
                    SettingsCaption("Controls KineticDesk's own windows. System follows your Mac's Light/Dark setting.")

                    LabeledSegmentedPicker("Wallpaper Theme", selection: $state.wallpaperAppearanceMode) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .onChange(of: state.wallpaperAppearanceMode) { _, _ in state.wallpaperAppearanceModeChanged() }
                    SettingsCaption("Controls the dim treatment on your desktop video. Can be set independently of App Theme above.")
                }

                SettingsSection("Startup", systemImage: "power", tint: .gray) {
                    Toggle("Launch KineticDesk at Login", isOn: launchAtLoginBinding)
                    SettingsCaption("Automatically starts KineticDesk when you log in to your Mac.")
                }

                SettingsSection("Desktop Wallpaper Sync", systemImage: "photo.on.rectangle", tint: .teal) {
                    Toggle("Match system wallpaper to playlist", isOn: $state.posterSyncEnabled)
                        .onChange(of: state.posterSyncEnabled) { _, _ in state.posterSyncToggled() }
                    Text(state.posterSyncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsCaption("Keeps your system wallpaper in sync with the current video. Your original wallpaper is backed up automatically.")
                    Button("Restore Original Wallpaper") { state.restoreOriginalWallpaper() }
                        .font(.caption)
                }

                SettingsSection("Lock Screen", systemImage: "lock.display", tint: .indigo) {
                    Toggle("Sync playlist to lock screen", isOn: $state.lockScreenEnabled)
                        .onChange(of: state.lockScreenEnabled) { _, _ in state.lockScreenToggled() }
                    Text(state.lockScreenStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsCaption("Experimental — may stop working after a macOS update. Requires an Apple Aerial wallpaper selected in Screen Saver settings first.")
                    Button("Restore Original Lock Screen") { state.restoreOriginalLockScreen() }
                        .font(.caption)
                }
            }
            .padding(24)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.setEnabled($0) }
        )
    }
}
