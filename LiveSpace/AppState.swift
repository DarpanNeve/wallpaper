import Foundation
import AppKit
import Combine

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
    @Published var videoFileNames: [String] = []
    @Published var currentVideoIndex: Int = 0

    private var refreshTimer: Timer?

    init() {
        let config = ConfigStore.shared.load()
        folderPath = config.folderPath
        intervalMinutes = config.intervalSeconds / 60
        lockScreenEnabled = config.lockScreenEnabled
        startOffsetPercent = config.startOffsetPercent
        rotateOnVideoEnd = config.rotateOnVideoEnd
        refreshVideoCount()
        refreshInstallStatus()
        refreshLockScreenStatus()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshVideoCount() }
        }
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
        }
        refreshVideoCount()
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
            lockScreenStatus = "No Apple Aerial wallpaper found — pick one in Screen Saver settings first"
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
