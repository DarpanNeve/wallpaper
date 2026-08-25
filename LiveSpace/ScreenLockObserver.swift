import Foundation

final class ScreenLockObserver {
    private let onLock: () -> Void
    private let onUnlock: () -> Void

    init(onLock: @escaping () -> Void, onUnlock: @escaping () -> Void) {
        self.onLock = onLock
        self.onUnlock = onUnlock
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(screenLocked),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func screenLocked() {
        DebugLog.write("[ScreenLockObserver] screen locked")
        onLock()
    }

    @objc private func screenUnlocked() {
        DebugLog.write("[ScreenLockObserver] screen unlocked")
        onUnlock()
    }
}
