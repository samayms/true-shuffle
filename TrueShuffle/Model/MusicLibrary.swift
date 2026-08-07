import Foundation
import MediaPlayer

/// A playlist as this app cares about it: an identity, a name, and enough
/// counts to tell the user what they're about to get.
///
/// This is a plain value type deliberately. `MPMediaPlaylist` is a live library
/// object that is not `Sendable` and is expensive to hold onto; lifting the few
/// fields we need out of it keeps the UI and the App Intents layer simple.
struct Playlist: Identifiable, Hashable, Sendable {
    /// `MPMediaEntityPersistentID`. Stable across launches, which is what makes
    /// it safe to persist as "the last playlist" and to use as a Shortcuts entity ID.
    let id: UInt64
    let name: String
    /// Total songs in the playlist.
    let songCount: Int
    /// Songs actually downloaded to this device (i.e. playable with no network).
    let downloadedCount: Int
    /// The most recent time any song in this playlist was played, from the
    /// library itself rather than from this app's own history.
    ///
    /// This exists for the widget. The widget extension is a separate process
    /// and this account can't use App Groups, so it cannot see the app's
    /// `recentShuffles`. The music library, though, *is* shared between the two
    /// — which makes this the only recency signal both processes can agree on.
    let lastPlayedDate: Date?

    var hasDownloads: Bool { downloadedCount > 0 }

    /// Reserved id for "every song in the library", which is not a playlist but
    /// is offered alongside them.
    ///
    /// Modelling it as a `Playlist` rather than as a separate concept is what
    /// keeps it working everywhere for free — the picker, the widget rows, the
    /// Edit Widget slots, the Shortcuts entity, the recents list and the
    /// now-playing bar all key off `Playlist`, and none of them need to know
    /// this one isn't real.
    ///
    /// Zero is safe as a sentinel: `MPMediaEntityPersistentID` is a hash and
    /// the framework uses 0 to mean "unknown", so no actual playlist carries it.
    static let entireLibraryID: UInt64 = 0

    var isEntireLibrary: Bool { id == Self.entireLibraryID }
}

enum MusicLibraryError: LocalizedError {
    case notAuthorized
    case playlistNotFound
    case noSongs(playlistName: String)
    case noDownloadedSongs(playlistName: String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "True Shuffle needs access to your music library. Enable it in Settings › Privacy & Security › Media & Apple Music."
        case .playlistNotFound:
            return "That playlist is no longer in your library."
        case .noSongs(let name):
            return "“\(name)” is empty."
        case .noDownloadedSongs(let name):
            return "No songs in “\(name)” are downloaded to this device. Turn off “Downloaded only” to shuffle the whole playlist."
        }
    }
}

/// Read-only access to the on-device music library.
///
/// Everything here touches `MediaPlayer`, which is main-thread-affine and
/// deals in non-`Sendable` types, so the whole surface is main-actor isolated.
@MainActor
enum MusicLibrary {

    // MARK: - Authorization

    static var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    static var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// Prompts on first call; subsequent calls return the settled status.
    @discardableResult
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Reading playlists

    /// Every playlist on the device, alphabetised.
    ///
    /// Empty playlists are filtered out — they can't be shuffled, so offering
    /// them in the picker would only create a dead end.
    static func playlists() throws -> [Playlist] {
        guard isAuthorized else { throw MusicLibraryError.notAuthorized }

        let query = MPMediaQuery.playlists()
        let collections = query.collections ?? []

        let named = collections
            .compactMap { $0 as? MPMediaPlaylist }
            .compactMap(summarize)
            .filter { $0.songCount > 0 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // Pinned to the front rather than sorted in among the "A"s: it isn't a
        // playlist, and it's the one entry that is always available.
        guard let everything = entireLibrary() else { return named }
        return [everything] + named
    }

    /// Every song in the library, summarised as if it were a playlist.
    ///
    /// `lastPlayedDate` is deliberately left nil. It would otherwise be the most
    /// recent play of *any* song, which is by definition never older than any
    /// real playlist's — so on the widget, which orders rows by recency, this
    /// would permanently pin itself to the top and push the actual playlists
    /// down. Leaving it nil lets it rank on the user's own shuffle history
    /// instead, which is the thing they actually care about.
    static func entireLibrary() -> Playlist? {
        let items = allSongs()
        guard !items.isEmpty else { return nil }

        return Playlist(
            id: Playlist.entireLibraryID,
            name: "All Songs",
            songCount: items.count,
            downloadedCount: items.count(where: isDownloaded),
            lastPlayedDate: nil
        )
    }

    /// Looks up a single playlist by persistent ID.
    static func playlist(id: UInt64) throws -> Playlist {
        guard isAuthorized else { throw MusicLibraryError.notAuthorized }

        if id == Playlist.entireLibraryID {
            guard let everything = entireLibrary() else {
                throw MusicLibraryError.playlistNotFound
            }
            return everything
        }

        guard let match = rawPlaylist(id: id), let summary = summarize(match) else {
            throw MusicLibraryError.playlistNotFound
        }
        return summary
    }

    /// The songs to actually enqueue, in library order (the caller shuffles).
    static func songs(inPlaylist id: UInt64, downloadedOnly: Bool) throws -> [MPMediaItem] {
        guard isAuthorized else { throw MusicLibraryError.notAuthorized }

        let name: String
        let all: [MPMediaItem]

        if id == Playlist.entireLibraryID {
            name = "All Songs"
            all = allSongs()
        } else {
            guard let playlist = rawPlaylist(id: id) else {
                throw MusicLibraryError.playlistNotFound
            }
            name = playlist.name ?? "Playlist"
            all = playlist.items
        }

        guard !all.isEmpty else { throw MusicLibraryError.noSongs(playlistName: name) }

        guard downloadedOnly else { return all }

        let downloaded = all.filter(isDownloaded)
        guard !downloaded.isEmpty else {
            throw MusicLibraryError.noDownloadedSongs(playlistName: name)
        }
        return downloaded
    }

    // MARK: - Internals

    /// Every song in the library.
    ///
    /// `MPMediaQuery.songs()` is already scoped to music, so podcasts,
    /// audiobooks and voice memos don't leak into a shuffle.
    private static func allSongs() -> [MPMediaItem] {
        MPMediaQuery.songs().items ?? []
    }

    private static func rawPlaylist(id: UInt64) -> MPMediaPlaylist? {
        let query = MPMediaQuery.playlists()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: NSNumber(value: id),
                forProperty: MPMediaPlaylistPropertyPersistentID
            )
        )
        return query.collections?.first as? MPMediaPlaylist
    }

    private static func summarize(_ playlist: MPMediaPlaylist) -> Playlist? {
        // A playlist with no name is a system artifact (e.g. a smart-folder
        // container); there's nothing meaningful to show for it.
        guard let name = playlist.name, !name.isEmpty else { return nil }

        let items = playlist.items
        return Playlist(
            id: playlist.persistentID,
            name: name,
            songCount: items.count,
            downloadedCount: items.count(where: isDownloaded),
            lastPlayedDate: items.compactMap(\.lastPlayedDate).max()
        )
    }

    /// Whether a song is stored on this device and playable with no network,
    /// no matter where it came from — an Apple Music download, an iTunes
    /// purchase, or a file you imported yourself.
    ///
    /// Deliberately *not* `assetURL != nil`. `assetURL` is nil for any
    /// DRM-protected item, and every Apple Music track is DRM-protected whether
    /// or not it has been downloaded — so testing it would silently exclude the
    /// entire Apple Music library and leave only DRM-free files.
    ///
    /// `isCloudItem` is the only public signal that distinguishes "in your cloud
    /// library" from "on this device," and it is source-agnostic, which is
    /// exactly the question being asked here.
    private static func isDownloaded(_ item: MPMediaItem) -> Bool {
        !item.isCloudItem
    }
}
