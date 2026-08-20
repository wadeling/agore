import SpriteKit
import AgoreCore

enum Shore {
    static let sand = Palette.rgba(0xEFD9A6, 255)
    static let sandLight = Palette.rgba(0xF8EAC6, 255)
    static let sandDark = Palette.rgba(0xD7BC88, 255)
    static let wetSand = Palette.rgba(0xC8AC7C, 255)
    static let shell = Palette.rgba(0xF6E2E4, 255)
    static let starfish = Palette.rgba(0xE8896A, 255)
    static let frond = Palette.rgba(0x3E9455, 255)
    static let frondLight = Palette.rgba(0x64BE6C, 255)
    static let frondDark = Palette.rgba(0x276E3F, 255)
    static let trunk = Palette.rgba(0xA97C4A, 255)
    static let trunkDark = Palette.rgba(0x7B5731, 255)
    static let coconut = Palette.rgba(0x6E4A28, 255)
    static let towelWhite = Palette.rgba(0xFBF3E2, 255)
    static let parasolRed = Palette.rgba(0xE85A4F, 255)
    static let parasolCream = Palette.rgba(0xFBF3E2, 255)
    static let pole = Palette.rgba(0xC9A87A, 255)
    static let poleDark = Palette.rgba(0x9A7B4E, 255)
    static let bucket = Palette.rgba(0x3FA8D8, 255)
    static let gull = Palette.rgba(0xF7F5EC, 255)
    static let sun = Palette.rgba(0xFFF6CE, 255)

    static let towels: [UInt32] = [
        Palette.rgba(0xE85A4F, 255),
        Palette.rgba(0x2FA8B8, 255),
        Palette.rgba(0xF0B429, 255),
    ]

    /// The shore repaints itself for the hour the same way the agora does, so the sky,
    /// the water and the clouds all have to move together rather than one at a time.
    struct Tint {
        let sky: UInt32
        let skyLow: UInt32
        let sea: UInt32
        let seaDeep: UInt32
        let shallow: UInt32
        let foam: UInt32
        let wave: UInt32
        let cloud: UInt32
        let cloudShade: UInt32
        let land: UInt32
        let landDark: UInt32
    }

    static func tint(for period: PlazaPeriod) -> Tint {
        switch period {
        case .day:
            return Tint(
                sky: Palette.rgba(0x3FB8EA, 255),
                skyLow: Palette.rgba(0x8FDDF3, 255),
                sea: Palette.rgba(0x2E9AC4, 255),
                seaDeep: Palette.rgba(0x1B6E9E, 255),
                shallow: Palette.rgba(0x76D3DE, 255),
                foam: Palette.rgba(0xF6FCFC, 255),
                wave: Palette.rgba(0xA7E6EE, 255),
                cloud: Palette.rgba(0xFBF4E4, 255),
                cloudShade: Palette.rgba(0xCEE7F0, 255),
                land: Palette.rgba(0x5E9A62, 255),
                landDark: Palette.rgba(0x37704A, 255)
            )
        case .dusk:
            return Tint(
                sky: Palette.rgba(0x7A5A93, 255),
                skyLow: Palette.rgba(0xF2A263, 255),
                sea: Palette.rgba(0x35709A, 255),
                seaDeep: Palette.rgba(0x2A4C74, 255),
                shallow: Palette.rgba(0xB08A8A, 255),
                foam: Palette.rgba(0xF6DCC8, 255),
                wave: Palette.rgba(0xE7B58C, 255),
                cloud: Palette.rgba(0xF6C6A0, 255),
                cloudShade: Palette.rgba(0xB98A96, 255),
                land: Palette.rgba(0x6A6F5A, 255),
                landDark: Palette.rgba(0x43483C, 255)
            )
        case .night:
            return Tint(
                sky: Palette.rgba(0x111B31, 255),
                skyLow: Palette.rgba(0x27405F, 255),
                sea: Palette.rgba(0x143C5C, 255),
                seaDeep: Palette.rgba(0x0C2542, 255),
                shallow: Palette.rgba(0x2C6C84, 255),
                foam: Palette.rgba(0xBCD7DF, 255),
                wave: Palette.rgba(0x5A93A8, 255),
                cloud: Palette.rgba(0x33415E, 255),
                cloudShade: Palette.rgba(0x232E45, 255),
                land: Palette.rgba(0x22374A, 255),
                landDark: Palette.rgba(0x162432, 255)
            )
        }
    }
}

extension PixelArt {
    static func buildSeasideBackground(_ geometry: PlazaGeometry, period: PlazaPeriod) -> SKTexture {
        var canvas = PixelCanvas(width: geometry.worldWidth, height: geometry.worldHeight, fill: Shore.sand)
        let tint = Shore.tint(for: period)
        // Distance runs upward on both themes: the beach is nearest, then the water, then
        // the sky sits along the top edge where the agora keeps its colonnade.
        let skyLine = geometry.skyY
        drawShoreSky(&canvas, geometry: geometry, skyLine: skyLine, tint: tint, period: period)
        drawSea(&canvas, geometry: geometry, skyLine: skyLine, tint: tint)
        drawBeach(&canvas, geometry: geometry)
        drawSurf(&canvas, geometry: geometry, tint: tint)
        for tree in geometry.trees {
            drawPalm(&canvas, tree: tree)
        }
        drawTowels(&canvas, geometry: geometry)
        applyFloorWash(&canvas, geometry: geometry, period: period)
        return canvas.texture()
    }

    private static func drawShoreSky(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        skyLine: Int,
        tint: Shore.Tint,
        period: PlazaPeriod
    ) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        canvas.fill(0, skyLine, width, max(0, height - skyLine), tint.sky)
        canvas.fill(0, skyLine, width, min(geometry.isStrip ? 3 : 10, max(0, height - skyLine)), tint.skyLow)

        switch period {
        case .day, .dusk:
            let sunX = geometry.isStrip ? width - 60 : width - 38
            let sunY = geometry.isStrip ? height - 4 : height - 26
            if !geometry.isStrip {
                canvas.disk(sunX, sunY, 8, tint.skyLow)
            }
            canvas.disk(sunX, sunY, geometry.isStrip ? 2 : 6, Shore.sun)
        case .night:
            scatterStars(&canvas, geometry: geometry, above: skyLine + 4, color: Palette.star)
            // Starts in a gap the clouds leave empty. They drift now, so one may later
            // slide across the moon — which is what a sky does.
            let moonX = geometry.isStrip ? 30 : 100
            let moonY = height - (geometry.isStrip ? 5 : 22)
            canvas.disk(moonX, moonY, geometry.isStrip ? 2 : 5, Palette.moon)
            canvas.disk(moonX + 2, moonY + 2, geometry.isStrip ? 1 : 3, tint.sky)
        }
    }

    static func cloud(_ spec: CloudSpec, period: PlazaPeriod) -> SKTexture {
        let lump = max(2, spec.size)
        return cached(.cloud(size: lump, shape: spec.shape, period: period)) {
            buildCloud(size: lump, shape: spec.shape, tint: Shore.tint(for: period))
        }
    }

    /// The sprite's centre in world pixels, so the flat base still sits on `spec.y`.
    static func cloudPosition(_ spec: CloudSpec) -> CGPoint {
        let metrics = cloudMetrics(spec.size, shape: spec.shape)
        return CGPoint(
            x: CGFloat(spec.x),
            y: CGFloat(spec.y) + CGFloat(metrics.height) / 2 - CGFloat(metrics.originY)
        )
    }

    static func cloudSpriteSize(_ spec: CloudSpec) -> CGSize {
        let metrics = cloudMetrics(spec.size, shape: spec.shape)
        return CGSize(width: metrics.width, height: metrics.height)
    }

    private struct CloudMetrics {
        let width: Int
        let height: Int
        let originX: Int
        let originY: Int
    }

    private struct CloudLump {
        var dx: Int
        var dy: Int
        var r: Int
    }

    /// Five silhouettes, scaled by `size`. Small weather uses puff, wispy and twin;
    /// the courtyard banks and anvils are the two large ones.
    private static func lumps(size: Int, shape: CloudShape) -> [CloudLump] {
        let r = max(2, size)
        switch shape {
        case .puff:
            return [
                CloudLump(dx: 0, dy: r / 2, r: r),
                CloudLump(dx: -r, dy: r / 3, r: max(1, (r * 2) / 3)),
                CloudLump(dx: r + 1, dy: r / 4, r: max(1, (r * 3) / 4)),
            ]
        case .wispy:
            let a = max(2, r / 2)
            let b = max(2, (r * 2) / 3)
            return [
                CloudLump(dx: -r - 1, dy: a / 2, r: a),
                CloudLump(dx: 0, dy: b / 2, r: b),
                CloudLump(dx: r + 1, dy: a / 2, r: a),
                CloudLump(dx: r + a + 1, dy: max(1, a / 2), r: max(1, a - 1)),
            ]
        case .twin:
            return [
                CloudLump(dx: -r, dy: r / 2, r: r),
                CloudLump(dx: r + 1, dy: max(1, r / 3), r: max(2, r - 1)),
            ]
        case .bank:
            return [
                CloudLump(dx: -r - r / 2, dy: r / 3, r: max(2, (r * 2) / 3)),
                CloudLump(dx: -r / 3, dy: r / 2, r: r),
                CloudLump(dx: r / 2, dy: (r * 2) / 3, r: r),
                CloudLump(dx: r + r / 2, dy: r / 4, r: max(2, (r * 3) / 5)),
            ]
        case .anvil:
            return [
                CloudLump(dx: 0, dy: r / 2, r: r),
                CloudLump(dx: -r, dy: r / 4, r: max(2, r / 2)),
                CloudLump(dx: r, dy: r / 3, r: max(2, (r * 3) / 4)),
                CloudLump(dx: r + r / 2 + 1, dy: r / 5, r: max(2, r / 2)),
            ]
        }
    }

    private static func cloudMetrics(_ size: Int, shape: CloudShape) -> CloudMetrics {
        let lumps = lumps(size: size, shape: shape)
        var minX = 0
        var maxX = 0
        var minY = 0
        var maxY = 0
        for lump in lumps {
            minX = min(minX, lump.dx - lump.r)
            maxX = max(maxX, lump.dx + lump.r)
            minY = min(minY, lump.dy - lump.r)
            maxY = max(maxY, lump.dy + lump.r)
        }
        minY = min(minY, 0)
        let pad = 1
        return CloudMetrics(
            width: maxX - minX + 1 + pad * 2,
            height: maxY - minY + 1 + pad * 2,
            originX: -minX + pad,
            originY: -minY + pad
        )
    }

    private static func buildCloud(size: Int, shape: CloudShape, tint: Shore.Tint) -> SKTexture {
        let metrics = cloudMetrics(size, shape: shape)
        var canvas = PixelCanvas(width: metrics.width, height: metrics.height, fill: Palette.clear)
        drawCloud(
            &canvas,
            cx: metrics.originX,
            cy: metrics.originY,
            size: size,
            shape: shape,
            tint: tint
        )
        return canvas.texture()
    }

    private static func drawCloud(
        _ canvas: inout PixelCanvas,
        cx: Int,
        cy: Int,
        size: Int,
        shape: CloudShape,
        tint: Shore.Tint
    ) {
        let r = max(2, size)
        let lumps = lumps(size: size, shape: shape)
        var left = cx
        var right = cx
        for lump in lumps {
            canvas.disk(cx + lump.dx, cy + lump.dy, lump.r, tint.cloud)
            left = min(left, cx + lump.dx - lump.r)
            right = max(right, cx + lump.dx + lump.r + 1)
        }
        let baseH: Int
        switch shape {
        case .wispy: baseH = max(1, r / 3)
        case .twin: baseH = max(2, r / 3)
        default: baseH = max(2, r / 2)
        }
        canvas.fill(left, cy, max(1, right - left), baseH, tint.cloud)
        canvas.fill(left, cy, max(1, right - left), 1, tint.cloudShade)
    }

    private static func drawSea(
        _ canvas: inout PixelCanvas,
        geometry: PlazaGeometry,
        skyLine: Int,
        tint: Shore.Tint
    ) {
        let width = geometry.worldWidth
        let waterline = geometry.horizonY
        let depth = skyLine - waterline
        guard depth > 0 else { return }

        // Headlands go down before the water does, so the sea buries their feet and only
        // the hilltops stand above the far edge — a bay rather than a blue stripe running
        // out of the frame.
        if !geometry.isStrip {
            drawHeadland(&canvas, cx: 16, base: skyLine, radius: 14, tint: tint)
            drawHeadland(&canvas, cx: 44, base: skyLine, radius: 9, tint: tint)
            drawHeadland(&canvas, cx: width - 14, base: skyLine, radius: 11, tint: tint)
        }

        canvas.fill(0, waterline, width, depth, tint.sea)
        let deep = waterline + depth / 2
        canvas.fill(0, deep, width, skyLine - deep, tint.seaDeep)
        dither(&canvas, y: deep, width: width, color: tint.sea)
        let shelf = max(1, depth / 5)
        canvas.fill(0, waterline, width, shelf, tint.shallow)
        dither(&canvas, y: waterline + shelf, width: width, color: tint.shallow)

        // Scattered rather than striped: a regular grid of dashes reads as a pattern, not
        // as water.
        var seed = width &* 2654435761 &+ waterline
        for _ in 0..<max(8, width * depth / 190) {
            seed = seed &* 1103515245 &+ 12345
            let bits = seed & Int.max
            let x = bits % width
            let y = waterline + 2 + (bits / 17) % max(1, depth - 3)
            canvas.fill(x, y, 3 + (bits / 7) % 3, 1, tint.wave)
        }
        canvas.fill(0, skyLine - 1, width, 1, tint.wave)
    }

    private static func drawHeadland(
        _ canvas: inout PixelCanvas,
        cx: Int,
        base: Int,
        radius: Int,
        tint: Shore.Tint
    ) {
        canvas.disk(cx, base - radius / 2, radius, tint.landDark)
        canvas.disk(cx - radius / 3, base - radius / 3, radius * 2 / 3, tint.land)
    }

    /// Every other pixel of the band above, which softens a seam that would otherwise cut
    /// a hard line straight across the water.
    private static func dither(_ canvas: inout PixelCanvas, y: Int, width: Int, color: UInt32) {
        for x in stride(from: 0, to: width, by: 2) {
            canvas.set(x, y, color)
        }
    }

    private static func drawBeach(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let width = geometry.worldWidth
        let waterline = geometry.horizonY
        canvas.fill(0, 0, width, waterline, Shore.sand)
        canvas.fill(0, 0, width, max(3, geometry.groundY), Shore.sandLight)
        dither(&canvas, y: max(3, geometry.groundY), width: width, color: Shore.sandLight)
        let damp = max(3, waterline / 9)
        canvas.fill(0, waterline - damp, width, damp, Shore.wetSand)
        dither(&canvas, y: waterline - damp, width: width, color: Shore.sand)

        var seed = width &* 7919 &+ waterline
        for _ in 0..<max(24, width * waterline / 110) {
            seed = seed &* 1103515245 &+ 12345
            let bits = seed & Int.max
            canvas.set(bits % width, (bits / 13) % waterline, (bits & 1) == 0 ? Shore.sandDark : Shore.sandLight)
        }

        guard !geometry.isStrip else { return }
        drawShell(&canvas, x: 52, y: 22)
        drawShell(&canvas, x: 188, y: 30)
        drawShell(&canvas, x: 120, y: 16)
        drawStarfish(&canvas, x: 150, y: 76)
        drawStarfish(&canvas, x: 62, y: 104)
    }

    private static func drawShell(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        canvas.fill(x, y, 3, 2, Shore.shell)
        canvas.set(x + 1, y + 2, Shore.shell)
        canvas.set(x, y, Shore.sandDark)
        canvas.set(x + 2, y, Shore.sandDark)
    }

    private static func drawStarfish(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        canvas.fill(x - 1, y, 3, 1, Shore.starfish)
        canvas.fill(x, y - 1, 1, 3, Shore.starfish)
        canvas.set(x - 2, y - 1, Shore.starfish)
        canvas.set(x + 2, y - 1, Shore.starfish)
        canvas.set(x, y + 2, Shore.starfish)
    }

    private static func drawSurf(_ canvas: inout PixelCanvas, geometry: PlazaGeometry, tint: Shore.Tint) {
        let width = geometry.worldWidth
        let waterline = geometry.horizonY
        for x in 0..<width {
            let wobble = (x / 6 + (x / 17) * 2) % 3
            canvas.fill(x, waterline - 1 - wobble, 1, 2 + wobble, tint.foam)
        }
        // A broken second line inland reads as the last reach of a spent wave.
        for x in 0..<width where (x / 4 + x / 9) % 3 == 0 {
            canvas.set(x, waterline - 5 - ((x / 11) % 2), tint.foam)
        }
    }

    private static func drawPalm(_ canvas: inout PixelCanvas, tree: TreeSpec) {
        let size = min(max(tree.size, 0), 2)
        let trunkH = [6, 9, 12][size]
        let span = [4, 6, 8][size]
        var topX = tree.x
        for i in 0..<trunkH {
            topX = tree.x + i / 5
            canvas.fill(topX, tree.y + i, 2, 1, Shore.trunk)
            canvas.set(topX, tree.y + i, Shore.trunkDark)
            if i % 3 == 0 {
                canvas.set(topX + 1, tree.y + i, Shore.trunkDark)
            }
        }
        let topY = tree.y + trunkH
        for direction in [-1, 1] {
            drawFrond(&canvas, x: topX, y: topY + 1, dx: direction, span: span, lift: 3)
            drawFrond(&canvas, x: topX, y: topY, dx: direction, span: span, lift: 1)
            drawFrond(&canvas, x: topX, y: topY - 1, dx: direction, span: max(2, span - 3), lift: 0)
        }
        canvas.fill(topX - 1, topY, 3, 3, Shore.frond)
        canvas.set(topX, topY + 3, Shore.frondLight)
        if size >= 1 {
            canvas.set(topX - 2, topY - 1, Shore.coconut)
            canvas.set(topX + 2, topY - 2, Shore.coconut)
        }
    }

    /// A frond climbs for a pixel or two, then droops — which is the whole silhouette of
    /// a palm at this size.
    private static func drawFrond(
        _ canvas: inout PixelCanvas,
        x: Int,
        y: Int,
        dx: Int,
        span: Int,
        lift: Int
    ) {
        var px = x
        var py = y
        for step in 0..<max(1, span) {
            px += dx
            py += step < lift ? 1 : (step > span / 2 ? -1 : 0)
            canvas.fill(px, py, 1, 2, step % 2 == 0 ? Shore.frond : Shore.frondDark)
            if step == span - 1 {
                canvas.set(px, py, Shore.frondLight)
            }
        }
    }

    private static func drawTowels(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let spots = geometry.restSpots
        let drawn = geometry.isStrip ? Array(spots.prefix(6)) : spots
        for (index, spot) in drawn.enumerated() {
            let x = Int(spot.x.rounded())
            let y = geometry.furnitureY(for: spot)
            drawTowel(&canvas, x: x, y: y, stripe: Shore.towels[index % Shore.towels.count])
        }
    }

    private static func drawTowel(_ canvas: inout PixelCanvas, x: Int, y: Int, stripe: UInt32) {
        let w = 16
        let left = x - w / 2
        canvas.fill(left, y, w, 5, Shore.towelWhite)
        for i in stride(from: 0, to: w, by: 4) {
            canvas.fill(left + i, y, 2, 5, stripe)
        }
        canvas.fill(left, y, w, 1, Shore.sandDark)
    }

    static func buildParasolFrame(_ wobble: Int) -> SKTexture {
        var canvas = PixelCanvas(width: centerpieceWidth, height: centerpieceHeight, fill: Palette.clear)
        canvas.fill(3, 0, 20, 3, Shore.towelWhite)
        for i in stride(from: 3, to: 23, by: 4) {
            canvas.fill(i, 0, 2, 3, Shore.parasolRed)
        }
        canvas.fill(3, 0, 20, 1, Shore.sandDark)
        canvas.fill(24, 0, 3, 4, Shore.bucket)
        canvas.fill(24, 3, 3, 1, Shore.towelWhite)

        canvas.fill(13, 2, 2, 9, Shore.pole)
        canvas.fill(13, 2, 1, 9, Shore.poleDark)

        for row in 0..<7 {
            let y = 11 + row
            let half = max(2, 13 - row * 2)
            for x in (14 - half)..<(14 + half) {
                canvas.set(x, y, (x / 4) % 2 == 0 ? Shore.parasolRed : Shore.parasolCream)
            }
        }
        for x in stride(from: 2 + wobble, to: 26, by: 3) {
            canvas.set(x, 10, (x / 4) % 2 == 0 ? Shore.parasolRed : Shore.parasolCream)
        }
        return canvas.texture()
    }
}
