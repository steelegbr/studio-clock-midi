//
//  MidiMappingView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//


import SwiftUI

struct MidiMappingsView: View {
    @ObservedObject private var midiService = MidiService.shared

    @AppStorage(Constants.settingsMidiDeviceId)
    private var selectedDeviceId: Int = 0

    @State private var mappingName = ""
    @State private var mappings: [MidiControlMapping] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Control Mappings")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox("Learn a control") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            midiService.isLearning
                                ? "Waiting for a control…"
                                : "Ready to learn",
                            systemImage: midiService.isLearning
                                ? "dot.radiowaves.left.and.right"
                                : "pianokeys"
                        )

                        Spacer()

                        if midiService.isLearning {
                            Button("Cancel") {
                                midiService.cancelLearning()
                            }
                        } else {
                            Button("Learn MIDI") {
                                midiService.startLearning()
                            }
                            .disabled(!midiService.isListening)
                        }
                    }

                    if !midiService.isListening {
                        Text("Start the MIDI Monitor first, and select your mixer.")
                            .foregroundStyle(.secondary)
                    } else if midiService.isLearning {
                        Text("Move a fader or press a button on your mixer.")
                            .foregroundStyle(.secondary)
                    }

                    if let control = midiService.learnedControl {
                        Divider()

                        Text("Detected control")
                            .font(.headline)

                        Text(control.displayName)
                            .font(.system(.body, design: .monospaced))

                        TextField("Mapping name (e.g. Mic Live)", text: $mappingName)

                        Button("Add Mapping") {
                            let name = mappingName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                            guard !name.isEmpty else { return }

                            mappings.append(
                                MidiControlMapping(
                                    name: name,
                                    control: control
                                )
                            )

                            mappingName = ""
                        }
                        .disabled(
                            mappingName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        )
                    }
                }
                .padding(4)
            }

            GroupBox("Mappings") {
                if mappings.isEmpty {
                    ContentUnavailableView(
                        "No Mappings Yet",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(
                            "Learn a mixer control and give it a name."
                        )
                    )
                    .frame(minHeight: 120)
                } else {
                    List {
                        ForEach(mappings) { mapping in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mapping.name)
                                    .fontWeight(.medium)

                                Text(mapping.control.displayName)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                        .onDelete { offsets in
                            mappings.remove(atOffsets: offsets)
                        }
                    }
                    .frame(minHeight: 150)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
        .onDisappear {
            midiService.cancelLearning()
        }
    }
}
