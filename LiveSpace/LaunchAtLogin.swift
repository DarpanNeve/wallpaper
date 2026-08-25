import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        DebugLog.write("[LaunchAtLogin] setEnabled(\(enabled)) called, current status=\(SMAppService.mainApp.status.rawValue) bundlePath=\(Bundle.main.bundlePath)")
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    DebugLog.write("[LaunchAtLogin] register() succeeded, new status=\(SMAppService.mainApp.status.rawValue)")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            DebugLog.write("[LaunchAtLogin] toggle FAILED: \(error)")
        }
    }
}
