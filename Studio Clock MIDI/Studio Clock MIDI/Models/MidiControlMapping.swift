//
//  MidiControlMapping.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import Foundation

enum MidiControlKind: String, Codable {
    case controlChange
    case note

    var displayName: String {
        switch self {
        case .controlChange: return "Control Change"
        case .note: return "Note"
        }
    }
}

struct MidiControl: Codable, Hashable {
    let kind: MidiControlKind
    let channel: Int
    let number: Int

    var displayName: String {
        "\(kind.displayName) · Ch \(channel) · #\(number)"
    }

    init?(event: MidiEvent) {
        let messageType = event.status & 0xF0

        switch messageType {
        case 0x80, 0x90:
            // Note Off and Note On represent the same physical note.
            kind = .note
        case 0xB0:
            kind = .controlChange
        default:
            // Ignore MIDI messages that aren't useful for our first mappings.
            return nil
        }

        channel = event.channel
        number = event.controllerOrNote
    }
}

struct MidiControlMapping: Identifiable, Codable {
    var id = UUID()
    var name: String
    var control: MidiControl
}
