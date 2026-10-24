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

final class StudioClockAPIClient {
    static let shared = StudioClockAPIClient()

    private let session: URLSession
    private let tokenAccount = "studio-clock-api-token"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let baseURLString =
            UserDefaults.standard.string(
                forKey: Constants.settingsStudioClockServer
            ) ?? ""

        guard
            let baseURL = URL(string: baseURLString),
            let scheme = baseURL.scheme?.lowercased(),
            let host = baseURL.host,
            !host.isEmpty,
            baseURL.user == nil,
            baseURL.password == nil,
            baseURL.query == nil,
            baseURL.fragment == nil
        else {
            throw StudioClockAPIError.invalidBaseURL
        }

        let isHTTPS = scheme == "https"
        let isLocalDevelopmentHost = [
            "localhost",
            "127.0.0.1",
            "::1",
        ].contains(host.lowercased())

        guard isHTTPS || (scheme == "http" && isLocalDevelopmentHost) else {
            throw StudioClockAPIError.insecureConnection
        }

        guard path.hasPrefix("/"), !path.hasPrefix("//") else {
            throw StudioClockAPIError.invalidBaseURL
        }

        // API paths are rooted at the configured server host.
        guard
            let url = URL(
                string: path,
                relativeTo: baseURL
            )
        else {
            throw StudioClockAPIError.invalidBaseURL
        }

        let token: String
        do {
            guard let savedToken = try KeychainStore.load(tokenAccount),
                !savedToken.isEmpty
            else {
                throw StudioClockAPIError.missingToken
            }
            token = savedToken
        } catch let error as StudioClockAPIError {
            throw error
        } catch {
            throw error
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            "Token \(token)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        if let body {
            request.httpBody = body
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StudioClockAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            // Avoid including response bodies: they can contain sensitive data.
            let message: String

            switch httpResponse.statusCode {
            case 401:
                message = "Authentication failed. Check the API token."
            case 403:
                message = "The token is valid but lacks permission."
            case 404:
                message = "The requested API endpoint was not found."
            case 429:
                message = "Too many requests. Try again later."
            case 500...599:
                message = "The server encountered an error."
            default:
                message = "The request could not be completed."
            }

            throw StudioClockAPIError.httpError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        return data
    }
}
