import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let launchAtLoginItem: NSMenuItem
    private let breakStatusItem: NSMenuItem
    private let state: AppState
    private var displayTimer: Timer?

    init(state: AppState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(MenuBarController.toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        breakStatusItem = NSMenuItem(title: "Next break in ...", action: nil, keyEquivalent: "")
        super.init()

        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            button.title = BreakReminderController.shared.menuBarTimeText
        }
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.statusItem.button?.title = BreakReminderController.shared.menuBarTimeText
        }
        RunLoop.main.add(t, forMode: .common)
        displayTimer = t

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Open Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Next Video", action: #selector(nextVideo), keyEquivalent: "").target = self
        menu.addItem(.separator())

        breakStatusItem.isEnabled = false
        menu.addItem(breakStatusItem)
        let pauseItem = NSMenuItem(title: "Pause Breaks", action: nil, keyEquivalent: "")
        pauseItem.submenu = pauseBreaksMenu()
        menu.addItem(pauseItem)
        menu.addItem(withTitle: "Reset Breaks", action: #selector(resetBreaks), keyEquivalent: "").target = self
        menu.addItem(.separator())

        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LiveSpace", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        breakStatusItem.title = BreakReminderController.shared.statusText
    }

    private func pauseBreaksMenu() -> NSMenu {
        let menu = NSMenu()
        let options: [(String, TimeInterval)] = [
            ("30 Minutes", 1800),
            ("1 Hour", 3600),
            ("2 Hours", 7200),
            ("Until Morning", secondsUntilMorning())
        ]
        for (title, duration) in options {
            let item = NSMenuItem(title: title, action: #selector(pauseBreaks(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration
            menu.addItem(item)
        }
        return menu
    }

    private func secondsUntilMorning() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 8
        let morning = calendar.date(from: components) ?? now
        return morning > now ? morning.timeIntervalSince(now) : morning.addingTimeInterval(86400).timeIntervalSince(now)
    }

    @objc private func openSettings() {
        WindowOpener.shared.show()
    }

    @objc private func nextVideo() {
        state.nextVideo()
    }

    @objc private func pauseBreaks(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        BreakReminderController.shared.pause(for: duration)
    }

    @objc private func resetBreaks() {
        BreakReminderController.shared.reset()
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
