import CoreGraphics
import AgoreCore

struct TreeSpec: Equatable, Sendable {
    var x: Int
    var y: Int
    /// 0 small, 1 medium, 2 large.
    var size: Int
}

/// Where everything stands, in world pixels. The painter and the actors both read their
/// coordinates from here, so a theme can move the shoreline without leaving anyone
/// walking on scenery that is no longer there.
struct PlazaGeometry: Hashable, Sendable {
    let layout: PlazaLayout
    let theme: PlazaTheme

    init(layout: PlazaLayout, theme: PlazaTheme) {
        self.layout = layout
        self.theme = theme
    }

    var worldWidth: Int { layout.worldWidth }
    var worldHeight: Int { layout.worldHeight }
    var isStrip: Bool { layout == .strip }

    /// Where the ground stops. Above it the agora shows its colonnade and the shore
    /// shows open water, and in both cases actors stay below the line.
    var horizonY: Int {
        switch (theme, layout) {
        case (.agora, .strip): return 28
        case (.agora, .courtyard): return 196
        case (.seaside, .strip): return 26
        case (.seaside, .courtyard): return 120
        }
    }

    /// A near edge for the paving band / dry sand line.
    var groundY: Int {
        switch (theme, layout) {
        case (.agora, .strip): return 12
        case (.agora, .courtyard): return 48
        case (.seaside, .strip): return 10
        case (.seaside, .courtyard): return 40
        }
    }

    /// Fountain on the agora, parasol on the shore: the one prop actors walk around.
    var centerpieceCenter: CGPoint {
        switch (theme, layout) {
        case (.agora, .strip): return CGPoint(x: 180, y: 12)
        case (.agora, .courtyard): return CGPoint(x: 120, y: 88)
        case (.seaside, .strip): return CGPoint(x: 180, y: 11)
        case (.seaside, .courtyard): return CGPoint(x: 120, y: 82)
        }
    }

    var centerpieceZoneX: ClosedRange<CGFloat> {
        isStrip ? 156...204 : 100...140
    }

    var centerpieceZoneY: ClosedRange<CGFloat> {
        switch (theme, layout) {
        case (.agora, .strip): return 0...28
        case (.agora, .courtyard): return 72...108
        case (.seaside, .strip): return 0...24
        case (.seaside, .courtyard): return 66...102
        }
    }

    var walkMinY: CGFloat {
        switch (theme, layout) {
        case (.agora, .strip): return 16
        case (.agora, .courtyard): return 28
        case (.seaside, .strip): return 12
        case (.seaside, .courtyard): return 24
        }
    }

    var walkMaxY: CGFloat {
        switch (theme, layout) {
        case (.agora, .strip): return 24
        case (.agora, .courtyard): return 170
        case (.seaside, .strip): return 20
        case (.seaside, .courtyard): return 106
        }
    }

    /// Actor rest positions. Benches and beach towels are painted at these feet, so a
    /// sleeper lies on furniture rather than on bare ground.
    var restSpots: [CGPoint] {
        let stripLanes: [CGFloat] = [138, 222, 92, 268, 46, 314, 20, 340]
        switch (theme, layout) {
        case (.agora, .strip):
            return stripLanes.map { CGPoint(x: $0, y: CGFloat(groundY + 10)) }
        case (.agora, .courtyard):
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
        case (.seaside, .strip):
            return stripLanes.map { CGPoint(x: $0, y: CGFloat(groundY + 8)) }
        case (.seaside, .courtyard):
            return [
                CGPoint(x: 70, y: 40),
                CGPoint(x: 170, y: 40),
                CGPoint(x: 46, y: 66),
                CGPoint(x: 194, y: 66),
                CGPoint(x: 86, y: 96),
                CGPoint(x: 154, y: 96),
                CGPoint(x: 36, y: 96),
                CGPoint(x: 204, y: 96),
            ]
        }
    }

    /// Where a thinking or running agent paces about.
    var strollSpots: [CGPoint] {
        switch (theme, layout) {
        case (.agora, .strip), (.seaside, .strip):
            return restSpots.map { CGPoint(x: $0.x + 10, y: $0.y - 3) }
        case (.agora, .courtyard):
            return [
                CGPoint(x: 100, y: 112),
                CGPoint(x: 140, y: 112),
                CGPoint(x: 64, y: 100),
                CGPoint(x: 176, y: 100),
                CGPoint(x: 108, y: 148),
                CGPoint(x: 132, y: 148),
                CGPoint(x: 96, y: 80),
                CGPoint(x: 144, y: 80),
            ]
        case (.seaside, .courtyard):
            return [
                CGPoint(x: 96, y: 54),
                CGPoint(x: 144, y: 54),
                CGPoint(x: 64, y: 86),
                CGPoint(x: 176, y: 86),
                CGPoint(x: 108, y: 32),
                CGPoint(x: 132, y: 32),
                CGPoint(x: 88, y: 62),
                CGPoint(x: 152, y: 62),
            ]
        }
    }

    var exits: [CGPoint] {
        switch (theme, layout) {
        case (.agora, .strip), (.seaside, .strip):
            let y = restSpots[0].y
            return [
                CGPoint(x: 8, y: y),
                CGPoint(x: CGFloat(worldWidth) - 8, y: y),
            ]
        case (.agora, .courtyard):
            return [
                CGPoint(x: 24, y: 32),
                CGPoint(x: 216, y: 32),
                CGPoint(x: 24, y: 168),
                CGPoint(x: 216, y: 168),
            ]
        case (.seaside, .courtyard):
            return [
                CGPoint(x: 24, y: 28),
                CGPoint(x: 216, y: 28),
                CGPoint(x: 24, y: 100),
                CGPoint(x: 216, y: 100),
            ]
        }
    }

    /// Olive trees on the agora, palms on the shore.
    var trees: [TreeSpec] {
        switch (theme, layout) {
        case (.agora, .strip):
            return [
                TreeSpec(x: 64, y: 6, size: 1),
                TreeSpec(x: 250, y: 5, size: 1),
                TreeSpec(x: 300, y: 7, size: 1),
            ]
        case (.agora, .courtyard):
            return [
                TreeSpec(x: 32, y: 30, size: 2),
                TreeSpec(x: 200, y: 38, size: 1),
                TreeSpec(x: 40, y: 134, size: 1),
                TreeSpec(x: 192, y: 150, size: 2),
                TreeSpec(x: 24, y: 86, size: 0),
                TreeSpec(x: 212, y: 94, size: 0),
            ]
        case (.seaside, .strip):
            return [
                TreeSpec(x: 62, y: 4, size: 1),
                TreeSpec(x: 252, y: 3, size: 1),
                TreeSpec(x: 306, y: 5, size: 0),
            ]
        case (.seaside, .courtyard):
            return [
                TreeSpec(x: 26, y: 62, size: 2),
                TreeSpec(x: 214, y: 68, size: 2),
                TreeSpec(x: 18, y: 24, size: 1),
                TreeSpec(x: 224, y: 28, size: 1),
            ]
        }
    }

    /// Strays that belong to the scenery, keeping out of the walking lanes. The shore has
    /// none, because there the agents are the cats and a nameless one would just be
    /// another agent you cannot account for.
    var catSpots: [CGPoint] {
        switch (theme, layout) {
        case (.agora, .strip):
            return [CGPoint(x: 118, y: 8), CGPoint(x: 246, y: 8)]
        case (.agora, .courtyard):
            return [
                CGPoint(x: 58, y: 46),
                CGPoint(x: 70, y: 44),
                CGPoint(x: 196, y: 118),
            ]
        case (.seaside, _):
            return []
        }
    }

    /// The bottom row of the bench or towel painted at a rest spot. Furniture is five
    /// pixels deep and a person stands ankle-deep in it; a cat is half as tall and has to
    /// sit at the far edge, or the towel would cover half of it.
    func furnitureY(for spot: CGPoint) -> Int {
        let spotY = Int(spot.y.rounded())
        switch theme {
        case .agora: return max(0, spotY - PixelArt.characterHeight / 2)
        case .seaside: return max(0, spotY - PixelArt.catHeight / 2 - 3)
        }
    }

    var birdAltitude: ClosedRange<CGFloat> {
        switch (theme, layout) {
        case (.agora, .strip): return 26...32
        case (.agora, .courtyard): return 186...222
        case (.seaside, .strip): return 30...39
        case (.seaside, .courtyard): return 150...220
        }
    }
}
