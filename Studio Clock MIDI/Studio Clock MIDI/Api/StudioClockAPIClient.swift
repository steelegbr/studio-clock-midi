//
//  StudioClockAPIClient.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 28/10/2026.
//

import SwiftUI

final class StudioClockAPIClient {
    static let shared = StudioClockAPIClient()

    private let session: URLSession
    private let tokenAccount = "studio-clock-api-token"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Tests that the server responds and accepts the saved API token.
    func testConnection() async throws {
        _ = try await send(path: "/api/status/")
    }

    /// Sends an authenticated request to the configured Studio Clock server.
    @discardableResult
    func send(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let configuredURL =
            UserDefaults.standard.string(
                forKey: Constants.settingsStudioClockServer
            ) ?? ""

        let trimmedURL = configuredURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            let baseURL = URL(string: trimmedURL),
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

        // A leading slash makes the endpoint relative to the host root,
        // regardless of whether the configured URL has a trailing slash.
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
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

    func setLampState(slug: String, state: Bool) async throws {
        struct LampStateRequest: Encodable {
            let state: Bool
        }

        let body = try JSONEncoder().encode(
            LampStateRequest(state: state)
        )

        let escapedSlug =
            slug.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ) ?? slug

        _ = try await send(
            path: "/api/lamp/\(escapedSlug)/state/",
            method: "PUT",
            body: body
        )
    }
}
