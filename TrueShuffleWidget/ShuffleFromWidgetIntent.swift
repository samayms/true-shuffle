import AppIntents

/// The intent behind every button in the widget.
///
/// `AudioPlaybackIntent` is the conformance that makes this work at all: it is
/// what tells the system this intent's purpose is to start audio, which is the
/// only way an extension is allowed to begin playback while running in the
/// background. A plain `AppIntent` would run and then be silently denied the
/// audio session.
///
/// `perform()` runs inside the widget extension's own process. It never wakes
/// the containing app — no App Group, no shared container, no cross-process
/// message. The extension reads the shared on-device music library directly and
/// hands the finished queue to the system Music app, which is a third process
/// again and the one that actually plays.
struct ShuffleFromWidgetIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Shuffle Playlist"
    static var description = IntentDescription(
        "Shuffles a playlist into a genuinely random order and plays it in the Music app."
    )
    static var openAppWhenRun = false

    /// The `MPMediaEntityPersistentID`, as a string.
    ///
    /// `UInt64` is not an `AppIntent` parameter type, and `Int` would misencode
    /// the top bit of a persistent ID, so the string form is the honest one —
    /// the same trick `PlaylistEntity.id` already uses.
    @Parameter(title: "Playlist")
    var playlistID: String

    init() {}

    init(playlistID: UInt64) {
        self.playlistID = String(playlistID)
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UInt64(playlistID) else {
            throw MusicLibraryError.playlistNotFound
        }

        // `ShuffleService` also records the shuffle and reloads the timeline, so
        // the row that was tapped moves to the top the way the design shows.
        try ShuffleService.shuffleAndPlay(
            playlistID: id,
            downloadedOnly: AppSettings.downloadedOnly
        )

        return .result()
    }
}
