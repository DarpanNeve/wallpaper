import AppKit

final class RotationController {
    private struct LoadedState {
        var index = -1
        var playlist: [URL] = []
        var loop = true
    }

    private let engine: WallpaperEngine
    private var timer: Timer?
    private var loadedByGroup: [String: LoadedState] = [:]

    init(engine: WallpaperEngine) {
        self.engine = engine
    }

    func start() {
        engine.onVideoEnded = { [weak self] screenID in self?.advanceOnVideoEnd(screenID: screenID) }
        engine.onScreensChanged = { [weak self] in self?.tick(force: true) }
        tick(force: false)
        let t = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.tick(force: false)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        RotationTrigger.shared.forceTick = { [weak self] in self?.tick(force: false) }
    }

    /// Screens without a customized playlist share one "default" group and mirror the same video.
    /// Customized screens get their own group keyed by screen id, tracked and advanced independently.
    private func groupKey(screenID: String, config: PlaylistConfig) -> String {
        config.perScreen[screenID] != nil ? screenID : "default"
    }

    /// `.static` pins the current video and never auto-advances, so it always loops regardless
    /// of the "rotate when video ends" toggle.
    private func effectiveLoop(_ screenConfig: ScreenConfig) -> Bool {
        screenConfig.orderPattern == .static ? true : !screenConfig.rotateOnVideoEnd
    }

    private func nextIndex(after current: Int, count: Int, pattern: PlaybackOrderPattern) -> Int {
        switch pattern {
        case .static:
            return current
        case .fromStart:
            return (current + 1) % count
        case .fromEnd:
            return (current - 1 + count) % count
        case .random:
            guard count > 1 else { return current }
            let candidate = Int.random(in: 0..<count)
            return candidate == current ? (candidate + 1) % count : candidate
        }
    }

    private func tick(force: Bool) {
        let config = ConfigStore.shared.load()
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        var resolved: [String: (index: Int, playlist: [URL], screenConfig: ScreenConfig)] = [:]
        for screen in screens {
            let key = groupKey(screenID: screen.stableID, config: config)
            guard resolved[key] == nil else { continue }

            let screenConfig = config.effectiveScreenConfig(for: screen.stableID)
            let playlist = ConfigStore.shared.playlist(inFolder: screenConfig.folderPath)
            guard !playlist.isEmpty else { continue }

            var index = screenConfig.currentIndex % playlist.count
            let shouldAutoAdvance = screenConfig.orderPattern != .static
                && !screenConfig.rotateOnVideoEnd
                && Date().timeIntervalSince(screenConfig.lastAdvanced) >= screenConfig.intervalSeconds
            if shouldAutoAdvance {
                index = nextIndex(after: index, count: playlist.count, pattern: screenConfig.orderPattern)
                persistAdvance(index: index, key: key, screenID: screen.stableID)
            }
            resolved[key] = (index, playlist, screenConfig)
        }

        // "Changed" is decided once per GROUP, against state from *before* this tick, not
        // recomputed screen-by-screen - mutating `loadedByGroup` inside the screen loop below
        // used to make every mirrored screen after the first in a shared group see the state
        // its predecessor had *just written moments earlier in the same tick*, always reading as
        // unchanged, and silently never getting `setVideo` called at all on a normal (force:
        // false) tick - including the very first tick at launch. A screen stuck like that shows
        // its window's plain black background forever, since no video was ever loaded into it.
        var groupChanged: [String: Bool] = [:]
        for (key, resolvedValue) in resolved {
            let loop = effectiveLoop(resolvedValue.screenConfig)
            let loaded = loadedByGroup[key] ?? LoadedState()
            let changed = loaded.index != resolvedValue.index || loaded.playlist != resolvedValue.playlist || loaded.loop != loop
            groupChanged[key] = changed
            if force || changed {
                loadedByGroup[key] = LoadedState(index: resolvedValue.index, playlist: resolvedValue.playlist, loop: loop)
            }
        }

        for screen in screens {
            let screenID = screen.stableID
            let key = groupKey(screenID: screenID, config: config)
            guard let (index, playlist, screenConfig) = resolved[key] else { continue }
            guard force || (groupChanged[key] ?? false) else { continue }
            let loop = effectiveLoop(screenConfig)

            engine.setVideo(
                screenID: screenID,
                url: playlist[index],
                startOffsetPercent: screenConfig.startOffsetPercent,
                loop: loop,
                pattern: screenConfig.renderPattern
            )
            DebugLog.write("tick: screen=\(screenID) group=\(key) index=\(index) order=\(screenConfig.orderPattern.rawValue) file=\(playlist[index].lastPathComponent)")
            syncIfPrimary(key: key, config: config, videoURL: playlist[index])
        }
    }

    private func advanceOnVideoEnd(screenID: String) {
        let config = ConfigStore.shared.load()
        let key = groupKey(screenID: screenID, config: config)

        // Mirrored "default" screens all finish the same video near-simultaneously; only the
        // first one's signal advances the shared index, avoiding N-1 duplicate skips.
        if key == "default", screenID != NSScreen.screens.first?.stableID { return }

        let screenConfig = config.effectiveScreenConfig(for: screenID)
        guard screenConfig.orderPattern != .static, screenConfig.rotateOnVideoEnd else { return }
        let playlist = ConfigStore.shared.playlist(inFolder: screenConfig.folderPath)
        let loaded = loadedByGroup[key] ?? LoadedState()
        guard !playlist.isEmpty, loaded.index >= 0 else { return }

        let index = nextIndex(after: loaded.index, count: playlist.count, pattern: screenConfig.orderPattern)
        persistAdvance(index: index, key: key, screenID: screenID)
        loadedByGroup[key] = LoadedState(index: index, playlist: playlist, loop: false)

        for screen in NSScreen.screens where groupKey(screenID: screen.stableID, config: config) == key {
            engine.setVideo(
                screenID: screen.stableID,
                url: playlist[index],
                startOffsetPercent: screenConfig.startOffsetPercent,
                loop: false,
                pattern: screenConfig.renderPattern
            )
        }
        DebugLog.write("videoEnded: group=\(key) index=\(index) order=\(screenConfig.orderPattern.rawValue) file=\(playlist[index].lastPathComponent)")
        syncIfPrimary(key: key, config: config, videoURL: playlist[index])
    }

    private func persistAdvance(index: Int, key: String, screenID: String) {
        ConfigStore.shared.mutate { c in
            if key == "default" {
                c.currentIndex = index
                c.lastAdvanced = Date()
            } else {
                c.perScreen[screenID]?.currentIndex = index
                c.perScreen[screenID]?.lastAdvanced = Date()
            }
        }
    }

    /// Poster (menu bar/Dock tint) and lock-screen sync only make sense for one video -
    /// tie both to whichever group currently drives the main screen.
    private func syncIfPrimary(key: String, config: PlaylistConfig, videoURL: URL) {
        guard let mainID = NSScreen.main?.stableID, groupKey(screenID: mainID, config: config) == key else { return }
        PosterFrameSync.sync(videoURL: videoURL)
        if config.lockScreenEnabled {
            LockScreenSync.sync(videoURL: videoURL)
        }
    }
}
