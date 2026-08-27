import AppKit
import SwiftUI

final class BreakOverlayModel: ObservableObject {
    @Published var kind: BreakKind = .mini
    @Published var remainingSeconds: Int = 0
    @Published var tip: String = ""
    var onSkip: () -> Void = {}
}

private struct BreakOverlayView: View {
    @ObservedObject var model: BreakOverlayModel

    var body: some View {
        VStack(spacing: 28) {
            Text(model.kind.title)
                .font(.system(size: 34, weight: .semibold))
            Text(timeString)
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(model.tip)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
            Button("Skip", action: model.onSkip)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    /// Matches the standard macOS window corner radius (the same continuous "squircle" curve
    /// every titled `NSWindow` gets automatically) - this panel is borderless, so it has to be
    /// replicated by hand rather than inherited for free.
    private static let cornerRadius: CGFloat = 12

    private var timeString: String {
        let minutes = model.remainingSeconds / 60
        let seconds = model.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Deliberately near-fullscreen (80% of each screen, not the literal full-screen takeover
/// declined earlier) - a small floating card didn't create enough real pressure to actually stop
/// working, per user feedback after seeing it live. Still `.nonactivatingPanel`, so it never
/// steals focus/activates the app over whatever the user was in, matching "window mode" rather
/// than becoming a true fullscreen window (which would also fight Spaces/Mission Control).
/// `.regularMaterial` tracks light/dark automatically - no manual appearance tracking needed here.
final class BreakOverlayWindow: NSPanel {
    private static let screenFraction: CGFloat = 0.8

    init(screen: NSScreen, model: BreakOverlayModel) {
        // `visibleFrame`, not `frame` - centers on the usable desktop area, excluding the menu
        // bar/Dock strips `frame` includes, which otherwise skews the panel off-center relative
        // to what's actually visible.
        let visible = screen.visibleFrame
        let size = NSSize(
            width: visible.width * Self.screenFraction,
            height: visible.height * Self.screenFraction
        )
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: BreakOverlayView(model: model))
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { true }
}
