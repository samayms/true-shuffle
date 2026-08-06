import AppIntents

/// Shuffle a specific playlist.
///
/// `openAppWhenRun = false` is the point of the whole app: the intent builds
/// the queue and hands it to the Music app without True Shuffle ever coming to
/// the foreground, so a home-screen shortcut or the Action Button starts music
/// with no UI at all.
struct ShufflePlaylistIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Shuffle Playlist"
    static var description = IntentDescription(
        "Shuffles a playlist into a genuinely random order and plays it in the Music app."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity

    @Parameter(title: "Downloaded Only", default: false)
    var downloadedOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Shuffle \(\.$playlist)") {
            \.$downloadedOnly
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = playlist.persistentID else {
            throw MusicLibraryError.playlistNotFound
        }

        let outcome = try ShuffleService.shuffleAndPlay(
            playlistID: id,
            downloadedOnly: downloadedOnly
        )

        return .result(dialog: IntentDialog(outcome.spokenSummary))
    }
}

/// Shuffle whatever was shuffled last, with no parameters at all.
///
/// This is the everyday path — one tap, no picker, no app launch.
struct ShuffleLastPlaylistIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Shuffle Last Playlist"
    static var description = IntentDescription(
        "Re-shuffles the playlist you shuffled most recently."
    )
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = AppSettings.lastPlaylistID else {
            throw ShuffleIntentError.noPreviousPlaylist
        }

        let outcome = try ShuffleService.shuffleAndPlay(
            playlistID: id,
            downloadedOnly: AppSettings.downloadedOnly
        )

        return .result(dialog: IntentDialog(outcome.spokenSummary))
    }
}

enum ShuffleIntentError: LocalizedError {
    case noPreviousPlaylist

    var errorDescription: String? {
        switch self {
        case .noPreviousPlaylist:
            return "No playlist has been shuffled yet. Open True Shuffle and pick one first."
        }
    }
}

private extension ShuffleOutcome {
    var spokenSummary: LocalizedStringResource {
        "Shuffling \(songCount) songs from \(playlistName)."
    }
}

/// Makes both intents available in Shortcuts and to Siri with no setup.
struct TrueShuffleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShuffleLastPlaylistIntent(),
            phrases: [
                "\(.applicationName)",
                "Shuffle my playlist with \(.applicationName)",
                "Shuffle again with \(.applicationName)"
            ],
            shortTitle: "Shuffle Last",
            systemImageName: "shuffle"
        )
        AppShortcut(
            intent: ShufflePlaylistIntent(),
            phrases: [
                "Shuffle a playlist with \(.applicationName)",
                "Shuffle with \(.applicationName)"
            ],
            shortTitle: "Shuffle Playlist",
            systemImageName: "music.note.list"
        )
    }
}
