import Foundation

final class WallpaperAppearanceTrigger {
    static let shared = WallpaperAppearanceTrigger()
    var apply: ((AppAppearance) -> Void)?
    private init() {}
}
