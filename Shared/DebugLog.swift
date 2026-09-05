import Foundation

enum DebugLog {
    private static let maxFileSize: UInt64 = 5 * 1024 * 1024

    private static let fileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LiveSpace/debug.log")
    private static let rotatedFileURL = fileURL.deletingLastPathComponent().appendingPathComponent("debug.log.1")
    private static let queue = DispatchQueue(label: "com.syntexco.kineticdesk.debuglog")

    static func write(_ message: String) {
        queue.async {
            let line = "[\(Date())] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                rotateIfNeeded(fm: fm)
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: fileURL)
            }
        }
    }

    private static func rotateIfNeeded(fm: FileManager) {
        guard let size = try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64,
              size >= maxFileSize else { return }
        try? fm.removeItem(at: rotatedFileURL)
        try? fm.moveItem(at: fileURL, to: rotatedFileURL)
    }
}
