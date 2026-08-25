import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let launchAtLoginItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(MenuBarController.toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: "LiveSpace")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LiveSpace", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        WindowOpener.shared.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = !LaunchAtLogin.isEnabled
        LaunchAtLogin.setEnabled(newValue)
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
