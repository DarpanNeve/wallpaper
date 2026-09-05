import SwiftUI

enum SidebarSection: String, Identifiable, CaseIterable {
    case playlist
    case library
    case displays
    case breakReminder
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlist: return "Playlist"
        case .library: return "Library"
        case .displays: return "Displays"
        case .breakReminder: return "Break Reminder"
        case .advanced: return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .playlist: return "play.rectangle"
        case .library: return "photo.stack"
        case .displays: return "display.2"
        case .breakReminder: return "figure.walk.motion"
        case .advanced: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: SidebarSection? = .playlist

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 560, idealHeight: 640)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .playlist {
        case .playlist: PlaylistSettingsView()
        case .library: LibrarySettingsView()
        case .displays: DisplaysSettingsView()
        case .breakReminder: BreakReminderSettingsView()
        case .advanced: AdvancedSettingsView()
        }
    }
}
