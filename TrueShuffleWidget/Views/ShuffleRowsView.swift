import SwiftUI
import WidgetKit

/// Every widget size is the same object: a column of hairline-separated rows
/// that divide the full height evenly, each one a button.
///
/// The three sizes differ only in constants, so they share this view rather
/// than existing as three near-identical files that would drift apart.
struct ShuffleRowsView: View {
    let entry: ShuffleEntry
    let style: RowStyle

    private var rows: [WidgetPlaylist] { Array(entry.playlists.prefix(style.rowCount)) }

    var body: some View {
        Group {
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
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shuffleWidgetSurface()
    }

    private func row(_ playlist: WidgetPlaylist, dividedFromRowAbove: Bool) -> some View {
        HStack(spacing: style.columnSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: style.nameSize, weight: .semibold))
                    .tracking(style.nameSize * -0.012)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(style.showsRecency ? playlist.subtitle : playlist.countLabel)
                    .font(.system(size: style.detailSize))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: -WidgetChrome.rowTextOpticalRise)

            PlayBadge(metrics: style.badge)
        }
        // Every row claims an equal share of the height, so the list never
        // scrolls and never depends on how many playlists there happen to be.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // An overlay rather than a `Divider`: in the design the hairline is
        // absolutely positioned, so it must not take height from the row and
        // must not disturb the even split.
        .overlay(alignment: .top) {
            if dividedFromRowAbove {
                Rectangle()
                    .fill(WidgetChrome.hairline)
                    .frame(height: 0.5)
            }
        }
    }
}

/// The per-size constants, transcribed from the design.
struct RowStyle {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let columnSpacing: CGFloat
    let nameSize: CGFloat
    let detailSize: CGFloat
    let badge: PlayBadge.Metrics
    let rowCount: Int
    /// Only the large widget has room to fold recency into the detail line;
    /// the smaller sizes show the song count alone.
    let showsRecency: Bool

    /// 158 × 158.
    static let small = RowStyle(
        horizontalPadding: 13, verticalPadding: 12, columnSpacing: 8,
        nameSize: 14, detailSize: 10.5, badge: .compact,
        rowCount: 3, showsRecency: false
    )

    /// 338 × 158.
    static let medium = RowStyle(
        horizontalPadding: 16, verticalPadding: 12, columnSpacing: 12,
        nameSize: 15, detailSize: 11.5, badge: .standard,
        rowCount: 3, showsRecency: false
    )

    /// 338 × 354.
    static let large = RowStyle(
        horizontalPadding: 16, verticalPadding: 14, columnSpacing: 12,
        nameSize: 15, detailSize: 11.5, badge: .standard,
        rowCount: 6, showsRecency: true
    )
}
