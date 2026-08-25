import AppKit

final class WallpaperEngine {
    private var windows: [WallpaperWindow] = []
    private var currentVideoURL: URL?
    private var currentStartOffsetPercent: Double = 0
    private var currentRotateOnVideoEnd: Bool = false
    var onVideoEnded: (() -> Void)?

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
            setVideo(url: url, startOffsetPercent: currentStartOffsetPercent, rotateOnVideoEnd: currentRotateOnVideoEnd)
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { WallpaperWindow(screen: $0) }
    }

    func setVideo(url: URL, startOffsetPercent: Double = 0, rotateOnVideoEnd: Bool = false) {
        currentVideoURL = url
        currentStartOffsetPercent = startOffsetPercent
        currentRotateOnVideoEnd = rotateOnVideoEnd
        for (index, window) in windows.enumerated() {
            window.setVideo(
                url: url,
                startOffsetPercent: startOffsetPercent,
                loop: !rotateOnVideoEnd,
                onEnded: index == 0 ? { [weak self] in self?.onVideoEnded?() } : nil
            )
        }
    }

    func pauseAll() {
        windows.forEach { $0.pause() }
    }

    func resumeAll() {
        windows.forEach { $0.resume() }
    }
}
