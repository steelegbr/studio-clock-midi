//
//  MidiSettingsView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import CoreMIDI
import SwiftUI

struct MidiSettingsView: View {
    @ObservedObject private var midiService = MidiService.shared
    @AppStorage(Constants.settingsMidiDeviceId) private var selectedDeviceId: Int = 0
    
    var body: some View {
        Form {
            Picker("Device", selection: $selectedDeviceId) {
                Text("Select a Device").tag(0)
                ForEach(midiService.devices) { device in
                    Text(device.name).tag(device.id)
                }
            }
        }
    }
}

struct MidiSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MidiSettingsView()
    }
}
