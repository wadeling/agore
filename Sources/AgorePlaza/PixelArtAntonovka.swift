import SpriteKit
import AgoreCore

enum Meadow {
    static let grass = Palette.rgba(0x4A9A3C, 255)
    static let grassLight = Palette.rgba(0x6BB84A, 255)
    static let grassDark = Palette.rgba(0x2F6E28, 255)
    static let petal = Palette.rgba(0xF0C030, 255)
    static let petalLight = Palette.rgba(0xF8DC68, 255)
    static let seed = Palette.rgba(0x6B3A18, 255)
    static let stem = Palette.rgba(0x3D7A32, 255)
    static let leaf = Palette.rgba(0x3E9455, 255)
    static let asphalt = Palette.rgba(0x4A4A52, 255)
    static let asphaltDark = Palette.rgba(0x34343C, 255)
    static let dash = Palette.rgba(0xC9A227, 255)
    static let walk = Palette.rgba(0xC8C0B0, 255)
    static let walkLight = Palette.rgba(0xDCD4C4, 255)
    static let concrete = Palette.rgba(0xE8DCC8, 255)
    static let concreteDark = Palette.rgba(0xC4B8A0, 255)
    static let sign = Palette.rgba(0x3A5A9A, 255)
    static let signLight = Palette.rgba(0xF5F0E6, 255)
    static let mural = Palette.rgba(0x6BB8B0, 255)
    static let muralDark = Palette.rgba(0x4A8A82, 255)
    static let suit = Palette.rgba(0xE87890, 255)
    static let helmet = Palette.rgba(0xF6F0E2, 255)
    static let wood = Palette.rgba(0x8B5A3C, 255)
    static let woodLight = Palette.rgba(0xC9A87A, 255)
    static let gull = Palette.rgba(0xF7F5EC, 255)
    static let sun = Palette.rgba(0xFFF6CE, 255)

    struct Tint {
        let sky: UInt32
        let skyLow: UInt32
        let cloud: UInt32
        let cloudShade: UInt32
        let field: UInt32
        let fieldDark: UInt32
    }

    static func tint(for period: PlazaPeriod) -> Tint {
        switch period {
        case .day:
            return Tint(
                sky: Palette.rgba(0x4AA8E8, 255),
                skyLow: Palette.rgba(0x8FD4F5, 255),
                cloud: Palette.rgba(0xF8FCFF, 255),
                cloudShade: Palette.rgba(0xC8E0F0, 255),
                field: grass,
                fieldDark: grassDark
            )
        case .dusk:
            return Tint(
                sky: Palette.rgba(0x6A4A8A, 255),
                skyLow: Palette.rgba(0xE88860, 255),
                cloud: Palette.rgba(0xF6C6A0, 255),
                cloudShade: Palette.rgba(0xB98A96, 255),
                field: Palette.rgba(0x4A6A3A, 255),
                fieldDark: Palette.rgba(0x2A4A28, 255)
            )
        case .night:
            return Tint(
                sky: Palette.rgba(0x1A2438, 255),
                skyLow: Palette.rgba(0x2C3A52, 255),
                cloud: Palette.rgba(0x33415E, 255),
                cloudShade: Palette.rgba(0x232E45, 255),
                field: Palette.rgba(0x1E3A28, 255),
                fieldDark: Palette.rgba(0x14241C, 255)
            )
        }
    }
}

extension PixelArt {
    static func buildAntonovkaBackground(_ geometry: PlazaGeometry, period: PlazaPeriod) -> SKTexture {
        var canvas = PixelCanvas(width: geometry.worldWidth, height: geometry.worldHeight, fill: Meadow.grass)
        let tint = Meadow.tint(for: period)
        drawMeadowSky(&canvas, geometry: geometry, tint: tint, period: period)
        drawField(&canvas, geometry: geometry, tint: tint)
        drawRoad(&canvas, geometry: geometry)
        for tree in geometry.trees {
            drawSunflower(&canvas, tree: tree)
        }
        scatterSunflowers(&canvas, geometry: geometry)
        drawMeadowBenches(&canvas, geometry: geometry)
        if !geometry.isStrip {
            drawShelterBody(&canvas, geometry: geometry)
        }
        applyFloorWash(&canvas, geometry: geometry, period: period)
        return canvas.texture()
    }

    private static func drawMeadowSky(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Meadow.Tint,
        period: PlazaPeriod
    ) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        let horizon = geometry.horizonY
        canvas.fill(0, horizon, width, max(0, height - horizon), tint.sky)
        canvas.fill(0, horizon, width, min(geometry.isStrip ? 3 : 10, max(0, height - horizon)), tint.skyLow)

        switch period {
        case .day, .dusk:
            let sunX = geometry.isStrip ? width - 48 : width - 36
            let sunY = geometry.isStrip ? height - 6 : height - 28
            stampSun(&canvas, x: sunX, y: sunY, isStrip: geometry.isStrip, body: Meadow.sun, halo: tint.skyLow)
        case .night:
            scatterStars(&canvas, geometry: geometry, above: horizon + 4, color: Palette.star)
            let moonX = geometry.isStrip ? 28 : 92
            let moonY = height - (geometry.isStrip ? 5 : 22)
            stampMoon(&canvas, x: moonX, y: moonY, isStrip: geometry.isStrip, sky: tint.sky)
        }
    }

    /// Grass runs up to the horizon so the field meets the sky with no hills in between.
    private static func drawField(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Meadow.Tint
    ) {
        let width = geometry.worldWidth
        let horizon = geometry.horizonY
        canvas.fill(0, 0, width, horizon, tint.field)
        canvas.fill(0, geometry.groundY, width, 3, Meadow.grassLight)
        var seed = width &* 7919 &+ horizon
        for _ in 0..<max(28, width * horizon / 90) {
            seed = seed &* 1103515245 &+ 12345
            let bits = seed & Int.max
            let x = bits % width
            let y = (bits / 13) % max(1, horizon)
            canvas.set(x, y, (bits & 1) == 0 ? tint.fieldDark : Meadow.grassLight)
        }
    }

    private static func roadHeight(_ geometry: PlazaGeometry) -> Int {
        geometry.isStrip ? 5 : 18
    }

    private static func walkHeight(_ geometry: PlazaGeometry) -> Int {
        geometry.isStrip ? 3 : 8
    }

    /// First grass pixel above the road and the sidewalk.
    private static func grassMinY(_ geometry: PlazaGeometry) -> Int {
        roadHeight(geometry) + walkHeight(geometry)
    }

    private static func drawRoad(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let width = geometry.worldWidth
        let roadH = roadHeight(geometry)
        canvas.fill(0, 0, width, roadH, Meadow.asphalt)
        canvas.fill(0, 0, width, 1, Meadow.asphaltDark)
        canvas.fill(0, roadH - 1, width, 1, Meadow.walk)
        canvas.fill(0, roadH, width, walkHeight(geometry), Meadow.walkLight)
        for x in stride(from: 6, to: width - 4, by: 10) {
            canvas.fill(x, roadH / 2, 4, 1, Meadow.dash)
        }
    }

    private static func scatterSunflowers(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let width = geometry.worldWidth
        let horizon = geometry.horizonY
        let grassLo = grassMinY(geometry)
        var seed = width &* 2654435761 &+ horizon
        let count = geometry.isStrip ? 48 : 168
        var placed = 0
        var attempts = 0
        while placed < count && attempts < count * 8 {
            attempts += 1
            seed = seed &* 1103515245 &+ 12345
            let bits = seed & Int.max
            let size = placed % 5 == 0 ? 1 : 0
            let stemH = [4, 7, 11][size]
            let headR = [2, 3, 4][size]
            let grassHi = max(grassLo, horizon - stemH - headR)
            let x = 6 + bits % max(1, width - 12)
            if geometry.centerpieceZoneX.contains(CGFloat(x)) { continue }
            let y = grassLo + (bits / 17) % max(1, grassHi - grassLo + 1)
            drawSunflower(&canvas, tree: TreeSpec(x: x, y: y, size: size))
            placed += 1
        }
    }

    private static func drawSunflower(_ canvas: inout PixelCanvas, tree: TreeSpec) {
        let size = min(max(tree.size, 0), 2)
        let stemH = [4, 7, 11][size]
        let headR = [2, 3, 4][size]
        let cx = tree.x
        canvas.fill(cx, tree.y, size == 0 ? 1 : 2, stemH, Meadow.stem)
        if size >= 1 {
            canvas.set(cx - 2, tree.y + stemH / 2, Meadow.leaf)
            canvas.set(cx - 1, tree.y + stemH / 2, Meadow.leaf)
            canvas.set(cx + 2, tree.y + stemH / 3, Meadow.leaf)
        }
        let hy = tree.y + stemH
        canvas.disk(cx, hy, headR, Meadow.petal)
        canvas.set(cx, hy + headR, Meadow.petalLight)
        canvas.set(cx, hy - headR, Meadow.petal)
        canvas.set(cx - headR, hy, Meadow.petalLight)
        canvas.set(cx + headR, hy, Meadow.petal)
        canvas.disk(cx, hy, max(1, headR - 2), Meadow.seed)
    }

    private static func drawMeadowBenches(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let spots = geometry.restSpots
        let drawn = geometry.isStrip ? spots.prefix(6) : spots.prefix(spots.count)
        for spot in drawn {
            let x = Int(spot.x.rounded())
            drawWoodBench(&canvas, x: x, y: geometry.furnitureY(for: spot))
        }
    }

    private static func drawWoodBench(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        let w = 16
        let left = x - w / 2
        canvas.fill(left, y, 2, 3, Meadow.wood)
        canvas.fill(left + w - 2, y, 2, 3, Meadow.wood)
        canvas.fill(left, y + 2, w, 2, Meadow.woodLight)
        canvas.fill(left + 1, y + 3, w - 2, 1, Meadow.wood)
    }

    /// Courtyard only: a shelter the 28×18 sprite can sit on, so the stop reads as a
    /// building rather than a floating sign.
    private static func drawShelterBody(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let cx = Int(geometry.centerpieceCenter.x)
        let cy = Int(geometry.centerpieceCenter.y)
        canvas.fill(cx - 22, cy - 6, 44, 4, Meadow.walk)
        canvas.fill(cx - 20, cy - 2, 4, 22, Meadow.concrete)
        canvas.fill(cx + 16, cy - 2, 4, 22, Meadow.concrete)
        canvas.fill(cx - 16, cy + 4, 14, 16, Meadow.mural)
        canvas.fill(cx - 2, cy + 4, 18, 16, Meadow.muralDark)
        canvas.fill(cx - 13, cy + 10, 5, 8, Meadow.suit)
        canvas.disk(cx - 11, cy + 16, 3, Meadow.helmet)
        canvas.set(cx - 12, cy + 16, Palette.ink)
        canvas.set(cx - 10, cy + 16, Palette.ink)
        canvas.fill(cx - 22, cy + 20, 44, 3, Meadow.concrete)
        canvas.fill(cx - 22, cy + 21, 44, 1, Meadow.concreteDark)
    }

    static func buildBusStopFrame(_ wobble: Int) -> SKTexture {
        var canvas = PixelCanvas(width: centerpieceWidth, height: centerpieceHeight, fill: Palette.clear)
        canvas.fill(1, 0, 26, 2, Meadow.walk)
        canvas.fill(2, 2, 3, 10, Meadow.concrete)
        canvas.fill(23, 2, 3, 10, Meadow.concrete)
        canvas.fill(5, 3, 9, 8, Meadow.mural)
        canvas.fill(14, 3, 9, 8, Meadow.muralDark)
        canvas.fill(7, 5, 4, 5, Meadow.suit)
        canvas.disk(9, 9, 2, Meadow.helmet)
        canvas.set(8, 9, Palette.ink)
        canvas.fill(2, 11, 24, 3, Meadow.concrete)
        canvas.fill(2, 12, 24, 1, Meadow.concreteDark)
        canvas.fill(6, 14, 16, 3, Meadow.sign)
        canvas.fill(8, 15, 2, 1, Meadow.signLight)
        canvas.fill(12, 15, 3, 1, Meadow.signLight)
        canvas.fill(17, 15, 2, 1, Meadow.signLight)
        let birdX = 8 + wobble * 4
        canvas.fill(birdX, 16, 3, 1, Meadow.gull)
        canvas.set(birdX + 1, 17, Meadow.gull)
        canvas.set(birdX + (wobble == 1 ? 3 : -1), 16, Meadow.gull)
        canvas.set(birdX, 16, Palette.ink)
        canvas.set(4 + wobble, 10, Meadow.petal)
        canvas.set(24 - wobble, 9, Meadow.petalLight)
        return canvas.texture()
    }
}
