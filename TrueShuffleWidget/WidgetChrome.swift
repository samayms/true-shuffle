import SwiftUI

/// The shared vocabulary of the three widget layouts.
///
/// The design draws exactly one accent object — the coral play button — and one
/// piece of chrome, the "TRUE SHUFFLE" caption. Both appear in all three sizes
/// at different scales, so they live here rather than being re-derived per view
/// and drifting apart.
enum WidgetChrome {
    /// Design tokens that only the widget uses. Everything else comes from
    /// `Theme`, which the app and the widget share.
    static let captionColor = Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.50)
    static let hintColor = Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.35)
    static let rowFill = Color.white.opacity(0.06)
    static let hairline = Color(red: 0.329, green: 0.329, blue: 0.345).opacity(0.45)
    static let widgetRadius: CGFloat = 24
}

/// The right-pointing play triangle.
///
/// Drawn rather than using `Image(systemName: "play.fill")`: the SF Symbol has
/// its own optical padding and slightly rounded corners, so at 8–11pt inside a
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

/// The coral circle that every tappable row ends with.
///
/// Purely visual — the tap target is the whole row's `Button`, which is why this
/// is a plain view and not a control.
struct PlayBadge: View {
    /// The design gives each badge size its own triangle rather than scaling one,
    /// so both sets of numbers are transcribed instead of derived.
    struct Metrics {
        let diameter: CGFloat
        let triangleWidth: CGFloat
        let triangleHeight: CGFloat
        /// How far right of the circle's geometric centre the triangle sits.
        ///
        /// This is *half* the design's `margin-left`, and that halving is the
        /// whole subtlety. The margin is on a flex item in a `justify-content:
        /// center` container, so it widens the item's outer box and the browser
        /// then centres that wider box — moving the triangle by only half the
        /// margin. Applying the full value puts it visibly off-centre.
        let offset: CGFloat

        /// The small widget's badge: 34pt, `margin-left: 3px`.
        static let large = Metrics(diameter: 34, triangleWidth: 11, triangleHeight: 13, offset: 1.5)
        /// Medium and large widgets: 26pt, `margin-left: 2px`.
        static let small = Metrics(diameter: 26, triangleWidth: 8, triangleHeight: 10, offset: 1)
    }

    let metrics: Metrics

    var body: some View {
        ZStack {
            Circle().fill(Theme.signal)
            PlayTriangle()
                .fill(.white)
                .frame(width: metrics.triangleWidth, height: metrics.triangleHeight)
                // A triangle's mass sits toward its base, so a geometrically
                // centred one reads as sitting too far left.
                .offset(x: metrics.offset)
        }
        .frame(width: metrics.diameter, height: metrics.diameter)
    }
}

/// "TRUE SHUFFLE" — the same caption in all three sizes.
struct WidgetCaption: View {
    var body: some View {
        Text("True Shuffle")
            .font(.system(size: 11.5, weight: .semibold))
            .textCase(.uppercase)
            .tracking(11.5 * 0.05)
            .foregroundStyle(WidgetChrome.captionColor)
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
