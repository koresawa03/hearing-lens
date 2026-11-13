// F-02 foundation: central hero visual (glossy sphere over water ripples) for S-02
import SwiftUI

/// A glossy gray sphere resting above flat elliptical ripples, drawn without image assets.
/// While active the sphere breathes and the ripples travel outward. With Reduce Motion it stays still.
struct HeroSphereView: View {
    /// Input level 0...1. Raises breathing amplitude and ripple speed/spread (fed by a real level in phase 3).
    var level: Double
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var clampedLevel: Double { min(max(level, 0), 1) }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { proxy in
            let layout = Layout(size: proxy.size)
            if isActive && !reduceMotion {
                TimelineView(.animation) { timeline in
                    scene(layout, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                scene(layout, time: nil)
            }
        }
        .accessibilityHidden(true) // decorative drawing
    }

    // MARK: Layout

    /// Sizes derived from the available space. Everything scales from one unit so the
    /// whole visual shrinks together when the height is limited.
    private struct Layout {
        let size: CGSize
        let unit: CGFloat
        let diameter: CGFloat
        let sphereCenter: CGPoint
        let waterY: CGFloat

        init(size: CGSize) {
            self.size = size
            // Total height of the visual in units of its width
            let heightRatio = Theme.Sphere.widthRatio * (1 + Theme.Sphere.liftRatio)
                + Theme.Ripple.outerRadiusRatio * Theme.Ripple.aspect
            unit = max(1, min(size.width, size.height / heightRatio))
            diameter = unit * Theme.Sphere.widthRatio
            let top = (size.height - unit * heightRatio) / 2
            sphereCenter = CGPoint(x: size.width / 2, y: top + diameter / 2)
            waterY = top + diameter * (1 + Theme.Sphere.liftRatio)
        }
    }

    // MARK: Scene

    /// `time` is nil when the visual is static
    private func scene(_ layout: Layout, time: Double?) -> some View {
        let scale = time.map { breathScale(at: $0) } ?? 1
        return ZStack {
            ripples(layout, time: time)
            shadow(diameter: layout.diameter)
                .position(x: layout.size.width / 2, y: layout.waterY)
            sphere(diameter: layout.diameter)
                .scaleEffect(scale)
                .position(layout.sphereCenter)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }

    private func breathScale(at time: Double) -> Double {
        let amplitude = Theme.Sphere.breathAmplitude + Theme.Sphere.levelBreathAmplitude * clampedLevel
        return 1 + amplitude * sin(2 * .pi * time / Theme.Sphere.breathPeriod)
    }

    // MARK: Sphere (shapes and gradients, flattened into one layer with drawingGroup)

    private func sphere(diameter: CGFloat) -> some View {
        let bodyStops = isDark ? Theme.Sphere.darkStops : Theme.Sphere.lightStops
        let rimStops = isDark ? Theme.Sphere.darkRimStops : Theme.Sphere.lightRimStops
        let highlightOpacity = isDark ? Theme.Sphere.darkHighlightOpacity : Theme.Sphere.lightHighlightOpacity
        return ZStack {
            Circle().fill(RadialGradient(stops: bodyStops,
                                         center: Theme.Sphere.gradientCenter,
                                         startRadius: 0,
                                         endRadius: diameter * Theme.Sphere.gradientEndRadiusRatio))
            Ellipse()
                .fill(Theme.Sphere.highlightColor.opacity(highlightOpacity))
                .frame(width: diameter * Theme.Sphere.highlightWidthRatio,
                       height: diameter * Theme.Sphere.highlightHeightRatio)
                .rotationEffect(.degrees(Theme.Sphere.highlightAngle))
                .offset(x: diameter * Theme.Sphere.highlightOffsetX,
                        y: diameter * Theme.Sphere.highlightOffsetY)
                .blur(radius: diameter * Theme.Sphere.highlightBlurRatio)
            Circle().strokeBorder(AngularGradient(stops: rimStops,
                                                  center: .center,
                                                  angle: .degrees(Theme.Sphere.rimStartAngle)),
                                  lineWidth: Theme.Sphere.rimWidth)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .drawingGroup()
    }

    private func shadow(diameter: CGFloat) -> some View {
        let opacity = isDark ? Theme.Sphere.darkShadowOpacity : Theme.Sphere.lightShadowOpacity
        return Ellipse()
            .fill(Theme.Sphere.shadowColor.opacity(opacity))
            .frame(width: diameter * Theme.Sphere.shadowWidthRatio,
                   height: diameter * Theme.Sphere.shadowHeightRatio)
            .blur(radius: diameter * Theme.Sphere.shadowBlurRatio)
    }

    // MARK: Ripples (one Canvas pass)

    private func ripples(_ layout: Layout, time: Double?) -> some View {
        let level = clampedLevel
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: layout.waterY)
            let count = Theme.Ripple.count
            let inner = layout.unit * Theme.Ripple.innerRadiusRatio
            let outer = layout.unit * Theme.Ripple.outerRadiusRatio
            for index in 0..<count {
                let position = Double(index) / Double(max(count - 1, 1))
                let radius: CGFloat
                let opacity: Double
                let lineWidth: CGFloat
                if let time {
                    // Each ring travels outward, fades in at the start and out at the end
                    let speed = 1 + Theme.Ripple.levelSpeedFactor * level
                    let raw = time * speed / Theme.Ripple.period + Double(index) / Double(count)
                    let progress = raw - raw.rounded(.down)
                    let calmOuter = layout.unit * Theme.Ripple.calmOuterRadiusRatio
                    let reach = calmOuter + (outer - calmOuter) * level
                    radius = inner + (reach - inner) * progress
                    let fadeIn = min(1, progress / Theme.Ripple.fadeInFraction)
                    opacity = Theme.Ripple.maxOpacity * (1 - progress) * fadeIn
                    lineWidth = Theme.Ripple.maxLineWidth
                        + (Theme.Ripple.minLineWidth - Theme.Ripple.maxLineWidth) * progress
                } else {
                    // Static: evenly spaced, thinner and fainter toward the outside
                    radius = inner + (outer - inner) * position
                    opacity = Theme.Ripple.maxOpacity
                        + (Theme.Ripple.minOpacity - Theme.Ripple.maxOpacity) * position
                    lineWidth = Theme.Ripple.maxLineWidth
                        + (Theme.Ripple.minLineWidth - Theme.Ripple.maxLineWidth) * position
                }
                let rect = CGRect(x: center.x - radius,
                                  y: center.y - radius * Theme.Ripple.aspect,
                                  width: radius * 2,
                                  height: radius * 2 * Theme.Ripple.aspect)
                context.stroke(Path(ellipseIn: rect),
                               with: .color(Theme.foreground.opacity(opacity)),
                               lineWidth: lineWidth)
            }
        }
    }
}

#Preview("Dark, level 0") {
    HeroSphereView(level: 0, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.dark)
}

#Preview("Dark, level 0.5") {
    HeroSphereView(level: 0.5, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.dark)
}

#Preview("Dark, level 1") {
    HeroSphereView(level: 1, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.dark)
}

#Preview("Dark, static") {
    HeroSphereView(level: 0, isActive: false)
        .padding().background(Theme.background).preferredColorScheme(.dark)
}

#Preview("Light, level 0") {
    HeroSphereView(level: 0, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.light)
}

#Preview("Light, level 0.5") {
    HeroSphereView(level: 0.5, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.light)
}

#Preview("Light, level 1") {
    HeroSphereView(level: 1, isActive: true)
        .padding().background(Theme.background).preferredColorScheme(.light)
}

#Preview("Light, static") {
    HeroSphereView(level: 0, isActive: false)
        .padding().background(Theme.background).preferredColorScheme(.light)
}
