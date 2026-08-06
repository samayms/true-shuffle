import Foundation
import MediaPlayer

/// What a completed shuffle did, so the caller can report it.
struct ShuffleOutcome: Sendable {
    let playlistName: String
    let songCount: Int
    let firstSongTitle: String?
}

/// The one code path that shuffles and starts playback.
///
/// Both the UI and the Shortcuts intents funnel through here, so there is
/// exactly one definition of what "shuffle and play" means.
@MainActor
enum ShuffleService {

    @discardableResult
    static func shuffleAndPlay(playlistID: UInt64, downloadedOnly: Bool) throws -> ShuffleOutcome {
        let playlist = try MusicLibrary.playlist(id: playlistID)
        let songs = try MusicLibrary.songs(inPlaylist: playlistID, downloadedOnly: downloadedOnly)

        let shuffled = Shuffle.fisherYates(songs)
        try play(shuffled)

        AppSettings.lastPlaylistID = playlistID

        return ShuffleOutcome(
            playlistName: playlist.name,
            songCount: shuffled.count,
            firstSongTitle: shuffled.first?.title
        )
    }

    /// Hands a fully-ordered queue to the system Music app.
    ///
    /// Playback deliberately happens in the Music app rather than in-process:
    /// that is what makes lock screen, Control Center, CarPlay, AirPlay and
    /// background audio all work without this app implementing any of them.
    private static func play(_ songs: [MPMediaItem]) throws {
        let player = MPMusicPlayerController.systemMusicPlayer

        // This is the load-bearing line, and it is easy to miss.
        //
        // If the Music app's own shuffle happens to be switched on, it will
        // re-shuffle the queue we just handed it — with its own weighted
        // algorithm — and silently discard the uniform ordering that is this
        // app's entire purpose. Our order is already random, so the player must
        // play it straight through.
        player.shuffleMode = .off
        player.repeatMode = .none

        player.setQueue(with: MPMediaItemCollection(items: songs))

        // `setQueue` is asynchronous internally. Calling `play()` immediately
        // can race the queue actually being loaded and start the *previous*
        // queue instead; `prepareToPlay` is the documented way to wait.
        player.prepareToPlay { error in
            Task { @MainActor in
                if let error {
                    // Nothing actionable to surface from here, but a silent
                    // no-op would be worse than a logged failure.
                    print("True Shuffle: prepareToPlay failed — \(error.localizedDescription)")
                }
                player.play()
            }
        }
    }
}
