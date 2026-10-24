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

    private static let tokenAccount = "studio-clock-api-token"

    var body: some View {
        Form {
            Section("Studio Clock Server") {
                TextField("Base URL", text: $server)
                    .textContentType(.URL)

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

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(
                            isError ? Color.red : Color.secondary
                        )
                }
            }
        }
        .padding()
        .onAppear(perform: loadSettings)
    }

    private func loadSettings() {
        // Upgrade any previously saved hostname to a full HTTPS URL.
        if !server.contains("://") {
            server = "https://" + server
        }

        do {
            if let storedToken = try KeychainStore.load(Self.tokenAccount) {
                tokenDraft = storedToken

                // Remove the old preference if it exists.
                UserDefaults.standard.removeObject(
                    forKey: Constants.settingsStudioClockApiKey
                )
            } else if let legacyToken = UserDefaults.standard.string(
                forKey: Constants.settingsStudioClockApiKey
            ), !legacyToken.isEmpty {
                // Migrate the old token to Keychain.
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
            isError = true
            statusMessage =
                "Couldn't load or migrate the API token: \(error.localizedDescription)"
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
            isError = false
            statusMessage = "API token saved securely."
        } catch {
            isError = true
            statusMessage =
                "Couldn't save the API token: \(error.localizedDescription)"
        }
    }

    private func removeToken() {
        do {
            try KeychainStore.delete(Self.tokenAccount)
            tokenDraft = ""
            isError = false
            statusMessage = "API token removed."
        } catch {
            isError = true
            statusMessage =
                "Couldn't remove the API token: \(error.localizedDescription)"
        }
    }
}
