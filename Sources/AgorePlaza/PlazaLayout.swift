import CoreGraphics

struct OliveTreeSpec: Equatable, Sendable {
    var x: Int
    var y: Int
    /// 0 small, 1 medium, 2 large.
    var size: Int
}

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

    /// Floor / stoa split. Actors walk below this and overlap the colonnade.
    var horizonY: Int {
        switch self {
        case .strip: return 28
        case .courtyard: return 196
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

    /// Actor rest positions. Pixel art benches are drawn at these feet, so the
    /// sleeper lies on furniture rather than on empty paving.
    var restSpots: [CGPoint] {
        switch self {
        case .strip:
            let restY = CGFloat(groundY + 10)
            return [138, 222, 92, 268, 46, 314, 20, 340].map { CGPoint(x: $0, y: restY) }
        case .courtyard:
            return [
                CGPoint(x: 88, y: 100),
                CGPoint(x: 152, y: 100),
                CGPoint(x: 72, y: 128),
                CGPoint(x: 168, y: 128),
                CGPoint(x: 96, y: 156),
                CGPoint(x: 144, y: 156),
                CGPoint(x: 80, y: 72),
                CGPoint(x: 160, y: 72),
            ]
        }
    }

    var oliveTrees: [OliveTreeSpec] {
        switch self {
        case .strip:
            return [
                OliveTreeSpec(x: 64, y: 6, size: 1),
                OliveTreeSpec(x: 250, y: 5, size: 1),
                OliveTreeSpec(x: 300, y: 7, size: 1),
            ]
        case .courtyard:
            return [
                OliveTreeSpec(x: 32, y: 30, size: 2),
                OliveTreeSpec(x: 200, y: 38, size: 1),
                OliveTreeSpec(x: 40, y: 134, size: 1),
                OliveTreeSpec(x: 192, y: 150, size: 2),
                OliveTreeSpec(x: 24, y: 86, size: 0),
                OliveTreeSpec(x: 212, y: 94, size: 0),
            ]
        }
    }

    var birdAltitude: ClosedRange<CGFloat> {
        switch self {
        case .strip: return 26...32
        case .courtyard: return 186...222
        }
    }
}
