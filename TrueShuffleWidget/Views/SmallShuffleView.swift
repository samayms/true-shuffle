import SwiftUI
import WidgetKit

/// The 158 × 158 widget: one playlist, one tap.
///
/// The whole card is the button, not just the coral badge — at this size the
/// badge is a 34pt target in a 158pt tile, and making the tile itself tappable
/// is both easier to hit and what the design's outer `onClick` specifies.
struct SmallShuffleView: View {
    let entry: ShuffleEntry

    var body: some View {
        Group {
            if let playlist = entry.playlists.first {
                Button(intent: ShuffleFromWidgetIntent(playlistID: playlist.id)) {
                    card(for: playlist)
                }
                .buttonStyle(.plain)
            } else {
                unavailable
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .shuffleWidgetSurface()
    }

    private func card(for playlist: WidgetPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetCaption()

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 19, weight: .bold))
                    .tracking(19 * -0.02)
                    .foregroundStyle(Theme.primaryText)
                    // The design caps the name at a 44pt box on a 19pt/1.15
                    // line — two lines — and lets the rest fall off the end.
                    //
                    // No `lineSpacing` here: CSS `line-height` sets the whole
                    // line box, whereas `lineSpacing` adds *on top of* the
                    // font's natural leading. SF at 19pt already lays out at
                    // roughly 1.19, so asking for another 15% would push two
                    // lines well past the 44pt the design allows.
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(playlist.countLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            // The name block is bottom-aligned so a one-line and a two-line
            // playlist name both sit on the same baseline above the badge.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            PlayBadge(metrics: .large)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetCaption()
            WidgetMessage(content: entry.content)
        }
    }
}
