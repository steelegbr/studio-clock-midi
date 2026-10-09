//
//  MidiService.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import Combine
import CoreMIDI
import Foundation

class MidiService: ObservableObject {
    static let shared = MidiService()
    
    @Published
    var devices: [MidiDevice] = []
    
    init() {
        refreshDevices()
    }
    
    func refreshDevices() {
        devices = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }
            
            var unmanagedName: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanagedName)
            
            let name: String
            if status == noErr, let unmanagedName {
                name = unmanagedName.takeRetainedValue() as String
            } else {
                name = "MIDI Input \(index + 1)"
            }
            
            var uniqueId: Int32 = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueId)
            
            devices.append(MidiDevice(id: Int(uniqueId), name: name))
        }
    }
}
