import AppKit

final class WallpaperEngine {
    private var windows: [WallpaperWindow] = []
    private var currentVideoURL: URL?
    private var currentStartOffsetPercent: Double = 0

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
        if let url = currentVideoURL {
            setVideo(url: url, startOffsetPercent: currentStartOffsetPercent)
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { WallpaperWindow(screen: $0) }
    }

    func setVideo(url: URL, startOffsetPercent: Double = 0) {
        currentVideoURL = url
        currentStartOffsetPercent = startOffsetPercent
        windows.forEach { $0.setVideo(url: url, startOffsetPercent: startOffsetPercent) }
    }

    func pauseAll() {
        windows.forEach { $0.pause() }
    }

    func resumeAll() {
        windows.forEach { $0.resume() }
    }
}
