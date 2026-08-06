import Foundation

/// The app's entire persisted state.
///
/// Two values, both small and both regenerable — `UserDefaults` is the right
/// tool and anything heavier would be architecture for its own sake.
enum AppSettings {
    private enum Key {
        static let lastPlaylistID = "lastPlaylistID"
        static let downloadedOnly = "downloadedOnly"
    }

    /// The most recently shuffled playlist.
    ///
    /// This is what makes the zero-argument "Shuffle Last Playlist" shortcut
    /// possible, which is the intended everyday path — tap once from the home
    /// screen or Action Button and never open the app at all.
    static var lastPlaylistID: UInt64? {
        get {
            let stored = UserDefaults.standard.object(forKey: Key.lastPlaylistID) as? NSNumber
            return stored?.uint64Value
        }
        set {
            let defaults = UserDefaults.standard
            if let newValue {
                defaults.set(NSNumber(value: newValue), forKey: Key.lastPlaylistID)
            } else {
                defaults.removeObject(forKey: Key.lastPlaylistID)
            }
        }
    }

    /// Restrict shuffles to songs downloaded on this device.
    ///
    /// Defaults to `false` so a first run never mysteriously plays nothing.
    static var downloadedOnly: Bool {
        get { UserDefaults.standard.bool(forKey: Key.downloadedOnly) }
        set { UserDefaults.standard.set(newValue, forKey: Key.downloadedOnly) }
    }
}
