import Foundation

final class RotationController {
    private let engine: WallpaperEngine
    private var timer: Timer?
    private var loadedIndex = -1
    private var loadedPlaylist: [URL] = []

    init(engine: WallpaperEngine) {
        self.engine = engine
    }

    func start() {
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
        if Date().timeIntervalSince(config.lastAdvanced) >= config.intervalSeconds {
            index = (index + 1) % playlist.count
            ConfigStore.shared.mutate { c in
                c.currentIndex = index
                c.lastAdvanced = Date()
            }
        }

        guard index != loadedIndex || playlist != loadedPlaylist else { return }
        loadedIndex = index
        loadedPlaylist = playlist
        engine.setVideo(url: playlist[index], startOffsetPercent: config.startOffsetPercent)
        PosterFrameSync.sync(videoURL: playlist[index])
        DebugLog.write("tick: reloaded index=\(index) file=\(playlist[index].lastPathComponent) lockScreenEnabled=\(config.lockScreenEnabled)")
        if config.lockScreenEnabled {
            LockScreenSync.sync(videoURL: playlist[index])
        }
    }
}
