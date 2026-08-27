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
    @Published var installStatus: String = "Not installed"
    @Published var lockScreenEnabled: Bool
    @Published var lockScreenStatus: String = ""
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

    private var refreshTimer: Timer?

    init() {
        let config = ConfigStore.shared.load()
        folderPath = config.folderPath
        intervalMinutes = config.intervalSeconds / 60
        lockScreenEnabled = config.lockScreenEnabled
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
        refreshVideoCount()
        refreshDisplays()
        refreshInstallStatus()
        refreshLockScreenStatus()
    }

    /// Only runs while the Settings window is actually visible - this polls the playlist folder
    /// via `FileManager` every 3s, which is wasted disk/CPU churn when nobody's looking at it,
    /// and was previously running unconditionally from app launch for the app's entire lifetime.
    func startAutoRefresh() {
        guard refreshTimer == nil else { return }
        refreshVideoCount()
        refreshDisplays()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshVideoCount()
                self?.refreshDisplays()
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
            config.startOffsetPercent = self.startOffsetPercent
            config.rotateOnVideoEnd = self.rotateOnVideoEnd
            config.renderPattern = self.renderPattern
            config.orderPattern = self.orderPattern
            config.breakReminder = BreakReminderConfig(
                miniBreakEnabled: self.miniBreakEnabled,
                miniBreakDurationSeconds: self.miniBreakDurationSeconds,
                miniBreakIntervalMinutes: self.miniBreakIntervalMinutes,
                longBreakEnabled: self.longBreakEnabled,
                longBreakDurationSeconds: self.longBreakDurationSeconds,
                longBreakIntervalMinutes: self.longBreakIntervalMinutes
            )
        }
        refreshVideoCount()
        refreshDisplays()
    }

    func breakReminderChanged() {
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

    /// Creates a screen's override from its current effective values if it doesn't have one yet.
    /// `customizesFolder` only takes effect when it's `true` - it force-enables folder/timing
    /// customization on the entry (creating or updating), but a look/order-only change
    /// (`customizesFolder: false`) never turns off folder customization an entry already has.
    private func materializeOverride(id: String, customizesFolder: Bool, config: inout PlaylistConfig) {
        if config.perScreen[id] == nil {
            var fresh = config.effectiveScreenConfig(for: id)
            fresh.customizesFolder = customizesFolder
            config.perScreen[id] = fresh
        } else if customizesFolder {
            config.perScreen[id]?.customizesFolder = true
        }
    }

    func setRenderPattern(_ pattern: VideoRenderPattern, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: false, config: &config)
            config.perScreen[screenID]?.renderPattern = pattern
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setOrderPattern(_ pattern: PlaybackOrderPattern, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: false, config: &config)
            config.perScreen[screenID]?.orderPattern = pattern
            config.perScreen[screenID]?.currentIndex = 0
            config.perScreen[screenID]?.lastAdvanced = .distantPast
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setCustomFolder(_ enabled: Bool, for screenID: String) {
        ConfigStore.shared.mutate { config in
            if enabled {
                self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            } else if var override = config.perScreen[screenID] {
                override.customizesFolder = false
                override.currentIndex = 0
                override.lastAdvanced = .distantPast
                if override.renderPattern == config.renderPattern && override.orderPattern == config.orderPattern {
                    config.perScreen.removeValue(forKey: screenID)
                } else {
                    config.perScreen[screenID] = override
                }
            }
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    /// Fully reverts a display to the default group, discarding any look/order/folder overrides.
    func resetToDefault(for screenID: String) {
        ConfigStore.shared.mutate { config in
            config.perScreen.removeValue(forKey: screenID)
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func chooseFolder(for screenID: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.folderPath = url.path
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setScreenInterval(_ minutes: Double, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.intervalSeconds = minutes * 60
        }
        refreshDisplays()
    }

    func setScreenRotateOnVideoEnd(_ value: Bool, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.rotateOnVideoEnd = value
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setScreenStartOffset(_ value: Double, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.startOffsetPercent = value
        }
        refreshDisplays()
    }

    func installSaver() {
        do {
            try SaverInstaller.install()
            refreshInstallStatus()
        } catch {
            installStatus = "Install failed: \(error.localizedDescription)"
        }
    }

    func uninstallSaver() {
        do {
            try SaverInstaller.uninstall()
            refreshInstallStatus()
        } catch {
            installStatus = "Uninstall failed: \(error.localizedDescription)"
        }
    }

    func refreshInstallStatus() {
        installStatus = SaverInstaller.isInstalled() ? "Installed" : "Not installed"
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
    }
}
