//
//  SettingsView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Studio Clock", systemImage: "clock") {
                StudioClockSettingsView()
            }
            Tab("Now Playing", systemImage: "radio") {
                NowPlayingSettingsView()
            }
        }
        .scenePadding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
