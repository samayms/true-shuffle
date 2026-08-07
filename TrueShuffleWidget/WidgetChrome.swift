import SwiftUI

/// Tokens the widget needs that the app's `Theme` doesn't carry.
enum WidgetChrome {
    static let hairline = Color(red: 0.329, green: 0.329, blue: 0.345).opacity(0.45)

    /// How far to lift a row's name/detail pair so it looks vertically centred.
    ///
    /// Centring the pair by its layout box leaves it looking about a point low,
    /// because the box is padded by type metrics the eye doesn't see: unused
    /// ascender space above the name's capitals, and descender space below the
    /// detail line. Measured against a render, the visible ink lands 1pt below
    /// the row's true centre, so the pair is raised by that much.
    ///
    /// This is what makes the hairlines look wrong before it is applied: the gap
    /// above a line comes out around 4pt against 6pt below it, even though the
    /// boxes either side are exactly symmetric.
    static let rowTextOpticalRise: CGFloat = 1
}

/// The right-pointing play triangle.
///
/// Drawn rather than using `Image(systemName: "play.fill")`: the SF Symbol has
/// its own optical padding and slightly rounded corners, so at 7–9pt inside a
/// small circle it reads visibly smaller and softer than the flat triangle the
/// design specifies.
struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The coral circle that every row ends with.
///
/// Purely visual — the tap target is the whole row's `Button`, which is why this
/// is a plain view and not a control.
struct PlayBadge: View {
    struct Metrics {
        let diameter: CGFloat
        let triangleWidth: CGFloat
        let triangleHeight: CGFloat

        /// How far right of the circle's geometric centre the triangle sits.
        ///
        /// Half the centroid correction, arrived at by bracketing. A triangle's
        /// centre of mass sits a third of the way from base to apex, so fully
        /// correcting for it means shifting by `w/2 - w/3 = w/6` — but on device
        /// that reads as clearly right of centre, and no correction at all reads
        /// as left of centre. Half of it is what actually looks centred.
        var opticalOffset: CGFloat { triangleWidth / 12 }

        /// The small widget's badge.
        static let compact = Metrics(diameter: 22, triangleWidth: 7, triangleHeight: 9)
        /// Medium and large widgets.
        static let standard = Metrics(diameter: 28, triangleWidth: 9, triangleHeight: 11)
    }

    let metrics: Metrics

    var body: some View {
        ZStack {
            Circle().fill(Theme.signal)
            PlayTriangle()
                .fill(.white)
                .frame(width: metrics.triangleWidth, height: metrics.triangleHeight)
                .offset(x: metrics.opticalOffset)
        }
        .frame(width: metrics.diameter, height: metrics.diameter)
    }
}

/// Shown instead of the playlist rows when the extension can't read the library
/// or the library has nothing to offer.
struct WidgetMessage: View {
    let content: WidgetContent

    private var text: String {
        switch content {
        case .needsAuthorization:
            // The extension has no way to present the system prompt, so the only
            // useful instruction is to go to the app that can.
            return "Open True Shuffle to allow access to your music."
        case .empty:
            return "No playlists with songs in them yet."
        case .ready:
            return ""
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

extension View {
    /// The card itself: true black is the *page* colour in the app, but a widget
    /// is a raised object on the home screen, so it takes the surface colour.
    func shuffleWidgetSurface() -> some View {
        containerBackground(Theme.surface, for: .widget)
    }
}
