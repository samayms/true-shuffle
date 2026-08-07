import SwiftUI
import WidgetKit

/// The 338 × 354 widget: six playlists, recents first — the whole choice at a
/// glance.
///
/// Where the medium size separates rows with a hairline, this one gives each
/// row its own filled capsule. With six of them the hairline reads as a dense
/// list; the fill reads as six buttons, which is what they are.
struct LargeShuffleView: View {
    let entry: ShuffleEntry

    private var rows: [WidgetPlaylist] { Array(entry.playlists.prefix(WidgetLayout.maximumRows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetCaption()

            if rows.isEmpty {
                WidgetMessage(content: entry.content)
            } else {
                VStack(spacing: 5) {
                    ForEach(rows) { playlist in
                        Button(intent: ShuffleFromWidgetIntent(playlistID: playlist.id)) {
                            row(playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shuffleWidgetSurface()
    }

    private func row(_ playlist: WidgetPlaylist) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(playlist.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .tracking(14.5 * -0.012)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(playlist.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -WidgetChrome.rowTextOpticalRise)

            PlayBadge(metrics: .small)
        }
        .padding(.horizontal, 12)
        // No vertical padding by design: row height comes entirely from the
        // even split, so all six stay identical whatever the text does.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WidgetChrome.rowFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
