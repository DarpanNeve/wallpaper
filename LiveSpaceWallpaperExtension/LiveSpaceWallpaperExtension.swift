import Foundation
import ExtensionFoundation
import SwiftUI

@main
struct LiveSpaceWallpaperExtension: AppExtension {
    init() {
        DebugLog.write("[WallpaperXPC] AppExtension init, pid=\(ProcessInfo.processInfo.processIdentifier)")
    }

    var body: some AppExtensionScene {
        PrimitiveAppExtensionScene(id: "com.syntexco.livespace.wallpaperextension") {
            EmptyView()
        } onConnection: { connection in
            DebugLog.write("[WallpaperXPC] onConnection fired for pid=\(connection.processIdentifier)")
            connection.exportedInterface = NSXPCInterface(with: WallpaperExtensionXPCProtocol.self)
            connection.exportedObject = WallpaperXPCHandler()
            connection.invalidationHandler = {
                DebugLog.write("[WallpaperXPC] connection invalidated")
            }
            connection.interruptionHandler = {
                DebugLog.write("[WallpaperXPC] connection interrupted")
            }
            connection.resume()
            return true
        }
    }
}
