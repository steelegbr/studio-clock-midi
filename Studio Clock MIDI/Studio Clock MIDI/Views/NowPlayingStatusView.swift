//
//  NowPlayingStatusView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import SwiftUI

struct NowPlayingStatusView: View {
    @ObservedObject private var service = NowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                service.isWatching ? "Watching playout file" : "Not watching",
                systemImage: service.isWatching
                    ? "waveform"
                    : "waveform.slash"
            )
            .foregroundStyle(
                service.isWatching ? .green : .secondary
            )

            if let track = service.lastTrack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.headline)

                    Text(track.artist)
                        .foregroundStyle(.secondary)

                    if let year = track.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Waiting for a valid track in the playout file.")
                    .foregroundStyle(.secondary)
            }

            if let lastUpdate = service.lastUpdate {
                Label(
                    "Last sent \(lastUpdate.formatted(date: .omitted, time: .standard))",
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let error = service.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
