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
    /// past that window still catches real occlusion (fullscreen app, hidden Space - both last
    /// well over a second) so the battery-saving pause stays intact.
    private static let occlusionDebounce: TimeInterval = 0.5

    private let queuePlayer = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private let dimLayer = CALayer()
    private let hostView = WallpaperHostView()
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
        // .stationary dropped (was in [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]):
        // Apple docs say it makes the window "unaffected by Exposé" - observed as WindowServer
        // excluding this window from live compositing during Mission Control's exploded per-space
        // view, flickering to flat gray mid-session. Testing without it to see whether Mission
        // Control renders the video continuously instead, at the cost of possibly reintroducing
        // window-slide animation during Space switches (the reason it was added).
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenNone]

        hostView.frame = NSRect(origin: .zero, size: screen.frame.size)
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

    /// Repositions/resizes this window in place for a screen that changed frame but is still the
    /// same physical display (`stableID` unchanged) - e.g. a resolution or arrangement change, or
    /// the color-space/HDR renegotiation an external display does when a new GPU-accelerated
    /// window lands on it. Keeps `queuePlayer` running through the change instead of the black
    /// flash a full destroy-and-recreate caused (see `WallpaperEngine.rebuildWindows`).
    func updateFrame(_ frame: NSRect) {
        setFrame(frame, display: true)
        let bounds = NSRect(origin: .zero, size: frame.size)
        hostView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        dimLayer.frame = bounds
        CATransaction.commit()
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

    /// Sets this window's own `appearance`, independent of `NSApp.appearance` - lets the wallpaper's
    /// dim treatment follow a different Light/Dark choice than KineticDesk's own Settings UI.
    /// `mode.nsAppearance` is `nil` for `.system`, but `NSWindow.appearance = nil` falls back to
    /// `NSApp.appearance` (not the OS setting) when that's non-nil - which is exactly App Theme
    /// overriding Wallpaper Theme. Resolving `.system` to a concrete `NSAppearance` here, read
    /// straight from the OS default rather than through `NSApp`, breaks that inheritance.
    func applyAppearance(_ mode: AppAppearance) {
        appearance = mode.nsAppearance ?? NSAppearance(named: Self.systemIsDark() ? .darkAqua : .aqua)
        updateDimLayer()
    }

    private static func systemIsDark() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private func updateDimLayer() {
        let isDarkMode = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        dimLayer.opacity = isDarkMode ? Self.darkModeDimOpacity : 0
    }

    @objc private func occlusionStateChanged() {
        pendingPause?.cancel()
        if occlusionState.contains(.visible) {
            DebugLog.write("[WallpaperWindow \(screenID)] occlusion -> visible, play")
            queuePlayer.play()
        } else {
            DebugLog.write("[WallpaperWindow \(screenID)] occlusion -> not visible, scheduling debounced pause")
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.occlusionState.contains(.visible) else { return }
                DebugLog.write("[WallpaperWindow \(self.screenID)] debounced pause firing")
                self.queuePlayer.pause()
            }
            pendingPause = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.occlusionDebounce, execute: work)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
