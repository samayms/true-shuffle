import SwiftUI

/// Design tokens from the True Shuffle design doc.
///
/// The palette is deliberately tiny: a black ground, one raised surface, and a
/// single signal colour that only ever marks the thing currently playing.
enum Theme {
    // MARK: - Colour

    /// `oklch(0.68 0.17 25)`, converted to sRGB.
    static let signal = Color(red: 0.9366, green: 0.4012, blue: 0.3791)

    /// The app ground. True black, not a dark grey — it matches the Music app
    /// and lets the raised cards read as objects sitting on nothing.
    static let ground = Color.black

    /// Raised surface for cards and list groups.
    static let surface = Color(red: 0.110, green: 0.110, blue: 0.118)   // #1C1C1E

    /// iOS system colours for text on dark, matched to the design doc's alphas.
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.45)
    static let tertiaryText = Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.30)
    static let nowPlayingMeta = Color(red: 0.922, green: 0.922, blue: 0.961).opacity(0.50)

    /// Hairline between rows inside a grouped list.
    static let separator = Color(red: 0.329, green: 0.329, blue: 0.345).opacity(0.5)

    /// Switch track when off.
    static let switchOff = Color(red: 0.224, green: 0.224, blue: 0.239)   // #39393D

    // MARK: - Metrics

    static let cardRadius: CGFloat = 16
    static let recentCardRadius: CGFloat = 14
    static let rowMinHeight: CGFloat = 56
    static let toggleRowMinHeight: CGFloat = 52
    static let horizontalPadding: CGFloat = 16
}

extension View {
    /// Section heading above a grouped list ("Recently shuffled", "All playlists").
    func sectionHeader() -> some View {
        self
            .font(.system(size: 12.5, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.75)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}
