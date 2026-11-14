import Foundation

enum SongExport {
    static func markdown(for songs: [Song], exportedAt: Date = .now) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "# Favorite songs from WFUV",
            "",
            "Exported: \(formatter.string(from: exportedAt))",
            "Favorites: \(songs.count)",
            ""
        ]
        for (index, song) in songs.enumerated() {
            lines += [
                "## \(index + 1). \(escapeMarkdown(song.title))",
                "- Artist: \(escapeMarkdown(song.artist))",
                "- Played on WFUV: \(formatter.string(from: song.playedAt))",
                "- [Find on Spotify](\(song.spotifySearchURL.absoluteString))",
                ""
            ]
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func saveToFiles(_ songs: [Song]) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destination = documents.appendingPathComponent("WFUV-favorites.md")
        try Data(markdown(for: songs).utf8).write(to: destination, options: .atomic)
        return destination
    }

    private static func escapeMarkdown(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
