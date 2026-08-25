import Foundation

struct PlaylistConfig: Codable, Equatable {
    var folderPath: String
    var intervalSeconds: Double
    var currentIndex: Int
    var lastAdvanced: Date
    var lockScreenEnabled: Bool = false
    var startOffsetPercent: Double = 0

    static let `default` = PlaylistConfig(
        folderPath: ("~/LiveWallpapers" as NSString).expandingTildeInPath,
        intervalSeconds: 300,
        currentIndex: 0,
        lastAdvanced: .distantPast,
        lockScreenEnabled: false,
        startOffsetPercent: 0
    )

    init(folderPath: String, intervalSeconds: Double, currentIndex: Int, lastAdvanced: Date, lockScreenEnabled: Bool, startOffsetPercent: Double) {
        self.folderPath = folderPath
        self.intervalSeconds = intervalSeconds
        self.currentIndex = currentIndex
        self.lastAdvanced = lastAdvanced
        self.lockScreenEnabled = lockScreenEnabled
        self.startOffsetPercent = startOffsetPercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        intervalSeconds = try container.decode(Double.self, forKey: .intervalSeconds)
        currentIndex = try container.decode(Int.self, forKey: .currentIndex)
        lastAdvanced = try container.decode(Date.self, forKey: .lastAdvanced)
        lockScreenEnabled = try container.decodeIfPresent(Bool.self, forKey: .lockScreenEnabled) ?? false
        startOffsetPercent = try container.decodeIfPresent(Double.self, forKey: .startOffsetPercent) ?? 0
    }
}

enum VideoFileKind {
    static let allowedExtensions: Set<String> = ["mp4", "mov", "m4v"]
}
