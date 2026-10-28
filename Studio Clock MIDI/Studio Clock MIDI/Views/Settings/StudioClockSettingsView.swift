//
//  StudioClockSettings.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 09/10/2026.
//

import SwiftUI

struct StudioClockSettingsView: View {
    @AppStorage(Constants.settingsStudioClockServer)
    private var server = "https://clock.example.org"

    @State private var tokenDraft = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isTestingConnection = false

    private static let tokenAccount = "studio-clock-api-token"

    var body: some View {
        Form {
            Section("Studio Clock Server") {
                TextField("Base URL", text: $server)

                Text("For example: https://clock.example.org")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("API Authentication") {
                SecureField("API token", text: $tokenDraft)

                HStack {
                    Button("Save Token", action: saveToken)
                        .disabled(
                            tokenDraft.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        )

                    Button(
                        "Remove Token",
                        role: .destructive,
                        action: removeToken
                    )
                }

                HStack {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing…")
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(
                                isError ? Color.red : Color.secondary
                            )
                    }
                }
            }
        }
        .padding()
        .onAppear(perform: loadSettings)
    }

    private func loadSettings() {
        if !server.contains("://") {
            server = "https://" + server
        }

        do {
            if let storedToken = try KeychainStore.load(Self.tokenAccount) {
                tokenDraft = storedToken

                UserDefaults.standard.removeObject(
                    forKey: Constants.settingsStudioClockApiKey
                )
            } else if let legacyToken = UserDefaults.standard.string(
                forKey: Constants.settingsStudioClockApiKey
            ), !legacyToken.isEmpty {
                try KeychainStore.save(
                    legacyToken,
                    for: Self.tokenAccount
                )
                tokenDraft = legacyToken

                UserDefaults.standard.removeObject(
                    forKey: Constants.settingsStudioClockApiKey
                )
            }
        } catch {
            showError(
                "Couldn't load or migrate the API token: \(error.localizedDescription)"
            )
        }
    }

    private func saveToken() {
        let token = tokenDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !token.isEmpty else { return }

        do {
            try KeychainStore.save(token, for: Self.tokenAccount)
            tokenDraft = token
            showSuccess("API token saved securely.")
        } catch {
            showError(
                "Couldn't save the API token: \(error.localizedDescription)"
            )
        }
    }

    private func removeToken() {
        do {
            try KeychainStore.delete(Self.tokenAccount)
            tokenDraft = ""
            showSuccess("API token removed.")
        } catch {
            showError(
                "Couldn't remove the API token: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    private func testConnection() async {
        isTestingConnection = true
        statusMessage = nil

        defer {
            isTestingConnection = false
        }

        do {
            try await StudioClockAPIClient.shared.testConnection()
            showSuccess("Connected successfully.")
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showSuccess(_ message: String) {
        isError = false
        statusMessage = message
    }

    private func showError(_ message: String) {
        isError = true
        statusMessage = message
    }
}
