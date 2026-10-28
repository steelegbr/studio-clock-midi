//
//  StudioClockAPIError.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 24/10/2026.
//

import Foundation

enum StudioClockAPIError: LocalizedError {
    case invalidBaseURL
    case insecureConnection
    case missingToken
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid Studio Clock server URL."
        case .insecureConnection:
            return "HTTPS is required, except for localhost during development."
        case .missingToken:
            return "No API token is saved. Add one in Studio Clock Settings."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpError(let statusCode, let message):
            return "Studio Clock returned HTTP \(statusCode): \(message)"
        }
    }
}
