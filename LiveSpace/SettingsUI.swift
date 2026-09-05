import SwiftUI

/// Card-style settings section used across all Settings tabs - a labeled group with an icon
/// badge, matching the colored-icon rows of the native macOS System Settings app.
struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder let content: Content

    init(_ title: String, systemImage: String, tint: Color = .accentColor, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                iconBadge
                Text(title)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var iconBadge: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Secondary explanatory text under a control - wraps instead of truncating.
struct SettingsCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labeled segmented picker row - `Label:  [Option A | Option B | ...]`.
/// Segmented `Picker(_:selection:)` doesn't reliably show its label on macOS outside a Form,
/// so every picker row in Settings uses this instead of the labeled initializer.
struct LabeledSegmentedPicker<Value: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: Value
    @ViewBuilder let content: Content

    init(_ label: String, selection: Binding<Value>, @ViewBuilder content: () -> Content) {
        self.label = label
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 90, alignment: .leading)
            Picker("", selection: $selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }
}
