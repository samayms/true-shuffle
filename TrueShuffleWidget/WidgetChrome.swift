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
    /// 34 in the small widget, 26 in medium and large.
    let diameter: CGFloat

    private var triangleWidth: CGFloat { diameter * (11.0 / 34.0) }
    private var triangleHeight: CGFloat { diameter * (13.0 / 34.0) }
    private var opticalOffset: CGFloat { diameter * (3.0 / 34.0) }

    var body: some View {
        ZStack {
            Circle().fill(Theme.signal)
            PlayTriangle()
                .fill(.white)
                .frame(width: triangleWidth, height: triangleHeight)
                // The triangle's visual centre of mass sits left of its bounding
                // box, so centring it geometrically makes it look off-centre.
                .offset(x: opticalOffset)
        }
        .frame(width: diameter, height: diameter)
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
