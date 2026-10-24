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
        switch event.status & 0xF0 {
        case 0x80, 0x90:
            kind = .note
        case 0xB0:
            kind = .controlChange
        default:
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

    // The Django lamp slug, not its human-readable label.
    var targetLampSlug: String = "mic-live"

    // MIDI CC values range from 0 to 127.
    var threshold: Int = 64
}
