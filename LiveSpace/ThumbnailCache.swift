import AVFoundation
import AppKit

/// Disk-cached video thumbnail + duration lookup for the Library tab. Mirrors `HEVCTranscoder`'s
/// cache-by-path+mtime scheme so a file replaced in place (same name, new mtime) invalidates
/// correctly. Throttles concurrent generation so opening the Library tab on a large uncached
/// folder doesn't fire dozens of simultaneous `AVAssetImageGenerator` decodes at once.
enum ThumbnailCache {
    private static var cacheDir: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveSpace/ThumbnailCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let maxConcurrent = 4
    private static var activeCount = 0
    private static var pendingWork: [() -> Void] = []
    /// Serializes access to `activeCount`/`pendingWork`, which are otherwise touched from both
    /// the calling thread (usually main) and AVFoundation's background completion callbacks.
    private static let queueLock = DispatchQueue(label: "com.syntexco.kineticdesk.thumbnailcache")

    private static func cacheKey(for sourceURL: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let mtime = Int((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
        let safeName = sourceURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
        return "\(safeName)-\(mtime)"
    }

    static func thumbnail(for sourceURL: URL, maxDimension: CGFloat = 320, completion: @escaping (NSImage?) -> Void) {
        let outputURL = cacheDir.appendingPathComponent("\(cacheKey(for: sourceURL)).jpg")

        if let cached = NSImage(contentsOf: outputURL) {
            completion(cached)
            return
        }

        enqueue {
            generate(sourceURL: sourceURL, outputURL: outputURL, maxDimension: maxDimension) { image in
                DispatchQueue.main.async { completion(image) }
                finishOne()
            }
        }
    }

    /// Not disk-cached - `AVURLAsset.load(.duration)` only reads the `moov` atom header, cheap
    /// enough to recompute every session unlike thumbnail rendering's real decode+resample cost.
    static func duration(for sourceURL: URL, completion: @escaping (TimeInterval?) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        Task {
            let seconds = (try? await asset.load(.duration).seconds).flatMap { $0.isFinite ? $0 : nil }
            await MainActor.run { completion(seconds) }
        }
    }

    private static func enqueue(_ work: @escaping () -> Void) {
        queueLock.sync {
            pendingWork.append(work)
        }
        drainQueue()
    }

    private static func finishOne() {
        queueLock.sync {
            activeCount -= 1
        }
        drainQueue()
    }

    private static func drainQueue() {
        while true {
            let next: (() -> Void)? = queueLock.sync {
                guard activeCount < maxConcurrent, !pendingWork.isEmpty else { return nil }
                activeCount += 1
                return pendingWork.removeFirst()
            }
            guard let next else { return }
            next()
        }
    }

    private static func generate(
        sourceURL: URL,
        outputURL: URL,
        maxDimension: CGFloat,
        completion: @escaping (NSImage?) -> Void
    ) {
        let asset = AVURLAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: 0)

        Task {
            let durationSeconds = (try? await asset.load(.duration).seconds) ?? 0
            let targetSeconds = min(1.0, durationSeconds / 2)
            let time = CMTime(seconds: max(0, targetSeconds), preferredTimescale: 600)

            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, error in
                guard let cgImage else {
                    DebugLog.write("thumbnail generation failed for \(sourceURL.lastPathComponent): \(String(describing: error))")
                    completion(nil)
                    return
                }
                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                if let jpegData = image.jpegData {
                    try? jpegData.write(to: outputURL)
                }
                completion(image)
            }
        }
    }
}

private extension NSImage {
    var jpegData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
