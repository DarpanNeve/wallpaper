import Foundation

final class WallpaperXPCHandler: NSObject, WallpaperExtensionXPCProtocol {

    private func log(_ selector: String, _ args: [Any?]) {
        let desc = args.map { arg -> String in
            guard let arg else { return "nil" }
            return "\(type(of: arg)): \(String(describing: arg).prefix(200))"
        }.joined(separator: " | ")
        DebugLog.write("[WallpaperXPC] \(selector) args=[\(desc)]")
    }

    func acquireWithId(_ id: NSObject?, request: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id, request])
        reply()
    }

    func updateWithId(_ id: NSObject?, request: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id, request])
        reply()
    }

    func invalidateWithId(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func snapshotWithId(_ id: NSObject?, reply: @escaping (NSObject?) -> Void) {
        log(#function, [id])
        reply(nil)
    }

    func provideSettingsViewModelsWithContentTypes(_ contentTypes: NSObject?, reply: @escaping (NSObject?) -> Void) {
        log(#function, [contentTypes])
        reply(nil)
    }

    func addChoiceRequestWithChoiceRequest(_ choiceRequest: NSObject?, onBehalfOfProcess: NSObject?, reply: @escaping () -> Void) {
        log(#function, [choiceRequest, onBehalfOfProcess])
        reply()
    }

    func removeChoiceRequestWithChoiceRequest(_ choiceRequest: NSObject?, reply: @escaping () -> Void) {
        log(#function, [choiceRequest])
        reply()
    }

    func selectedChoicesDidChangeFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func invokeContextMenuActionWithMenuItemID(_ menuItemID: NSObject?, groupItemID: NSObject?, reply: @escaping () -> Void) {
        log(#function, [menuItemID, groupItemID])
        reply()
    }

    func isChoiceDownloadedWith(_ id: NSObject?, reply: @escaping (NSObject?) -> Void) {
        log(#function, [id])
        reply(NSNumber(value: true))
    }

    func downloadWithChoiceID(_ choiceID: NSObject?, reply: @escaping () -> Void) {
        log(#function, [choiceID])
        reply()
    }

    func migrateSelectedChoiceFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func migrateFrom(_ from: NSObject?, to: NSObject?, reply: @escaping () -> Void) {
        log(#function, [from, to])
        reply()
    }

    func skipShuffledContentWithId(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func canSkipShuffledContentWithId(_ id: NSObject?, reply: @escaping (NSObject?) -> Void) {
        log(#function, [id])
        reply(NSNumber(value: false))
    }

    func handleDebugRequestFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func handleNotificationWithNamed(_ name: NSObject?, reply: @escaping () -> Void) {
        log(#function, [name])
        reply()
    }

    func cancelDownloadFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func pauseDownloadFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func resumeDownloadFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }

    func removeDownloadFor(_ id: NSObject?, reply: @escaping () -> Void) {
        log(#function, [id])
        reply()
    }
}
