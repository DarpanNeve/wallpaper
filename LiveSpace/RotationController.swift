import Foundation

final class RotationController {
    private let engine: WallpaperEngine
    private var timer: Timer?
    private var loadedIndex = -1
    private var loadedPlaylist: [URL] = []
    private var loadedRotateOnVideoEnd = false

    init(engine: WallpaperEngine) {
        self.engine = engine
    }

    func start() {
        engine.onVideoEnded = { [weak self] in self?.advanceOnVideoEnd() }
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        RotationTrigger.shared.forceTick = { [weak self] in self?.tick() }
    }

    private func tick() {
        let config = ConfigStore.shared.load()
        let playlist = ConfigStore.shared.playlist(for: config)
        guard !playlist.isEmpty else { return }

        var index = config.currentIndex % playlist.count
        if !config.rotateOnVideoEnd, Date().timeIntervalSince(config.lastAdvanced) >= config.intervalSeconds {
            index = (index + 1) % playlist.count
            ConfigStore.shared.mutate { c in
                c.currentIndex = index
                c.lastAdvanced = Date()
            }
        }

        guard index != loadedIndex || playlist != loadedPlaylist || config.rotateOnVideoEnd != loadedRotateOnVideoEnd else { return }
        load(index: index, playlist: playlist, config: config, reason: "tick")
    }

    private func advanceOnVideoEnd() {
        let config = ConfigStore.shared.load()
        guard config.rotateOnVideoEnd else { return }
        let playlist = ConfigStore.shared.playlist(for: config)
        guard !playlist.isEmpty, loadedIndex >= 0 else { return }

        let index = (loadedIndex + 1) % playlist.count
        ConfigStore.shared.mutate { c in
            c.currentIndex = index
            c.lastAdvanced = Date()
        }
        load(index: index, playlist: playlist, config: config, reason: "videoEnded")
    }

    private func load(index: Int, playlist: [URL], config: PlaylistConfig, reason: String) {
        loadedIndex = index
        loadedPlaylist = playlist
        loadedRotateOnVideoEnd = config.rotateOnVideoEnd
        engine.setVideo(url: playlist[index], startOffsetPercent: config.startOffsetPercent, rotateOnVideoEnd: config.rotateOnVideoEnd)
        PosterFrameSync.sync(videoURL: playlist[index])
        DebugLog.write("\(reason): reloaded index=\(index) file=\(playlist[index].lastPathComponent) lockScreenEnabled=\(config.lockScreenEnabled) rotateOnVideoEnd=\(config.rotateOnVideoEnd)")
        if config.lockScreenEnabled {
            LockScreenSync.sync(videoURL: playlist[index])
        }
    }
}
