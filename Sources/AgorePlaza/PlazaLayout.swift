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
        case .strip: return 42
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
}
