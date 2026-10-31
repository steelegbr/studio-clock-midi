//
//  StationResponse.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Foundation

struct StationResponse: Decodable, Sendable {
    let id: Int?
    let name: String
}
