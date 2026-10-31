//
//  NowPlayingDTO.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Foundation

struct NowPlayingDTO: Codable, Equatable, Sendable {
    let artist: String
    let title: String
    let year: Int?

    init(artist: String, title: String, year: Int? = nil) {
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.year = year
    }

    var isValid: Bool {
        !artist.isEmpty && !title.isEmpty
    }
}
