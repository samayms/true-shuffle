import AppIntents
import SwiftUI
import WidgetKit

/// Builds the timeline entry by reading the library directly, in this process.
///
/// Everything the widget shows is derived here rather than handed over by the
/// app, because there is nothing to hand it over with: no App Group, no shared
/// container. What the two processes *do* share is the on-device music library,
/// so that is the source of truth.
struct ShuffleProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ShuffleEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectPlaylistsIntent, in context: Context) async -> ShuffleEntry {
        // The widget gallery renders against a device that may have no library
        // and no authorization; showing "grant access" there would misrepresent
        // what the widget does.
        if context.isPreview { return .placeholder }
        return await Self.load(configuration: configuration)
    }

    func timeline(for configuration: SelectPlaylistsIntent, in context: Context) async -> Timeline<ShuffleEntry> {
        let entry = await Self.load(configuration: configuration)

        // A shuffle from anywhere reloads this timeline immediately, so the only
        // thing this policy has to cover is "2 hours ago" quietly becoming
        // wrong on its own.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }

    /// The design's ordering: pinned slots first, then whatever was played most
    /// recently, then everything else alphabetically.
    @MainActor
    private static func load(configuration: SelectPlaylistsIntent) -> ShuffleEntry {
        guard MusicLibrary.isAuthorized else {
            return ShuffleEntry(date: Date(), content: .needsAuthorization)
        }
        guard let library = try? MusicLibrary.playlists(), !library.isEmpty else {
            return ShuffleEntry(date: Date(), content: .empty)
        }

        let byID = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Shuffles started from the widget's own buttons land in the extension's
        // defaults, which is the only first-hand history this process has. It's
        // more precise than the library's play dates when it exists, so it wins.
        let ownHistory = Dictionary(
            AppSettings.recentShuffles.map { ($0.playlistID, $0.date) },
            uniquingKeysWith: { first, _ in first }
        )

        func recency(_ playlist: Playlist) -> Date? {
            [ownHistory[playlist.id], playlist.lastPlayedDate].compactMap { $0 }.max()
        }

        let pinned = configuration.pinnedIDs.compactMap { byID[$0] }
        let pinnedIDs = Set(pinned.map(\.id))

        let rest = library
            .filter { !pinnedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                switch (recency(lhs), recency(rhs)) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }

        let rows = (pinned + rest).prefix(WidgetLayout.maximumRows).map { playlist in
            WidgetPlaylist(
                id: playlist.id,
                name: playlist.name,
                songCount: playlist.songCount,
                lastPlayedDescription: recency(playlist)?.relativeDescription
            )
        }

        return ShuffleEntry(date: Date(), content: .ready(Array(rows)))
    }
}

enum WidgetLayout {
    /// The large widget shows six; the smaller sizes take a prefix of the same
    /// ordered list, so one fetch serves all three.
    static let maximumRows = 6
}

struct ShuffleWidget: Widget {
    static let kind = "TrueShuffleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectPlaylistsIntent.self,
            provider: ShuffleProvider()
        ) { entry in
            ShuffleWidgetView(entry: entry)
        }
        .configurationDisplayName("True Shuffle")
        .description("Shuffle a playlist into a genuinely random order, straight from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The design specifies its own padding per size — 14pt in the small
        // widget, 12/16 in the medium — which the default content margins would
        // sit on top of.
        .contentMarginsDisabled()
    }
}

struct ShuffleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShuffleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallShuffleView(entry: entry)
        case .systemLarge:
            LargeShuffleView(entry: entry)
        default:
            MediumShuffleView(entry: entry)
        }
    }
}
