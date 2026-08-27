import AppKit

enum BreakKind {
    case mini
    case long

    var title: String {
        switch self {
        case .mini: return "Mini Break"
        case .long: return "Long Break"
        }
    }
}

private enum BreakTips {
    static let all: [String] = [
        "Look at something 20 feet away for 20 seconds.",
        "Roll your shoulders backward, slowly.",
        "Stand up and stretch your arms overhead.",
        "Relax your jaw and unclench your teeth.",
        "Take five slow, deep breaths.",
        "Blink several times to re-wet your eyes.",
        "Roll your neck gently side to side.",
        "Shake out your hands and wrists.",
        "Stretch your legs, stand and walk a few steps.",
        "Sit up straight and drop your shoulders."
    ]

    static func random() -> String { all.randomElement() ?? "" }
}

/// Singleton (matches `ConfigStore`/`WindowOpener`/`RotationTrigger` - this app's convention for
/// shared modules) so the menu bar can drive it directly without threading a reference through
/// `AppState`. Reads `BreakReminderConfig` fresh from `ConfigStore` every tick, same pattern as
/// `RotationController.tick()`, so Settings changes apply live with no extra wiring.
@MainActor
final class BreakReminderController {
    static let shared = BreakReminderController()

    private var timer: Timer?
    private var miniElapsed: TimeInterval = 0
    private var longElapsed: TimeInterval = 0
    private var pausedUntil: Date?
    private var breakEndTime: Date?
    private var activeKind: BreakKind?
    private var overlayWindows: [BreakOverlayWindow] = []
    private let overlayModel = BreakOverlayModel()

    private init() {
        overlayModel.onSkip = { [weak self] in self?.dismissBreak() }
    }

    func start() {
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var statusText: String {
        if let activeKind {
            return "\(activeKind.title) in progress"
        }
        if let pausedUntil {
            return "Paused for \(Self.formatted(pausedUntil.timeIntervalSinceNow))"
        }
        let config = ConfigStore.shared.load().breakReminder
        var remainders: [TimeInterval] = []
        if config.miniBreakEnabled {
            remainders.append(config.miniBreakIntervalMinutes * 60 - miniElapsed)
        }
        if config.longBreakEnabled {
            remainders.append(config.longBreakIntervalMinutes * 60 - longElapsed)
        }
        guard let soonest = remainders.min() else {
            return "No breaks enabled"
        }
        return "Next break in \(Self.formatted(soonest))"
    }

    /// Compact `mm:ss` form for the menu bar title itself (the full sentence in `statusText` is
    /// too long to sit in the bar) - counts down to the next break, or the remaining break time
    /// while one is showing.
    var menuBarTimeText: String {
        if activeKind != nil {
            guard let breakEndTime else { return "--:--" }
            return Self.compact(breakEndTime.timeIntervalSinceNow)
        }
        if let pausedUntil {
            return "Paused for \(Self.formatted(pausedUntil.timeIntervalSinceNow))"
        }
        let config = ConfigStore.shared.load().breakReminder
        var remainders: [TimeInterval] = []
        if config.miniBreakEnabled {
            remainders.append(config.miniBreakIntervalMinutes * 60 - miniElapsed)
        }
        if config.longBreakEnabled {
            remainders.append(config.longBreakIntervalMinutes * 60 - longElapsed)
        }
        guard let soonest = remainders.min() else {
            return "--:--"
        }
        return Self.compact(soonest)
    }

    private static func compact(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Dismisses any break currently showing, then pauses the schedule for `duration`.
    func pause(for duration: TimeInterval) {
        dismissBreak()
        pausedUntil = Date().addingTimeInterval(duration)
        DebugLog.write("breakReminder: paused until \(pausedUntil!)")
    }

    func reset() {
        miniElapsed = 0
        longElapsed = 0
        pausedUntil = nil
        dismissBreak()
        DebugLog.write("breakReminder: reset")
    }

    private func tick() {
        if activeKind != nil {
            guard let breakEndTime else { return }
            if breakEndTime.timeIntervalSinceNow <= 0 {
                dismissBreak()
            } else {
                // Deliberately NOT re-measuring `breakEndTime.timeIntervalSinceNow` into the
                // displayed number each tick - a wall-clock float sampled once a second is right on
                // top of ceil()'s own integer boundary, so a few ms of ordinary Timer jitter either
                // way flips the rounded result and the display stutters (holds a value for 2 ticks)
                // or skips one. Counting fires down by exactly 1 is immune to that: it can only ever
                // move by one, every tick, full stop. `breakEndTime` above still solely decides when
                // the break actually ends, so a rare stalled tick just makes the overlay disappear a
                // beat after the display reads "0" rather than skewing what's shown mid-countdown.
                overlayModel.remainingSeconds = max(0, overlayModel.remainingSeconds - 1)
            }
            return
        }

        if let pausedUntil {
            guard Date() >= pausedUntil else { return }
            self.pausedUntil = nil
        }

        let config = ConfigStore.shared.load().breakReminder
        if config.miniBreakEnabled { miniElapsed += 1 }
        if config.longBreakEnabled { longElapsed += 1 }

        if config.longBreakEnabled, longElapsed >= config.longBreakIntervalMinutes * 60 {
            trigger(.long, duration: config.longBreakDurationSeconds)
            longElapsed = 0
            miniElapsed = 0
        } else if config.miniBreakEnabled, miniElapsed >= config.miniBreakIntervalMinutes * 60 {
            trigger(.mini, duration: config.miniBreakDurationSeconds)
            miniElapsed = 0
        }
    }

    private func trigger(_ kind: BreakKind, duration: TimeInterval) {
        let now = Date()
        activeKind = kind
        breakEndTime = now.addingTimeInterval(duration)
        overlayModel.kind = kind
        overlayModel.remainingSeconds = Int(duration.rounded(.up))
        overlayModel.startTime = now
        overlayModel.duration = duration
        overlayModel.tip = BreakTips.random()
        overlayWindows = NSScreen.screens.map { BreakOverlayWindow(screen: $0, model: overlayModel) }
        DebugLog.write("breakReminder: triggered \(kind) duration=\(duration)s screens=\(overlayWindows.count)")
    }

    private func dismissBreak() {
        guard activeKind != nil else { return }
        DebugLog.write("breakReminder: dismissed")
        overlayWindows.forEach { $0.close() }
        overlayWindows = []
        activeKind = nil
        breakEndTime = nil
    }

    private static func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return minutes > 0 ? "\(minutes)m \(secs)s" : "\(secs)s"
    }
}
