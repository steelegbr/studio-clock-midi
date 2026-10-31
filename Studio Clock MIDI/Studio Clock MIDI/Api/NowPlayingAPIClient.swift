//
//  NowPlayingAPIClient.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Foundation

extension StudioClockAPIClient {
    func createStation(name: String) async throws {
        let payload = CreateStationRequest(name: name)
        let body = try JSONEncoder().encode(payload)

        _ = try await send(
            path: "/api/station/",
            method: "POST",
            body: body
        )
    }

    func updateNowPlaying(
        stationName: String,
        track: NowPlayingDTO
    ) async throws {
        let station = Self.pathSegment(stationName)

        let payload = UpdateNowPlayingRequest(
            artist: track.artist,
            title: track.title,
            year: track.year
        )

        let body = try JSONEncoder().encode(payload)

        _ = try await send(
            path: "/api/station/\(station)/now-playing/",
            method: "POST",
            body: body
        )
    }

    private static func pathSegment(_ value: String) -> String {
        // Encode one path component, not an entire URL.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        return value.addingPercentEncoding(
            withAllowedCharacters: allowed
        ) ?? ""
    }
}

private struct CreateStationRequest: Encodable {
    let name: String
}

private struct UpdateNowPlayingRequest: Encodable {
    let artist: String
    let title: String
    let year: Int?
}
