import AppKit
import SpriteKit
import AgoreCore

enum Palette {
    static let sky = rgba(0x4A7C9B, 255)
    static let skyLight = rgba(0x6A9BB8, 255)
    static let stone = rgba(0xD4C4A8, 255)
    static let stoneDark = rgba(0xB8A888, 255)
    static let stoneLight = rgba(0xE8DCC8, 255)
    static let column = rgba(0xF5F0E6, 255)
    static let columnShadow = rgba(0xC9B89A, 255)
    static let olive = rgba(0x6B8F71, 255)
    static let roof = rgba(0x8B5A3C, 255)
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

    func texture() -> SKTexture {
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        let texture = SKTexture(data: data, size: CGSize(width: width, height: height))
        texture.filteringMode = .nearest
        return texture
    }
}

enum PixelArt {
    /// The world is exactly half the on-screen strip, so everything lands on a 2x pixel grid.
    static let worldWidth = 360
    static let worldHeight = 42
    static let characterWidth = 16
    static let characterHeight = 20
    /// Floor below, colonnade band above. The band stays shallow so the actors get most
    /// of the strip to move around in.
    static let horizonY = 33
    /// The plane the actors' feet rest on.
    static let groundY = 12
    static let fountainWidth = 28
    static let fountainHeight = 18
    static let fountainCenterX = 180

    static func plazaBackground() -> SKTexture {
        var canvas = PixelCanvas(width: worldWidth, height: worldHeight, fill: Palette.stone)
        canvas.fill(0, horizonY, worldWidth, worldHeight - horizonY, Palette.sky)
        canvas.fill(0, horizonY, worldWidth, 3, Palette.skyLight)
        for y in stride(from: 0, to: horizonY, by: 7) {
            for x in stride(from: 0, to: worldWidth, by: 8) {
                let grout = ((x / 8) + (y / 7)) % 2 == 0 ? Palette.stoneDark : Palette.stoneLight
                canvas.fill(x, y, 8, 1, grout)
                canvas.fill(x, y, 1, 7, grout)
            }
        }
        for x in stride(from: 6, to: worldWidth - 6, by: 30) {
            drawColumn(&canvas, x: x)
        }
        canvas.fill(46, 4, 12, 4, Palette.olive)
        canvas.fill(212, 3, 10, 4, Palette.olive)
        canvas.fill(312, 5, 14, 4, Palette.olive)
        return canvas.texture()
    }

    static func fountainFrame(_ frame: Int) -> SKTexture {
        var canvas = PixelCanvas(width: fountainWidth, height: fountainHeight, fill: Palette.clear)
        let wobble = frame % 3
        canvas.fill(0, 0, fountainWidth, 3, Palette.basin)
        canvas.fill(0, 2, fountainWidth, 1, Palette.columnShadow)
        canvas.fill(2, 3, 24, 5, Palette.water)
        canvas.fill(4 + wobble, 5, 20 - wobble * 2, 2, Palette.waterLight)
        canvas.fill(12, 8, 4, 5, Palette.basin)
        let jet = 3 + wobble
        canvas.fill(13, 13, 2, jet, Palette.waterLight)
        canvas.set(12, 12 + jet, Palette.waterLight)
        canvas.set(15, 12 + jet, Palette.waterLight)
        return canvas.texture()
    }

    /// The plaza's caretaker: shown napping while no coding agent is awake.
    static func sleeper(frame: Int) -> SKTexture {
        var canvas = PixelCanvas(width: 22, height: 12, fill: Palette.clear)
        let breath = frame % 2
        let skin = Palette.skin(3)
        let hair = Palette.hair(3)
        let tunic = Palette.tunic(3)
        canvas.fill(1, 0, 20, 2, Palette.stoneDark)
        canvas.fill(13, 2, 7, 3, Palette.ink)
        canvas.fill(7, 2, 8, 5 + breath, tunic)
        canvas.fill(7, 2, 8, 1, Palette.ink)
        canvas.fill(3, 3, 5, 4, skin)
        canvas.fill(2, 6, 6, 3, hair)
        canvas.fill(4, 5, 2, 1, Palette.ink)
        return canvas.texture()
    }

    static func sleepZ() -> SKTexture {
        var canvas = PixelCanvas(width: 6, height: 6, fill: Palette.clear)
        canvas.fill(1, 4, 4, 1, Palette.ink)
        canvas.set(3, 3, Palette.ink)
        canvas.set(2, 2, Palette.ink)
        canvas.fill(1, 1, 4, 1, Palette.ink)
        return canvas.texture()
    }

    static func character(hash: Int, kind: ActivityKind, frame: Int, small: Bool) -> SKTexture {
        var canvas = PixelCanvas(width: characterWidth, height: characterHeight)
        let skin = Palette.skin(hash)
        let hair = Palette.hair(hash)
        let tunic = Palette.tunic(hash)
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

    private static func drawColumn(_ canvas: inout PixelCanvas, x: Int) {
        let base = horizonY - 2
        let shaft = worldHeight - base - 3
        canvas.fill(x, base, 8, 2, Palette.columnShadow)
        canvas.fill(x + 1, base + 2, 6, shaft, Palette.column)
        canvas.fill(x + 1, base + 2, 1, shaft, Palette.columnShadow)
        canvas.fill(x, worldHeight - 3, 8, 2, Palette.column)
        canvas.fill(x, worldHeight - 1, 8, 1, Palette.roof)
    }
}
