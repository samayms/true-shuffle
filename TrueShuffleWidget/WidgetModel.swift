import Foundation
import WidgetKit

/// One row of the widget: enough to draw it and enough to shuffle it.
///
/// Deliberately not `Playlist`. The widget needs a pre-rendered "2 hours ago"
/// string, and it must not carry anything that would tempt a view into touching
/// `MediaPlayer` — every library read has to happen in the timeline provider,
/// inside the extension's very short execution budget.
struct WidgetPlaylist: Identifiable, Hashable, Sendable {
    let id: UInt64
    let name: String
    let songCount: Int
    /// "2 hours ago", "Yesterday", "Sunday" — or nil if it has never been played.
    let lastPlayedDescription: String?

    /// The line under the name in the small and medium widgets.
    var countLabel: String {
        "\(songCount.formatted()) song\(songCount == 1 ? "" : "s")"
    }

    /// The line under the name in the large widget, which folds in recency.
    var subtitle: String {
        guard let lastPlayedDescription else { return countLabel }
        return "\(lastPlayedDescription) · \(countLabel)"
    }
}

/// What the widget has to show, including the two ways it can have nothing.
enum WidgetContent: Hashable, Sendable {
    case ready([WidgetPlaylist])
    /// The extension can't read the library. Only the main app can ask for
    /// access, so the widget's job is to say so rather than look broken.
    case needsAuthorization
    /// Authorised, but there are no non-empty playlists to offer.
    case empty
}

struct ShuffleEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent

    var playlists: [WidgetPlaylist] {
        if case .ready(let playlists) = content { return playlists }
        return []
    }
}

extension ShuffleEntry {
    /// Fixture for Xcode previews and for the widget gallery, where the real
    /// library is not readable.
    static let placeholder = ShuffleEntry(
        date: Date(),
        content: .ready([
            WidgetPlaylist(id: 1, name: "Late Nights", songCount: 214, lastPlayedDescription: "2 hours ago"),
            WidgetPlaylist(id: 4, name: "Ambient / Work", songCount: 158, lastPlayedDescription: "Yesterday"),
            WidgetPlaylist(id: 2, name: "Long Run", songCount: 96, lastPlayedDescription: "Sunday"),
            WidgetPlaylist(id: 3, name: "Kitchen Radio", songCount: 431, lastPlayedDescription: nil),
            WidgetPlaylist(id: 5, name: "1996", songCount: 62, lastPlayedDescription: nil),
            WidgetPlaylist(id: Playlist.entireLibraryID, name: "All Songs", songCount: 2165,
                           lastPlayedDescription: nil)
        ])
    )
}
