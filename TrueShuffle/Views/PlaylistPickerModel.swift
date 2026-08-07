import SwiftUI

/// A playlist as one row in the list.
struct PlaylistRowModel: Identifiable {
    let playlist: Playlist
    let meta: String
    /// "Playing" / "Paused" when this is the active playlist, otherwise nil.
    let status: String?

    var id: UInt64 { playlist.id }
}

/// A playlist in the "Recently shuffled" row.
struct RecentEntry: Identifiable {
    let playlist: Playlist
    let when: String

    var id: UInt64 { playlist.id }
}

@MainActor
@Observable
final class PlaylistPickerModel {
    enum State {
        case loading
        case denied
        case empty
        case loaded
    }

    private(set) var state: State = .loading
    private(set) var playlists: [Playlist] = []

    let nowPlaying = NowPlayingMonitor()

    var errorMessage: String?
    var isShowingError = false

    var downloadedOnly: Bool = AppSettings.downloadedOnly {
        didSet {
            AppSettings.downloadedOnly = downloadedOnly
            nowPlaying.refresh()
        }
    }

    // MARK: - Derived rows

    /// Playlists to show. With the filter on, playlists with nothing downloaded
    /// are hidden entirely rather than shown as unplayable dead ends.
    var visible: [PlaylistRowModel] {
        playlists
            .filter { !downloadedOnly || $0.hasDownloads }
            .map { playlist in
                PlaylistRowModel(
                    playlist: playlist,
                    meta: meta(for: playlist),
                    status: status(for: playlist)
                )
            }
    }

    var recent: [RecentEntry] {
        AppSettings.recentShuffles.compactMap { entry in
            guard let playlist = playlists.first(where: { $0.id == entry.playlistID }) else {
                return nil
            }
            guard !downloadedOnly || playlist.hasDownloads else { return nil }
            return RecentEntry(playlist: playlist, when: entry.relativeDescription)
        }
    }

    var nowPlayingName: String {
        guard let id = nowPlaying.playlistID,
              let playlist = playlists.first(where: { $0.id == id })
        else { return "" }
        return playlist.name
    }

    /// Kept short deliberately: the bar also holds a 44pt button and the
    /// "Again" pill, so anything longer truncates mid-word on a 6.1" phone.
    var nowPlayingMeta: String {
        let prefix = nowPlaying.isPlaying ? "Playing in Music" : "Paused"
        let count = nowPlaying.songCount
        return "\(prefix) · \(count.formatted()) song\(count == 1 ? "" : "s")"
    }

    private func meta(for playlist: Playlist) -> String {
        let count = downloadedOnly ? playlist.downloadedCount : playlist.songCount
        let noun = count == 1 ? "song" : "songs"
        return downloadedOnly
            ? "\(count.formatted()) \(noun) · on device"
            : "\(count.formatted()) \(noun)"
    }

    private func status(for playlist: Playlist) -> String? {
        guard nowPlaying.playlistID == playlist.id else { return nil }
        return nowPlaying.isPlaying ? "Playing" : "Paused"
    }

    // MARK: - Lifecycle

    func start() async {
        #if DEBUG
        if SampleData.isEnabled {
            SampleData.seed()
            await reload()
            return
        }
        #endif

        if MusicLibrary.authorizationStatus == .notDetermined {
            _ = await MusicLibrary.requestAuthorization()
        }
        await reload()
    }

    func reload() async {
        #if DEBUG
        if SampleData.isEnabled {
            playlists = SampleData.playlists
            state = .loaded
            nowPlaying.adopt(playlistID: 1, songCount: 214)
            return
        }
        #endif

        guard MusicLibrary.isAuthorized else {
            state = .denied
            return
        }

        do {
            playlists = try MusicLibrary.playlists()
            state = playlists.isEmpty ? .empty : .loaded
            nowPlaying.refresh()
        } catch {
            state = .denied
        }
    }

    // MARK: - Actions

    func shuffle(_ playlist: Playlist) {
        do {
            let outcome = try ShuffleService.shuffleAndPlay(
                playlistID: playlist.id,
                downloadedOnly: downloadedOnly
            )
            nowPlaying.adopt(playlistID: outcome.playlistID, songCount: outcome.songCount)
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    func reshuffle() {
        guard let id = nowPlaying.playlistID,
              let playlist = playlists.first(where: { $0.id == id })
        else { return }
        shuffle(playlist)
    }

    func togglePlayPause() {
        nowPlaying.togglePlayPause()
    }
}
