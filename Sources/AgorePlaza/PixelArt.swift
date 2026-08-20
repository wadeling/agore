import AppKit
import SpriteKit
import AgoreCore

enum Palette {
    static let sky = rgba(0x4A7C9B, 255)
    static let skyLight = rgba(0x6A9BB8, 255)
    static let duskSky = rgba(0x3A3560, 255)
    static let duskHorizon = rgba(0xD4896A, 255)
    static let nightSky = rgba(0x1A2438, 255)
    static let nightHorizon = rgba(0x2C3A52, 255)
    static let stone = rgba(0xD4C4A8, 255)
    static let stoneDark = rgba(0xB8A888, 255)
    static let stoneLight = rgba(0xE8DCC8, 255)
    static let grout = rgba(0xC6B69A, 255)
    static let slabTint = rgba(0xDDD0B8, 255)
    static let column = rgba(0xF5F0E6, 255)
    static let columnShadow = rgba(0xC9B89A, 255)
    static let stoaShade = rgba(0x9A886C, 255)
    static let olive = rgba(0x6B8F71, 255)
    static let oliveDark = rgba(0x4F6F55, 255)
    static let oliveLight = rgba(0x8AAB7A, 255)
    static let oliveFruit = rgba(0x3D4A28, 255)
    static let trunk = rgba(0x5A3A22, 255)
    static let roof = rgba(0x8B5A3C, 255)
    static let roofDark = rgba(0x6E4028, 255)
    static let roofLight = rgba(0xA86C48, 255)
    static let mosaic = rgba(0xC9A66B, 255)
    static let mosaicDark = rgba(0x6B4A32, 255)
    static let hill = rgba(0x3D5A4A, 255)
    static let hillDark = rgba(0x2A4038, 255)
    static let lantern = rgba(0xF0D070, 255)
    static let star = rgba(0xF5F0E6, 255)
    static let moon = rgba(0xE8E0C8, 255)
    static let water = rgba(0x3D7A8C, 255)
    static let waterLight = rgba(0x6BB3C4, 255)
    static let basin = rgba(0xC4B8A0, 255)
    static let ink = rgba(0x3D3428, 255)
    static let bubble = rgba(0xFFF8E7, 255)
    static let clear = rgba(0x000000, 0)

    static func rgba(_ rgb: UInt32, _ alpha: UInt8) -> UInt32 {
        let r = (rgb >> 16) & 0xFF
        let g = (rgb >> 8) & 0xFF
        let b = rgb & 0xFF
        return (UInt32(alpha) << 24) | (b << 16) | (g << 8) | r
    }

    static func tunic(_ hash: Int) -> UInt32 {
        let colors: [UInt32] = [
            rgba(0xC45C26, 255),
            rgba(0x2E6B8A, 255),
            rgba(0x6B3FA0, 255),
            rgba(0xB43B3B, 255),
            rgba(0x2F7D4A, 255),
            rgba(0xC9A227, 255),
        ]
        return colors[abs(hash) % colors.count]
    }

    static func hair(_ hash: Int) -> UInt32 {
        let colors: [UInt32] = [
            rgba(0x2B2118, 255),
            rgba(0x6A3E1A, 255),
            rgba(0xD8C07A, 255),
            rgba(0x1A1A1A, 255),
            rgba(0x8A4B28, 255),
        ]
        return colors[abs(hash / 7) % colors.count]
    }

    static func skin(_ hash: Int) -> UInt32 {
        let colors: [UInt32] = [
            rgba(0xF1D0B0, 255),
            rgba(0xD4A574, 255),
            rgba(0x8D5524, 255),
            rgba(0xE8C39E, 255),
        ]
        return colors[abs(hash / 13) % colors.count]
    }
}

struct PixelCanvas {
    let width: Int
    let height: Int
    var pixels: [UInt32]

    init(width: Int, height: Int, fill: UInt32 = Palette.clear) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    mutating func set(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        pixels[y * width + x] = color
    }

    mutating func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UInt32) {
        for py in y..<(y + h) {
            for px in x..<(x + w) {
                set(px, py, color)
            }
        }
    }

    mutating func disk(_ cx: Int, _ cy: Int, _ r: Int, _ color: UInt32) {
        guard r >= 0 else { return }
        let r2 = r * r
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let dx = x - cx
                let dy = y - cy
                if dx * dx + dy * dy <= r2 {
                    set(x, y, color)
                }
            }
        }
    }

    mutating func circle(_ cx: Int, _ cy: Int, _ r: Int, _ color: UInt32) {
        guard r > 0 else { return }
        let r2 = r * r
        let inner = (r - 1) * (r - 1)
        for y in (cy - r)...(cy + r) {
            for x in (cx - r)...(cx + r) {
                let d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if d <= r2 && d >= inner {
                    set(x, y, color)
                }
            }
        }
    }

    mutating func ellipse(_ cx: Int, _ cy: Int, _ rx: Int, _ ry: Int, _ color: UInt32) {
        guard rx > 0, ry > 0 else { return }
        let rx2 = rx * rx
        let ry2 = ry * ry
        for y in (cy - ry)...(cy + ry) {
            for x in (cx - rx)...(cx + rx) {
                let nx = x - cx
                let ny = y - cy
                if nx * nx * ry2 + ny * ny * rx2 <= rx2 * ry2 {
                    set(x, y, color)
                }
            }
        }
    }

    /// Tint a horizontal band without touching fully transparent pixels.
    mutating func multiply(_ color: UInt32, yRange: Range<Int>) {
        let mr = Int(color & 0xFF)
        let mg = Int((color >> 8) & 0xFF)
        let mb = Int((color >> 16) & 0xFF)
        let lo = max(0, yRange.lowerBound)
        let hi = min(height, yRange.upperBound)
        guard lo < hi else { return }
        for y in lo..<hi {
            for x in 0..<width {
                let i = y * width + x
                let p = pixels[i]
                let a = p >> 24
                guard a > 0 else { continue }
                let r = Int(p & 0xFF) * mr / 255
                let g = Int((p >> 8) & 0xFF) * mg / 255
                let b = Int((p >> 16) & 0xFF) * mb / 255
                pixels[i] = (a << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | UInt32(r)
            }
        }
    }

    /// Trace a one-pixel border around everything already drawn. Sprites with a lot of
    /// curves — a cat far more than a person — read as a shape rather than a smudge with
    /// this on, and outlining afterwards is far less fiddly than placing the edge by hand.
    mutating func outline(_ color: UInt32) {
        var edges: [Int] = []
        for y in 0..<height {
            for x in 0..<width {
                guard pixels[y * width + x] >> 24 == 0 else { continue }
                var touches = false
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    if pixels[ny * width + nx] >> 24 > 0 {
                        touches = true
                        break
                    }
                }
                if touches {
                    edges.append(y * width + x)
                }
            }
        }
        for index in edges {
            pixels[index] = color
        }
    }

    func texture() -> SKTexture {
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        let texture = SKTexture(data: data, size: CGSize(width: width, height: height))
        texture.filteringMode = .nearest
        return texture
    }
}

enum PixelArt {
    static let characterWidth = 16
    static let characterHeight = 20
    static let characterFrames = 6
    static let centerpieceWidth = 28
    static let centerpieceHeight = 18
    static let centerpieceFrames = 3

    /// Every sprite is a pure function of a handful of inputs, so the whole plaza needs
    /// only a few dozen textures. Building them per frame instead would hand SpriteKit a
    /// new GPU allocation several times a second per actor, which never comes back.
    private static var cache: [TextureKey: SKTexture] = [:]

    enum TextureKey: Hashable {
        case background(PlazaGeometry, PlazaPeriod)
        case centerpiece(theme: PlazaTheme, phase: Int)
        case sleeper(skin: UInt32, hair: UInt32, tunic: UInt32, phase: Int)
        case sleepZ
        case bubble
        case bird(theme: PlazaTheme, phase: Int)
        case leaf(theme: PlazaTheme)
        case cat(variant: Int, pose: CatPose, phase: Int, small: Bool)
        case catSleeper(variant: Int, phase: Int)
        case character(skin: UInt32, hair: UInt32, tunic: UInt32, kind: ActivityKind, phase: Int, small: Bool)
    }

    static func cached(_ key: TextureKey, _ build: () -> SKTexture) -> SKTexture {
        if let texture = cache[key] { return texture }
        let texture = build()
        cache[key] = texture
        return texture
    }

    static func plazaBackground(_ geometry: PlazaGeometry, period: PlazaPeriod = .current()) -> SKTexture {
        cached(.background(geometry, period)) {
            switch geometry.theme {
            case .agora: return buildAgoraBackground(geometry, period: period)
            case .seaside: return buildSeasideBackground(geometry, period: period)
            }
        }
    }

    private static func buildAgoraBackground(_ geometry: PlazaGeometry, period: PlazaPeriod) -> SKTexture {
        var canvas = PixelCanvas(width: geometry.worldWidth, height: geometry.worldHeight, fill: Palette.stone)
        drawSky(&canvas, geometry: geometry, period: period)
        drawHills(&canvas, geometry: geometry)
        drawPaving(&canvas, geometry: geometry)
        drawFountainMosaic(&canvas, geometry: geometry)
        for tree in geometry.trees {
            drawOliveTree(&canvas, tree: tree)
        }
        drawBenches(&canvas, geometry: geometry)
        applyFloorWash(&canvas, geometry: geometry, period: period)
        drawStoa(&canvas, geometry: geometry, period: period)
        return canvas.texture()
    }

    static func applyFloorWash(_ canvas: inout PixelCanvas, geometry: PlazaGeometry, period: PlazaPeriod) {
        switch period {
        case .day:
            return
        case .dusk:
            canvas.multiply(Palette.rgba(0xE8C8B0, 255), yRange: 0..<geometry.horizonY)
        case .night:
            canvas.multiply(Palette.rgba(0x8898B8, 255), yRange: 0..<geometry.horizonY)
        }
    }

    private static func drawSky(_ canvas: inout PixelCanvas, geometry: PlazaGeometry, period: PlazaPeriod) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        let horizon = geometry.horizonY
        let sky: UInt32
        let glow: UInt32
        switch period {
        case .day:
            sky = Palette.sky
            glow = Palette.skyLight
        case .dusk:
            sky = Palette.duskSky
            glow = Palette.duskHorizon
        case .night:
            sky = Palette.nightSky
            glow = Palette.nightHorizon
        }
        canvas.fill(0, horizon, width, max(0, height - horizon), sky)
        let band = min(period == .day ? 3 : 6, max(0, height - horizon))
        canvas.fill(0, horizon, width, band, glow)
        if period == .dusk, !geometry.isStrip {
            canvas.disk(width / 4, horizon + 1, 3, Palette.lantern)
            canvas.disk(width / 4, horizon + 1, 1, Palette.stoneLight)
        }
        if period == .night {
            scatterStars(&canvas, geometry: geometry, above: horizon + band, color: Palette.star)
            let moonX = geometry.isStrip ? 28 : width - 22
            let moonY = min(height - 5, horizon + max(4, (height - horizon) / 2))
            canvas.disk(moonX, moonY, geometry.isStrip ? 2 : 4, Palette.moon)
            canvas.disk(moonX + 1, moonY + 1, geometry.isStrip ? 1 : 2, Palette.nightSky)
        }
    }

    /// Deterministic so a repainted background keeps the same night sky.
    static func scatterStars(_ canvas: inout PixelCanvas, geometry: PlazaGeometry, above: Int, color: UInt32) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        var seed = width &* 1103515245 &+ height
        let starCount = geometry.isStrip ? 7 : 18
        for _ in 0..<starCount {
            seed = seed &* 1103515245 &+ 12345
            let bits = seed & Int.max
            let sx = bits % width
            let room = max(1, height - above)
            canvas.set(sx, above + (bits / 11) % room, color)
        }
    }

    private static func drawHills(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        guard !geometry.isStrip else { return }
        let horizon = geometry.horizonY
        canvas.disk(36, horizon + 2, 26, Palette.hillDark)
        canvas.disk(88, horizon, 20, Palette.hill)
        canvas.disk(158, horizon + 4, 28, Palette.hillDark)
        canvas.disk(210, horizon + 1, 18, Palette.hill)
    }

    private static func drawPaving(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let width = geometry.worldWidth
        let horizon = geometry.horizonY
        var xs = [0]
        var x = 0
        var col = 0
        while x < width {
            x += 10 + (col % 3) * 2
            xs.append(min(x, width))
            col += 1
        }
        var ys = [0]
        var y = 0
        var row = 0
        while y < horizon {
            y += 5 + (row % 2) * 2
            ys.append(min(y, horizon))
            row += 1
        }
        for r in 0..<(ys.count - 1) {
            for c in 0..<(xs.count - 1) {
                let tint = ((r + c * 3) % 7 == 0) ? Palette.slabTint : Palette.stone
                canvas.fill(xs[c], ys[r], xs[c + 1] - xs[c], ys[r + 1] - ys[r], tint)
            }
        }
        for gx in xs {
            canvas.fill(gx, 0, 1, horizon, Palette.grout)
        }
        for gy in ys {
            canvas.fill(0, gy, width, 1, Palette.grout)
        }
        canvas.fill(0, 0, width, 2, Palette.stoneDark)
        canvas.fill(8, geometry.groundY - 2, width - 16, 3, Palette.slabTint)
    }

    private static func drawFountainMosaic(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let cx = Int(geometry.centerpieceCenter.x)
        let cy = Int(geometry.centerpieceCenter.y)
        if geometry.isStrip {
            canvas.ellipse(cx, cy, 36, 9, Palette.mosaic)
            canvas.ellipse(cx, cy, 32, 7, Palette.stoneLight)
            canvas.ellipse(cx, cy, 26, 5, Palette.mosaicDark)
            canvas.ellipse(cx, cy, 20, 3, Palette.stone)
            drawMeander(&canvas, x: cx - 34, y: max(0, cy - 10), width: 68, color: Palette.mosaicDark)
        } else {
            canvas.disk(cx, cy, 44, Palette.mosaic)
            canvas.disk(cx, cy, 40, Palette.stoneLight)
            canvas.circle(cx, cy, 38, Palette.mosaicDark)
            canvas.circle(cx, cy, 34, Palette.mosaic)
            canvas.disk(cx, cy, 28, Palette.stone)
            drawMeander(&canvas, x: cx - 42, y: cy - 42, width: 84, color: Palette.mosaicDark)
            drawMeander(&canvas, x: cx - 42, y: cy + 40, width: 84, color: Palette.mosaicDark)
            canvas.fill(cx - 42, cy - 42, 2, 84, Palette.mosaicDark)
            canvas.fill(cx + 40, cy - 42, 2, 84, Palette.mosaicDark)
        }
    }

    private static func drawMeander(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, color: UInt32) {
        var px = x
        while px + 8 <= x + width {
            canvas.fill(px, y + 2, 5, 1, color)
            canvas.set(px + 7, y + 2, color)
            canvas.set(px, y + 1, color)
            canvas.set(px + 4, y + 1, color)
            canvas.set(px + 7, y + 1, color)
            canvas.set(px, y, color)
            canvas.fill(px + 3, y, 5, 1, color)
            px += 8
        }
    }

    private static func drawStoa(_ canvas: inout PixelCanvas, geometry: PlazaGeometry, period: PlazaPeriod) {
        let width = geometry.worldWidth
        let height = geometry.worldHeight
        let horizon = geometry.horizonY
        let lanterns = period == .night
        let centerX = Int(geometry.centerpieceCenter.x)
        if geometry.isStrip {
            canvas.fill(0, horizon, width, max(0, height - horizon - 4), Palette.stoaShade)
            let colTop = height - 5
            for x in stride(from: 14, to: width - 14, by: 28) {
                if abs((x + 4) - centerX) < 22 { continue }
                drawColumn(&canvas, x: x, baseY: horizon - 8, topY: colTop, lantern: lanterns && (x / 28) % 2 == 0)
            }
            canvas.fill(0, height - 6, width, 1, Palette.columnShadow)
            canvas.fill(0, height - 5, width, 2, Palette.column)
            for x in stride(from: 1, to: width, by: 3) {
                canvas.fill(x, height - 6, 2, 1, Palette.column)
            }
            drawRoof(&canvas, x: 0, y: height - 3, width: width, height: 3)
            drawPediment(&canvas, centerX: width / 2, apexY: height - 1, rise: 5, halfWidth: 26)
            drawGate(&canvas, x: 1, baseY: 10, topY: height - 3)
            drawGate(&canvas, x: width - 11, baseY: 10, topY: height - 3)
        } else {
            canvas.fill(0, horizon - 4, width, max(0, height - horizon - 10), Palette.stoaShade)
            let colTop = height - 18
            for x in stride(from: 12, to: width - 12, by: 24) {
                drawColumn(
                    &canvas,
                    x: x,
                    baseY: horizon - 10,
                    topY: colTop,
                    lantern: lanterns && (x / 24) % 2 == 0
                )
            }
            canvas.fill(0, height - 19, width, 1, Palette.columnShadow)
            canvas.fill(0, height - 18, width, 3, Palette.column)
            drawRoof(&canvas, x: 0, y: height - 16, width: width, height: 6)
            drawPediment(&canvas, centerX: width / 2, apexY: height - 2, rise: 14, halfWidth: 48)
            for y in stride(from: 48, to: horizon - 16, by: 40) {
                drawColumn(&canvas, x: 8, baseY: y, topY: min(y + 40, horizon + 4), lantern: lanterns && y % 80 == 48)
                drawColumn(&canvas, x: width - 16, baseY: y, topY: min(y + 40, horizon + 4), lantern: false)
            }
            drawGate(&canvas, x: 16, baseY: 22, topY: 62)
            drawGate(&canvas, x: width - 26, baseY: 22, topY: 62)
        }
    }

    private static func drawRoof(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        for px in stride(from: x, to: x + width, by: 4) {
            canvas.fill(px, y, 4, height, Palette.roof)
            canvas.fill(px, y, 1, max(1, height - 1), Palette.roofLight)
            canvas.fill(px + 3, y, 1, height, Palette.roofDark)
        }
    }

    private static func drawPediment(
        _ canvas: inout PixelCanvas,
        centerX: Int,
        apexY: Int,
        rise: Int,
        halfWidth: Int
    ) {
        for i in 0..<rise {
            let y = apexY - rise + 1 + i
            let w = max(4, (i + 1) * (halfWidth * 2) / rise)
            canvas.fill(centerX - w / 2, y, w, 1, Palette.roof)
            canvas.set(centerX - w / 2, y, Palette.roofLight)
            canvas.set(centerX + w / 2 - 1, y, Palette.roofDark)
        }
        for i in 2..<(rise - 1) {
            let y = apexY - rise + 1 + i
            let w = max(2, (i - 1) * (halfWidth * 2) / rise - 4)
            canvas.fill(centerX - w / 2, y, w, 1, Palette.column)
        }
        canvas.fill(centerX - 1, apexY - rise + 3, 3, 2, Palette.mosaic)
    }

    private static func drawGate(_ canvas: inout PixelCanvas, x: Int, baseY: Int, topY: Int) {
        let shaft = max(4, topY - baseY - 5)
        canvas.fill(x, baseY, 10, 3, Palette.stoneDark)
        canvas.fill(x + 1, baseY + 3, 8, shaft, Palette.column)
        canvas.fill(x + 1, baseY + 3, 2, shaft, Palette.columnShadow)
        canvas.fill(x + 7, baseY + 3, 1, shaft, Palette.stoneLight)
        canvas.fill(x, baseY + 3 + shaft, 10, 2, Palette.column)
        canvas.fill(x, baseY + 5 + shaft, 10, 2, Palette.roof)
    }

    private static func drawOliveTree(_ canvas: inout PixelCanvas, tree: TreeSpec) {
        let size = min(max(tree.size, 0), 2)
        let canopyR = [3, 5, 7][size]
        let trunkH = [3, 5, 7][size]
        let trunkW = size == 0 ? 1 : 2
        let cx = tree.x
        canvas.fill(cx - trunkW / 2, tree.y, trunkW, trunkH + 2, Palette.trunk)
        let canopyY = tree.y + trunkH + canopyR - 1
        canvas.disk(cx, canopyY, canopyR, Palette.olive)
        canvas.disk(cx - max(1, canopyR / 3), canopyY + 1, max(2, canopyR - 2), Palette.oliveDark)
        canvas.disk(cx + max(1, canopyR / 3), canopyY - 1, max(2, canopyR / 2), Palette.oliveLight)
        if size >= 1 {
            canvas.set(cx - 2, canopyY - 1, Palette.oliveFruit)
            canvas.set(cx + 1, canopyY + 1, Palette.oliveFruit)
            canvas.set(cx, canopyY + 2, Palette.oliveFruit)
        }
    }

    /// Where falling foliage should start, so leaves let go of the canopy and not the trunk.
    static func foliageTop(_ tree: TreeSpec, theme: PlazaTheme) -> CGPoint {
        let size = min(max(tree.size, 0), 2)
        switch theme {
        case .agora:
            return CGPoint(x: CGFloat(tree.x), y: CGFloat(tree.y + [3, 5, 7][size] * 2 + 3))
        case .seaside:
            return CGPoint(x: CGFloat(tree.x), y: CGFloat(tree.y + [6, 9, 12][size] + 1))
        }
    }

    private static func drawBenches(_ canvas: inout PixelCanvas, geometry: PlazaGeometry) {
        let spots = geometry.restSpots
        let drawn = geometry.isStrip ? spots.prefix(6) : spots.prefix(spots.count)
        for spot in drawn {
            let x = Int(spot.x.rounded())
            drawBench(&canvas, x: x, y: geometry.furnitureY(for: spot))
        }
    }

    private static func drawBench(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        let w = 16
        let left = x - w / 2
        canvas.fill(left, y, 2, 3, Palette.stoneDark)
        canvas.fill(left + w - 2, y, 2, 3, Palette.stoneDark)
        canvas.fill(left, y + 2, w, 2, Palette.stoneLight)
        canvas.fill(left + 1, y + 3, w - 2, 1, Palette.column)
    }

    /// The one animated prop at the middle of the plaza.
    static func centerpieceFrame(theme: PlazaTheme, frame: Int) -> SKTexture {
        let wobble = phase(frame, over: centerpieceFrames)
        return cached(.centerpiece(theme: theme, phase: wobble)) {
            switch theme {
            case .agora: return buildFountainFrame(wobble)
            case .seaside: return buildParasolFrame(wobble)
            }
        }
    }

    private static func buildFountainFrame(_ wobble: Int) -> SKTexture {
        var canvas = PixelCanvas(width: centerpieceWidth, height: centerpieceHeight, fill: Palette.clear)
        canvas.fill(0, 0, centerpieceWidth, 3, Palette.basin)
        canvas.fill(0, 2, centerpieceWidth, 1, Palette.columnShadow)
        canvas.fill(2, 3, 24, 5, Palette.water)
        canvas.fill(4 + wobble, 5, 20 - wobble * 2, 2, Palette.waterLight)
        canvas.fill(12, 8, 4, 5, Palette.basin)
        let jet = 3 + wobble
        canvas.fill(13, 13, 2, jet, Palette.waterLight)
        canvas.set(12, 12 + jet, Palette.waterLight)
        canvas.set(15, 12 + jet, Palette.waterLight)
        return canvas.texture()
    }

    static let sleeperWidth = 22
    static let sleeperHeight = 12
    static let sleeperFrames = 2

    /// A napping agent, drawn in the same colours as its standing sprite so the person
    /// who lay down is still recognisable.
    static func sleeper(hash: Int, frame: Int) -> SKTexture {
        let skin = Palette.skin(hash)
        let hair = Palette.hair(hash)
        let tunic = Palette.tunic(hash)
        let breath = phase(frame, over: sleeperFrames)
        let key = TextureKey.sleeper(skin: skin, hair: hair, tunic: tunic, phase: breath)
        return cached(key) { buildSleeper(skin: skin, hair: hair, tunic: tunic, breath: breath) }
    }

    private static func buildSleeper(skin: UInt32, hair: UInt32, tunic: UInt32, breath: Int) -> SKTexture {
        var canvas = PixelCanvas(width: sleeperWidth, height: sleeperHeight, fill: Palette.clear)
        canvas.fill(2, 0, 18, 1, Palette.columnShadow)
        canvas.fill(13, 1, 7, 3, Palette.stoneDark)
        canvas.fill(7, 2, 8, 5 + breath, tunic)
        canvas.fill(7, 2, 8, 1, Palette.ink)
        canvas.fill(3, 3, 5, 4, skin)
        canvas.fill(2, 6, 6, 3, hair)
        canvas.fill(4, 5, 2, 1, Palette.ink)
        return canvas.texture()
    }

    static func sleepZ() -> SKTexture {
        cached(.sleepZ) { buildSleepZ() }
    }

    private static func buildSleepZ() -> SKTexture {
        var canvas = PixelCanvas(width: 6, height: 6, fill: Palette.clear)
        canvas.fill(1, 4, 4, 1, Palette.ink)
        canvas.set(3, 3, Palette.ink)
        canvas.set(2, 2, Palette.ink)
        canvas.fill(1, 1, 4, 1, Palette.ink)
        return canvas.texture()
    }

    /// A theme decides who inhabits the plaza: people on the agora, cats on the shore.
    /// Mapping an activity onto a pose lives here, so an actor only has to say whether it
    /// is currently on the move.
    static func actorSize(theme: PlazaTheme, small: Bool) -> CGSize {
        switch theme {
        case .agora:
            return small
                ? CGSize(width: 12, height: 16)
                : CGSize(width: characterWidth, height: characterHeight)
        case .seaside:
            return catSize(small: small)
        }
    }

    static func actorBody(
        theme: PlazaTheme,
        hash: Int,
        kind: ActivityKind,
        moving: Bool,
        frame: Int,
        small: Bool
    ) -> SKTexture {
        switch theme {
        case .agora:
            // The idle sprite carries the walk cycle, so an agent on its way to bed borrows
            // the waiting pose instead: standing and breathing rather than marching on the spot.
            let visualKind: ActivityKind = kind == .idle ? (moving ? .idle : .waiting) : kind
            return character(hash: hash, kind: visualKind, frame: frame, small: small)
        case .seaside:
            return cat(variant: hash, pose: moving ? .walking : .sitting, frame: frame, small: small)
        }
    }

    static func actorSleeper(theme: PlazaTheme, hash: Int, frame: Int) -> SKTexture {
        switch theme {
        case .agora: return sleeper(hash: hash, frame: frame)
        case .seaside: return catSleeper(variant: hash, frame: frame)
        }
    }

    static func actorSleeperSize(theme: PlazaTheme) -> CGSize {
        switch theme {
        case .agora: return CGSize(width: sleeperWidth, height: sleeperHeight)
        case .seaside: return CGSize(width: catSleeperWidth, height: catSleeperHeight)
        }
    }

    static func character(hash: Int, kind: ActivityKind, frame: Int, small: Bool) -> SKTexture {
        let skin = Palette.skin(hash)
        let hair = Palette.hair(hash)
        let tunic = Palette.tunic(hash)
        // The walk cycle repeats every 2 frames and the breath every 6, so frame 6 draws
        // exactly what frame 0 does. Folding the counter onto that period is what keeps
        // an actor that ticks all night down to six textures per activity.
        let step = phase(frame, over: characterFrames)
        let key = TextureKey.character(
            skin: skin, hair: hair, tunic: tunic, kind: kind, phase: step, small: small
        )
        return cached(key) {
            buildCharacter(skin: skin, hair: hair, tunic: tunic, kind: kind, frame: step, small: small)
        }
    }

    private static func buildCharacter(
        skin: UInt32,
        hair: UInt32,
        tunic: UInt32,
        kind: ActivityKind,
        frame: Int,
        small: Bool
    ) -> SKTexture {
        var canvas = PixelCanvas(width: characterWidth, height: characterHeight)
        let walk = frame % 2 == 0
        // Everything above the legs rides a slow breath so even a seated agent reads as
        // alive; the legs stretch by the same pixel to avoid a gap at the waist.
        let breath = (frame / 3) % 2
        canvas.fill(5, 13 + breath, 6, 5, hair)
        canvas.fill(5, 10 + breath, 6, 4, skin)
        canvas.set(6, 12 + breath, Palette.ink)
        canvas.set(9, 12 + breath, Palette.ink)
        canvas.fill(4, 5 + breath, 8, 6, tunic)
        canvas.fill(4, 5 + breath, 8, 1, Palette.ink)
        if kind == .running || kind == .thinking || (kind == .idle && walk) {
            canvas.fill(5, 0, 2, walk ? 5 : 4, Palette.ink)
            canvas.fill(9, 0, 2, walk ? 4 : 5, Palette.ink)
        } else {
            canvas.fill(5, 0, 3, 5 + breath, Palette.ink)
            canvas.fill(8, 0, 3, 5 + breath, Palette.ink)
        }
        switch kind {
        case .reading:
            canvas.fill(10, 6 + breath, 5, 4, Palette.stoneLight)
            canvas.fill(11, 7 + breath, 3, 2, Palette.ink)
            if walk {
                canvas.fill(13, 7 + breath, 1, 2, Palette.stoneLight)
            }
        case .writing:
            canvas.fill(11, 7 + breath, 4, 1, Palette.ink)
            if walk {
                canvas.fill(12, 8 + breath, 1, 2, Palette.ink)
            }
        case .waiting:
            break
        case .running:
            canvas.fill(3, 8 + breath, 2, 2, skin)
            canvas.fill(11, 8 + breath, 2, 2, skin)
        default:
            break
        }
        if small {
            var tiny = PixelCanvas(width: 12, height: 16)
            for y in 0..<16 {
                for x in 0..<12 {
                    let sx = min(characterWidth - 1, x + 2)
                    let sy = min(characterHeight - 1, y + 2)
                    tiny.set(x, y, canvas.pixels[sy * characterWidth + sx])
                }
            }
            return tiny.texture()
        }
        return canvas.texture()
    }

    static func bubble() -> SKTexture {
        cached(.bubble) { buildBubble() }
    }

    static func bird(theme: PlazaTheme, frame: Int) -> SKTexture {
        let flap = phase(frame, over: 2)
        return cached(.bird(theme: theme, phase: flap)) { buildBird(theme: theme, flap: flap) }
    }

    private static func buildBird(theme: PlazaTheme, flap: Int) -> SKTexture {
        var canvas = PixelCanvas(width: 7, height: 5, fill: Palette.clear)
        // A gull is the same silhouette in a lighter feather, so the shore keeps its own
        // bird without a second flight path.
        let feather = theme == .seaside ? Shore.gull : Palette.ink
        canvas.fill(2, 2, 3, 1, feather)
        canvas.set(5, 2, feather)
        canvas.set(1, 2, feather)
        if flap == 0 {
            canvas.set(2, 3, feather)
            canvas.set(4, 3, feather)
            canvas.set(2, 1, feather)
            canvas.set(4, 1, feather)
        } else {
            canvas.fill(0, 2, 2, 1, feather)
            canvas.fill(5, 2, 2, 1, feather)
        }
        if theme == .seaside {
            canvas.set(0, 2, Palette.ink)
            canvas.set(6, 2, Palette.ink)
        }
        return canvas.texture()
    }

    static func leaf(theme: PlazaTheme) -> SKTexture {
        cached(.leaf(theme: theme)) { buildLeaf(theme: theme) }
    }

    private static func buildLeaf(theme: PlazaTheme) -> SKTexture {
        var canvas = PixelCanvas(width: 3, height: 3, fill: Palette.clear)
        switch theme {
        case .agora:
            canvas.set(1, 1, Palette.olive)
            canvas.set(1, 2, Palette.oliveLight)
            canvas.set(0, 1, Palette.oliveDark)
        case .seaside:
            canvas.set(1, 1, Shore.frond)
            canvas.set(1, 2, Shore.frondLight)
            canvas.set(0, 1, Shore.frondDark)
        }
        return canvas.texture()
    }

    private static func buildBubble() -> SKTexture {
        var canvas = PixelCanvas(width: 14, height: 12, fill: Palette.clear)
        canvas.fill(1, 3, 12, 8, Palette.bubble)
        canvas.fill(1, 3, 12, 1, Palette.ink)
        canvas.fill(1, 10, 12, 1, Palette.ink)
        canvas.fill(1, 3, 1, 8, Palette.ink)
        canvas.fill(12, 3, 1, 8, Palette.ink)
        canvas.fill(6, 1, 2, 2, Palette.bubble)
        canvas.set(6, 7, Palette.ink)
        canvas.set(7, 7, Palette.ink)
        canvas.set(6, 5, Palette.ink)
        canvas.set(7, 8, Palette.ink)
        return canvas.texture()
    }

    static func phase(_ frame: Int, over period: Int) -> Int {
        let step = frame % period
        return step < 0 ? step + period : step
    }

    private static func drawColumn(
        _ canvas: inout PixelCanvas,
        x: Int,
        baseY: Int,
        topY: Int,
        lantern: Bool = false
    ) {
        let shaft = max(4, topY - baseY - 4)
        canvas.fill(x, baseY, 8, 2, Palette.columnShadow)
        canvas.fill(x + 1, baseY + 2, 6, shaft, Palette.column)
        canvas.fill(x + 1, baseY + 2, 1, shaft, Palette.columnShadow)
        canvas.fill(x, baseY + 2 + shaft, 8, 2, Palette.column)
        if lantern {
            let ly = baseY + max(2, shaft / 2)
            canvas.fill(x + 3, ly, 2, 2, Palette.lantern)
            canvas.set(x + 3, ly + 2, Palette.roofDark)
        }
    }
}
