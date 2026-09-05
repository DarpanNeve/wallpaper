import AVFoundation
import AppKit

enum PosterFrameSync {
    private static var posterDir: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveSpace/PosterCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let stateFile = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LiveSpace/poster-sync-state.json")

    static func sync(videoURL: URL) {
        DispatchQueue.global(qos: .utility).async {
            guard let posterURL = generatePoster(for: videoURL) else {
                NSLog("KineticDesk: poster generation failed for \(videoURL.lastPathComponent)")
                return
            }
            DispatchQueue.main.async {
                backupOriginalsIfNeeded()
                var allSucceeded = true
                for screen in NSScreen.screens {
                    do {
                        try NSWorkspace.shared.setDesktopImageURL(posterURL, for: screen, options: [:])
                    } catch {
                        allSucceeded = false
                        NSLog("KineticDesk: setDesktopImageURL failed: \(error)")
                    }
                }
                if allSucceeded {
                    pruneOldPosters(keeping: posterURL)
                }
            }
        }
    }

    /// Captures each screen's real Desktop Picture the first time KineticDesk ever touches it, so
    /// `restore()` can hand it back later. Only runs once per screen (by `stableID`, survives
    /// relaunches via `stateFile`) - later calls would just capture our own poster instead of the
    /// user's original.
    private static func backupOriginalsIfNeeded() {
        var state = loadState()
        var changed = false
        for screen in NSScreen.screens {
            let id = screen.stableID
            guard state[id] == nil else { continue }
            guard let currentURL = NSWorkspace.shared.desktopImageURL(for: screen),
                  currentURL.deletingLastPathComponent() != posterDir else { continue }
            state[id] = currentURL.path
            changed = true
        }
        if changed { saveState(state) }
    }

    /// Restores every screen's original Desktop Picture and forgets the backup, so a later
    /// `sync()` treats the current picture as a fresh original again.
    static func restore() -> Bool {
        let state = loadState()
        guard !state.isEmpty else { return false }
        var restoredAny = false
        for screen in NSScreen.screens {
            guard let originalPath = state[screen.stableID] else { continue }
            let originalURL = URL(fileURLWithPath: originalPath)
            guard FileManager.default.fileExists(atPath: originalURL.path) else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(originalURL, for: screen, options: [:])
                restoredAny = true
            } catch {
                NSLog("KineticDesk: restore setDesktopImageURL failed: \(error)")
            }
        }
        try? FileManager.default.removeItem(at: stateFile)
        return restoredAny
    }

    private static func loadState() -> [String: String] {
        guard let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return state
    }

    private static func saveState(_ state: [String: String]) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateFile, options: .atomic)
    }

    private static func generatePoster(for videoURL: URL) -> URL? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let posterURL = posterDir.appendingPathComponent("poster-\(Int(Date().timeIntervalSince1970 * 1000)).png")
        try? data.write(to: posterURL, options: .atomic)
        return posterURL
    }

    private static func pruneOldPosters(keeping current: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: posterDir, includingPropertiesForKeys: nil) else { return }
        let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent }
        let keepSet = Set(sorted.prefix(2) + [current])
        for file in files where !keepSet.contains(file) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
