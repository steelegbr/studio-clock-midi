//
//  StudioClockAPIClient.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 28/10/2026.
//

import Foundation

final class StudioClockAPIClient {
    static let shared = StudioClockAPIClient()

    private let session: URLSession
    private let tokenAccount = "studio-clock-api-token"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func testConnection() async throws {
        _ = try await send(path: "/api/status/")
    }

    func setLampState(slug: String, state: Bool) async throws {
        let lamp = Self.pathSegment(slug)
        guard !lamp.isEmpty else {
            throw StudioClockAPIError.invalidPath
        }

        let body = try JSONEncoder().encode(SetLampStateRequest(state: state))
        _ = try await send(
            path: "/api/lamp/\(lamp)/state/",
            method: "POST",
            body: body
        )
    }

    private static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

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

        guard let baseURL = URL(string: trimmedURL),
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

        let localHosts: Set<String> = [
            "localhost", "127.0.0.1", "::1",
        ]

        guard
            scheme == "https"
                || (scheme == "http" && localHosts.contains(host.lowercased()))
        else {
            throw StudioClockAPIError.insecureConnection
        }

        guard path.hasPrefix("/"), !path.hasPrefix("//") else {
            throw StudioClockAPIError.invalidPath
        }

        // A leading slash intentionally makes API paths relative to
        // the server root, not to any path in the configured base URL.
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
            url.scheme == scheme,
            url.host?.lowercased() == host.lowercased(),
            url.port == baseURL.port
        else {
            throw StudioClockAPIError.invalidPath
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

        guard let response = response as? HTTPURLResponse else {
            throw StudioClockAPIError.invalidResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            let message: String

            switch response.statusCode {
            case 401:
                message = "Authentication failed. Check the API token."
            case 403:
                message = "The token does not have permission."
            case 404:
                message = "The requested API resource was not found."
            case 429:
                message = "Too many requests. Try again later."
            case 500...599:
                message = "Studio Clock encountered a server error."
            default:
                message = "The request failed (HTTP \(response.statusCode))."
            }

            throw StudioClockAPIError.httpError(
                statusCode: response.statusCode,
                message: message
            )
        }

        return data
    }
}

private struct SetLampStateRequest: Encodable {
    let state: Bool
}
