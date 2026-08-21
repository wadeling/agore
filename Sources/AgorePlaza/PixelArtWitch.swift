import SpriteKit
import AgoreCore

enum WitchPose: Hashable, Sendable {
    case sitting
    case flying
}

extension PixelArt {
    /// Room for the pointed hat leaning back off her head, hair down to the waist,
    /// and a handle reaching out ahead of her.
    static let witchWidth = 26
    static let witchHeight = 25
    static let witchlingWidth = 20
    static let witchlingHeight = 19
    static let witchSleeperWidth = 24
    static let witchSleeperHeight = 13
    static let witchVariants = 1
    static let witchFrames = 2

    static func witchSize(small: Bool) -> CGSize {
        small
            ? CGSize(width: witchlingWidth, height: witchlingHeight)
            : CGSize(width: witchWidth, height: witchHeight)
    }

    static func witch(variant: Int, pose: WitchPose, frame: Int, small: Bool = false) -> SKTexture {
        let step = phase(frame, over: witchFrames)
        return cached(.witch(variant: 0, pose: pose, phase: step, small: small)) {
            small
                ? buildWitchling(frame: step, flying: pose == .flying)
                : buildWitch(frame: step, flying: pose == .flying)
        }
    }

    static func witchSleeper(variant: Int, frame: Int) -> SKTexture {
        let breath = phase(frame, over: sleeperFrames)
        return cached(.witchSleeper(variant: 0, phase: breath)) {
            buildSleepingWitch(breath: breath)
        }
    }

    private struct Kit {
        let hat: UInt32
        let hatDark: UInt32
        let hatLight: UInt32
        let band: UInt32
        let bandDark: UInt32
        let hair: UInt32
        let hairLight: UInt32
        let hairDark: UInt32
        let skin: UInt32
        let skinShade: UInt32
        let blush: UInt32
        let dress: UInt32
        let dressDark: UInt32
        let dressLight: UInt32
        let collar: UInt32
        let bag: UInt32
        let bagDark: UInt32
        let tights: UInt32
        let boot: UInt32
        let bootDark: UInt32
        let stick: UInt32
        let stickDark: UInt32
        let straw: UInt32
        let strawMid: UInt32
        let strawDark: UInt32
        let bind: UInt32
        let pouch: UInt32
        let pouchDark: UInt32
        let buckle: UInt32
    }

    /// One girl: navy hat with a red band, blue dress, orange satchel. Agents are
    /// told apart by name, not by outfit.
    private static let kit = Kit(
        hat: Palette.rgba(0x3A3E68, 255),
        hatDark: Palette.rgba(0x242746, 255),
        hatLight: Palette.rgba(0x4E5486, 255),
        band: Palette.rgba(0xC0303A, 255),
        bandDark: Palette.rgba(0x8E2029, 255),
        hair: Palette.rgba(0x8A5A3B, 255),
        hairLight: Palette.rgba(0xAE7950, 255),
        hairDark: Palette.rgba(0x5C3924, 255),
        skin: Palette.rgba(0xF1C4A0, 255),
        skinShade: Palette.rgba(0xD8A280, 255),
        blush: Palette.rgba(0xE8A090, 255),
        dress: Palette.rgba(0x2F4A9E, 255),
        dressDark: Palette.rgba(0x1D2F70, 255),
        dressLight: Palette.rgba(0x4262BE, 255),
        collar: Palette.rgba(0xE87820, 255),
        bag: Palette.rgba(0xE87820, 255),
        bagDark: Palette.rgba(0xC06018, 255),
        tights: Palette.rgba(0x2A2C48, 255),
        boot: Palette.rgba(0xC02838, 255),
        bootDark: Palette.rgba(0x8C1C2A, 255),
        stick: Palette.rgba(0xAE7F3E, 255),
        stickDark: Palette.rgba(0x765326, 255),
        straw: Palette.rgba(0xF4E2B4, 255),
        strawMid: Palette.rgba(0xDABE84, 255),
        strawDark: Palette.rgba(0xA88A50, 255),
        bind: Palette.rgba(0xA83034, 255),
        pouch: Palette.rgba(0x7A4A2A, 255),
        pouchDark: Palette.rgba(0x553118, 255),
        buckle: Palette.rgba(0xD8B060, 255)
    )

    /// A column of straw, light along the top edge where the sun lands and dark
    /// underneath, so the bundle reads as round.
    private static func strawColumn(_ canvas: inout PixelCanvas, x: Int, low: Int, high: Int) {
        let k = kit
        canvas.fill(x, low, 1, high - low + 1, k.strawMid)
        canvas.set(x, high, k.straw)
        canvas.set(x, high - 1, k.straw)
        canvas.set(x, low, k.strawDark)
        canvas.set(x, low + 1, k.strawDark)
    }

    /// The broom, facing right: the handle leads so it points the way she is
    /// looking, and the straw trails behind, pinched at the binding and flaring
    /// into a droop. The handle is two pixels thick where she sits on it and steps
    /// up to a single pixel at the tip, so the broom flies at an angle instead of
    /// lying flat across the sprite.
    private static func stampBroom(_ canvas: inout PixelCanvas, frame: Int) {
        let k = kit
        strawColumn(&canvas, x: 1, low: 2, high: 6)
        strawColumn(&canvas, x: 2, low: 1, high: 7)
        strawColumn(&canvas, x: 3, low: 1, high: 8)
        strawColumn(&canvas, x: 4, low: 2, high: 8)
        strawColumn(&canvas, x: 5, low: 4, high: 8)
        for (i, x) in [5, 4, 3, 2].enumerated() {
            canvas.set(x, 6 - i, k.strawDark)
        }
        for (i, x) in [4, 3, 2].enumerated() {
            canvas.set(x, 7 - i, k.straw)
        }
        // Loose straws, kept touching the bundle: an island would let the outline
        // pass wall off the gap and cut the tail in two.
        canvas.set(1, 7, k.straw)
        canvas.set(5, 9, k.strawMid)
        canvas.set(4, 1, k.strawDark)
        canvas.set(1, frame == 1 ? 1 : 8, k.strawMid)

        canvas.fill(8, 7, 10, 1, k.stick)
        canvas.fill(8, 6, 9, 1, k.stickDark)
        canvas.fill(18, 8, 4, 1, k.stick)
        canvas.set(18, 7, k.stickDark)
        canvas.fill(22, 9, 3, 1, k.stick)
        canvas.set(22, 8, k.stickDark)
        canvas.set(24, 10, k.stick)

        canvas.fill(6, 6, 2, 3, k.bind)
        canvas.set(6, 8, k.bandDark)
        canvas.set(7, 6, k.bandDark)

        let swing = frame == 1 ? 1 : 0
        canvas.set(7, 5, k.pouchDark)
        canvas.fill(6 + swing, 2, 3, 3, k.pouch)
        canvas.fill(6 + swing, 2, 3, 1, k.pouchDark)
        canvas.set(7 + swing, 3, k.buckle)
    }

    private static func buildWitch(frame: Int, flying: Bool) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchWidth, height: witchHeight, fill: Palette.clear)
        stampBroom(&canvas, frame: frame)
        let y = frame == 1 ? 1 : 0

        // Hair first, so the dress and the hat sit over it: a long fall down her
        // back, tapering to a point at the waist.
        canvas.fill(8, 9 + y, 4, 9, k.hair)
        canvas.fill(9, 8 + y, 3, 1, k.hair)
        canvas.fill(10, 7 + y, 2, 1, k.hair)
        canvas.fill(8, 9 + y, 1, 9, k.hairDark)
        canvas.fill(11, 11 + y, 1, 7, k.hairLight)
        canvas.set(10, 14 + y, k.hairLight)
        canvas.set(9, 10 + y, k.hairDark)

        canvas.fill(9, 7 + y, 8, 2, k.dress)
        canvas.fill(9, 7 + y, 8, 1, k.dressDark)
        canvas.fill(11, 9 + y, 5, 4, k.dress)
        canvas.set(11, 11 + y, k.dressDark)
        canvas.set(15, 10 + y, k.dressLight)
        canvas.fill(12, 12 + y, 3, 1, k.collar)

        canvas.fill(7, 10 + y, 2, 3, k.bag)
        canvas.fill(7, 10 + y, 2, 1, k.bagDark)
        canvas.set(9, 12 + y, k.bagDark)

        canvas.set(16, 11 + y, k.dress)
        canvas.set(17, 10 + y, k.skin)
        canvas.fill(18, 9 + y, 2, 1, k.skin)
        canvas.set(19, 9 + y, k.skinShade)

        // Legs hang when she is idling and trail back when she is flying. The far
        // one is in shadow, so the two read apart without a gap between them.
        let legX = flying ? -1 : 0
        let legY = flying ? 1 : 0
        canvas.fill(14 + legX, 4 + y + legY, 2, 3, k.tights)
        canvas.fill(14 + legX, 2 + y + legY, 3, 2, k.bootDark)
        canvas.fill(12 + legX, 4 + y + legY, 2, 3, k.tights)
        canvas.fill(11 + legX, 3 + y + legY, 4, 2, k.boot)
        canvas.set(14 + legX, 4 + y + legY, k.boot)

        // Face in three-quarter view, looking the way the handle points.
        canvas.fill(12, 14 + y, 4, 4, k.skin)
        canvas.fill(13, 13 + y, 2, 1, k.skin)
        canvas.set(12, 14 + y, k.skinShade)
        canvas.set(16, 15 + y, k.skin)
        canvas.set(16, 16 + y, k.skin)
        canvas.set(15, 16 + y, Palette.ink)
        canvas.set(15, 17 + y, k.hairDark)
        canvas.set(15, 15 + y, k.blush)
        canvas.set(16, 14 + y, k.blush)
        canvas.set(14, 17 + y, k.hair)
        canvas.fill(12, 17 + y, 2, 1, k.hair)
        canvas.set(11, 15 + y, k.hair)
        canvas.set(11, 16 + y, k.hairLight)
        // Hair streaming out behind her, kept touching the rest of it: a pixel on
        // its own diagonal would come back from the outline pass ringed in ink.
        if flying {
            canvas.set(7, 16 + y, k.hair)
            canvas.set(6, 16 + y, k.hairLight)
        }

        stampHat(&canvas, originY: y, tip: frame == 1 ? 1 : 0)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// Wide brim, red band, then a crown that leans back into a floppy tip
    /// trailing behind her. The tip flaps a pixel between frames.
    private static func stampHat(_ canvas: inout PixelCanvas, originY y: Int, tip: Int) {
        let k = kit
        canvas.fill(9, 18 + y, 9, 1, k.hat)
        canvas.set(8, 18 + y, k.hatDark)
        canvas.set(18, 18 + y, k.hatDark)
        canvas.fill(10, 19 + y, 7, 1, k.band)
        canvas.fill(10, 19 + y, 3, 1, k.bandDark)
        canvas.fill(10, 20 + y, 6, 1, k.hat)
        canvas.fill(8, 21 + y, 6, 1, k.hat)
        canvas.fill(6, 22 + y, 5, 1, k.hat)
        canvas.set(14, 20 + y, k.hatLight)
        canvas.set(12, 21 + y, k.hatLight)
        canvas.set(9, 22 + y, k.hatLight)
        canvas.set(8, 21 + y, k.hatDark)
        canvas.set(6, 22 + y, k.hatDark)
        canvas.fill(4, 22 + y + tip, 2, 1, k.hat)
        canvas.fill(2, 21 + y + tip, 3, 1, k.hat)
        canvas.set(2, 21 + y + tip, k.hatDark)
        canvas.set(4, 22 + y + tip, k.hatLight)
        canvas.set(16, 19 + y, k.buckle)
    }

    /// A subagent's witch, three quarters of the size: the same hat and trailing
    /// straw on a shorter body, with the face cut down to an eye and a cheek.
    private static func buildWitchling(frame: Int, flying: Bool) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchlingWidth, height: witchlingHeight, fill: Palette.clear)
        let y = frame == 1 ? 1 : 0

        strawColumn(&canvas, x: 1, low: 2, high: 5)
        strawColumn(&canvas, x: 2, low: 1, high: 6)
        strawColumn(&canvas, x: 3, low: 1, high: 7)
        strawColumn(&canvas, x: 4, low: 3, high: 7)
        for (i, x) in [4, 3, 2].enumerated() {
            canvas.set(x, 5 - i, k.strawDark)
        }
        canvas.set(3, 6, k.straw)
        canvas.set(1, frame == 1 ? 1 : 6, k.strawMid)
        canvas.fill(5, 5, 1, 3, k.bind)

        canvas.fill(6, 6, 8, 1, k.stick)
        canvas.fill(6, 5, 7, 1, k.stickDark)
        canvas.fill(14, 7, 3, 1, k.stick)
        canvas.set(14, 6, k.stickDark)
        canvas.fill(17, 8, 2, 1, k.stick)

        let swing = frame == 1 ? 1 : 0
        canvas.set(5, 4, k.pouchDark)
        canvas.fill(4 + swing, 2, 2, 2, k.pouch)
        canvas.set(4 + swing, 3, k.pouchDark)

        canvas.fill(6, 8 + y, 3, 6, k.hair)
        canvas.fill(7, 7 + y, 2, 1, k.hair)
        canvas.fill(6, 8 + y, 1, 6, k.hairDark)
        canvas.set(8, 10 + y, k.hairLight)

        canvas.fill(7, 6 + y, 6, 2, k.dress)
        canvas.fill(7, 6 + y, 6, 1, k.dressDark)
        canvas.fill(8, 8 + y, 4, 3, k.dress)
        canvas.fill(9, 10 + y, 2, 1, k.collar)
        canvas.fill(5, 9 + y, 2, 2, k.bag)
        canvas.set(5, 9 + y, k.bagDark)
        canvas.set(12, 9 + y, k.dress)
        canvas.fill(13, 8 + y, 2, 1, k.skin)

        let legX = flying ? -1 : 0
        let legY = flying ? 1 : 0
        canvas.fill(11 + legX, 4 + y + legY, 1, 2, k.tights)
        canvas.fill(11 + legX, 3 + y + legY, 2, 1, k.bootDark)
        canvas.fill(9 + legX, 4 + y + legY, 2, 2, k.tights)
        canvas.fill(8 + legX, 3 + y + legY, 3, 1, k.boot)

        canvas.fill(9, 11 + y, 3, 2, k.skin)
        canvas.set(9, 11 + y, k.skinShade)
        canvas.set(11, 12 + y, Palette.ink)
        canvas.set(11, 11 + y, k.blush)
        canvas.set(8, 12 + y, k.hair)
        if flying {
            canvas.set(5, 12 + y, k.hair)
        }

        canvas.fill(7, 13 + y, 7, 1, k.hat)
        canvas.set(6, 13 + y, k.hatDark)
        canvas.set(14, 13 + y, k.hatDark)
        canvas.fill(8, 14 + y, 5, 1, k.band)
        canvas.fill(8, 14 + y, 2, 1, k.bandDark)
        canvas.fill(8, 15 + y, 4, 1, k.hat)
        canvas.fill(6, 16 + y, 4, 1, k.hat)
        canvas.set(6, 16 + y, k.hatDark)
        canvas.set(10, 15 + y, k.hatLight)
        let tip = frame == 1 ? 1 : 0
        canvas.fill(4, 16 + y + tip, 2, 1, k.hat)
        canvas.set(3, 15 + y + tip, k.hatDark)

        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// Asleep on her back along the handle, head at the right end so the Z's rise
    /// from the right place, hat tipped back off her face.
    private static func buildSleepingWitch(breath b: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchSleeperWidth, height: witchSleeperHeight, fill: Palette.clear)
        strawColumn(&canvas, x: 1, low: 2, high: 5)
        strawColumn(&canvas, x: 2, low: 1, high: 6)
        strawColumn(&canvas, x: 3, low: 2, high: 6)
        canvas.set(2, 7, k.straw)
        canvas.fill(4, 2, 1, 3, k.bind)
        canvas.fill(5, 3, 17, 1, k.stick)
        canvas.fill(5, 2, 15, 1, k.stickDark)

        canvas.fill(6, 4 + b, 3, 2, k.boot)
        canvas.set(5, 4 + b, k.bootDark)
        canvas.fill(9, 4 + b, 6, 2, k.dress)
        canvas.fill(10, 6 + b, 4, 1, k.dress)
        canvas.fill(9, 4 + b, 6, 1, k.dressDark)
        canvas.set(14, 6 + b, k.collar)
        canvas.fill(14, 4 + b, 3, 3, k.hair)
        canvas.set(15, 6 + b, k.hairLight)
        canvas.fill(17, 4 + b, 3, 3, k.skin)
        canvas.set(17, 4 + b, k.blush)
        canvas.fill(18, 5 + b, 2, 1, Palette.ink)

        canvas.fill(14, 7 + b, 8, 1, k.hat)
        canvas.set(21, 7 + b, k.hatDark)
        canvas.fill(14, 8 + b, 5, 1, k.band)
        canvas.fill(13, 9 + b, 5, 1, k.hat)
        canvas.set(16, 9 + b, k.hatLight)
        canvas.fill(11, 10 + b, 3, 1, k.hat)
        canvas.set(11, 10 + b, k.hatDark)

        canvas.outline(Palette.ink)
        return canvas.texture()
    }
}
