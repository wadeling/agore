import CoreGraphics

/// Two distinct plazas: the menu-bar strip and the square courtyard window.
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

    /// Floor / sky split. Actors walk below this.
    var horizonY: Int {
        switch self {
        case .strip: return 33
        case .courtyard: return 200
        }
    }

    var groundY: Int {
        switch self {
        case .strip: return 12
        case .courtyard: return 48
        }
    }

    var fountainCenter: CGPoint {
        switch self {
        case .strip: return CGPoint(x: 180, y: 12)
        case .courtyard: return CGPoint(x: 120, y: 88)
        }
    }

    var fountainZoneX: ClosedRange<CGFloat> {
        switch self {
        case .strip: return 156...204
        case .courtyard: return 100...140
        }
    }

    var fountainZoneY: ClosedRange<CGFloat> {
        switch self {
        case .strip: return 0...28
        case .courtyard: return 72...108
        }
    }

    var walkMinY: CGFloat {
        switch self {
        case .strip: return 16
        case .courtyard: return 28
        }
    }

    var walkMaxY: CGFloat {
        switch self {
        case .strip: return 24
        case .courtyard: return 170
        }
    }
}
