import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let wallpaperEngine = WallpaperEngine()
    let rotationController: RotationController
    let state = AppState()
    private var menuBarController: MenuBarController?
    private var settingsWindow: NSWindow?
    private var screenLockObserver: ScreenLockObserver?

    private static let hasRequestedLoginItemKey = "hasRequestedLoginItem"

    override init() {
        rotationController = RotationController(engine: wallpaperEngine)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        rotationController.start()
        menuBarController = MenuBarController(state: state)
        showSettingsWindow()
        screenLockObserver = ScreenLockObserver(
            onLock: { [weak self] in
                self?.wallpaperEngine.pauseAll()
                LockScreenSync.refreshOnLock()
            },
            onUnlock: { [weak self] in
                self?.wallpaperEngine.resumeAll()
            }
        )

        if !UserDefaults.standard.bool(forKey: Self.hasRequestedLoginItemKey) {
            UserDefaults.standard.set(true, forKey: Self.hasRequestedLoginItemKey)
            LaunchAtLogin.setEnabled(true)
        }
    }

    private func showSettingsWindow() {
        let hostingController = NSHostingController(rootView: ContentView().environmentObject(state))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "LiveSpace"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        WindowOpener.shared.mainWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}
