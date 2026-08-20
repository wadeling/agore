import Foundation

/// How see-through the menu-bar strip is. The plaza is meant to sit in the corner of
/// the eye, so it starts a little translucent and can be dragged live from the status
/// item without a restart.
///
/// One hundred percent is a solid card: the designed floor translucency would otherwise
/// still let the desktop show through after the window itself is fully opaque.
public enum PanelOpacity {
    public static let `default`: Double = 0.8
    public static let minimum: Double = 0.2
    public static let maximum: Double = 1.0

    /// Status chrome at the default 80% look, matching the original strip.
    public static let designedBarAlpha: Double = 0.55
    /// Floor at 20%, still a hint of plaza rather than an empty hole.
    public static let ghostGroundAlpha: Double = 0.25
    public static let ghostBarAlpha: Double = 0.18

    public struct Visuals: Equatable, Sendable {
        public var fillAlpha: Double
        public var groundAlpha: Double
        public var barAlpha: Double
    }

    public static var current: Double {
        get {
            guard UserDefaults.standard.object(forKey: AgoreConstants.panelOpacityKey) != nil else {
                return `default`
            }
            return clamped(UserDefaults.standard.double(forKey: AgoreConstants.panelOpacityKey))
        }
        set {
            UserDefaults.standard.set(clamped(newValue), forKey: AgoreConstants.panelOpacityKey)
        }
    }

    public static func clamped(_ value: Double) -> Double {
        min(maximum, max(minimum, value))
    }

    public static func percentLabel(for value: Double) -> String {
        "\(Int((clamped(value) * 100).rounded()))%"
    }

    public static func visuals(for opacity: Double) -> Visuals {
        let t = clamped(opacity)
        let designedGround = Double(AgoreConstants.groundOpacity)
        if t >= maximum {
            return Visuals(fillAlpha: 1, groundAlpha: 1, barAlpha: 1)
        }
        if t <= `default` {
            let u = (t - minimum) / (`default` - minimum)
            return Visuals(
                fillAlpha: 0,
                groundAlpha: lerp(ghostGroundAlpha, designedGround, u),
                barAlpha: lerp(ghostBarAlpha, designedBarAlpha, u)
            )
        }
        let u = (t - `default`) / (maximum - `default`)
        return Visuals(
            fillAlpha: u,
            groundAlpha: lerp(designedGround, 1, u),
            barAlpha: lerp(designedBarAlpha, 1, u)
        )
    }

    private static func lerp(_ a: Double, _ b: Double, _ u: Double) -> Double {
        a + (b - a) * u
    }
}
