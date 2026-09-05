import AppKit
import SwiftUI

final class BreakOverlayModel: ObservableObject {
    @Published var kind: BreakKind = .mini
    @Published var remainingSeconds: Int = 0
    @Published var tip: String = ""
    @Published var accentColor: Color = .primary
    @Published var material: Material = .regular
    var startTime: Date = Date()
    var duration: TimeInterval = 0
    var onSkip: () -> Void = {}
}

extension OverlayMaterial {
    var swiftUIMaterial: Material {
        switch self {
        case .regular: return .regular
        case .thick: return .thick
        case .ultraThin: return .ultraThin
        case .chrome: return .bar
        }
    }
}

private struct BreakOverlayView: View {
    @ObservedObject var model: BreakOverlayModel

    var body: some View {
        VStack(spacing: 28) {
            Text(model.kind.title)
                .font(.system(size: 34, weight: .semibold))
            ringAndTime
            Text(model.tip)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
            Button("Skip", action: model.onSkip)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(model.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(model.material)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    /// Matches the standard macOS window corner radius (the same continuous "squircle" curve
    /// every titled `NSWindow` gets automatically) - this panel is borderless, so it has to be
    /// replicated by hand rather than inherited for free.
    private static let cornerRadius: CGFloat = 12
    private static let ringDiameter: CGFloat = 260

    /// The number only updates once a second (it must - that's what's actually true), which on
    /// its own reads as stalled/frozen for that whole second. `TimelineView(.animation)` repaints
    /// the ring every frame straight off `startTime`/`duration`, independent of `remainingSeconds`,
    /// so there's always visible motion between ticks even though the digits still jump once a
    /// second.
    private var ringAndTime: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(model.startTime)
            let progress = model.duration > 0 ? min(max(elapsed / model.duration, 0), 1) : 0
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: 1 - progress)
                    .stroke(model.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timeString)
                    .font(.system(size: 68, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    // `TimelineView(.animation)` puts an implicit animation on everything it
                    // redraws each frame, including this - without opting out, the once-a-second
                    // digit jump gets tweened/morphed instead of snapping, reading as a glitch.
                    .animation(nil, value: model.remainingSeconds)
            }
            .frame(width: Self.ringDiameter, height: Self.ringDiameter)
        }
    }

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
