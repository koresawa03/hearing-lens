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

    /// Opacity of the outline of a disabled round button (foreground over background).
    /// Non-text UI needs at least 3 : 1 (WCAG 1.4.11). Computed contrast of the blended outline:
    ///   dark  (white at 0.5 over #0E0E10): about 5.3 : 1
    ///   light (#111111 at 0.5 over #F5F5F3): about 3.5 : 1
    static let disabledOutlineOpacity: Double = 0.5
    /// Line width of the disabled button outline
    static let outlineLineWidth: CGFloat = 1.5

    // MARK: Spacing scale
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let spaceXL: CGFloat = 40

    // MARK: Shape and size
    static let cornerRadius: CGFloat = 12
    static let thinLineWidth: CGFloat = 1
    /// Maximum content width so the layout stays calm on iPad
    static let maxContentWidth: CGFloat = 520
    /// Minimum height of the central visual
    static let heroMinHeight: CGFloat = 220
    /// Fixed height of the central visual at accessibility text sizes (leaves room for text)
    static let heroAccessibilityHeight: CGFloat = 160
    /// Width of the fade at the trailing edge of the scrolling profile tabs
    static let tabFadeWidth: CGFloat = 28

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
}

// MARK: - Central visual: glossy sphere (all grays, no chromatic colors)
extension Theme {
    enum Sphere {
        /// Sphere diameter as a fraction of the available width
        static let widthRatio: CGFloat = 0.45
        /// Gap between the sphere bottom and the water line (fraction of the diameter)
        static let liftRatio: CGFloat = 0.06

        // Body: radial gradient whose bright center sits up-left, giving a round look
        /// Gradient center as a unit point (up-left = light source)
        static let gradientCenter = UnitPoint(x: 0.35, y: 0.3)
        /// Gradient end radius as a fraction of the diameter
        static let gradientEndRadiusRatio: CGFloat = 0.85
        /// Dark appearance: a dark sphere (gray levels from the lit area to the edge)
        static let darkStops: [Gradient.Stop] = [
            .init(color: Color(white: 0.42), location: 0),
            .init(color: Color(white: 0.22), location: 0.4),
            .init(color: Color(white: 0.09), location: 0.75),
            .init(color: Color(white: 0.03), location: 1)
        ]
        /// Light appearance: a light sphere
        static let lightStops: [Gradient.Stop] = [
            .init(color: Color(white: 1.0), location: 0),
            .init(color: Color(white: 0.92), location: 0.4),
            .init(color: Color(white: 0.78), location: 0.75),
            .init(color: Color(white: 0.62), location: 1)
        ]

        // Rim: thin ring with an angular gradient (light and dark sweeps read as metal)
        static let rimWidth: CGFloat = 1.5
        /// Angle where the rim sweep starts (degrees)
        static let rimStartAngle: Double = -120
        static let darkRimStops: [Gradient.Stop] = [
            .init(color: Color(white: 1, opacity: 0.7), location: 0),
            .init(color: Color(white: 1, opacity: 0.08), location: 0.25),
            .init(color: Color(white: 1, opacity: 0.45), location: 0.5),
            .init(color: Color(white: 1, opacity: 0.06), location: 0.75),
            .init(color: Color(white: 1, opacity: 0.7), location: 1)
        ]
        static let lightRimStops: [Gradient.Stop] = [
            .init(color: Color(white: 1, opacity: 0.95), location: 0),
            .init(color: Color(white: 0.45, opacity: 0.55), location: 0.25),
            .init(color: Color(white: 0.9, opacity: 0.8), location: 0.5),
            .init(color: Color(white: 0.4, opacity: 0.6), location: 0.75),
            .init(color: Color(white: 1, opacity: 0.95), location: 1)
        ]

        // Highlight: blurred white ellipse at the upper left
        static let highlightColor = Color(white: 1)
        /// Offset from the sphere center (fractions of the diameter)
        static let highlightOffsetX: CGFloat = -0.18
        static let highlightOffsetY: CGFloat = -0.24
        /// Ellipse size (fractions of the diameter)
        static let highlightWidthRatio: CGFloat = 0.38
        static let highlightHeightRatio: CGFloat = 0.2
        /// Tilt so the ellipse follows the curve of the sphere (degrees)
        static let highlightAngle: Double = -35
        /// Blur radius (fraction of the diameter)
        static let highlightBlurRatio: CGFloat = 0.03
        static let darkHighlightOpacity: Double = 0.55
        static let lightHighlightOpacity: Double = 0.95

        // Shadow: soft flattened ellipse on the water line
        static let shadowColor = Color(white: 0)
        static let shadowWidthRatio: CGFloat = 0.8
        static let shadowHeightRatio: CGFloat = 0.14
        static let shadowBlurRatio: CGFloat = 0.06
        static let darkShadowOpacity: Double = 0.7
        static let lightShadowOpacity: Double = 0.3

        // Breathing (active only)
        /// Seconds per breath
        static let breathPeriod: Double = 4
        /// Scale change at level 0 (fraction)
        static let breathAmplitude: Double = 0.02
        /// Extra scale change at level 1 (fraction)
        static let levelBreathAmplitude: Double = 0.03
    }

    // MARK: Central visual: ripples on the water
    enum Ripple {
        static let count = 5
        /// Ellipse height divided by width (flat, seen from a low angle)
        static let aspect: CGFloat = 0.22
        /// Innermost and outermost ring radius (fractions of the visual width)
        static let innerRadiusRatio: CGFloat = 0.28
        static let outerRadiusRatio: CGFloat = 0.48
        /// Opacity of the innermost ring and of the outermost ring (floor keeps it visible)
        static let maxOpacity: Double = 0.5
        static let minOpacity: Double = 0.18
        /// Line width of the innermost ring and of the outermost ring
        static let maxLineWidth: CGFloat = 1.5
        static let minLineWidth: CGFloat = 0.75

        // Animation (active only)
        /// Seconds for a ring to travel from the center to the outer edge
        static let period: Double = 5
        /// Extra speed at level 1 (speed = 1 + factor * level)
        static let levelSpeedFactor: Double = 1
        /// Outer travel radius at level 0 (fraction of width); at level 1 it reaches outerRadiusRatio
        static let calmOuterRadiusRatio: CGFloat = 0.40
        /// Fraction of the travel over which a new ring fades in
        static let fadeInFraction: Double = 0.1
    }
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
