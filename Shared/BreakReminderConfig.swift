import Foundation

struct BreakReminderConfig: Codable, Equatable {
    var miniBreakEnabled: Bool
    var miniBreakDurationSeconds: Double
    var miniBreakIntervalMinutes: Double
    var longBreakEnabled: Bool
    var longBreakDurationSeconds: Double
    var longBreakIntervalMinutes: Double

    static let `default` = BreakReminderConfig(
        miniBreakEnabled: true,
        miniBreakDurationSeconds: 10,
        miniBreakIntervalMinutes: 5,
        longBreakEnabled: false,
        longBreakDurationSeconds: 300,
        longBreakIntervalMinutes: 15
    )

    init(
        miniBreakEnabled: Bool,
        miniBreakDurationSeconds: Double,
        miniBreakIntervalMinutes: Double,
        longBreakEnabled: Bool,
        longBreakDurationSeconds: Double,
        longBreakIntervalMinutes: Double
    ) {
        self.miniBreakEnabled = miniBreakEnabled
        self.miniBreakDurationSeconds = miniBreakDurationSeconds
        self.miniBreakIntervalMinutes = miniBreakIntervalMinutes
        self.longBreakEnabled = longBreakEnabled
        self.longBreakDurationSeconds = longBreakDurationSeconds
        self.longBreakIntervalMinutes = longBreakIntervalMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        miniBreakEnabled = try container.decodeIfPresent(Bool.self, forKey: .miniBreakEnabled) ?? true
        miniBreakDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .miniBreakDurationSeconds) ?? 10
        miniBreakIntervalMinutes = try container.decodeIfPresent(Double.self, forKey: .miniBreakIntervalMinutes) ?? 5
        longBreakEnabled = try container.decodeIfPresent(Bool.self, forKey: .longBreakEnabled) ?? false
        longBreakDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .longBreakDurationSeconds) ?? 300
        longBreakIntervalMinutes = try container.decodeIfPresent(Double.self, forKey: .longBreakIntervalMinutes) ?? 15
    }
}
