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

    @Published private(set) var devices: [MidiDevice] = []
    @Published private(set) var events: [MidiEvent] = []
    @Published private(set) var isListening = false
    @Published private(set) var listeningDeviceName: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLearning = false
    @Published private(set) var learnedControl: MidiControl?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSource = MIDIEndpointRef()
    private var generation = 0

    private let maximumEvents = 500

    init() {
        refreshDevices()
    }

    func refreshDevices() {
        var discovered: [MidiDevice] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }

            var unmanagedName: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(
                endpoint,
                kMIDIPropertyDisplayName,
                &unmanagedName
            )

            let name: String
            if status == noErr, let unmanagedName {
                name = unmanagedName.takeRetainedValue() as String
            } else {
                name = "MIDI Input \(index + 1)"
            }

            var uniqueId: Int32 = 0
            MIDIObjectGetIntegerProperty(
                endpoint,
                kMIDIPropertyUniqueID,
                &uniqueId
            )

            discovered.append(MidiDevice(id: Int(uniqueId), name: name))
        }

        DispatchQueue.main.async { [weak self] in
            self?.devices = discovered
        }
    }

    func startListening(deviceID: Int) {
        stopListening()

        let listeningGeneration = generation
        errorMessage = nil

        guard
            let device = devices.first(where: {
                $0.id == deviceID
            })
        else {
            errorMessage = "The selected MIDI device is unavailable."
            return
        }

        // Resolve the current endpoint using its persistent unique ID.
        var endpoint = MIDIEndpointRef()
        var found = false

        for index in 0..<MIDIGetNumberOfSources() {
            let candidate = MIDIGetSource(index)
            guard candidate != 0 else { continue }

            var uniqueID: Int32 = 0
            let status = MIDIObjectGetIntegerProperty(
                candidate,
                kMIDIPropertyUniqueID,
                &uniqueID
            )

            if status == noErr, Int(uniqueID) == deviceID {
                endpoint = candidate
                found = true
                break
            }
        }

        guard found else {
            errorMessage = "The MIDI source could not be found."
            refreshDevices()
            return
        }

        var newClient = MIDIClientRef()
        var status = MIDIClientCreate(
            "Studio Clock MIDI" as CFString,
            nil,
            nil,
            &newClient
        )

        guard status == noErr else {
            errorMessage = "Could not create MIDI client (\(status))."
            return
        }

        var newPort = MIDIPortRef()
        status = MIDIInputPortCreateWithBlock(
            newClient,
            "Studio Clock MIDI Input" as CFString,
            &newPort
        ) { [weak self] packetList, _ in
            let packetCount = Int(packetList.pointee.numPackets)
            guard packetCount > 0 else { return }

            let packetOffset = MemoryLayout<MIDIPacketList>.offset(
                of: \.packet
            )!
            var packetPointer = UnsafeMutableRawPointer(
                mutating: UnsafeRawPointer(packetList)
            )
            .advanced(by: packetOffset)
            .assumingMemoryBound(to: MIDIPacket.self)

            var decodedEvents: [MidiEvent] = []

            for _ in 0..<packetCount {
                let packet = packetPointer.pointee
                let length = Int(packet.length)

                let bytes = withUnsafeBytes(of: packet.data) {
                    Array($0.prefix(length))
                }

                if let message = Self.decode(bytes) {
                    decodedEvents.append(message)
                }

                packetPointer = MIDIPacketNext(packetPointer)
            }

            guard !decodedEvents.isEmpty else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self,
                    self.isListening,
                    self.generation == listeningGeneration
                else {
                    return
                }

                self.appendEvents(decodedEvents, deviceName: device.name)
            }
        }

        guard status == noErr else {
            MIDIClientDispose(newClient)
            errorMessage = "Could not create MIDI input port (\(status))."
            return
        }

        status = MIDIPortConnectSource(
            newPort,
            endpoint,
            nil
        )

        guard status == noErr else {
            MIDIPortDispose(newPort)
            MIDIClientDispose(newClient)
            errorMessage = "Could not connect to MIDI source (\(status))."
            return
        }

        client = newClient
        inputPort = newPort
        connectedSource = endpoint
        listeningDeviceName = device.name
        isListening = true
    }

    func stopListening() {
        generation += 1
        isListening = false
        listeningDeviceName = nil

        if connectedSource != 0, inputPort != 0 {
            MIDIPortDisconnectSource(
                inputPort,
                connectedSource
            )
        }

        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }

        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }

        connectedSource = 0
    }

    func clearEvents() {
        events.removeAll()
    }

    private static func decode(_ bytes: [UInt8]) -> MidiEvent? {
        guard let status = bytes.first,
            status >= 0x80,
            status < 0xF0
        else {
            // System messages and stray data bytes aren't part
            // of this initial fader/button monitor.
            return nil
        }

        let messageType = status & 0xF0

        // Program Change and Channel Aftertouch use one data byte.
        let requiredLength =
            (messageType == 0xC0 || messageType == 0xD0) ? 2 : 3

        guard bytes.count >= requiredLength else { return nil }

        let data1 = bytes.count > 1 ? bytes[1] : 0
        let data2 = bytes.count > 2 ? bytes[2] : 0

        return MidiEvent(
            timestamp: Date(),
            deviceName: "",
            status: status,
            data1: data1,
            data2: data2
        )
    }

    private func appendEvents(
        _ newEvents: [MidiEvent],
        deviceName: String
    ) {
        let namedEvents = newEvents.map { event in
            MidiEvent(
                timestamp: event.timestamp,
                deviceName: deviceName,
                status: event.status,
                data1: event.data1,
                data2: event.data2
            )
        }

        if isLearning,
            let event = namedEvents.first(where: {
                MidiControl(event: $0) != nil
            }),
            let control = MidiControl(event: event)
        {
            learnedControl = control
            isLearning = false
        }

        events.append(contentsOf: namedEvents)

        if events.count > maximumEvents {
            events.removeFirst(events.count - maximumEvents)
        }
    }

    func startLearning() {
        learnedControl = nil
        isLearning = true
    }

    func cancelLearning() {
        isLearning = false
    }

    deinit {
        stopListening()
    }
}
