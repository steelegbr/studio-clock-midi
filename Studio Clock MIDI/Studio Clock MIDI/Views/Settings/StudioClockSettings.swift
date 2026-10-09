//
//  StudioClockSettings.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import SwiftUI

struct StudioClockSettingsView: View {
    @AppStorage(Constants.settingsStudioClockApiKey) private var apiKey = ""
    @AppStorage(Constants.settingsStudioClockServer) private var server = "clock.example.org"
    
    var body: some View {
        Form {
            TextField("Studio Clock Server", text: $server)
            SecureField("API Key", text: $apiKey)
        }
    }
}
