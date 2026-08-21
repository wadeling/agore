import CoreGraphics
import AgoreCore

struct TreeSpec: Equatable, Sendable {
    var x: Int
    var y: Int
    /// 0 small, 1 medium, 2 large.
    var size: Int
}

/// A painted cloud's home. `size` is how big the lumps are; `shape` is how they
/// sit, so two clouds of the same size can still read as different weather.
struct CloudSpec: Equatable, Sendable {
    var x: Int
    var y: Int
    var size: Int
    var shape: CloudShape
    var flipped: Bool = false
}

enum CloudShape: Int, Hashable, Sendable {
    /// Three overlapping hills — the original lump.
    case puff
    /// Long and low, a streak more than a pile.
    case wispy
    /// Two puffs with a dip between them.
    case twin
    /// A wide rolling bank of four hills.
    case bank
    /// Tall in the middle, a tail off one side.
    case anvil
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

    /// Where the ground stops. Above it the agora shows its colonnade, the shore
    /// shows open water, and the stop shows sky over the sunflower field. Koriko
    /// is sky all the way down, so the line sits at zero and actors fly in it.
    var horizonY: Int {
        switch (theme, layout) {
        case (.agora, .strip): return 28
        case (.agora, .courtyard): return 196
        case (.seaside, .strip): return 26
        case (.antonovka, .strip): return 38
        case (.koriko, .strip): return 0
        case (.seaside, .courtyard): return 120
        case (.antonovka, .courtyard): return 160
        case (.koriko, .courtyard): return 0
        }
    }

    /// A near edge for the paving band / dry sand line / roadside verge / cloud deck.
    var groundY: Int {
        switch (theme, layout) {
        case (.agora, .strip): return 12
        case (.agora, .courtyard): return 48
        case (.seaside, .strip), (.antonovka, .strip): return 10
        case (.koriko, .strip): return 8
        case (.seaside, .courtyard), (.antonovka, .courtyard): return 40
        case (.koriko, .courtyard): return 32
        }
    }

    /// Fountain, parasol, bus shelter, or clock tower: the one prop actors walk around.
    var centerpieceCenter: CGPoint {
        switch (theme, layout) {
        case (.agora, .strip): return CGPoint(x: 180, y: 12)
        case (.agora, .courtyard): return CGPoint(x: 120, y: 88)
        case (.seaside, .strip), (.antonovka, .strip): return CGPoint(x: 180, y: 11)
        case (.koriko, .strip): return CGPoint(x: 180, y: 18)
        case (.seaside, .courtyard), (.antonovka, .courtyard): return CGPoint(x: 120, y: 82)
        case (.koriko, .courtyard): return CGPoint(x: 120, y: 108)
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
        case (.antonovka, .strip): return 0...28
        case (.koriko, .strip): return 8...32
        case (.seaside, .courtyard), (.antonovka, .courtyard): return 66...102
        case (.koriko, .courtyard): return 90...130
        }
    }

    var walkMinY: CGFloat {
        switch (theme, layout) {
        case (.agora, .strip): return 16
        case (.agora, .courtyard): return 28
        case (.seaside, .strip), (.antonovka, .strip): return 12
        case (.koriko, .strip): return 20
        case (.seaside, .courtyard), (.antonovka, .courtyard): return 24
        case (.koriko, .courtyard): return 28
        }
    }

    var walkMaxY: CGFloat {
        switch (theme, layout) {
        case (.agora, .strip): return 24
        case (.agora, .courtyard): return 170
        case (.seaside, .strip): return 20
        case (.antonovka, .strip): return 32
        case (.koriko, .strip): return 34
        case (.seaside, .courtyard): return 106
        case (.antonovka, .courtyard): return 144
        case (.koriko, .courtyard): return 190
        }
    }

    /// Actor rest positions. Benches, beach towels and roadside benches are painted
    /// at these feet, so a sleeper lies on furniture rather than on bare ground.
    /// Koriko has no floor; the spots are just places to hover in the sky.
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
        case (.seaside, .strip), (.antonovka, .strip):
            return stripLanes.map { CGPoint(x: $0, y: CGFloat(groundY + 8)) }
        case (.koriko, .strip):
            // A witch is the tallest actor on any plaza and carries her name below
            // her boots, so she flies higher up the strip than a rabbit walks.
            let heights: [CGFloat] = [25, 30, 23, 33, 27, 24, 31, 28]
            return zip(stripLanes, heights).map { CGPoint(x: $0, y: $1) }
        case (.seaside, .courtyard), (.antonovka, .courtyard):
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
        case (.koriko, .courtyard):
            return [
                CGPoint(x: 70, y: 56),
                CGPoint(x: 170, y: 64),
                CGPoint(x: 46, y: 110),
                CGPoint(x: 194, y: 98),
                CGPoint(x: 86, y: 150),
                CGPoint(x: 154, y: 142),
                CGPoint(x: 36, y: 168),
                CGPoint(x: 204, y: 176),
            ]
        }
    }

    /// Where a thinking or running agent paces about.
    var strollSpots: [CGPoint] {
        switch (theme, layout) {
        case (.agora, .strip), (.seaside, .strip), (.antonovka, .strip), (.koriko, .strip):
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
        case (.seaside, .courtyard), (.antonovka, .courtyard):
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
        case (.koriko, .courtyard):
            return [
                CGPoint(x: 96, y: 80),
                CGPoint(x: 144, y: 88),
                CGPoint(x: 64, y: 128),
                CGPoint(x: 176, y: 136),
                CGPoint(x: 108, y: 48),
                CGPoint(x: 132, y: 52),
                CGPoint(x: 88, y: 164),
                CGPoint(x: 152, y: 172),
            ]
        }
    }

    var exits: [CGPoint] {
        switch (theme, layout) {
        case (.agora, .strip), (.seaside, .strip), (.antonovka, .strip), (.koriko, .strip):
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
        case (.seaside, .courtyard), (.antonovka, .courtyard):
            return [
                CGPoint(x: 24, y: 28),
                CGPoint(x: 216, y: 28),
                CGPoint(x: 24, y: 100),
                CGPoint(x: 216, y: 100),
            ]
        case (.koriko, .courtyard):
            return [
                CGPoint(x: 24, y: 40),
                CGPoint(x: 216, y: 40),
                CGPoint(x: 24, y: 180),
                CGPoint(x: 216, y: 180),
            ]
        }
    }

    /// Olive trees on the agora, palms on the shore, sunflowers at the stop.
    /// Koriko is open sky, so it has none.
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
                // Inset from the last towel and from the panel's rounded corner, which
                // would otherwise clip the right-hand fronds.
                TreeSpec(x: 334, y: 4, size: 1),
            ]
        case (.seaside, .courtyard):
            return [
                TreeSpec(x: 26, y: 62, size: 2),
                TreeSpec(x: 214, y: 68, size: 2),
                TreeSpec(x: 18, y: 24, size: 1),
                TreeSpec(x: 224, y: 28, size: 1),
            ]
        case (.antonovka, .strip):
            // Bases sit on the grass above the road, not on the asphalt. Higher y
            // is further back in the field, now that the horizon sits nearer the sky.
            return [
                TreeSpec(x: 16, y: 10, size: 0),
                TreeSpec(x: 22, y: 20, size: 0),
                TreeSpec(x: 28, y: 18, size: 1),
                TreeSpec(x: 40, y: 14, size: 0),
                TreeSpec(x: 48, y: 12, size: 0),
                TreeSpec(x: 58, y: 22, size: 1),
                TreeSpec(x: 68, y: 9, size: 1),
                TreeSpec(x: 74, y: 26, size: 0),
                TreeSpec(x: 80, y: 16, size: 0),
                TreeSpec(x: 92, y: 11, size: 0),
                TreeSpec(x: 98, y: 22, size: 1),
                TreeSpec(x: 104, y: 24, size: 1),
                TreeSpec(x: 118, y: 12, size: 0),
                TreeSpec(x: 124, y: 18, size: 0),
                TreeSpec(x: 132, y: 20, size: 0),
                TreeSpec(x: 208, y: 16, size: 0),
                TreeSpec(x: 216, y: 14, size: 0),
                TreeSpec(x: 228, y: 22, size: 0),
                TreeSpec(x: 238, y: 9, size: 1),
                TreeSpec(x: 242, y: 26, size: 0),
                TreeSpec(x: 248, y: 18, size: 1),
                TreeSpec(x: 258, y: 12, size: 0),
                TreeSpec(x: 268, y: 12, size: 0),
                TreeSpec(x: 282, y: 24, size: 1),
                TreeSpec(x: 292, y: 10, size: 1),
                TreeSpec(x: 300, y: 20, size: 0),
                TreeSpec(x: 310, y: 16, size: 0),
                TreeSpec(x: 322, y: 9, size: 1),
                TreeSpec(x: 330, y: 24, size: 1),
                TreeSpec(x: 338, y: 20, size: 0),
            ]
        case (.antonovka, .courtyard):
            return [
                TreeSpec(x: 22, y: 48, size: 2),
                TreeSpec(x: 50, y: 34, size: 1),
                TreeSpec(x: 12, y: 40, size: 0),
                TreeSpec(x: 38, y: 60, size: 1),
                TreeSpec(x: 64, y: 78, size: 0),
                TreeSpec(x: 28, y: 88, size: 1),
                TreeSpec(x: 16, y: 70, size: 0),
                TreeSpec(x: 44, y: 100, size: 1),
                TreeSpec(x: 8, y: 52, size: 0),
                TreeSpec(x: 32, y: 42, size: 1),
                TreeSpec(x: 56, y: 56, size: 0),
                TreeSpec(x: 72, y: 92, size: 1),
                TreeSpec(x: 20, y: 108, size: 0),
                TreeSpec(x: 48, y: 76, size: 1),
                TreeSpec(x: 6, y: 84, size: 0),
                TreeSpec(x: 70, y: 36, size: 0),
                TreeSpec(x: 10, y: 58, size: 1),
                TreeSpec(x: 42, y: 50, size: 0),
                TreeSpec(x: 18, y: 96, size: 1),
                TreeSpec(x: 60, y: 44, size: 1),
                TreeSpec(x: 36, y: 112, size: 0),
                TreeSpec(x: 74, y: 68, size: 0),
                TreeSpec(x: 4, y: 74, size: 1),
                TreeSpec(x: 54, y: 88, size: 0),
                TreeSpec(x: 214, y: 52, size: 2),
                TreeSpec(x: 188, y: 30, size: 1),
                TreeSpec(x: 198, y: 40, size: 0),
                TreeSpec(x: 226, y: 64, size: 1),
                TreeSpec(x: 176, y: 70, size: 0),
                TreeSpec(x: 208, y: 90, size: 1),
                TreeSpec(x: 224, y: 74, size: 0),
                TreeSpec(x: 218, y: 102, size: 1),
                TreeSpec(x: 168, y: 48, size: 1),
                TreeSpec(x: 182, y: 86, size: 0),
                TreeSpec(x: 196, y: 58, size: 1),
                TreeSpec(x: 230, y: 80, size: 0),
                TreeSpec(x: 172, y: 98, size: 1),
                TreeSpec(x: 204, y: 34, size: 0),
                TreeSpec(x: 220, y: 46, size: 1),
                TreeSpec(x: 236, y: 94, size: 0),
                TreeSpec(x: 160, y: 56, size: 0),
                TreeSpec(x: 190, y: 74, size: 1),
                TreeSpec(x: 210, y: 44, size: 0),
                TreeSpec(x: 234, y: 70, size: 1),
                TreeSpec(x: 178, y: 108, size: 0),
                TreeSpec(x: 200, y: 82, size: 1),
                TreeSpec(x: 228, y: 96, size: 0),
                TreeSpec(x: 166, y: 36, size: 1),
            ]
        case (.koriko, .strip), (.koriko, .courtyard):
            return []
        }
    }

    /// Strays that belong to the scenery, keeping out of the walking lanes. The shore,
    /// the stop and Koriko have none, because there the agents are the inhabitants and
    /// a nameless one would just be another agent you cannot account for.
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
        case (.seaside, _), (.antonovka, _), (.koriko, _):
            return []
        }
    }

    /// The bottom row of the bench or towel painted at a rest spot. Furniture is five
    /// pixels deep and a person stands ankle-deep in it; a cat is half as tall and has to
    /// sit at the far edge, or the towel would cover half of it. A rabbit is in between,
    /// and a witch sits on her broom just above the puff.
    func furnitureY(for spot: CGPoint) -> Int {
        let spotY = Int(spot.y.rounded())
        switch theme {
        case .agora: return max(0, spotY - PixelArt.characterHeight / 2)
        case .seaside: return max(0, spotY - PixelArt.catHeight / 2 - 3)
        case .antonovka: return max(0, spotY - PixelArt.rabbitHeight / 2)
        case .koriko: return max(0, spotY - PixelArt.witchHeight / 2)
        }
    }

    /// Where the sea gives way to sky. Clouds live above this line so they cannot
    /// sit on a palm. Koriko is all sky, so the line is only used for drifting weather.
    var skyY: Int {
        horizonY + max(6, (worldHeight - horizonY) * 2 / 5)
    }

    /// The agora keeps its weather painted on, because a colonnade does not want
    /// clouds sliding through the beams. Everywhere else the sky is wide enough to watch.
    var clouds: [CloudSpec] {
        switch (theme, layout) {
        case (.seaside, .strip), (.antonovka, .strip):
            let y = worldHeight - 5
            return [
                CloudSpec(x: 36, y: y, size: 2, shape: .twin),
                CloudSpec(x: 88, y: y - 1, size: 3, shape: .puff),
                CloudSpec(x: 148, y: y + 1, size: 2, shape: .wispy),
                CloudSpec(x: 210, y: y - 2, size: 3, shape: .twin, flipped: true),
                CloudSpec(x: 268, y: y, size: 2, shape: .puff),
                CloudSpec(x: 322, y: y - 1, size: 2, shape: .wispy, flipped: true),
            ]
        case (.koriko, .strip), (.koriko, .courtyard):
            return scatteredSkyClouds()
        case (.seaside, .courtyard), (.antonovka, .courtyard):
            return [
                CloudSpec(x: 54, y: worldHeight - 34, size: 7, shape: .bank),
                CloudSpec(x: 148, y: worldHeight - 16, size: 9, shape: .anvil),
                CloudSpec(x: 206, y: skyY + 14, size: 5, shape: .bank, flipped: true),
            ]
        default:
            return []
        }
    }

    /// A handful of clouds scattered through the sky rather than lined up along the
    /// top. The sequence is seeded from the world size, so a repaint keeps the same
    /// weather instead of jumping every frame.
    private func scatteredSkyClouds() -> [CloudSpec] {
        var seed = worldWidth &* 2654435761 &+ worldHeight &* 1597334677 &+ 0xC10D
        func next() -> Int {
            seed = seed &* 1103515245 &+ 12345
            return seed & Int.max
        }
        let shapes: [CloudShape] = [.puff, .wispy, .twin, .bank, .anvil]
        let count = isStrip ? 7 : 8
        let yLo = isStrip ? 8 : 28
        let yHi = worldHeight - (isStrip ? 6 : 20)
        let ySpan = max(1, yHi - yLo)
        return (0..<count).map { _ in
            let x = 18 + next() % max(1, worldWidth - 36)
            let y = yLo + next() % ySpan
            let size = isStrip ? 2 + next() % 3 : 4 + next() % 5
            let shape = shapes[next() % shapes.count]
            return CloudSpec(x: x, y: y, size: size, shape: shape, flipped: next() % 2 == 0)
        }
    }

    var birdAltitude: ClosedRange<CGFloat> {
        switch (theme, layout) {
        case (.agora, .strip): return 26...32
        case (.agora, .courtyard): return 186...222
        case (.seaside, .strip): return 30...39
        case (.antonovka, .strip): return 40...49
        case (.koriko, .strip): return 16...44
        case (.seaside, .courtyard): return 150...220
        case (.antonovka, .courtyard): return 168...228
        case (.koriko, .courtyard): return 40...220
        }
    }
}
