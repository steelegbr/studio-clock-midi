//
//  NowPlayingResponse.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Foundation

struct NowPlayingResponse: Decodable, Sendable {
    let artist: String?
    let title: String?
    let year: Int?
}
