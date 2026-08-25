import ScreenSaver
import AVFoundation

@objc(LiveSpaceSaverView)
final class LiveSpaceSaverView: ScreenSaverView {

    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var looper: AVPlayerLooper?
    private var rotationTimer: Timer?
    private var currentPlaylist: [URL] = []
    private var loadedIndex = -1

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0 / 30.0
    }

    override func startAnimation() {
        super.startAnimation()
        reload(force: true)
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkRotation()
        }
        RunLoop.current.add(timer, forMode: .common)
        rotationTimer = timer
    }

    override func stopAnimation() {
        super.stopAnimation()
        rotationTimer?.invalidate()
        rotationTimer = nil
        player?.pause()
    }

    override func animateOneFrame() {}

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    private func checkRotation() {
        let config = ConfigStore.shared.load()
        let playlist = ConfigStore.shared.playlist(for: config)
        guard !playlist.isEmpty else { return }

        var index = config.currentIndex % playlist.count
        if Date().timeIntervalSince(config.lastAdvanced) >= config.intervalSeconds {
            index = (index + 1) % playlist.count
            ConfigStore.shared.mutate { c in
                c.currentIndex = index
                c.lastAdvanced = Date()
            }
        }
        loadVideo(at: index, in: playlist)
    }

    private func reload(force: Bool) {
        let config = ConfigStore.shared.load()
        let playlist = ConfigStore.shared.playlist(for: config)
        guard !playlist.isEmpty else { return }
        loadVideo(at: config.currentIndex % playlist.count, in: playlist, force: force)
    }

    private func loadVideo(at index: Int, in playlist: [URL], force: Bool = false) {
        guard force || index != loadedIndex || playlist != currentPlaylist else { return }
        currentPlaylist = playlist
        loadedIndex = index

        let item = AVPlayerItem(url: playlist[index])
        let queuePlayer = AVQueuePlayer()
        let newLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        playerLayer?.removeFromSuperlayer()
        let newLayer = AVPlayerLayer(player: queuePlayer)
        newLayer.frame = bounds
        newLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(newLayer)

        queuePlayer.isMuted = true
        queuePlayer.play()

        player = queuePlayer
        playerLayer = newLayer
        looper = newLooper
    }
}
