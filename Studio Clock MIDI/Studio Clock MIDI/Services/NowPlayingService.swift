//
//  NowPlayingService.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Combine
import Foundation

@MainActor
final class NowPlayingService: ObservableObject {
    static let shared = NowPlayingService()

    @Published private(set) var isWatching = false
    @Published private(set) var lastTrack: NowPlayingDTO?
    @Published private(set) var lastSentTrack: NowPlayingDTO?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdate: Date?

    private let parser = NowPlayingParser()
    private let api = StudioClockAPIClient.shared

    private var watchTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var fileURL: URL?
    private var isAccessingSecurityScope = false

    private var stationName: String {
        UserDefaults.standard.string(
            forKey: Constants.settingsNowPlayingStation
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var configuredFileURL: URL? {
        try? resolveConfiguredFileURL()
    }

    private func resolveConfiguredFileURL() throws -> URL {
        guard
            let bookmark = UserDefaults.standard.data(
                forKey: Constants.settingsNowPlayingBookmark
            )
        else {
            throw CocoaError(.fileReadNoPermission)
        }

        #if os(macOS)
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let refreshedBookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                UserDefaults.standard.set(
                    refreshedBookmark,
                    forKey: Constants.settingsNowPlayingBookmark
                )
            }

            return url
        #else
            throw CocoaError(.featureUnsupported)
        #endif
    }

    private init() {}

    func start() {
        stop()

        guard let url = configuredFileURL,
            !stationName.isEmpty
        else {
            lastError = "Configure a station and a playout file first."
            return
        }

        fileURL = url

        // Start security-scoped access once for the life of the watcher.
        // The URL should come from an NSOpenPanel and be stored in
        // UserDefaults with a security-scoped bookmark for long-term use.
        #if os(macOS)
            isAccessingSecurityScope =
                url.startAccessingSecurityScopedResource()
            guard isAccessingSecurityScope else {
                fileURL = nil
                lastError =
                    "Couldn't access the selected playout file. Choose it again."
                return
            }
        #endif

        isWatching = true
        lastError = nil

        watchTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.readCurrentFile()

                do {
                    try await Task.sleep(for: .milliseconds(750))
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil

        sendTask?.cancel()
        sendTask = nil

        #if os(macOS)
            if isAccessingSecurityScope, let fileURL {
                fileURL.stopAccessingSecurityScopedResource()
            }
        #endif

        isAccessingSecurityScope = false
        fileURL = nil
        isWatching = false
    }

    private func readCurrentFile() {
        guard let fileURL else { return }

        do {
            let contents = try String(
                contentsOf: fileURL,
                encoding: .utf8
            )

            guard let track = parser.parse(contents) else {
                // The file may currently be empty or partially written.
                // Leave the last valid track alone and try again.
                return
            }

            guard track != lastTrack else { return }

            lastTrack = track
            queueUpdate(track)
        } catch {
            // Don't overwrite the UI with a transient file-read error
            // every 750 ms. The next poll will retry.
            lastError =
                "Unable to read the playout file: \(error.localizedDescription)"
        }
    }

    private func queueUpdate(_ track: NowPlayingDTO) {
        sendTask?.cancel()

        sendTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()

                try await api.updateNowPlaying(
                    stationName: stationName,
                    track: track
                )

                try Task.checkCancellation()

                lastSentTrack = track
                lastUpdate = Date()
                lastError = nil
            } catch is CancellationError {
                // A newer track superseded this one.
            } catch {
                lastError =
                    "Unable to update Now Playing: \(error.localizedDescription)"
            }
        }
    }
}
