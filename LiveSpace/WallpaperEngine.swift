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
        rebuildWindows()
        onScreensChanged?()
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = WallpaperWindow(screen: screen)
            let screenID = window.screenID
            window.onEnded = { [weak self] in self?.onVideoEnded?(screenID) }
            return window
        }
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
