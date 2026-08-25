import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            PlaylistSettingsView()
                .tabItem { Label("Playlist", systemImage: "play.rectangle") }
            DisplaysSettingsView()
                .tabItem { Label("Displays", systemImage: "display.2") }
            AdvancedSettingsView()
                .tabItem { Label("Advanced", systemImage: "gearshape") }
        }
        .frame(minWidth: 600, idealWidth: 620, minHeight: 480, idealHeight: 580)
    }
}
