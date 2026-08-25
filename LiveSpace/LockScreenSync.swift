import Foundation
import AVFoundation
import AppKit

enum LockScreenSync {
    private static let aerialsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos")
    private static let backupSuffix = ".livespace-backup"
    private static let stateFile = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LiveSpace/lockscreen-state.json")

    static func sync(videoURL: URL) {
        DebugLog.write("LockScreenSync.sync called for \(videoURL.lastPathComponent)")
        HEVCTranscoder.hevcURL(for: videoURL) { hevcURL in
            guard let hevcURL else {
                DebugLog.write("LockScreenSync got nil hevcURL, aborting")
                return
            }
            DebugLog.write("LockScreenSync proceeding to install with \(hevcURL.lastPathComponent)")
            DispatchQueue.global(qos: .utility).async {
                install(hevcSourceURL: hevcURL)
            }
        }
    }

    static func restore(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let ok = performRestore()
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func hasDownloadedAerial() -> Bool {
        findAerialSlot() != nil
    }

    static func refreshOnLock() {
        let config = ConfigStore.shared.load()
        guard config.lockScreenEnabled else { return }
        DebugLog.write("[LockScreenSync] refreshing on lock event")
        restartWallpaperAgent()
    }

    private static func findAerialSlot() -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: aerialsDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files.first {
            $0.pathExtension == "mov" && !$0.lastPathComponent.hasSuffix(backupSuffix) && !$0.lastPathComponent.hasSuffix(".tmp")
        }
    }

    private static func install(hevcSourceURL: URL) {
        DebugLog.write("install() starting for \(hevcSourceURL.lastPathComponent)")
        guard let aerialSlot = findAerialSlot() else {
            DebugLog.write("no downloaded Aerial found — pick one in System Settings > Screen Saver first")
            return
        }
        DebugLog.write("found aerial slot \(aerialSlot.lastPathComponent)")

        let backupURL = URL(fileURLWithPath: aerialSlot.path + backupSuffix)
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                try FileManager.default.copyItem(at: aerialSlot, to: backupURL)
            } catch {
                DebugLog.write("failed to back up original aerial: \(error)")
                return
            }
        }

        let tmpURL = URL(fileURLWithPath: aerialSlot.path + ".tmp")
        do {
            try? FileManager.default.removeItem(at: tmpURL)
            try FileManager.default.copyItem(at: hevcSourceURL, to: tmpURL)
            _ = try FileManager.default.replaceItemAt(aerialSlot, withItemAt: tmpURL)
        } catch {
            DebugLog.write("aerial slot swap failed: \(error)")
            return
        }

        DebugLog.write("aerial slot swap succeeded")
        saveState(aerialPath: aerialSlot.path, backupPath: backupURL.path)
        updateColdBootPoster(videoURL: hevcSourceURL)
        restartWallpaperAgent()
    }

    private static func updateColdBootPoster(videoURL: URL) {
        guard let uuid = generatedUID() else {
            DebugLog.write("could not resolve GeneratedUID for cold-boot poster")
            return
        }

        let cacheDir = URL(fileURLWithPath: "/Library/Caches/Desktop Pictures/\(uuid)")
        guard (try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)) != nil else {
            DebugLog.write("could not create cold-boot poster cache dir")
            return
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil) else {
            DebugLog.write("could not extract cold-boot poster frame")
            return
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }

        let posterURL = cacheDir.appendingPathComponent("lockscreen.png")
        let tmpURL = cacheDir.appendingPathComponent("lockscreen.new.png")
        do {
            try data.write(to: tmpURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(posterURL, withItemAt: tmpURL)
        } catch {
            DebugLog.write("cold-boot poster write failed: \(error)")
        }
    }

    private static func generatedUID() -> String? {
        guard let user = ProcessInfo.processInfo.environment["USER"] else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dscl")
        process.arguments = [".", "-read", "/Users/\(user)", "GeneratedUID"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return output.split(separator: " ").last.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func performRestore() -> Bool {
        guard let state = loadState(),
              let aerialPath = state["aerialPath"],
              let backupPath = state["backupPath"] else {
            return false
        }
        let aerialURL = URL(fileURLWithPath: aerialPath)
        let backupURL = URL(fileURLWithPath: backupPath)
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return false }

        let tmpURL = URL(fileURLWithPath: aerialURL.path + ".restore.tmp")
        do {
            try? FileManager.default.removeItem(at: tmpURL)
            try FileManager.default.copyItem(at: backupURL, to: tmpURL)
            _ = try FileManager.default.replaceItemAt(aerialURL, withItemAt: tmpURL)
        } catch {
            DebugLog.write("restore failed: \(error)")
            return false
        }

        try? FileManager.default.removeItem(at: stateFile)
        restartWallpaperAgent()
        return true
    }

    private static func restartWallpaperAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent", "WallpaperAerialsExtension"]
        try? process.run()
    }

    private static func saveState(aerialPath: String, backupPath: String) {
        let state = ["aerialPath": aerialPath, "backupPath": backupPath]
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateFile, options: .atomic)
    }

    private static func loadState() -> [String: String]? {
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}
