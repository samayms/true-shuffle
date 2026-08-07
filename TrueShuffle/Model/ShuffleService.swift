import Foundation
import MediaPlayer
import WidgetKit

/// What a completed shuffle did, so the caller can report it.
struct ShuffleOutcome: Sendable {
    let playlistID: UInt64
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
    static func shuffleAndPlay(playlistID: UInt64, downloadedOnly: Bool) async throws -> ShuffleOutcome {
        let playlist = try MusicLibrary.playlist(id: playlistID)
        let songs = try MusicLibrary.songs(inPlaylist: playlistID, downloadedOnly: downloadedOnly)

        let shuffled = Shuffle.fisherYates(songs)
        await play(shuffled)

        AppSettings.recordShuffle(playlistID: playlistID, songCount: shuffled.count)

        // The widget orders its rows by recency, so every shuffle — from the
        // app, from Shortcuts, or from the widget's own button — invalidates
        // what it is showing.
        WidgetCenter.shared.reloadAllTimelines()

        return ShuffleOutcome(
            playlistID: playlistID,
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
    private static func play(_ songs: [MPMediaItem]) async {
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
        await queueDidLoad(player)
        player.play()
    }

    /// Waits for `setQueue` to take effect, then lets the caller start playback.
    ///
    /// `setQueue` is asynchronous internally, so calling `play()` immediately
    /// can start the *previous* queue instead. `prepareToPlay` is the
    /// documented way to wait — but calling `play()` from inside its completion
    /// handler, as this once did, breaks the widget outright: the intent's
    /// `perform()` returns as soon as the handler is registered, the extension
    /// process is torn down, and the completion never runs. The queue ends up
    /// loaded and silent, which is exactly the reported symptom.
    ///
    /// Awaiting instead keeps the process alive until the queue is ready. The
    /// deadline matters for the same reason: a completion that never arrives
    /// must cost a short pause, not silence.
    private static func queueDidLoad(_ player: MPMusicPlayerController) async {
        let gate = ResumeGate()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            player.prepareToPlay { error in
                Task { @MainActor in
                    if let error {
                        print("True Shuffle: prepareToPlay failed — \(error.localizedDescription)")
                    }
                    if gate.claim() { continuation.resume() }
                }
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                if gate.claim() { continuation.resume() }
            }
        }
    }
}

/// Lets two racing paths share one continuation without resuming it twice,
/// which would trap.
@MainActor
private final class ResumeGate {
    private var hasResumed = false

    func claim() -> Bool {
        guard !hasResumed else { return false }
        hasResumed = true
        return true
    }
}
