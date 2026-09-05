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
        NSApp.appearance = state.appearanceMode.nsAppearance
        wallpaperEngine.applyWallpaperAppearance(state.wallpaperAppearanceMode)
        rotationController.start()
        BreakReminderController.shared.start()

        if !UserDefaults.standard.bool(forKey: Self.hasRequestedLoginItemKey) {
            UserDefaults.standard.set(true, forKey: Self.hasRequestedLoginItemKey)
            requestLoginItemConsent()
        }

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
    }

    private func requestLoginItemConsent() {
        let alert = NSAlert()
        alert.messageText = "Launch KineticDesk at Login?"
        alert.informativeText = "KineticDesk runs from the menu bar. Starting it automatically when you log in keeps your wallpaper rotating without needing to open it manually. You can change this anytime from the menu bar menu."
        alert.addButton(withTitle: "Launch at Login")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational
        let response = alert.runModal()
        LaunchAtLogin.setEnabled(response == .alertFirstButtonReturn)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ContentView().environmentObject(state))
        // Default `.standardBounds` includes `.intrinsicContentSize`, which keeps resizing the
        // window to match the detail view's ideal size as it changes (e.g. the Library tab's grid
        // growing as thumbnails load async) - causes a visible jump/reposition switching tabs.
        // `[.minSize, .maxSize]` keeps the `.frame(minWidth:...)` constraints synced without that.
        hostingController.sizingOptions = [.minSize, .maxSize]
        let window = NSWindow(contentViewController: hostingController)
        window.title = "KineticDesk"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
