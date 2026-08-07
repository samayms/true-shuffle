#if DEBUG
import Foundation

/// Stand-in library for working on the UI without a device.
///
/// The simulator has no music library at all, so every real code path lands in
/// an empty state there. Launching with `-sampleData` swaps in this fixture so
/// layout, the recent row, and the now-playing bar can be seen and screenshot.
///
/// `#if DEBUG` means none of this exists in the Release builds that
/// `scripts/resign.sh` installs on the phone.
enum SampleData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-sampleData")
    }

    static let playlists: [Playlist] = [
        Playlist(id: 1, name: "Late Nights", songCount: 214, downloadedCount: 198),
        Playlist(id: 2, name: "Long Run", songCount: 96, downloadedCount: 96),
        Playlist(id: 3, name: "Kitchen Radio", songCount: 431, downloadedCount: 112),
        Playlist(id: 4, name: "Ambient / Work", songCount: 158, downloadedCount: 158),
        Playlist(id: 5, name: "1996", songCount: 62, downloadedCount: 0),
        Playlist(id: 6, name: "Everything I Liked", songCount: 1204, downloadedCount: 640)
    ]

    /// Seeds the recent row and the now-playing bar so both are visible.
    static func seed() {
        AppSettings.recentShuffles = [
            RecentShuffle(playlistID: 1, date: Date().addingTimeInterval(-2 * 3600)),
            RecentShuffle(playlistID: 4, date: Date().addingTimeInterval(-26 * 3600)),
            RecentShuffle(playlistID: 2, date: Date().addingTimeInterval(-4 * 24 * 3600))
        ]
        AppSettings.lastPlaylistID = 1
        AppSettings.lastShuffleCount = 214
    }
}
#endif
