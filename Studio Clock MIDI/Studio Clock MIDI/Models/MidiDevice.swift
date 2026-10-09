//
//  MidiDevice.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import CoreMIDI
import Foundation

struct MidiDevice: Identifiable, Hashable {
    var id: MIDIEntityRef
    var name: String
}
