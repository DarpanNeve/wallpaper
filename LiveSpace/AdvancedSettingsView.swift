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

                    SettingsCaption("Shows a small floating window on every display when a break is due. Pauses while the system is idle. Skip, Pause, and Reset are in the menu bar.")
                }
            }
            .padding(24)
        }
    }

    /// `asMinutesPast` renders values above that threshold as minutes instead of the raw suffix —
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
