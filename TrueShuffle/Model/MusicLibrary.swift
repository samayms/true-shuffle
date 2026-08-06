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

    var hasDownloads: Bool { downloadedCount > 0 }
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

        return collections
            .compactMap { $0 as? MPMediaPlaylist }
            .compactMap(summarize)
            .filter { $0.songCount > 0 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Looks up a single playlist by persistent ID.
    static func playlist(id: UInt64) throws -> Playlist {
        guard isAuthorized else { throw MusicLibraryError.notAuthorized }
        guard let match = rawPlaylist(id: id), let summary = summarize(match) else {
            throw MusicLibraryError.playlistNotFound
        }
        return summary
    }

    /// The songs to actually enqueue, in library order (the caller shuffles).
    static func songs(inPlaylist id: UInt64, downloadedOnly: Bool) throws -> [MPMediaItem] {
        guard isAuthorized else { throw MusicLibraryError.notAuthorized }
        guard let playlist = rawPlaylist(id: id) else {
            throw MusicLibraryError.playlistNotFound
        }

        let name = playlist.name ?? "Playlist"
        let all = playlist.items
        guard !all.isEmpty else { throw MusicLibraryError.noSongs(playlistName: name) }

        guard downloadedOnly else { return all }

        let downloaded = all.filter(isDownloaded)
        guard !downloaded.isEmpty else {
            throw MusicLibraryError.noDownloadedSongs(playlistName: name)
        }
        return downloaded
    }

    // MARK: - Internals

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
            downloadedCount: items.count(where: isDownloaded)
        )
    }

    /// Whether a song is playable from local storage with no network.
    ///
    /// `isCloudItem` is true for anything backed by Apple Music's catalog rather
    /// than local storage. `assetURL` is nil when there is no locally readable
    /// asset at all. Requiring both is stricter than either alone and matches
    /// what the user means by "downloaded" — this local-only signal is precisely
    /// what web/MusicKit approaches cannot see, and the reason this app is native.
    private static func isDownloaded(_ item: MPMediaItem) -> Bool {
        !item.isCloudItem && item.assetURL != nil
    }
}
