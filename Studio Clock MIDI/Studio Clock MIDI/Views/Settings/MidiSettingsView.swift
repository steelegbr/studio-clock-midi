//
//  MidiSettingsView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import CoreMIDI
import SwiftUI

struct MidiSettingsView: View {
    @ObservedObject var midiService = MidiService.shared
    @State private var selectedDevice: MIDIEntityRef?
    
    var body: some View {
        Form {
            Picker("Device", selection: $selectedDevice) {
                Text("Select a Device").tag(nil as MIDIEntityRef?)
                ForEach(midiService.devices) { device in
                    Text(device.name).tag(Optional(device.id))
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
