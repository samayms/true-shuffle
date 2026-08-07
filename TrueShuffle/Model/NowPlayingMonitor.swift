import Foundation
import MediaPlayer

/// Watches the system Music app so the now-playing bar reflects reality.
///
/// The queue lives in the Music app, not here, which means playback can change
/// without this app doing anything — the lock screen, CarPlay, Siri, or the
/// user simply opening Music. Observing the player rather than tracking our own
/// last command is what keeps the bar honest.
@MainActor
@Observable
final class NowPlayingMonitor {
    private let player = MPMusicPlayerController.systemMusicPlayer

    /// `deinit` is nonisolated, so the tokens it needs to unregister can't be
    /// main-actor state — and they aren't observable UI state either, so they
    /// stay out of `@Observable`'s storage. Only touched in init and deinit,
    /// so there is no concurrent access to protect against.
    @ObservationIgnored
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    private(set) var isPlaying = false
    /// The playlist this app last handed to the player, if it's still playing.
    private(set) var playlistID: UInt64?
    private(set) var songCount: Int = 0

    /// Whether *this run of the app* started the current queue.
    ///
    /// Load-bearing: `setQueue` and `prepareToPlay` are asynchronous, so for a
    /// moment after we hand over a queue the player still reports `.stopped`
    /// with no item — indistinguishable from "nothing is loaded" unless we
    /// remember that we just asked for playback.
    private var didStartPlayback = false

    /// Whether the queue we started has actually produced a now-playing item.
    private var hasLoaded = false

    var isActive: Bool { playlistID != nil }

    init() {
        playlistID = AppSettings.lastPlaylistID
        songCount = AppSettings.lastShuffleCount

        #if DEBUG
        // Touching the system player triggers the media-library permission
        // prompt, which defeats the point of a fixture-only UI run.
        if SampleData.isEnabled { return }
        #endif

        start()
    }

    private func start() {
        player.beginGeneratingPlaybackNotifications()
        refresh()

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: .MPMusicPlayerControllerPlaybackStateDidChange,
                object: player,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        )
        observers.append(
            center.addObserver(
                forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
                object: player,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        )
    }

    deinit {
        guard !observers.isEmpty else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        // `player` is main-actor-isolated only by our own annotation; stopping
        // notification generation here is safe and balances beginGenerating.
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }

    func refresh() {
        // Once an item actually appears, the queue we handed over has finished
        // loading. That's what separates "still starting" from "now ended" —
        // both look like `.stopped` with a nil item otherwise.
        if player.nowPlayingItem != nil { hasLoaded = true }

        let isStarting = didStartPlayback && !hasLoaded

        switch player.playbackState {
        case .playing:
            isPlaying = true
        case .paused, .interrupted:
            isPlaying = false
        default:
            // Staying optimistic during the load window avoids a visible
            // Playing → Paused → Playing flicker on every tap.
            if !isStarting { isPlaying = false }
        }

        // Drop the bar only when nothing is loaded and we aren't mid-start.
        // Without the second condition, the async load window clears the
        // playlist we just set and the bar never appears at all.
        if player.nowPlayingItem == nil, !isStarting {
            playlistID = nil
            didStartPlayback = false
            hasLoaded = false
        }
    }

    /// Called after this app starts a shuffle, so the bar appears immediately
    /// rather than waiting for a notification round-trip.
    func adopt(playlistID: UInt64, songCount: Int) {
        self.playlistID = playlistID
        self.songCount = songCount
        didStartPlayback = true
        hasLoaded = false
        isPlaying = true
    }

    func togglePlayPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        refresh()
    }
}
