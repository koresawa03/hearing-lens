// S-01, S-02 design guidelines
// Single place for every color, spacing value and size used by the UI (ADR-0004).
// The UI is fully monochrome: only white, black and gray steps. No chromatic colors.
import SwiftUI
import UIKit

enum Theme {
    // MARK: Colors
    // Built in code with a dynamic UIColor so light/dark follows the OS without an asset catalog.

    /// Background: dark #0E0E10 / light #F5F5F3
    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 14 / 255, green: 14 / 255, blue: 16 / 255, alpha: 1)
            : UIColor(red: 245 / 255, green: 245 / 255, blue: 243 / 255, alpha: 1)
    })

    /// Foreground: dark white / light #111111
    static let foreground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
    })

    /// Opacity of the secondary text color (foreground over background).
    /// Computed WCAG contrast ratio of the blended color against the background:
    ///   dark  (white at 0.65 over #0E0E10): about 8.4 : 1
    ///   light (#111111 at 0.65 over #F5F5F3): about 5.7 : 1
    /// Both are at least 4.5 : 1 (WCAG AA for body text).
    static let secondaryOpacity: Double = 0.65
    static let secondary = foreground.opacity(secondaryOpacity)

    /// Opacity for thin lines and rings (decorative, not text)
    static let lineOpacity: Double = 0.25
    static let line = foreground.opacity(lineOpacity)

    /// Opacity of a disabled control
    static let disabledOpacity: Double = 0.35

    // MARK: Spacing scale
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let spaceXL: CGFloat = 40

    // MARK: Shape and size
    static let cornerRadius: CGFloat = 12
    static let thinLineWidth: CGFloat = 1
    static let ringLineWidth: CGFloat = 1
    /// Maximum content width so the layout stays calm on iPad
    static let maxContentWidth: CGFloat = 520
    /// Minimum height of the central visual
    static let rippleMinHeight: CGFloat = 220
    /// Fixed height of the central visual at accessibility text sizes (leaves room for text)
    static let rippleAccessibilityHeight: CGFloat = 160

    // MARK: Controls
    /// Diameter of the round main button (at least 64pt for a comfortable touch target)
    static let mainButtonDiameter: CGFloat = 72
    /// Largest factor the main button may grow by with Dynamic Type
    static let mainButtonMaxScale: CGFloat = 1.4
    /// Diameter of the dot under a selected tab
    static let selectedDotSize: CGFloat = 5
    /// Minimum touch target size
    static let minTouchTarget: CGFloat = 44
    /// Width of the icon column in list-style rows
    static let iconColumnWidth: CGFloat = 30
    /// Width of the small icon in the status line
    static let statusIconWidth: CGFloat = 20

    // MARK: Typography details
    /// Letter spacing for small headings
    static let headingTracking: CGFloat = 1.5
    /// Smallest scale for the profile title when one word is wider than the line
    static let titleMinScale: CGFloat = 0.7
    /// Largest Dynamic Type size for the profile title only. The longest single word
    /// ("High-Frequency") must fit on one line on a 375pt-wide iPhone; larger sizes would
    /// force a mid-word break. Body text below the title is not capped.
    static let titleMaxDynamicTypeSize: DynamicTypeSize = .accessibility2
    /// One weight for all SF Symbols
    static let symbolWeight: Font.Weight = .regular

    // MARK: Motion
    /// Period of the slow "breathing" animation of the ripples (seconds)
    static let ripplePeriod: Double = 4
}

extension View {
    /// Small uppercase-style heading: footnote, semibold, wide tracking, secondary color
    func themeHeading() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .tracking(Theme.headingTracking)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
