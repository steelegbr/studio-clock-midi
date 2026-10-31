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
    case invalidPath
    case missingToken
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid Studio Clock server URL."
        case .insecureConnection:
            return "Use HTTPS, except for localhost development."
        case .invalidPath:
            return "The API path is invalid."
        case .missingToken:
            return "No Studio Clock API token is configured."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpError(_, let message):
            return message
        }
    }
}
