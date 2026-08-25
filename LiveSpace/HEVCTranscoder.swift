import AVFoundation

enum HEVCTranscoder {
    private static var cacheDir: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveSpace/HEVCCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func hevcURL(for sourceURL: URL, completion: @escaping (URL?) -> Void) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let mtime = Int((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
        let safeName = sourceURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
        let outputURL = cacheDir.appendingPathComponent("\(safeName)-\(mtime).mov")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            DebugLog.write("HEVC cache hit for \(sourceURL.lastPathComponent) -> \(outputURL.lastPathComponent)")
            completion(outputURL)
            return
        }

        DebugLog.write("HEVC cache miss, starting export for \(sourceURL.lastPathComponent)")
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            DebugLog.write("could not create HEVC export session for \(sourceURL.lastPathComponent)")
            completion(nil)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        activeSessions.append(exportSession)
        exportSession.exportAsynchronously {
            DebugLog.write("HEVC export finished for \(sourceURL.lastPathComponent), status=\(exportSession.status.rawValue)")
            if exportSession.status == .completed {
                completion(outputURL)
            } else {
                DebugLog.write("HEVC export failed for \(sourceURL.lastPathComponent): \(String(describing: exportSession.error))")
                completion(nil)
            }
            activeSessions.removeAll { $0 === exportSession }
        }
    }

    private static var activeSessions: [AVAssetExportSession] = []
}
