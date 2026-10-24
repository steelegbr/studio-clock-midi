//
//  RuleEngine.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import Combine
import Foundation

@MainActor
final class RuleEngine: ObservableObject {
    static let shared = RuleEngine()

    @Published private(set) var lampStates: [String: Bool] = [:]
    @Published private(set) var unknownLampSlugs: Set<String> = []

    private var mappings: [MidiControlMapping] = []

    // nil means that we haven't observed this control's state yet.
    private var inputStates: [UUID: Bool] = [:]

    private init() {}

    func setMappings(_ newMappings: [MidiControlMapping]) {
        mappings = newMappings

        // Discard states belonging to removed mappings.
        let validIDs = Set(newMappings.map(\.id))
        inputStates = inputStates.filter { validIDs.contains($0.key) }

        // New mappings remain unknown until an event identifies their state.
        recomputeLampStates()
    }

    func process(_ events: [MidiEvent]) {
        for event in events {
            guard let control = MidiControl(event: event) else {
                continue
            }

            for mapping in mappings where mapping.control == control {
                switch control.kind {
                case .controlChange:
                    inputStates[mapping.id] =
                        event.value >= mapping.threshold

                case .note:
                    let messageType = event.status & 0xF0

                    // Note On with velocity zero is conventionally Note Off.
                    inputStates[mapping.id] =
                        messageType == 0x90 && event.value > 0
                }
            }
        }

        recomputeLampStates()
    }

    private func recomputeLampStates() {
        var newLampStates: [String: Bool] = [:]
        var newUnknownLampSlugs = Set<String>()

        let groups = Dictionary(
            grouping: mappings,
            by: \.targetLampSlug
        )

        for (slug, lampMappings) in groups {
            let states = lampMappings.compactMap {
                inputStates[$0.id]
            }

            if states.contains(true) {
                // Any active input keeps the lamp on.
                newLampStates[slug] = true
            } else if states.count == lampMappings.count {
                // Every input is known and every input is inactive.
                newLampStates[slug] = false
            } else {
                // No active input, but at least one input is unknown.
                newUnknownLampSlugs.insert(slug)
            }
        }

        lampStates = newLampStates
        unknownLampSlugs = newUnknownLampSlugs
    }
}
