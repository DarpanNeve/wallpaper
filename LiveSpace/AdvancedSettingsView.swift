import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Startup", systemImage: "power") {
                    Toggle("Launch LiveSpace at Login", isOn: launchAtLoginBinding)
                    SettingsCaption("Automatically starts LiveSpace when you log in to your Mac.")
                }

                SettingsSection("Desktop Wallpaper Sync", systemImage: "photo.on.rectangle") {
                    Toggle("Match system wallpaper to playlist", isOn: $state.posterSyncEnabled)
                        .onChange(of: state.posterSyncEnabled) { _, _ in state.posterSyncToggled() }
                    Text(state.posterSyncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsCaption("Keeps your system wallpaper in sync with the current video. Your original wallpaper is backed up automatically.")
                    Button("Restore Original Wallpaper") { state.restoreOriginalWallpaper() }
                        .font(.caption)
                }

                SettingsSection("Lock Screen", systemImage: "lock.display") {
                    Toggle("Sync playlist to lock screen", isOn: $state.lockScreenEnabled)
                        .onChange(of: state.lockScreenEnabled) { _, _ in state.lockScreenToggled() }
                    Text(state.lockScreenStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsCaption("Experimental — may stop working after a macOS update. Requires an Apple Aerial wallpaper selected in Screen Saver settings first.")
                    Button("Restore Original Lock Screen") { state.restoreOriginalLockScreen() }
                        .font(.caption)
                }

                SettingsSection("Break Reminder", systemImage: "figure.walk.motion") {
                    Toggle("Enable Mini Breaks", isOn: $state.miniBreakEnabled)
                        .onChange(of: state.miniBreakEnabled) { _, _ in state.breakReminderChanged() }
                    if state.miniBreakEnabled {
                        breakSliderRow("Every", value: $state.miniBreakIntervalMinutes, range: 1...60, step: 1, suffix: "min")
                        breakSliderRow("Break for", value: $state.miniBreakDurationSeconds, range: 5...60, step: 5, suffix: "sec")
                    }

                    Divider()

                    Toggle("Enable Long Breaks", isOn: $state.longBreakEnabled)
                        .onChange(of: state.longBreakEnabled) { _, _ in state.breakReminderChanged() }
                    if state.longBreakEnabled {
                        breakSliderRow("Every", value: $state.longBreakIntervalMinutes, range: 5...120, step: 5, suffix: "min")
                        breakSliderRow("Break for", value: $state.longBreakDurationSeconds, range: 30...900, step: 30, suffix: "sec", asMinutesPast: 60)
                    }

                    SettingsCaption("Shows a small floating window on every display when a break is due. Skip, Pause, and Reset are in the menu bar.")
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

    /// `asMinutesPast` renders values above that threshold as minutes instead of the raw suffix -
    /// used for the long-break duration slider, whose range runs well past a minute.
    private func breakSliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String,
        asMinutesPast: Double? = nil
    ) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range, step: step)
                .onChange(of: value.wrappedValue) { _, _ in state.breakReminderChanged() }
            Text(formattedBreakValue(value.wrappedValue, suffix: suffix, asMinutesPast: asMinutesPast))
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func formattedBreakValue(_ value: Double, suffix: String, asMinutesPast: Double?) -> String {
        if let threshold = asMinutesPast, value >= threshold {
            return "\(Int(value / 60)) min"
        }
        return "\(Int(value)) \(suffix)"
    }
}
