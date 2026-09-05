import SwiftUI

struct LibrarySettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var pendingDelete: LibraryVideoItem?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(state.folderPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Add Videos…") { state.addVideos() }
                    Button("Choose Folder…") { state.chooseFolder() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if state.libraryItems.isEmpty {
                    SettingsCaption("No videos found. Add some with \u{201C}Add Videos\u{2026}\u{201D} above.")
                        .padding(.horizontal, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(state.libraryItems) { item in
                            LibraryVideoCell(
                                item: item,
                                isPlaying: item.filename == state.videoFileNames[safe: state.currentVideoIndex],
                                onPlay: { state.playNow(item) },
                                onReveal: { state.revealInFinder(item) },
                                onDelete: { pendingDelete = item }
                            )
                            .onAppear { state.loadThumbnailIfNeeded(for: item) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert(
            "Move \(pendingDelete?.filename ?? "") to Trash?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Move to Trash", role: .destructive) {
                if let item = pendingDelete {
                    state.deleteVideo(item)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}

private struct LibraryVideoCell: View {
    let item: LibraryVideoItem
    let isPlaying: Bool
    let onPlay: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    /// Fixed, not aspect-ratio-derived - a thumbnail's own intrinsic pixel size (which varies per
    /// video, especially ones with a rotation transform baked in) was driving the cell's layout
    /// size directly, producing visibly distorted/oversized cells for some videos and throwing
    /// off the whole grid's column math. A hard frame + `.clipped()` makes every cell identical
    /// regardless of what the source thumbnail's real dimensions are.
    private static let thumbnailHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(0.4))
                if let thumbnail = item.thumbnail {
                    // GeometryReader pins the frame to the PROPOSED size only, never the
                    // image's own intrinsic pixel size - without it, `Image` still leaks its
                    // natural dimensions upward as an ideal-size hint that `LazyVGrid` can
                    // fold into that row's column-width negotiation, desyncing one row's
                    // column widths from every other row's.
                    GeometryReader { geo in
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                if isPlaying {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.white, .blue)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                if let duration = item.duration {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatted(duration))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                                .padding(5)
                        }
                    }
                }
                if isHovered {
                    Color.black.opacity(0.35)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    HStack(spacing: 14) {
                        Button(action: onPlay) {
                            Image(systemName: "play.fill")
                        }
                        Button(action: onReveal) {
                            Image(systemName: "folder")
                        }
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.thumbnailHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()
            .onHover { isHovered = $0 }

            Text(item.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
