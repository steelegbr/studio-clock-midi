//
//  NowPlayingSettingsView.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct NowPlayingSettingsView: View {
    @AppStorage(Constants.settingsNowPlayingStation)
    private var stationName = ""

#if os(macOS)
    @State private var selectedFileURL: URL?
    @State private var isChoosingFile = false
    @State private var fileError: String?
#endif

    var body: some View {
#if os(macOS)
        Form {
            Section("Now Playing") {
                TextField("Station name", text: $stationName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Playout file")
                        Text(selectedFileURL?.path ?? "No file selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    Button("Choose…") {
                        isChoosingFile = true
                    }
                }

                if let fileError {
                    Text(fileError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Start watching") {
                        NowPlayingService.shared.start()
                    }
                    .disabled(
                        stationName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty || selectedFileURL == nil
                    )

                    Button("Stop") {
                        NowPlayingService.shared.stop()
                    }
                }
            }

            Section("Status") {
                NowPlayingStatusView()
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            restoreBookmark()
        }
#else
        Form {
            Section("Now Playing") {
                Text("Watching a playout file is available in the macOS app.")
                    .foregroundStyle(.secondary)
            }
        }
#endif
    }

#if os(macOS)
    private func handleFileSelection(
        _ result: Result<[URL], Error>
    ) {
        do {
            guard let url = try result.get().first else { return }

            // The file importer grants temporary access to the selected
            // URL. Save a bookmark so it can be reopened after relaunch.
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(
                bookmark,
                forKey: Constants.settingsNowPlayingBookmark
            )

            selectedFileURL = url
            fileError = nil

            // Restart if already watching, so the new file is used.
            if NowPlayingService.shared.isWatching {
                NowPlayingService.shared.start()
            }
        } catch {
            fileError =
                "Couldn't save the selected file: \(error.localizedDescription)"
        }
    }

    private func restoreBookmark() {
        guard
            let bookmark = UserDefaults.standard.data(
                forKey: Constants.settingsNowPlayingBookmark
            )
        else {
            return
        }

        do {
            var isStale = false

            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let refreshed = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                UserDefaults.standard.set(
                    refreshed,
                    forKey: Constants.settingsNowPlayingBookmark
                )
            }

            selectedFileURL = url
        } catch {
            fileError =
                "Couldn't restore the saved file access. Choose the file again."
        }
    }
#endif
}
