import AppKit
import AVFoundation

private final class WallpaperHostView: NSView {
    var onEffectiveAppearanceChanged: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onEffectiveAppearanceChanged?()
    }
}

private extension VideoRenderPattern {
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: return .resizeAspectFill
        case .fit: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

final class WallpaperWindow: NSWindow {
    private static let darkModeDimOpacity: Float = 0.35

    let screenID: String
    var onEnded: (() -> Void)?

    /// A 3-finger Space swipe briefly flips `occlusionState` off `.visible` for ~250-400ms even
    /// though this window is `.stationary`/`canJoinAllSpaces` and never actually moves. Reacting
    /// instantly caused an audible/visible stutter: `pause()` immediately followed by `play()`
    /// forces `AVPlayerLayer` to re-schedule display, which hitches right at the swipe. Debouncing
    /// past that window still catches real occlusion (fullscreen app, hidden Space — both last
    /// well over a second) so the battery-saving pause stays intact.
    private static let occlusionDebounce: TimeInterval = 0.5

    private let queuePlayer = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private let dimLayer = CALayer()
    private var looper: AVPlayerLooper?
    private var endObserver: NSObjectProtocol?
    private var pendingPause: DispatchWorkItem?

    init(screen: NSScreen) {
        screenID = screen.stableID
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        level = NSWindow.Level(rawValue: desktopIconLevel - 1)
        isOpaque = true
        backgroundColor = .black
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        let hostView = WallpaperHostView(frame: screen.frame)
        hostView.wantsLayer = true
        playerLayer.frame = hostView.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.player = queuePlayer
        hostView.layer?.addSublayer(playerLayer)

        dimLayer.frame = hostView.bounds
        dimLayer.backgroundColor = NSColor.black.cgColor
        hostView.layer?.addSublayer(dimLayer)

        hostView.onEffectiveAppearanceChanged = { [weak self] in self?.updateDimLayer() }
        contentView = hostView
        updateDimLayer()

        setFrame(screen.frame, display: true)
        orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionStateChanged),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: self
        )
    }

    func setVideo(url: URL, startOffsetPercent: Double = 0, loop: Bool = true, pattern: VideoRenderPattern = .fill) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        looper = nil
        playerLayer.videoGravity = pattern.videoGravity

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        queuePlayer.isMuted = true

        if loop {
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        } else {
            queuePlayer.removeAllItems()
            queuePlayer.insert(item, after: nil)
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.endObserver = nil
                self?.onEnded?()
            }
        }

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

    private func updateDimLayer() {
        let isDarkMode = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        dimLayer.opacity = isDarkMode ? Self.darkModeDimOpacity : 0
    }

    @objc private func occlusionStateChanged() {
        pendingPause?.cancel()
        if occlusionState.contains(.visible) {
            queuePlayer.play()
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.occlusionState.contains(.visible) else { return }
                self.queuePlayer.pause()
            }
            pendingPause = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.occlusionDebounce, execute: work)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
