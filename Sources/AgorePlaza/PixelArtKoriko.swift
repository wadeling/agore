import SpriteKit
import AgoreCore

enum Sky {
    static let cloud = Palette.rgba(0xF8FCFF, 255)
    static let cloudShade = Palette.rgba(0xC8E0F4, 255)
    static let stone = Palette.rgba(0xE8DCC8, 255)
    static let stoneDark = Palette.rgba(0xC4B8A0, 255)
    static let roof = Palette.rgba(0xC43C3C, 255)
    static let roofDark = Palette.rgba(0x8A2828, 255)
    static let clock = Palette.rgba(0xF5F0E6, 255)
    static let stick = Palette.rgba(0xC4A060, 255)
    static let sparkle = Palette.rgba(0xFFF8E7, 255)
    static let sparkleGold = Palette.rgba(0xF0D070, 255)
    static let gull = Palette.rgba(0xF7F5EC, 255)
    static let sun = Palette.rgba(0xFFF6CE, 255)

    struct Tint {
        let sky: UInt32
        let skyLow: UInt32
        let cloud: UInt32
        let cloudShade: UInt32
    }

    static func tint(for period: PlazaPeriod) -> Tint {
        switch period {
        case .day:
            return Tint(
                sky: Palette.rgba(0x2F8FDC, 255),
                skyLow: Palette.rgba(0x8FD4F8, 255),
                cloud: cloud,
                cloudShade: cloudShade
            )
        case .dusk:
            return Tint(
                sky: Palette.rgba(0x6A4A8A, 255),
                skyLow: Palette.rgba(0xE88860, 255),
                cloud: Palette.rgba(0xF6C6A0, 255),
                cloudShade: Palette.rgba(0xB98A96, 255)
            )
        case .night:
            return Tint(
                sky: Palette.rgba(0x111B31, 255),
                skyLow: Palette.rgba(0x27405F, 255),
                cloud: Palette.rgba(0x33415E, 255),
                cloudShade: Palette.rgba(0x232E45, 255)
            )
        }
    }
}

extension PixelArt {
    static func buildKorikoBackground(_ geometry: PlazaGeometry, period: PlazaPeriod) -> SKTexture {
        var canvas = PixelCanvas(width: geometry.worldWidth, height: geometry.worldHeight, fill: Palette.clear)
        let tint = Sky.tint(for: period)
        drawKorikoSky(&canvas, geometry: geometry, tint: tint, period: period)
        return canvas.texture()
    }

    /// The whole plaza is sky: a vertical wash from a paler horizon to a deeper blue
    /// at the top, then the sun or the night sky. Clouds are sprites, not paint.
    private static func drawKorikoSky(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Sky.Tint,
        period: PlazaPeriod
    ) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        fillSkyGradient(&canvas, width: width, height: height, low: tint.skyLow, high: tint.sky)

        switch period {
        case .day, .dusk:
            let sunX = geometry.isStrip ? width - 52 : width - 36
            let sunY = geometry.isStrip ? height - 6 : height - 30
            // Elsewhere the sun sits just over the horizon, but this sky is all
            // gradient and the sun hangs near the top of it, so the haze has to
            // dissolve into the shade of sky it is actually sitting in.
            stampSun(
                &canvas,
                x: sunX,
                y: sunY,
                isStrip: geometry.isStrip,
                body: Sky.sun,
                halo: Palette.mix(tint.skyLow, tint.sky, sunY, of: max(1, height - 1)),
                period: period
            )
        case .night:
            scatterStars(&canvas, geometry: geometry, above: 4, color: Palette.star)
            let moonX = geometry.isStrip ? 30 : 100
            let moonY = height - (geometry.isStrip ? 5 : 24)
            stampMoon(&canvas, x: moonX, y: moonY, isStrip: geometry.isStrip, sky: tint.sky)
        }
    }

    private static func fillSkyGradient(
        _ canvas: inout PixelCanvas,
        width: Int,
        height: Int,
        low: UInt32,
        high: UInt32
    ) {
        let span = max(1, height - 1)
        for y in 0..<height {
            canvas.fill(0, y, width, 1, Palette.mix(low, high, y, of: span))
        }
    }

    static func buildClockTowerFrame(_ wobble: Int) -> SKTexture {
        var canvas = PixelCanvas(width: centerpieceWidth, height: centerpieceHeight, fill: Palette.clear)
        canvas.ellipse(14, 2, 10, 2, Sky.cloud)
        canvas.disk(7, 2, 2, Sky.cloud)
        canvas.disk(21, 2, 2, Sky.cloud)
        canvas.fill(6, 0, 16, 1, Sky.cloudShade)

        canvas.fill(11, 3, 6, 8, Sky.stone)
        canvas.fill(11, 3, 1, 8, Sky.stoneDark)
        canvas.fill(16, 3, 1, 8, Sky.stoneDark)
        canvas.fill(12, 6, 4, 4, Sky.clock)
        canvas.set(13, 7, Palette.ink)
        canvas.set(14, 7, Palette.ink)
        canvas.set(14, 8, Palette.ink)
        canvas.set(15, 8, Palette.ink)

        for i in 0..<4 {
            let w = 8 - i * 2
            canvas.fill(14 - w / 2, 11 + i, max(2, w), 1, i == 3 ? Sky.roofDark : Sky.roof)
        }
        canvas.set(14, 15, Sky.stick)
        let vaneX = 13 + wobble
        canvas.set(vaneX, 14, Sky.gull)
        canvas.set(vaneX + 1, 14, Sky.gull)
        return canvas.texture()
    }
}
