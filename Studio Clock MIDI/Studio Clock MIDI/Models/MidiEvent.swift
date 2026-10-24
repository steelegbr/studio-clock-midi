//
//  MidiEvent.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import Foundation

struct MidiEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deviceName: String
    let status: UInt8
    let data1: UInt8
    let data2: UInt8

    var messageType: String {
        switch status & 0xF0 {
        case 0x80: return "Note Off"
        case 0x90: return data2 == 0 ? "Note Off" : "Note On"
        case 0xA0: return "Poly Aftertouch"
        case 0xB0: return "Control Change"
        case 0xC0: return "Program Change"
        case 0xD0: return "Channel Aftertouch"
        case 0xE0: return "Pitch Bend"
        default: return "Other"
        }
    }

    var channel: Int {
        Int(status & 0x0F) + 1
    }

    var controllerOrNote: Int {
        Int(data1)
    }

    var value: Int {
        Int(data2)
    }

    var hexadecimal: String {
        String(
            format: "%02X %02X %02X",
            status,
            data1,
            data2
        )
    }
}
