import Foundation

enum SaverInstallerError: LocalizedError {
    case bundledSaverMissing
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledSaverMissing:
            return "LiveSpace.saver not found inside app bundle."
        case .copyFailed(let reason):
            return reason
        }
    }
}

enum SaverInstaller {
    private static var destinationURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/LiveSpace.saver", isDirectory: true)
    }

    private static var bundledSourceURL: URL? {
        Bundle.main.url(forResource: "LiveSpace", withExtension: "saver")
    }

    static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: destinationURL.path)
    }

    static func install() throws {
        guard let source = bundledSourceURL else {
            throw SaverInstallerError.bundledSaverMissing
        }
        let fm = FileManager.default
        let destDir = destinationURL.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        do {
            try fm.copyItem(at: source, to: destinationURL)
        } catch {
            throw SaverInstallerError.copyFailed(error.localizedDescription)
        }
    }

    static func uninstall() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: destinationURL.path) else { return }
        try fm.removeItem(at: destinationURL)
    }
}
