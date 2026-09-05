import Foundation
import AppKit
import Combine

struct DisplayRowState: Identifiable, Equatable {
    let id: String
    let name: String
    /// True only when this display's folder/timing are actually customized - distinct from
    /// `hasOverride`, since a display can customize just its look/order and still play the
    /// default folder live.
    var isCustomFolder: Bool
    /// True if this display has ANY override at all (folder and/or look/order) - drives whether
    /// "Reset to Default" is shown.
    var hasOverride: Bool
    var folderPath: String
    var intervalMinutes: Double
    var rotateOnVideoEnd: Bool
    var startOffsetPercent: Double
    var renderPattern: VideoRenderPattern
    var orderPattern: PlaybackOrderPattern
    var videoCount: Int
}

@MainActor
final class AppState: ObservableObject {
    @Published var folderPath: String
    @Published var intervalMinutes: Double
    @Published var videoCount: Int = 0
    @Published var lockScreenEnabled: Bool
    @Published var lockScreenStatus: String = ""
    @Published var posterSyncEnabled: Bool
    @Published var posterSyncStatus: String = ""
    @Published var startOffsetPercent: Double
    @Published var rotateOnVideoEnd: Bool
    @Published var renderPattern: VideoRenderPattern
    @Published var orderPattern: PlaybackOrderPattern
    @Published var videoFileNames: [String] = []
    @Published var currentVideoIndex: Int = 0
    @Published var displayRows: [DisplayRowState] = []
    @Published var miniBreakEnabled: Bool
    @Published var miniBreakDurationSeconds: Double
    @Published var miniBreakIntervalMinutes: Double
    @Published var longBreakEnabled: Bool
    @Published var longBreakDurationSeconds: Double
    @Published var longBreakIntervalMinutes: Double
    @Published var showOnAllDisplays: Bool
    @Published var accentColorHex: String
    @Published var overlayMaterial: OverlayMaterial
    @Published var libraryItems: [LibraryVideoItem] = []
    @Published var appearanceMode: AppAppearance

    private var refreshTimer: Timer?

    init() {
        let config = ConfigStore.shared.load()
        folderPath = config.folderPath
        intervalMinutes = config.intervalSeconds / 60
        lockScreenEnabled = config.lockScreenEnabled
        posterSyncEnabled = config.posterSyncEnabled
        startOffsetPercent = config.startOffsetPercent
        rotateOnVideoEnd = config.rotateOnVideoEnd
        renderPattern = config.renderPattern
        orderPattern = config.orderPattern
        miniBreakEnabled = config.breakReminder.miniBreakEnabled
        miniBreakDurationSeconds = config.breakReminder.miniBreakDurationSeconds
        miniBreakIntervalMinutes = config.breakReminder.miniBreakIntervalMinutes
        longBreakEnabled = config.breakReminder.longBreakEnabled
        longBreakDurationSeconds = config.breakReminder.longBreakDurationSeconds
        longBreakIntervalMinutes = config.breakReminder.longBreakIntervalMinutes
        showOnAllDisplays = config.breakReminder.showOnAllDisplays
        accentColorHex = config.breakReminder.accentColorHex
        overlayMaterial = config.breakReminder.overlayMaterial
        appearanceMode = config.appearanceMode
        refreshVideoCount()
        refreshDisplays()
        refreshLockScreenStatus()
        refreshPosterSyncStatus()
        refreshLibrary()
    }

    /// Only runs while the Settings window is actually visible - this polls the playlist folder
    /// via `FileManager` every 3s, which is wasted disk/CPU churn when nobody's looking at it,
    /// and was previously running unconditionally from app launch for the app's entire lifetime.
    func startAutoRefresh() {
        guard refreshTimer == nil else { return }
        refreshVideoCount()
        refreshDisplays()
        refreshLibrary()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshVideoCount()
                self?.refreshDisplays()
                self?.refreshLibrary()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: folderPath, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderPath = url.path
        persist()
    }

    func createFolderIfNeeded() {
        try? FileManager.default.createDirectory(
            atPath: folderPath,
            withIntermediateDirectories: true
        )
        refreshVideoCount()
    }

    func intervalChanged() {
        persist()
    }

    func persist() {
        ConfigStore.shared.mutate { config in
            config.folderPath = self.folderPath
            config.intervalSeconds = self.intervalMinutes * 60
            config.lockScreenEnabled = self.lockScreenEnabled
            config.posterSyncEnabled = self.posterSyncEnabled
            config.startOffsetPercent = self.startOffsetPercent
            config.rotateOnVideoEnd = self.rotateOnVideoEnd
            config.renderPattern = self.renderPattern
            config.orderPattern = self.orderPattern
            config.breakReminder = self.breakReminderConfigSnapshot()
            config.appearanceMode = self.appearanceMode
        }
        refreshVideoCount()
        refreshDisplays()
        refreshLibrary()
    }

    func breakReminderChanged() {
        persist()
    }

    /// Applies immediately (not just on next launch) - `NSApp.appearance = nil` for `.system`
    /// lets AppKit fall back to following the OS setting again.
    func appearanceModeChanged() {
        NSApp.appearance = appearanceMode.nsAppearance
        persist()
    }

    func renderPatternChanged() {
        persist()
    }

    func orderPatternChanged() {
        persist()
    }

    func startOffsetChanged() {
        persist()
    }

    func rotateOnVideoEndToggled() {
        persist()
    }

    func jumpToVideo(index: Int) {
        guard index >= 0, index < videoFileNames.count else { return }
        currentVideoIndex = index
        ConfigStore.shared.mutate { config in
            config.currentIndex = index
            config.lastAdvanced = Date()
        }
        RotationTrigger.shared.forceTick?()
    }

    func nextVideo() {
        guard !videoFileNames.isEmpty else { return }
        jumpToVideo(index: (currentVideoIndex + 1) % videoFileNames.count)
    }

    // Undocumented mechanism: overwrites the .mov file backing a downloaded Apple Aerial
    // wallpaper slot, then kills WallpaperAgent to force a reload. No public API exists for this.
    func lockScreenToggled() {
        persist()
        refreshLockScreenStatus()
    }

    func refreshLockScreenStatus() {
        if !LockScreenSync.hasDownloadedAerial() {
            lockScreenStatus = "No Apple Aerial wallpaper found. Pick one in Screen Saver settings first"
        } else if lockScreenEnabled {
            lockScreenStatus = "Syncing with playlist"
        } else {
            lockScreenStatus = "Off"
        }
    }

    func restoreOriginalLockScreen() {
        LockScreenSync.restore { [weak self] success in
            self?.lockScreenStatus = success ? "Restored original Aerial" : "Nothing to restore"
        }
    }

    // Extracts a still frame from the current video and calls NSWorkspace.setDesktopImageURL
    // so the menu bar/Dock tint matches the video playing in our overlay window (which the OS
    // doesn't otherwise know about). Original desktopImageURL is captured before the first write.
    func posterSyncToggled() {
        persist()
        refreshPosterSyncStatus()
    }

    func refreshPosterSyncStatus() {
        posterSyncStatus = posterSyncEnabled
            ? "Syncing with playlist"
            : "Off"
    }

    func restoreOriginalWallpaper() {
        let restored = PosterFrameSync.restore()
        posterSyncStatus = restored ? "Restored original wallpaper" : "Nothing to restore"
    }

    func refreshVideoCount() {
        let config = ConfigStore.shared.load()
        let playlist = ConfigStore.shared.playlist(for: config)
        videoCount = playlist.count
        videoFileNames = playlist.map { $0.lastPathComponent }
        if !playlist.isEmpty {
            currentVideoIndex = config.currentIndex % playlist.count
        }
    }

    func refreshDisplays() {
        let config = ConfigStore.shared.load()
        displayRows = NSScreen.screens.map { screen in
            let id = screen.stableID
            let effective = config.effectiveScreenConfig(for: id)
            return DisplayRowState(
                id: id,
                name: screen.displayName,
                isCustomFolder: config.perScreen[id]?.customizesFolder ?? false,
                hasOverride: config.perScreen[id] != nil,
                folderPath: effective.folderPath,
                intervalMinutes: effective.intervalSeconds / 60,
                rotateOnVideoEnd: effective.rotateOnVideoEnd,
                startOffsetPercent: effective.startOffsetPercent,
                renderPattern: effective.renderPattern,
                orderPattern: effective.orderPattern,
                videoCount: ConfigStore.shared.playlist(inFolder: effective.folderPath).count
            )
        }
    }
}
