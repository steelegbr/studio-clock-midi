//
//  MidiMappingStore.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import Combine
import Foundation

@MainActor
final class MidiMappingStore: ObservableObject {
    static let shared = MidiMappingStore()

    @Published private(set) var mappings: [MidiControlMapping] = []
    @Published private(set) var persistenceError: String?

    private let fileURL: URL

    private init() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let appDirectory =
            applicationSupport
            .appendingPathComponent("StudioClockMIDI", isDirectory: true)

        fileURL = appDirectory.appendingPathComponent("midi-mappings.json")

        load()
        RuleEngine.shared.setMappings(mappings)
    }

    func add(_ mapping: MidiControlMapping) {
        mappings.append(mapping)
        persist()
    }

    func remove(id: UUID) {
        mappings.removeAll { $0.id == id }
        persist()
    }

    func replaceAll(with newMappings: [MidiControlMapping]) {
        mappings = newMappings
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            mappings = try JSONDecoder().decode(
                [MidiControlMapping].self,
                from: data
            )
        } catch {
            persistenceError =
                "Could not load MIDI mappings: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()

            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(mappings)
            try data.write(to: fileURL, options: .atomic)

            persistenceError = nil
            RuleEngine.shared.setMappings(mappings)
        } catch {
            persistenceError =
                "Could not save MIDI mappings: \(error.localizedDescription)"
        }
    }
}
