import AppKit

final class WallpaperEngine {
    private var windows: [WallpaperWindow] = []
    var onVideoEnded: ((String) -> Void)?
    var onScreensChanged: (() -> Void)?

    init() {
        rebuildWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        DebugLog.write("[WallpaperEngine] didChangeScreenParametersNotification: \(NSScreen.screens.map { "\($0.stableID)=\($0.frame)" })")
        guard rebuildWindows() else {
            DebugLog.write("[WallpaperEngine] rebuildWindows: no identity change, skipped teardown/onScreensChanged")
            return
        }
        DebugLog.write("[WallpaperEngine] rebuildWindows: display set changed, rebuilt + firing onScreensChanged")
        onScreensChanged?()
    }

    /// `didChangeScreenParametersNotification` can fire with the exact same set of physical
    /// displays - an external display renegotiating color space/HDR/refresh rate (observed with a
    /// new Chrome window landing on it) reposts it with a nudged frame, not a real add/remove.
    /// Destroying and recreating the window blanked that screen to black for a beat even though
    /// nothing about the display actually changed identity. A same-`stableID` frame change is now
    /// resized in place (`updateFrame`, no teardown, `queuePlayer` keeps running) instead. Only an
    /// actual add/remove of a physical display (the `stableID` set itself changing) tears a window
    /// down or creates one - and only that case returns `true`, so `onScreensChanged` (which forces
    /// every window to reload its video, its own decode-restart cost) doesn't fire for a resize.
    @discardableResult
    private func rebuildWindows() -> Bool {
        let screens = NSScreen.screens
        let screenIDs = Set(screens.map { $0.stableID })
        let existingIDs = Set(windows.map { $0.screenID })

        for screen in screens {
            if let existing = windows.first(where: { $0.screenID == screen.stableID }), existing.frame != screen.frame {
                DebugLog.write("[WallpaperEngine] resizing in place: \(screen.stableID) \(existing.frame) -> \(screen.frame)")
                existing.updateFrame(screen.frame)
            }
        }

        guard screenIDs != existingIDs else { return false }

        windows
            .filter { !screenIDs.contains($0.screenID) }
            .forEach { $0.orderOut(nil) }

        let newWindows = screens
            .filter { !existingIDs.contains($0.stableID) }
            .map { screen -> WallpaperWindow in
                let window = WallpaperWindow(screen: screen)
                let screenID = window.screenID
                window.onEnded = { [weak self] in self?.onVideoEnded?(screenID) }
                return window
            }

        windows = windows.filter { screenIDs.contains($0.screenID) } + newWindows
        return true
    }

    func setVideo(screenID: String, url: URL, startOffsetPercent: Double = 0, loop: Bool = true, pattern: VideoRenderPattern = .fill) {
        guard let window = windows.first(where: { $0.screenID == screenID }) else { return }
        window.setVideo(url: url, startOffsetPercent: startOffsetPercent, loop: loop, pattern: pattern)
    }

    func pauseAll() {
        windows.forEach { $0.pause() }
    }

    func resumeAll() {
        windows.forEach { $0.resume() }
    }
}
