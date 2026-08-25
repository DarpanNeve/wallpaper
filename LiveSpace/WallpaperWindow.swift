import AppKit
import AVFoundation

final class WallpaperWindow: NSWindow {
    private let queuePlayer = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        level = NSWindow.Level(rawValue: desktopIconLevel - 1)
        isOpaque = true
        backgroundColor = .black
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        let hostView = NSView(frame: screen.frame)
        hostView.wantsLayer = true
        playerLayer.frame = hostView.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.player = queuePlayer
        hostView.layer?.addSublayer(playerLayer)
        contentView = hostView

        setFrame(screen.frame, display: true)
        orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionStateChanged),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: self
        )
    }

    func setVideo(url: URL, startOffsetPercent: Double = 0) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        queuePlayer.isMuted = true
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        if occlusionState.contains(.visible) {
            queuePlayer.play()
        }

        guard startOffsetPercent > 0 else { return }
        Task {
            guard let duration = try? await asset.load(.duration), duration.isValid, duration.seconds > 0 else { return }
            let seekSeconds = duration.seconds * min(max(startOffsetPercent, 0), 95) / 100
            await item.seek(to: CMTime(seconds: seekSeconds, preferredTimescale: 600))
        }
    }

    func pause() {
        queuePlayer.pause()
    }

    func resume() {
        guard occlusionState.contains(.visible) else { return }
        queuePlayer.play()
    }

    @objc private func occlusionStateChanged() {
        if occlusionState.contains(.visible) {
            queuePlayer.play()
        } else {
            queuePlayer.pause()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
