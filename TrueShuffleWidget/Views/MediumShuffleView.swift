import SwiftUI
import WidgetKit

/// The 338 × 158 widget: the three most recent playlists, one tap each.
///
/// The rows divide the available height evenly and there is no scrolling — a
/// widget cannot scroll, so the design fixes the row count instead of letting
/// content decide it.
struct MediumShuffleView: View {
    let entry: ShuffleEntry

    private var rows: [WidgetPlaylist] { Array(entry.playlists.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                WidgetCaption()
                Spacer(minLength: 8)
                Text("Tap to shuffle")
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetChrome.hintColor)
            }

            if rows.isEmpty {
                WidgetMessage(content: entry.content)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, playlist in
                        Button(intent: ShuffleFromWidgetIntent(playlistID: playlist.id)) {
                            row(playlist, dividedFromRowAbove: index > 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shuffleWidgetSurface()
    }

    private func row(_ playlist: WidgetPlaylist, dividedFromRowAbove: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(playlist.name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(14 * -0.012)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(playlist.countLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -WidgetChrome.rowTextOpticalRise)

            PlayBadge(metrics: .small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // An overlay rather than a `Divider`: in the design the hairline is
        // absolutely positioned, so it must not take height from the row and
        // must not shrink the even three-way split.
        .overlay(alignment: .top) {
            if dividedFromRowAbove {
                Rectangle()
                    .fill(WidgetChrome.hairline)
                    .frame(height: 0.5)
            }
        }
    }
}
