import SpriteKit
import AgoreCore

enum Floe {
    /// Sampled from the arctic strip reference: pale lids, a medium-blue lip,
    /// royal water, and a lighter sky so the distant bergs have something to sit on.
    static let iceTop = Palette.rgba(0xC8ECFF, 255)
    static let iceLit = Palette.rgba(0x86CCF0, 255)
    static let iceShade = Palette.rgba(0x3890D0, 255)
    static let iceDeep = Palette.rgba(0x2C68B8, 255)

    struct Tint {
        let sky: UInt32
        let sea: UInt32
        let seaDeep: UInt32
        let iceTop: UInt32
        let iceLit: UInt32
        let iceShade: UInt32
        let iceDeep: UInt32
    }

    /// The four ice tones are deliberately far apart. Sunlit and shaded faces
    /// only read as facets when neighbouring steps do not blur together.
    static func tint(for period: PlazaPeriod) -> Tint {
        switch period {
        case .day:
            return Tint(
                sky: Palette.rgba(0x5EB9E6, 255),
                sea: Palette.rgba(0x445ABD, 255),
                seaDeep: Palette.rgba(0x3A50B0, 255),
                iceTop: iceTop,
                iceLit: iceLit,
                iceShade: iceShade,
                iceDeep: iceDeep
            )
        case .dusk:
            // Keep the royal blue and pale cyan. Greying the ice reads as stone.
            return Tint(
                sky: Palette.rgba(0x56AAD8, 255),
                sea: Palette.rgba(0x3E54B8, 255),
                seaDeep: Palette.rgba(0x3448A4, 255),
                iceTop: Palette.rgba(0xBCE4FC, 255),
                iceLit: Palette.rgba(0x7CC0E8, 255),
                iceShade: Palette.rgba(0x3284C8, 255),
                iceDeep: Palette.rgba(0x285EAC, 255)
            )
        case .night:
            // Mid navy, not near-black, so a penguin still reads on the water.
            return Tint(
                sky: Palette.rgba(0x2E5C8C, 255),
                sea: Palette.rgba(0x2E4A88, 255),
                seaDeep: Palette.rgba(0x243C78, 255),
                iceTop: Palette.rgba(0x9CCCE8, 255),
                iceLit: Palette.rgba(0x64A8D0, 255),
                iceShade: Palette.rgba(0x2A6CA8, 255),
                iceDeep: Palette.rgba(0x1F5090, 255)
            )
        }
    }
}

extension PixelArt {
    /// Pale sky, a row of short distant bergs, royal water, and a few painted
    /// chips near the horizon. Drifting floes are sprites, not paint.
    static func buildIcebergBackground(_ geometry: PlazaGeometry, period: PlazaPeriod) -> SKTexture {
        let tint = Floe.tint(for: period)
        var canvas = PixelCanvas(width: geometry.worldWidth, height: geometry.worldHeight, fill: tint.sea)
        let room = max(0, geometry.worldHeight - geometry.horizonY)
        canvas.fill(0, geometry.horizonY, geometry.worldWidth, room, tint.sky)
        drawHorizonHaze(&canvas, geometry: geometry, tint: tint)
        drawDistantBergs(&canvas, geometry: geometry, tint: tint)
        drawHorizonChips(&canvas, geometry: geometry, tint: tint)
        return canvas.texture()
    }

    /// A dithered shadow on the water under the ice, so the skyline does not
    /// sit on a ruled line.
    private static func drawHorizonHaze(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Floe.Tint
    ) {
        let band = geometry.isStrip ? 2 : 3
        let width = geometry.worldWidth
        let base = geometry.horizonY
        for y in 0..<band {
            let row = base - 1 - y
            guard row >= 0 else { continue }
            let step = y == 0 ? 2 : 3
            for x in 0..<width where (x + y) % step == 0 {
                canvas.set(x, row, tint.seaDeep)
            }
        }
    }

    private struct Berg {
        let x: Int
        let width: Int
        let height: Int
        let slant: Int
        /// Pixels of flat plateau at the crest. Zero is a sharp peak.
        let crown: Int
        /// A pale seam down the face, as the nearest bergs carry.
        let crevasse: Bool
        /// How far the base sits below the waterline. A berg that drops reads
        /// as nearer than the row behind it.
        let drop: Int

        init(
            _ x: Int,
            _ width: Int,
            _ height: Int,
            slant: Int = 0,
            crown: Int = 0,
            crevasse: Bool = false,
            drop: Int = 0
        ) {
            self.x = x
            self.width = width
            self.height = height
            self.slant = slant
            self.crown = crown
            self.crevasse = crevasse
            self.drop = drop
        }
    }

    /// A skyline rather than a fence. A pale, low back row sets the distance;
    /// a taller front row overlaps it with no two neighbours the same height,
    /// and one near berg drops below the waterline carrying a crevasse.
    private static func drawDistantBergs(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Floe.Tint
    ) {
        let base = geometry.horizonY
        let room = max(2, geometry.worldHeight - base)
        let far = Floe.Tint(
            sky: tint.sky,
            sea: tint.sea,
            seaDeep: tint.seaDeep,
            iceTop: Palette.mix(tint.iceTop, tint.sky, 1, of: 3),
            iceLit: Palette.mix(tint.iceLit, tint.sky, 1, of: 3),
            iceShade: Palette.mix(tint.iceShade, tint.sky, 1, of: 3),
            iceDeep: Palette.mix(tint.iceDeep, tint.sky, 1, of: 3)
        )
        for berg in backBergs(geometry) {
            stampBerg(&canvas, berg, base: base, room: room, tint: far)
        }
        for berg in frontBergs(geometry) {
            stampBerg(&canvas, berg, base: base, room: room, tint: tint)
        }
    }

    /// Small and pale, sitting in the gaps of the front row so the skyline has
    /// something behind it wherever it opens up.
    private static func backBergs(_ geometry: PlazaGeometry) -> [Berg] {
        if geometry.isStrip {
            return [
                Berg(6, 18, 5), Berg(36, 14, 3), Berg(62, 18, 5), Berg(92, 12, 3),
                Berg(120, 20, 6), Berg(150, 14, 4), Berg(180, 18, 5), Berg(206, 12, 3),
                Berg(240, 20, 6), Berg(268, 14, 4), Berg(298, 18, 5), Berg(328, 12, 3),
                Berg(356, 16, 5),
            ]
        }
        return [
            Berg(4, 26, 10), Berg(34, 20, 7), Berg(60, 30, 12), Berg(90, 18, 6),
            Berg(116, 28, 11), Berg(142, 20, 7), Berg(180, 30, 12), Berg(206, 18, 6),
            Berg(232, 26, 10),
        ]
    }

    /// Wide beats tall: a berg roughly twice as broad as it is high reads as
    /// ice, where a narrow one reads as a spire.
    private static func frontBergs(_ geometry: PlazaGeometry) -> [Berg] {
        if geometry.isStrip {
            return [
                Berg(16, 20, 8),
                Berg(46, 12, 4, slant: 1, crown: 3),
                Berg(72, 26, 10, slant: -1),
                Berg(104, 14, 5, crown: 3),
                Berg(132, 18, 7, slant: 1),
                Berg(160, 10, 3),
                Berg(184, 16, 6, slant: -1),
                Berg(216, 30, 10, slant: -1, crown: 6, crevasse: true, drop: 3),
                Berg(252, 14, 4, slant: 1),
                Berg(278, 22, 8),
                Berg(308, 12, 4, slant: -1, crown: 2),
                Berg(338, 24, 9, slant: 1),
            ]
        }
        return [
            Berg(10, 30, 15),
            Berg(40, 18, 8, slant: 1, crown: 4),
            Berg(66, 42, 22, slant: -1),
            Berg(100, 22, 10, crown: 5),
            Berg(124, 16, 7, slant: 1),
            Berg(152, 56, 30, slant: -1, crown: 10, crevasse: true, drop: 8),
            Berg(190, 24, 11, slant: 1),
            Berg(214, 38, 19),
            Berg(240, 20, 9, slant: 1),
        ]
    }

    /// Light from the top left: a white left slope, a pale cyan body, and a
    /// medium-blue right face, so two overlapping bergs never merge into one
    /// flat shape.
    private static func stampBerg(
        _ canvas: inout PixelCanvas,
        _ berg: Berg,
        base: Int,
        room: Int,
        tint: Floe.Tint
    ) {
        let height = max(2, min(berg.height, room - 1))
        let glint = Palette.mix(tint.iceTop, Palette.rgba(0xFFFFFF, 255), 1, of: 2)
        let crownHalf = max(0, berg.crown / 2)
        let baseHalf = max(crownHalf + 1, berg.width / 2)
        let span = max(1, height - 1)
        for y in -berg.drop..<height {
            let rise = max(0, y)
            var half = crownHalf + (span - rise) * (baseHalf - crownHalf) / span
            if rise > 1, (berg.x + rise) % 5 == 0 {
                half = max(crownHalf, half - 1)
            }
            if rise > 1, (berg.x &* 7 &+ rise &* 13) % 7 == 0 {
                half = max(crownHalf, half - 1)
            }
            let left = berg.x - half + berg.slant * rise / max(2, height)
            let wide = max(2, half * 2)
            canvas.fill(left, base + y, wide, 1, tint.iceLit)
            let dark = max(1, wide / 3)
            canvas.fill(left + wide - dark, base + y, dark, 1, tint.iceShade)
            canvas.set(left + wide - 1, base + y, tint.iceDeep)
            canvas.fill(left, base + y, max(1, wide / 3), 1, tint.iceTop)
            canvas.set(left, base + y, glint)
            if wide > 6 {
                canvas.set(left + 1, base + y, glint)
            }
            if rise >= height - 2 {
                canvas.fill(left, base + y, max(1, wide - 1), 1, tint.iceTop)
            }
            if berg.crevasse, rise < height - 2, wide > 8 {
                let seam = left + wide - max(3, wide / 3)
                canvas.set(seam, base + y, tint.iceTop)
                canvas.set(seam + 1, base + y, tint.iceDeep)
            }
        }
    }

    /// Tiny static chips just below the horizon, so the far water is not empty
    /// while the drifting sprites stay nearer the walkers.
    private static func drawHorizonChips(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        tint: Floe.Tint
    ) {
        let chips: [(x: Int, y: Int, w: Int)]
        if geometry.isStrip {
            chips = [
                (44, 34, 4),
                (96, 36, 3),
                (190, 33, 5),
                (248, 35, 3),
                (348, 34, 4),
            ]
        } else {
            chips = [
                (36, 184, 5),
                (80, 190, 3),
                (128, 178, 6),
                (210, 186, 4),
            ]
        }
        for chip in chips {
            stampChip(&canvas, cx: chip.x, y: chip.y, width: chip.w, tint: tint)
        }
    }

    private static func stampChip(
        _ canvas: inout PixelCanvas,
        cx: Int,
        y: Int,
        width: Int,
        tint: Floe.Tint
    ) {
        let left = cx - width / 2
        canvas.fill(left, y, width, 1, tint.iceDeep)
        canvas.fill(left, y + 1, width, 1, tint.iceTop)
        if width > 3 {
            canvas.set(left, y + 1, Palette.mix(tint.iceTop, Palette.rgba(0xFFFFFF, 255), 1, of: 3))
        }
    }

    /// Four pancake sizes: a chip, a small oval, a medium sheet, a wide platform.
    /// `spec.size` is 0...3.
    static func floe(_ spec: IceSpec, period: PlazaPeriod) -> SKTexture {
        let size = min(max(spec.size, 0), 3)
        return cached(.floe(size: size, period: period)) {
            buildFloe(size: size, period: period)
        }
    }

    static func floeSpriteSize(_ spec: IceSpec) -> CGSize {
        let metrics = floeMetrics(spec.size)
        return CGSize(width: metrics.width, height: metrics.height)
    }

    /// The sprite's centre, so the waterline still sits on `spec.y`.
    static func floePosition(_ spec: IceSpec) -> CGPoint {
        let metrics = floeMetrics(spec.size)
        return CGPoint(
            x: CGFloat(spec.x),
            y: CGFloat(spec.y) + CGFloat(metrics.height) / 2
        )
    }

    private struct FloeMetrics {
        let width: Int
        let height: Int
    }

    private static func floeMetrics(_ size: Int) -> FloeMetrics {
        switch min(max(size, 0), 3) {
        case 0: return FloeMetrics(width: 8, height: 3)
        case 1: return FloeMetrics(width: 16, height: 5)
        case 2: return FloeMetrics(width: 28, height: 8)
        default: return FloeMetrics(width: 44, height: 11)
        }
    }

    private enum IceFace {
        case keel
        case rim
        case top
    }

    /// One scanline of a pancake, counted from the waterline up. `shift`
    /// nudges a row so the silhouette is stepped rather than a clean oval.
    private struct PancakeRow {
        var width: Int
        var shift: Int
        var face: IceFace
    }

    private static func pancakeRows(_ size: Int) -> [PancakeRow] {
        switch min(max(size, 0), 3) {
        case 0:
            return [
                PancakeRow(width: 5, shift: 0, face: .keel),
                PancakeRow(width: 7, shift: 0, face: .top),
            ]
        case 1:
            return [
                PancakeRow(width: 10, shift: 0, face: .keel),
                PancakeRow(width: 14, shift: 0, face: .rim),
                PancakeRow(width: 14, shift: 1, face: .top),
                PancakeRow(width: 10, shift: 0, face: .top),
            ]
        case 2:
            return [
                PancakeRow(width: 16, shift: 0, face: .keel),
                PancakeRow(width: 22, shift: 0, face: .keel),
                PancakeRow(width: 26, shift: 1, face: .rim),
                PancakeRow(width: 26, shift: 0, face: .top),
                PancakeRow(width: 24, shift: -1, face: .top),
                PancakeRow(width: 18, shift: 0, face: .top),
            ]
        default:
            return [
                PancakeRow(width: 22, shift: 1, face: .keel),
                PancakeRow(width: 32, shift: 0, face: .keel),
                PancakeRow(width: 38, shift: 2, face: .rim),
                PancakeRow(width: 42, shift: 0, face: .top),
                PancakeRow(width: 40, shift: -2, face: .top),
                PancakeRow(width: 36, shift: 1, face: .top),
                PancakeRow(width: 28, shift: -1, face: .top),
                PancakeRow(width: 18, shift: 2, face: .top),
            ]
        }
    }

    private static func buildFloe(size: Int, period: PlazaPeriod) -> SKTexture {
        let metrics = floeMetrics(size)
        var canvas = PixelCanvas(width: metrics.width, height: metrics.height, fill: Palette.clear)
        stampPancake(&canvas, rows: pancakeRows(size), tint: Floe.tint(for: period))
        return canvas.texture()
    }

    /// A flat oval: pale cyan lid, a medium-blue lip one pixel thick.
    private static func stampPancake(
        _ canvas: inout PixelCanvas,
        rows: [PancakeRow],
        tint: Floe.Tint
    ) {
        let cx = canvas.width / 2
        let glint = Palette.mix(tint.iceTop, Palette.rgba(0xFFFFFF, 255), 1, of: 2)
        for (index, row) in rows.enumerated() {
            let left = cx - row.width / 2 + row.shift
            let color: UInt32
            switch row.face {
            case .keel: color = tint.iceDeep
            case .rim: color = tint.iceShade
            case .top: color = tint.iceTop
            }
            canvas.fill(left, index, row.width, 1, color)
            if row.face == .top {
                canvas.set(left, index, glint)
            }
        }
    }

    /// Unused on the floe — there is no centre prop, only drifting ice — but
    /// the theme switch still asks every style for a frame.
    static func buildIcebergFrame(_ wobble: Int) -> SKTexture {
        var canvas = PixelCanvas(width: centerpieceWidth, height: centerpieceHeight, fill: Palette.clear)
        stampPancake(&canvas, rows: pancakeRows(2), tint: Floe.tint(for: .day))
        _ = wobble
        return canvas.texture()
    }
}
