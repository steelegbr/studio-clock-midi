//
//  MidiMonitorView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import SwiftUI

struct MidiMonitorView: View {
    @ObservedObject private var midiService = MidiService.shared

    @AppStorage(Constants.settingsMidiDeviceId)
    private var selectedDeviceId: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDI Monitor")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh Devices") {
                    midiService.refreshDevices()
                }

                if midiService.isListening {
                    Button("Stop") {
                        midiService.stopListening()
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Start Listening") {
                        midiService.startListening(
                            deviceID: selectedDeviceId
                        )
                    }
                    .disabled(selectedDeviceId == 0)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding()

            HStack {
                Text("Input")

                Picker("Input", selection: $selectedDeviceId) {
                    Text("Select a Device").tag(0)

                    ForEach(midiService.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 300)
                .disabled(midiService.isListening)

                Spacer()

                Text("\(midiService.events.count) events")
                    .foregroundStyle(.secondary)

                Button("Clear") {
                    midiService.clearEvents()
                }
                .disabled(midiService.events.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)

            if let error = midiService.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            if midiService.events.isEmpty {
                ContentUnavailableView(
                    midiService.isListening
                        ? "Waiting for MIDI"
                        : "No MIDI Events",
                    systemImage: "pianokeys",
                    description: Text(
                        midiService.isListening
                            ? "Move a fader or press a button on your mixer."
                            : "Select a MIDI input and start listening."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(midiService.events.reversed()) { event in
                    HStack(spacing: 12) {
                        Text(
                            event.timestamp.formatted(
                                date: .omitted,
                                time: .standard
                            )
                        )
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                        Text(event.messageType)
                            .frame(width: 150, alignment: .leading)

                        Text("Ch \(event.channel)")
                            .frame(width: 55, alignment: .leading)

                        Text("\(event.controllerOrNote)")
                            .frame(width: 45, alignment: .trailing)

                        Text("\(event.value)")
                            .frame(width: 45, alignment: .trailing)

                        Spacer(minLength: 8)

                        Text(event.hexadecimal)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            midiService.refreshDevices()
        }
    }

    private var statusText: String {
        if midiService.isListening {
            return
                "Listening to \(midiService.listeningDeviceName ?? "MIDI input")"
        }

        return "Not listening"
    }
}
