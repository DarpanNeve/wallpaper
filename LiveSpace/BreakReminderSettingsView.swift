import SwiftUI

struct BreakReminderSettingsView: View {
    @EnvironmentObject var state: AppState

    private static let accentPresets: [String] = [
        "#0A84FF", "#FF453A", "#FF9F0A", "#30D158", "#BF5AF2", "#64D2FF"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Mini Breaks", systemImage: "eye", tint: .cyan) {
                    Toggle("Enable Mini Breaks", isOn: $state.miniBreakEnabled)
                        .onChange(of: state.miniBreakEnabled) { _, _ in state.breakReminderChanged() }
                    if state.miniBreakEnabled {
                        breakSliderRow("Every", value: $state.miniBreakIntervalMinutes, range: 1...60, step: 1, suffix: "min")
                        breakSliderRow("Break for", value: $state.miniBreakDurationSeconds, range: 5...60, step: 5, suffix: "sec")
                    }
                    SettingsCaption("A short reminder to look away from the screen.")
                }

                SettingsSection("Long Breaks", systemImage: "figure.walk.motion", tint: .orange) {
                    Toggle("Enable Long Breaks", isOn: $state.longBreakEnabled)
                        .onChange(of: state.longBreakEnabled) { _, _ in state.breakReminderChanged() }
                    if state.longBreakEnabled {
                        breakSliderRow("Every", value: $state.longBreakIntervalMinutes, range: 5...120, step: 5, suffix: "min")
                        breakSliderRow("Break for", value: $state.longBreakDurationSeconds, range: 30...900, step: 30, suffix: "sec", asMinutesPast: 60)
                    }
                    SettingsCaption("A longer break to step away entirely. Skip, Pause, and Reset are in the menu bar.")
                }

                SettingsSection("Display", systemImage: "rectangle.on.rectangle", tint: .indigo) {
                    Toggle("Show on all displays", isOn: $state.showOnAllDisplays)
                        .onChange(of: state.showOnAllDisplays) { _, _ in state.breakReminderChanged() }
                    SettingsCaption("When off, the break overlay only appears on your main display instead of every connected screen.")
                }

                SettingsSection("Appearance", systemImage: "paintpalette", tint: .pink) {
                    HStack(spacing: 10) {
                        Text("Accent Color")
                            .frame(width: 90, alignment: .leading)
                        ForEach(Self.accentPresets, id: \.self) { hex in
                            swatch(hex)
                        }
                        ColorPicker("", selection: accentColorBinding)
                            .labelsHidden()
                    }

                    LabeledSegmentedPicker("Background", selection: $state.overlayMaterial) {
                        ForEach(OverlayMaterial.allCases) { material in
                            Text(material.label).tag(material)
                        }
                    }
                    .onChange(of: state.overlayMaterial) { _, _ in state.breakReminderChanged() }
                    SettingsCaption("Customizes the color and background of the break overlay window.")
                }
            }
            .padding(24)
        }
    }

    private var accentColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: state.accentColorHex) },
            set: {
                state.accentColorHex = $0.hexString
                state.breakReminderChanged()
            }
        )
    }

    private func swatch(_ hex: String) -> some View {
        Button {
            state.accentColorHex = hex
            state.breakReminderChanged()
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(.primary, lineWidth: state.accentColorHex.uppercased() == hex ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
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
