import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let wallpaperEngine = WallpaperEngine()
    let rotationController: RotationController
    let state = AppState()
    private var menuBarController: MenuBarController?
    private var screenLockObserver: ScreenLockObserver?

    private static let hasRequestedLoginItemKey = "hasRequestedLoginItem"

    override init() {
        rotationController = RotationController(engine: wallpaperEngine)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        rotationController.start()
        menuBarController = MenuBarController(state: state)
        WindowOpener.shared.configure { [weak self] in self!.makeSettingsWindow() }
        WindowOpener.shared.onShow = { [weak self] in self?.state.startAutoRefresh() }
        WindowOpener.shared.onClose = { [weak self] in self?.state.stopAutoRefresh() }
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

    private func makeSettingsWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ContentView().environmentObject(state))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "LiveSpace"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
