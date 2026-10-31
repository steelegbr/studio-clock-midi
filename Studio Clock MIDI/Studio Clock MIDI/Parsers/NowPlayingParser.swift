//
//  NowPlayingParser.swift
//  Studio Clock MIDI
//
//  Created by Marc Steele on 31/10/2026.
//

import Foundation

struct NowPlayingParser {
    private static let withYear = try! NSRegularExpression(
        pattern:
            #"^\s*(?<artist>.+?)\s+-\s+(?<title>.+?)\s+\((?<year>\d{4})\)\s*$"#
    )

    private static let withoutYear = try! NSRegularExpression(
        pattern: #"^\s*(?<artist>.+?)\s+-\s+(?<title>.+?)\s*$"#
    )

    func parse(_ contents: String) -> NowPlayingDTO? {
        let line = contents.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !line.isEmpty else { return nil }

        if let result = match(Self.withYear, in: line),
            let yearText = result["year"],
            let year = Int(yearText)
        {
            let track = NowPlayingDTO(
                artist: result["artist"] ?? "",
                title: result["title"] ?? "",
                year: year
            )
            return track.isValid ? track : nil
        }

        guard let result = match(Self.withoutYear, in: line) else {
            return nil
        }

        let track = NowPlayingDTO(
            artist: result["artist"] ?? "",
            title: result["title"] ?? ""
        )

        return track.isValid ? track : nil
    }

    private func match(
        _ regex: NSRegularExpression,
        in string: String
    ) -> [String: String]? {
        let range = NSRange(string.startIndex..., in: string)

        guard
            let match = regex.firstMatch(
                in: string,
                range: range
            )
        else {
            return nil
        }

        var groups: [String: String] = [:]

        for name in ["artist", "title", "year"] {
            let range = match.range(withName: name)

            guard range.location != NSNotFound,
                let swiftRange = Range(range, in: string)
            else {
                continue
            }

            groups[name] = String(string[swiftRange])
        }

        return groups
    }
}
