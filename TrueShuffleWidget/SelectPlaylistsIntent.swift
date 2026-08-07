import AppIntents
import WidgetKit

/// What long-press → Edit Widget shows: three playlist pickers.
///
/// Three, and optional, on purpose. The design draws the widget as a view of
/// what you have shuffled recently, and that is what an unconfigured widget
/// does — it needs no setup to be useful. Pinning a slot is the override: fill
/// in "First" and that playlist stays at the top no matter what you play.
///
/// The pickers are populated by `PlaylistEntityQuery`, the same query the
/// Shortcuts editor uses, so they list real on-device playlists rather than
/// asking anyone to type a name. Because a slot stores the persistent ID,
/// renaming a playlist in Music doesn't break it.
///
/// There is deliberately no in-app settings screen for this. Widget
/// configuration belongs to the widget, and duplicating it in the app would
/// create two sources of truth that cannot even see each other — the extension
/// and the app don't share a defaults container on this account.
struct SelectPlaylistsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Playlists"
    static var description = IntentDescription(
        "Pin up to three playlists. Any slot you leave empty falls back to what you shuffled most recently."
    )

    @Parameter(title: "First")
    var slot1: PlaylistEntity?

    @Parameter(title: "Second")
    var slot2: PlaylistEntity?

    @Parameter(title: "Third")
    var slot3: PlaylistEntity?

    /// Pinned slots in order, with empty ones dropped.
    var pinnedIDs: [UInt64] {
        [slot1, slot2, slot3].compactMap { $0?.persistentID }
    }
}
