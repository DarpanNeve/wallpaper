import Foundation
import AppKit

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` for `.system` - clearing `NSApp.appearance` lets AppKit follow the OS setting again.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum VideoRenderPattern: String, Codable, CaseIterable, Identifiable {
    case fill
    case fit
    case stretch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fill: return "Fill"
        case .fit: return "Fit"
        case .stretch: return "Stretch"
        }
    }
}

enum PlaybackOrderPattern: String, Codable, CaseIterable, Identifiable {
    case fromStart
    case fromEnd
    case random
    case `static`

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fromStart: return "In Order"
        case .fromEnd: return "Reverse"
        case .random: return "Shuffle"
        case .static: return "Pinned"
        }
    }

    var explanation: String {
        switch self {
        case .fromStart: return "Plays the playlist in order, looping back to the first video after the last."
        case .fromEnd: return "Plays the playlist backwards, from the last video to the first."
        case .random: return "Picks a random video each time it switches."
        case .static: return "Stays on the selected video and never switches automatically."
        }
    }
}

struct ScreenConfig: Codable, Equatable {
    var folderPath: String
    var intervalSeconds: Double
    var currentIndex: Int
    var lastAdvanced: Date
    var rotateOnVideoEnd: Bool
    var startOffsetPercent: Double
    var renderPattern: VideoRenderPattern
    var orderPattern: PlaybackOrderPattern
    /// Whether this screen's `folderPath`/`intervalSeconds`/`rotateOnVideoEnd`/`startOffsetPercent`
    /// are actually customized. When `false`, those four fields are stale snapshots and
    /// `PlaylistConfig.effectiveScreenConfig(for:)` overrides them with the live default -
    /// only `renderPattern`/`orderPattern` (and this screen's own rotation index) are real here.
    /// Lets a display customize just its look/order without silently freezing its playlist folder.
    var customizesFolder: Bool

    init(
        folderPath: String,
        intervalSeconds: Double,
        currentIndex: Int = 0,
        lastAdvanced: Date = .distantPast,
        rotateOnVideoEnd: Bool = false,
        startOffsetPercent: Double = 0,
        renderPattern: VideoRenderPattern = .fill,
        orderPattern: PlaybackOrderPattern = .fromStart,
        customizesFolder: Bool = true
    ) {
        self.folderPath = folderPath
        self.intervalSeconds = intervalSeconds
        self.currentIndex = currentIndex
        self.lastAdvanced = lastAdvanced
        self.rotateOnVideoEnd = rotateOnVideoEnd
        self.startOffsetPercent = startOffsetPercent
        self.renderPattern = renderPattern
        self.orderPattern = orderPattern
        self.customizesFolder = customizesFolder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        intervalSeconds = try container.decode(Double.self, forKey: .intervalSeconds)
        currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex) ?? 0
        lastAdvanced = try container.decodeIfPresent(Date.self, forKey: .lastAdvanced) ?? .distantPast
        rotateOnVideoEnd = try container.decodeIfPresent(Bool.self, forKey: .rotateOnVideoEnd) ?? false
        startOffsetPercent = try container.decodeIfPresent(Double.self, forKey: .startOffsetPercent) ?? 0
        renderPattern = try container.decodeIfPresent(VideoRenderPattern.self, forKey: .renderPattern) ?? .fill
        orderPattern = try container.decodeIfPresent(PlaybackOrderPattern.self, forKey: .orderPattern) ?? .fromStart
        // Overrides persisted before this field existed were always fully custom - preserve that.
        customizesFolder = try container.decodeIfPresent(Bool.self, forKey: .customizesFolder) ?? true
    }
}

struct PlaylistConfig: Codable, Equatable {
    var folderPath: String
    var intervalSeconds: Double
    var currentIndex: Int
    var lastAdvanced: Date
    var lockScreenEnabled: Bool = false
    var posterSyncEnabled: Bool = true
    var startOffsetPercent: Double = 0
    var rotateOnVideoEnd: Bool = false
    var renderPattern: VideoRenderPattern = .fill
    var orderPattern: PlaybackOrderPattern = .fromStart
    var perScreen: [String: ScreenConfig] = [:]
    var breakReminder: BreakReminderConfig = .default
    var appearanceMode: AppAppearance = .system
    var wallpaperAppearanceMode: AppAppearance = .system

    static let `default` = PlaylistConfig(
        folderPath: ("~/LiveWallpapers" as NSString).expandingTildeInPath,
        intervalSeconds: 300,
        currentIndex: 0,
        lastAdvanced: .distantPast,
        lockScreenEnabled: false,
        posterSyncEnabled: true,
        startOffsetPercent: 0,
        rotateOnVideoEnd: false,
        renderPattern: .fill,
        orderPattern: .fromStart,
        perScreen: [:]
    )

    init(
        folderPath: String,
        intervalSeconds: Double,
        currentIndex: Int,
        lastAdvanced: Date,
        lockScreenEnabled: Bool,
        posterSyncEnabled: Bool = true,
        startOffsetPercent: Double,
        rotateOnVideoEnd: Bool,
        renderPattern: VideoRenderPattern = .fill,
        orderPattern: PlaybackOrderPattern = .fromStart,
        perScreen: [String: ScreenConfig] = [:],
        breakReminder: BreakReminderConfig = .default,
        appearanceMode: AppAppearance = .system,
        wallpaperAppearanceMode: AppAppearance = .system
    ) {
        self.folderPath = folderPath
        self.intervalSeconds = intervalSeconds
        self.currentIndex = currentIndex
        self.lastAdvanced = lastAdvanced
        self.lockScreenEnabled = lockScreenEnabled
        self.posterSyncEnabled = posterSyncEnabled
        self.startOffsetPercent = startOffsetPercent
        self.rotateOnVideoEnd = rotateOnVideoEnd
        self.renderPattern = renderPattern
        self.orderPattern = orderPattern
        self.perScreen = perScreen
        self.breakReminder = breakReminder
        self.appearanceMode = appearanceMode
        self.wallpaperAppearanceMode = wallpaperAppearanceMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        intervalSeconds = try container.decode(Double.self, forKey: .intervalSeconds)
        currentIndex = try container.decode(Int.self, forKey: .currentIndex)
        lastAdvanced = try container.decode(Date.self, forKey: .lastAdvanced)
        lockScreenEnabled = try container.decodeIfPresent(Bool.self, forKey: .lockScreenEnabled) ?? false
        posterSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .posterSyncEnabled) ?? true
        startOffsetPercent = try container.decodeIfPresent(Double.self, forKey: .startOffsetPercent) ?? 0
        rotateOnVideoEnd = try container.decodeIfPresent(Bool.self, forKey: .rotateOnVideoEnd) ?? false
        renderPattern = try container.decodeIfPresent(VideoRenderPattern.self, forKey: .renderPattern) ?? .fill
        orderPattern = try container.decodeIfPresent(PlaybackOrderPattern.self, forKey: .orderPattern) ?? .fromStart
        perScreen = try container.decodeIfPresent([String: ScreenConfig].self, forKey: .perScreen) ?? [:]
        breakReminder = try container.decodeIfPresent(BreakReminderConfig.self, forKey: .breakReminder) ?? .default
        appearanceMode = try container.decodeIfPresent(AppAppearance.self, forKey: .appearanceMode) ?? .system
        wallpaperAppearanceMode = try container.decodeIfPresent(AppAppearance.self, forKey: .wallpaperAppearanceMode) ?? .system
    }

    /// Resolves the config a given screen should actually play - its own override if customized,
    /// otherwise the default (mirrored) fields above. A screen that only customized its look/order
    /// (`customizesFolder == false`) still tracks its own rotation index, but its folder/timing
    /// fields are pulled live from the default here rather than a frozen snapshot.
    func effectiveScreenConfig(for screenID: String) -> ScreenConfig {
        guard let override = perScreen[screenID] else {
            return ScreenConfig(
                folderPath: folderPath,
                intervalSeconds: intervalSeconds,
                currentIndex: currentIndex,
                lastAdvanced: lastAdvanced,
                rotateOnVideoEnd: rotateOnVideoEnd,
                startOffsetPercent: startOffsetPercent,
                renderPattern: renderPattern,
                orderPattern: orderPattern,
                customizesFolder: false
            )
        }
        guard override.customizesFolder else {
            return ScreenConfig(
                folderPath: folderPath,
                intervalSeconds: intervalSeconds,
                currentIndex: override.currentIndex,
                lastAdvanced: override.lastAdvanced,
                rotateOnVideoEnd: rotateOnVideoEnd,
                startOffsetPercent: startOffsetPercent,
                renderPattern: override.renderPattern,
                orderPattern: override.orderPattern,
                customizesFolder: false
            )
        }
        return override
    }
}

enum VideoFileKind {
    static let allowedExtensions: Set<String> = ["mp4", "mov", "m4v"]
}
