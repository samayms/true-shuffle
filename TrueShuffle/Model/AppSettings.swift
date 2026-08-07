import Foundation

/// One past shuffle, for the "Recently shuffled" row.
struct RecentShuffle: Codable, Hashable, Sendable {
    let playlistID: UInt64
    let date: Date

    var relativeDescription: String { date.relativeDescription }
}

extension Date {
    /// "Just now", "2 hours ago", "Yesterday", "Sunday", or a date.
    ///
    /// Hand-rolled rather than `RelativeDateTimeFormatter` because the design
    /// calls for a weekday name in the 2–7 day range, which the system
    /// formatter renders as "6 days ago".
    var relativeDescription: String {
        let date = self
        let calendar = Calendar.current
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 { return "Just now" }

        if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }

        if calendar.isDateInToday(date) {
            let hours = Int(elapsed / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }

        if calendar.isDateInYesterday(date) { return "Yesterday" }

        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// The app's persisted state.
///
/// All of it is small and regenerable, so `UserDefaults` is the right tool and
/// anything heavier would be architecture for its own sake.
enum AppSettings {
    private enum Key {
        static let lastPlaylistID = "lastPlaylistID"
        static let downloadedOnly = "downloadedOnly"
        static let recentShuffles = "recentShuffles"
        static let lastShuffleCount = "lastShuffleCount"
    }

    /// How many entries the "Recently shuffled" row shows.
    static let recentLimit = 3

    /// The most recently shuffled playlist.
    ///
    /// This is what makes the zero-argument "Shuffle Last Playlist" shortcut
    /// possible, which is the intended everyday path — tap once from the home
    /// screen or Action Button and never open the app at all.
    static var lastPlaylistID: UInt64? {
        get { (UserDefaults.standard.object(forKey: Key.lastPlaylistID) as? NSNumber)?.uint64Value }
        set {
            let defaults = UserDefaults.standard
            if let newValue {
                defaults.set(NSNumber(value: newValue), forKey: Key.lastPlaylistID)
            } else {
                defaults.removeObject(forKey: Key.lastPlaylistID)
            }
        }
    }

    /// How many songs the last shuffle queued, for the now-playing bar.
    static var lastShuffleCount: Int {
        get { UserDefaults.standard.integer(forKey: Key.lastShuffleCount) }
        set { UserDefaults.standard.set(newValue, forKey: Key.lastShuffleCount) }
    }

    /// Restrict shuffles to songs downloaded on this device.
    ///
    /// Defaults to `false` so a first run never mysteriously plays nothing.
    static var downloadedOnly: Bool {
        get { UserDefaults.standard.bool(forKey: Key.downloadedOnly) }
        set { UserDefaults.standard.set(newValue, forKey: Key.downloadedOnly) }
    }

    /// Most recent first.
    static var recentShuffles: [RecentShuffle] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Key.recentShuffles),
                  let decoded = try? JSONDecoder().decode([RecentShuffle].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Key.recentShuffles)
        }
    }

    /// Records a shuffle, moving the playlist to the front if it's already there
    /// so the row shows three *distinct* playlists rather than three of the same.
    static func recordShuffle(playlistID: UInt64, songCount: Int) {
        lastPlaylistID = playlistID
        lastShuffleCount = songCount

        var updated = recentShuffles.filter { $0.playlistID != playlistID }
        updated.insert(RecentShuffle(playlistID: playlistID, date: Date()), at: 0)
        recentShuffles = Array(updated.prefix(recentLimit))
    }
}
