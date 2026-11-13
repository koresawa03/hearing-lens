// F-02 foundation: central visual (concentric thin circles) for S-02
import SwiftUI

/// Thin concentric circles drawn with Canvas (no image assets).
/// While active it slowly "breathes". With Reduce Motion it stays still.
struct RippleView: View {
    /// Input level 0...1. Slightly scales ring amplitude (fed by a real level in phase 3).
    var level: Double
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ringCount = 5
    /// Base breathing amplitude (fraction of ring spacing)
    private static let baseAmplitude: Double = 0.12
    /// Extra amplitude added at level 1
    private static let levelAmplitude: Double = 0.2
    private static let inactiveOpacityFactor: Double = 0.6

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (t / Theme.ripplePeriod) * 2 * .pi
                    canvas(breath: sin(phase))
                }
            } else {
                canvas(breath: 0)
            }
        }
        .accessibilityHidden(true) // decorative drawing
    }

    private func canvas(breath: Double) -> some View {
        let clamped = min(max(level, 0), 1)
        let amplitude = Self.baseAmplitude + Self.levelAmplitude * clamped
        let activeFactor = isActive ? 1.0 : Self.inactiveOpacityFactor
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - Theme.ringLineWidth
            guard maxRadius > 0 else { return }
            let spacing = maxRadius / Double(Self.ringCount)
            for index in 1...Self.ringCount {
                // Outer rings move a little more than inner rings, each slightly out of phase
                let ringBreath = breath * amplitude * spacing * (Double(index) / Double(Self.ringCount))
                let radius = max(1, min(maxRadius, spacing * Double(index) + ringBreath))
                let rect = CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2)
                // Outer rings fade; breathing also shifts opacity slightly
                let fade = 1 - Double(index - 1) / Double(Self.ringCount + 1)
                let opacity = Theme.lineOpacity * 2 * fade * activeFactor * (1 + 0.15 * breath)
                context.stroke(Path(ellipseIn: rect),
                               with: .color(Theme.foreground.opacity(min(opacity, 1))),
                               lineWidth: Theme.ringLineWidth)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    RippleView(level: 0, isActive: true)
        .padding()
        .background(Theme.background)
}
