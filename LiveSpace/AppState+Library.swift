import Foundation
import AppKit
import UniformTypeIdentifiers

struct LibraryVideoItem: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
    let filename: String
    var duration: TimeInterval?
    var thumbnail: NSImage?

    static func == (lhs: LibraryVideoItem, rhs: LibraryVideoItem) -> Bool {
        lhs.url == rhs.url && lhs.duration == rhs.duration && lhs.thumbnail === rhs.thumbnail
    }
}

/// Wallpaper Library tab support - grid gallery of the current video folder's contents.
/// Methods only; the `@Published var libraryItems` storage lives in `AppState.swift` itself
/// (Swift requires `@Published`'s stored backing to sit in the type's primary declaration).
extension AppState {
    /// Rebuilds `libraryItems` from the current playlist folder, preserving already-loaded
    /// thumbnail/duration for files that haven't changed so reopening the tab doesn't re-decode.
    func refreshLibrary() {
        let config = ConfigStore.shared.load()
        let urls = ConfigStore.shared.playlist(for: config)
        let existing = Dictionary(uniqueKeysWithValues: libraryItems.map { ($0.url, $0) })
        libraryItems = urls.map { url in
            if let previous = existing[url] {
                return previous
            }
            return LibraryVideoItem(url: url, filename: url.lastPathComponent, duration: nil, thumbnail: nil)
        }
    }

    func loadThumbnailIfNeeded(for item: LibraryVideoItem) {
        guard item.thumbnail == nil else { return }
        ThumbnailCache.thumbnail(for: item.url) { [weak self] image in
            guard let self, let index = self.libraryItems.firstIndex(where: { $0.url == item.url }) else { return }
            self.libraryItems[index].thumbnail = image
        }
        ThumbnailCache.duration(for: item.url) { [weak self] seconds in
            guard let self, let index = self.libraryItems.firstIndex(where: { $0.url == item.url }) else { return }
            self.libraryItems[index].duration = seconds
        }
    }

    /// Multi-select import - copies chosen files into the current video folder so they join the
    /// playlist. Auto-suffixes on a name collision rather than silently overwriting.
    func addVideos() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = VideoFileKind.allowedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        guard panel.runModal() == .OK else { return }

        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for source in panel.urls {
            let destination = uniqueDestination(for: source.lastPathComponent, in: folder)
            try? FileManager.default.copyItem(at: source, to: destination)
        }
        persist()
    }

    /// Moves the file to the Trash rather than deleting permanently, so a mis-click is recoverable.
    func deleteVideo(_ item: LibraryVideoItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        persist()
    }

    func revealInFinder(_ item: LibraryVideoItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func playNow(_ item: LibraryVideoItem) {
        guard let index = videoFileNames.firstIndex(of: item.filename) else { return }
        jumpToVideo(index: index)
    }

    private func uniqueDestination(for sourceName: String, in folder: URL) -> URL {
        var candidate = folder.appendingPathComponent(sourceName)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var counter = 2
        repeat {
            let name = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = folder.appendingPathComponent(name)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }
}
