import AppKit

final class WindowOpener {
    static let shared = WindowOpener()
    weak var mainWindow: NSWindow?
    private init() {}

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = mainWindow else {
            DebugLog.write("[WindowOpener] show() called but mainWindow is nil")
            return
        }
        window.makeKeyAndOrderFront(nil)
    }
}
