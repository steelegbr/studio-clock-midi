import Playgrounds
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MidiMonitorView()
                .tabItem {
                    Label("MIDI Monitor", systemImage: "pianokeys")
                }

            MidiMappingsView()
                .tabItem {
                    Label(
                        "Mappings",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                }
            NowPlayingStatusView()
                .tabItem {
                    Label(
                        "Now Playing",
                        systemImage: "radio"
                    )
                }
        }
    }
}

#Preview {
    ContentView()
}
