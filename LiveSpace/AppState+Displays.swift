import Foundation
import AppKit

/// Per-screen override setters, split out of `AppState.swift` to stay under the 400-line cap.
extension AppState {
    /// Creates a screen's override from its current effective values if it doesn't have one yet.
    /// `customizesFolder` only takes effect when it's `true` - it force-enables folder/timing
    /// customization on the entry (creating or updating), but a look/order-only change
    /// (`customizesFolder: false`) never turns off folder customization an entry already has.
    fileprivate func materializeOverride(id: String, customizesFolder: Bool, config: inout PlaylistConfig) {
        if config.perScreen[id] == nil {
            var fresh = config.effectiveScreenConfig(for: id)
            fresh.customizesFolder = customizesFolder
            config.perScreen[id] = fresh
        } else if customizesFolder {
            config.perScreen[id]?.customizesFolder = true
        }
    }

    func setRenderPattern(_ pattern: VideoRenderPattern, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: false, config: &config)
            config.perScreen[screenID]?.renderPattern = pattern
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setOrderPattern(_ pattern: PlaybackOrderPattern, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: false, config: &config)
            config.perScreen[screenID]?.orderPattern = pattern
            config.perScreen[screenID]?.currentIndex = 0
            config.perScreen[screenID]?.lastAdvanced = .distantPast
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setCustomFolder(_ enabled: Bool, for screenID: String) {
        ConfigStore.shared.mutate { config in
            if enabled {
                self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            } else if var override = config.perScreen[screenID] {
                override.customizesFolder = false
                override.currentIndex = 0
                override.lastAdvanced = .distantPast
                if override.renderPattern == config.renderPattern && override.orderPattern == config.orderPattern {
                    config.perScreen.removeValue(forKey: screenID)
                } else {
                    config.perScreen[screenID] = override
                }
            }
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    /// Fully reverts a display to the default group, discarding any look/order/folder overrides.
    func resetToDefault(for screenID: String) {
        ConfigStore.shared.mutate { config in
            config.perScreen.removeValue(forKey: screenID)
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func chooseFolder(for screenID: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.folderPath = url.path
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setScreenInterval(_ minutes: Double, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.intervalSeconds = minutes * 60
        }
        refreshDisplays()
    }

    func setScreenRotateOnVideoEnd(_ value: Bool, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.rotateOnVideoEnd = value
        }
        RotationTrigger.shared.forceTick?()
        refreshDisplays()
    }

    func setScreenStartOffset(_ value: Double, for screenID: String) {
        ConfigStore.shared.mutate { config in
            self.materializeOverride(id: screenID, customizesFolder: true, config: &config)
            config.perScreen[screenID]?.startOffsetPercent = value
        }
        refreshDisplays()
    }
}
