import Foundation

/// Single place the full `BreakReminderConfig` gets assembled from `AppState`'s `@Published`
/// mirrors - `persist()` calls this instead of hand-listing every field inline, so a future field
/// addition only ever needs updating here (plus the struct itself and the `@Published`/`init()`
/// pair in `AppState.swift`).
extension AppState {
    func breakReminderConfigSnapshot() -> BreakReminderConfig {
        BreakReminderConfig(
            miniBreakEnabled: miniBreakEnabled,
            miniBreakDurationSeconds: miniBreakDurationSeconds,
            miniBreakIntervalMinutes: miniBreakIntervalMinutes,
            longBreakEnabled: longBreakEnabled,
            longBreakDurationSeconds: longBreakDurationSeconds,
            longBreakIntervalMinutes: longBreakIntervalMinutes,
            showOnAllDisplays: showOnAllDisplays,
            accentColorHex: accentColorHex,
            overlayMaterial: overlayMaterial
        )
    }
}
