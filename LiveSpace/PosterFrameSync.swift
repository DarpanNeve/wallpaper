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

    static func sync(videoURL: URL) {
        DispatchQueue.global(qos: .utility).async {
            guard let posterURL = generatePoster(for: videoURL) else {
                NSLog("LiveSpace: poster generation failed for \(videoURL.lastPathComponent)")
                return
            }
            DispatchQueue.main.async {
                var allSucceeded = true
                for screen in NSScreen.screens {
                    do {
                        try NSWorkspace.shared.setDesktopImageURL(posterURL, for: screen, options: [:])
                    } catch {
                        allSucceeded = false
                        NSLog("LiveSpace: setDesktopImageURL failed: \(error)")
                    }
                }
                if allSucceeded {
                    pruneOldPosters(keeping: posterURL)
                }
            }
        }
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
