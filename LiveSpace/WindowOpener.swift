import AppKit

@MainActor
final class WindowOpener {
    static let shared = WindowOpener()
    var onShow: (() -> Void)?
    var onClose: (() -> Void)?

    private var window: NSWindow?
    private var windowFactory: (() -> NSWindow)?
    private var closeObserver: NSObjectProtocol?
    private init() {}

    /// Set once at launch. The window itself is built lazily on first `show()`, not at launch -
    /// that's what keeps a login-item boot from popping the Settings window on screen.
    func configure(factory: @escaping () -> NSWindow) {
        windowFactory = factory
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            guard let factory = windowFactory else {
                DebugLog.write("[WindowOpener] show() called but no window factory configured")
                return
            }
            let newWindow = factory()
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: newWindow,
                queue: .main
            ) { [weak self] _ in self?.onClose?() }
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        onShow?()
    }
}
