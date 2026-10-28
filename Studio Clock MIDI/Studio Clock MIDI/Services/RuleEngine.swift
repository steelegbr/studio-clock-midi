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
    private var inputStates: [UUID: Bool] = [:]
    private var pendingLampUpdates: [String: Task<Void, Never>] = [:]

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
                // Every input is known and inactive.
                newLampStates[slug] = false
            } else {
                // At least one input is still unknown.
                newUnknownLampSlugs.insert(slug)
            }
        }

        // Send only actual, known state transitions.
        for (slug, state) in newLampStates
        where lampStates[slug] != state {
            enqueueLampUpdate(slug: slug, state: state)
        }

        lampStates = newLampStates
        unknownLampSlugs = newUnknownLampSlugs
    }

    private func enqueueLampUpdate(slug: String, state: Bool) {
        let previousTask = pendingLampUpdates[slug]

        let task = Task { @MainActor [weak self] in
            // Preserve request order for this lamp.
            await previousTask?.value

            guard !Task.isCancelled else {
                return
            }

            do {
                try await StudioClockAPIClient.shared.setLampState(
                    slug: slug,
                    state: state
                )
            } catch {
                print(
                    "Failed to update Studio Clock lamp '\(slug)': \(error)"
                )
            }

            // Keep the completed task as the chain's predecessor.
            // The next update can safely await it.
            _ = self
        }

        pendingLampUpdates[slug] = task
    }
}
