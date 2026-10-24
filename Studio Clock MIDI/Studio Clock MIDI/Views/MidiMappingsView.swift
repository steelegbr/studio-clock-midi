//
//  MidiMappingView.swift
//  Studio Clock MIDI
//

import SwiftUI

struct MidiMappingsView: View {
    @ObservedObject private var midiService = MidiService.shared
    @ObservedObject private var ruleEngine = RuleEngine.shared
    @ObservedObject private var mappingStore = MidiMappingStore.shared

    @State private var mappingName = ""
    @State private var targetLampSlug = "mic-live"
    @State private var threshold = 64

    private var mappings: [MidiControlMapping] {
        mappingStore.mappings
    }

    private var trimmedMappingName: String {
        mappingName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLampSlug: String {
        targetLampSlug.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidLampSlug: Bool {
        guard !trimmedLampSlug.isEmpty else { return false }

        let pattern = "^[a-z0-9]+(?:-[a-z0-9]+)*$"
        return trimmedLampSlug.range(
            of: pattern,
            options: .regularExpression
        ) != nil
    }

    private var canAddMapping: Bool {
        !trimmedMappingName.isEmpty && isValidLampSlug
    }

    private var targetLampSlugs: [String] {
        Array(Set(mappings.map(\.targetLampSlug))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let error = mappingStore.persistenceError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .textSelection(.enabled)
                }

                learnPanel

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        mappingsPanel
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        lampStatesPanel
                            .frame(width: 230, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        mappingsPanel
                        lampStatesPanel
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 560, minHeight: 500)
        .onDisappear {
            midiService.cancelLearning()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Control Mappings")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Connect mixer controls to studio-clock lamps.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - MIDI Learn

    private var learnPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        learnStatusTitle,
                        systemImage: midiService.isLearning
                            ? "dot.radiowaves.left.and.right"
                            : "pianokeys"
                    )
                    .font(.headline)

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

                Text(learnStatusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let control = midiService.learnedControl {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detected control")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(control.displayName)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        Grid(
                            alignment: .leading,
                            horizontalSpacing: 16,
                            verticalSpacing: 12
                        ) {
                            GridRow {
                                fieldLabel("Mapping name")

                                TextField(
                                    "e.g. Studio Mic",
                                    text: $mappingName
                                )
                                .textFieldStyle(.roundedBorder)
                            }

                            GridRow {
                                fieldLabel("Target lamp")

                                TextField(
                                    "e.g. mic-live",
                                    text: $targetLampSlug
                                )
                                .textFieldStyle(.roundedBorder)
                            }
                        }

                        if !trimmedLampSlug.isEmpty && !isValidLampSlug {
                            Label(
                                "Use lowercase letters, numbers and single hyphens.",
                                systemImage: "exclamationmark.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.red)
                        }

                        if control.kind == .controlChange {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Fader threshold")
                                    Spacer()
                                    Text("\(threshold) / 127")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(threshold) },
                                        set: { threshold = Int($0) }
                                    ),
                                    in: 0...127,
                                    step: 1
                                )

                                Text(
                                    "Values at or above the threshold count as open."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(
                                "This note control is interpreted as pressed or released."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Spacer()

                            Button("Add Mapping") {
                                addMapping(control: control)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canAddMapping)
                        }
                    }
                }
            }
            .padding(4)
        } label: {
            Label("Learn a control", systemImage: "waveform")
        }
    }

    private var learnStatusTitle: String {
        if midiService.isLearning {
            return "Waiting for a control"
        }

        if midiService.learnedControl != nil {
            return "Control detected"
        }

        return "Ready to learn"
    }

    private var learnStatusDescription: String {
        if !midiService.isListening {
            return "Start listening in MIDI Monitor before learning a control."
        }

        if midiService.isLearning {
            return "Move a fader or press a button on your mixer."
        }

        if midiService.learnedControl != nil {
            return "Give this control a name and choose its target lamp."
        }

        return "Learn a fader or button from your connected MIDI device."
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private func addMapping(control: MidiControl) {
        guard canAddMapping else { return }

        let mapping = MidiControlMapping(
            name: trimmedMappingName,
            control: control,
            targetLampSlug: trimmedLampSlug,
            threshold: threshold
        )

        mappingStore.add(mapping)
        mappingName = ""
    }

    // MARK: - Mappings

    private var mappingsPanel: some View {
        GroupBox {
            VStack(spacing: 0) {
                if mappings.isEmpty {
                    ContentUnavailableView(
                        "No Mappings Yet",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(
                            "Learn a mixer control to create your first mapping."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(mappings.enumerated()), id: \.element.id)
                        { index, mapping in
                            mappingRow(mapping)

                            if index < mappings.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Label(
                    "Mappings",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                Spacer()
                Text("\(mappings.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func mappingRow(_ mapping: MidiControlMapping) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(mapping.name)
                    .fontWeight(.medium)

                Text(mapping.control.displayName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text(mapping.targetLampSlug)

                    if mapping.control.kind == .controlChange {
                        Text("·")
                        Text("Threshold \(mapping.threshold)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button(role: .destructive) {
                removeMapping(mapping)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove mapping")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func removeMapping(_ mapping: MidiControlMapping) {
        mappingStore.remove(id: mapping.id)
    }

    // MARK: - Calculated lamp states

    private var lampStatesPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                if targetLampSlugs.isEmpty {
                    Text("Lamp states will appear when you add mappings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(targetLampSlugs, id: \.self) { slug in
                        lampStateRow(slug)

                        if slug != targetLampSlugs.last {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Lamp States", systemImage: "lightbulb")
        }
    }

    private func lampStateRow(_ slug: String) -> some View {
        let state = ruleEngine.lampStates[slug]
        let inputCount = mappings.filter {
            $0.targetLampSlug == slug
        }.count

        return HStack(alignment: .top, spacing: 10) {
            Image(
                systemName: state == true
                    ? "lightbulb.fill"
                    : "lightbulb"
            )
            .font(.title3)
            .foregroundStyle(lampColor(state))

            VStack(alignment: .leading, spacing: 4) {
                Text(slug)
                    .fontWeight(.medium)
                    .textSelection(.enabled)

                Text(
                    "\(inputCount) mapped \(inputCount == 1 ? "control" : "controls")"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(lampStatus(state))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(lampColor(state))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func lampStatus(_ state: Bool?) -> String {
        guard let state else { return "UNKNOWN" }
        return state ? "ON" : "OFF"
    }

    private func lampColor(_ state: Bool?) -> Color {
        guard let state else { return .secondary }
        return state ? .green : .secondary
    }
}
