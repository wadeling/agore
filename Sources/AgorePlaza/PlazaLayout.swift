import CoreGraphics

/// Two distinct plazas: the menu-bar strip and the square courtyard window. A layout
/// only fixes the size of the world; what fills it is up to `PlazaTheme`.
public enum PlazaLayout: Hashable, Sendable {
    case strip
    case courtyard

    public var worldWidth: Int {
        switch self {
        case .strip: return 360
        case .courtyard: return 240
        }
    }

    public var worldHeight: Int {
        switch self {
        case .strip: return 51
        case .courtyard: return 240
        }
    }

    public var worldSize: CGSize {
        CGSize(width: worldWidth, height: worldHeight)
    }

    /// How many view pixels a world pixel occupies. Strip is 2×, courtyard 3×.
    public var pixelScale: Int {
        switch self {
        case .strip: return 2
        case .courtyard: return 3
        }
    }

    /// How many times a second the view asks to draw while something is moving.
    /// Pixel art ticks at 0.18s; the strip sits in the corner all day, so it
    /// asks for less. An idle strip does not draw at all.
    public var framesPerSecond: Int {
        switch self {
        case .strip: return 8
        case .courtyard: return 30
        }
    }
}
