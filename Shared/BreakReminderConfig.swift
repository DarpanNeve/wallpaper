import Foundation

enum OverlayMaterial: String, Codable, CaseIterable, Identifiable {
    case regular
    case thick
    case ultraThin
    case chrome

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: return "Regular"
        case .thick: return "Thick"
        case .ultraThin: return "Ultra Thin"
        case .chrome: return "Chrome"
        }
    }
}

struct BreakReminderConfig: Codable, Equatable {
    var miniBreakEnabled: Bool
    var miniBreakDurationSeconds: Double
    var miniBreakIntervalMinutes: Double
    var longBreakEnabled: Bool
    var longBreakDurationSeconds: Double
    var longBreakIntervalMinutes: Double
    var showOnAllDisplays: Bool
    var accentColorHex: String
    var overlayMaterial: OverlayMaterial

    static let `default` = BreakReminderConfig(
        miniBreakEnabled: true,
        miniBreakDurationSeconds: 10,
        miniBreakIntervalMinutes: 5,
        longBreakEnabled: false,
        longBreakDurationSeconds: 300,
        longBreakIntervalMinutes: 15,
        showOnAllDisplays: true,
        accentColorHex: "#0A84FF",
        overlayMaterial: .regular
    )
}
