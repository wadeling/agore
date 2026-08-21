import SpriteKit
import AgoreCore

enum WitchPose: Hashable, Sendable {
    case sitting
    case flying
}

extension PixelArt {
    /// Wide enough for a long handle reaching out in front of her, tall enough for
    /// a pointed chin and the bow above the bob.
    static let witchWidth = 24
    static let witchHeight = 21
    static let witchlingWidth = 18
    static let witchlingHeight = 16
    static let witchSleeperWidth = 22
    static let witchSleeperHeight = 10
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
            switch (pose, small) {
            case (.sitting, false): return buildSittingWitch(frame: step)
            case (.flying, false): return buildFlyingWitch(frame: step)
            case (.sitting, true): return buildSittingWitchling(frame: step)
            case (.flying, true): return buildFlyingWitchling(frame: step)
            }
        }
    }

    static func witchSleeper(variant: Int, frame: Int) -> SKTexture {
        let breath = phase(frame, over: sleeperFrames)
        return cached(.witchSleeper(variant: 0, phase: breath)) {
            buildSleepingWitch(breath: breath)
        }
    }

    private struct Kit {
        let hair: UInt32
        let skin: UInt32
        let blush: UInt32
        let bow: UInt32
        let dress: UInt32
        let dressDark: UInt32
        let collar: UInt32
        let bag: UInt32
        let bagDark: UInt32
        let boot: UInt32
        let bootDark: UInt32
        let stick: UInt32
        let stickDark: UInt32
        let straw: UInt32
        let strawDark: UInt32
        let ribbon: UInt32
        let cat: UInt32
        let catEye: UInt32
    }

    /// One girl: blue dress, orange bow, orange bag. Agents are told apart by name.
    private static let kit = Kit(
        hair: Palette.rgba(0x2A1810, 255),
        skin: Palette.rgba(0xF1C4A0, 255),
        blush: Palette.rgba(0xE8A090, 255),
        bow: Palette.rgba(0xF07828, 255),
        dress: Palette.rgba(0x2A4A9C, 255),
        dressDark: Palette.rgba(0x1A3478, 255),
        collar: Palette.rgba(0xE87820, 255),
        bag: Palette.rgba(0xE87820, 255),
        bagDark: Palette.rgba(0xC06018, 255),
        boot: Palette.rgba(0xC02838, 255),
        bootDark: Palette.rgba(0x8C1C2A, 255),
        stick: Palette.rgba(0xD4B070, 255),
        stickDark: Palette.rgba(0xA88448, 255),
        straw: Palette.rgba(0xE8C070, 255),
        strawDark: Palette.rgba(0xB88838, 255),
        ribbon: Palette.rgba(0xD02838, 255),
        cat: Palette.rgba(0x1A1818, 255),
        catEye: Palette.rgba(0xF0D070, 255)
    )

    /// The broom, facing right. Straw splays out behind her, widest at the tail and
    /// bound in tight where the stick starts; the stick itself climbs a row at a
    /// time toward the tip, so the whole broom sits at an angle rather than lying
    /// flat across the sprite. A ribbon is wrapped round it ahead of her hands.
    private static func stampBroom(_ canvas: inout PixelCanvas, stickY: Int, frame: Int) {
        let k = kit
        canvas.fill(0, stickY - 3, 2, 7, k.straw)
        canvas.fill(2, stickY - 2, 2, 5, k.straw)
        canvas.fill(0, stickY - 3, 2, 3, k.strawDark)
        canvas.fill(2, stickY - 2, 2, 2, k.strawDark)
        canvas.fill(4, stickY - 1, 1, 3, k.strawDark)
        // Loose straws, so the tail frays instead of ending on a clean edge.
        canvas.set(0, stickY + 4, k.straw)
        canvas.set(1, stickY - 4, k.strawDark)
        canvas.set(3, stickY + 3, k.straw)

        canvas.fill(5, stickY, 9, 1, k.stick)
        canvas.fill(5, stickY - 1, 8, 1, k.stickDark)
        canvas.fill(14, stickY + 1, 5, 1, k.stick)
        canvas.set(14, stickY, k.stickDark)
        canvas.fill(19, stickY + 2, 5, 1, k.stick)
        canvas.set(19, stickY + 1, k.stickDark)

        canvas.fill(15, stickY + 1, 2, 1, k.ribbon)
        canvas.fill(15, stickY - 1, 1, 2, k.ribbon)
        canvas.set(frame == 0 ? 15 : 16, stickY - 2, k.ribbon)
    }

    /// 瓜子脸: seven pixels across so the face can stay symmetric — widest at the
    /// eyes, a three-pixel chin with the bob curling in beside it, and the bow on
    /// top. Stamped after the body so nothing covers the face.
    private static func stampHead(_ canvas: inout PixelCanvas, originX x: Int, originY y: Int) {
        let k = kit
        canvas.fill(x, y + 3, 7, 2, k.hair)
        canvas.fill(x + 1, y + 5, 5, 1, k.hair)
        canvas.set(x, y + 2, k.hair)
        canvas.set(x + 6, y + 2, k.hair)
        canvas.set(x, y + 1, k.hair)
        canvas.set(x + 6, y + 1, k.hair)
        canvas.set(x + 1, y, k.hair)
        canvas.set(x + 5, y, k.hair)
        canvas.fill(x + 1, y + 1, 5, 2, k.skin)
        canvas.fill(x + 2, y, 3, 1, k.skin)
        canvas.set(x + 2, y + 1, Palette.ink)
        canvas.set(x + 4, y + 1, Palette.ink)
        canvas.set(x + 1, y + 1, k.blush)
        canvas.set(x + 5, y + 1, k.blush)
        canvas.fill(x + 2, y + 7, 3, 1, k.bow)
        canvas.set(x + 1, y + 6, k.bow)
        canvas.set(x + 3, y + 6, k.bow)
        canvas.set(x + 5, y + 6, k.bow)
    }

    private static func buildSittingWitch(frame: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchWidth, height: witchHeight, fill: Palette.clear)
        stampBroom(&canvas, stickY: 8, frame: frame)

        canvas.fill(6, 9, 3, 4, k.bag)
        canvas.fill(6, 9, 3, 1, k.bagDark)
        canvas.fill(5, 13, 2, 2, k.cat)
        canvas.set(6, 13, k.catEye)

        canvas.fill(8, 8, 5, 5, k.dress)
        canvas.fill(8, 8, 5, 1, k.dressDark)
        canvas.fill(10, 12, 3, 1, k.collar)
        canvas.set(13, 10, k.dress)
        canvas.set(14, 10, k.skin)

        // The far leg in shadow, so the two legs read apart without a gap.
        canvas.fill(11, 3, 2, 5, k.bootDark)
        canvas.fill(9, 4, 2, 4, k.boot)
        stampHead(&canvas, originX: 7, originY: 13)

        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildFlyingWitch(frame: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchWidth, height: witchHeight, fill: Palette.clear)
        let lift = frame == 1 ? 1 : 0
        stampBroom(&canvas, stickY: 8 + lift, frame: frame)

        canvas.fill(6, 9 + lift, 3, 3, k.bag)
        canvas.set(7, 12 + lift, k.cat)

        canvas.fill(8, 9 + lift, 5, 4, k.dress)
        canvas.fill(8, 9 + lift, 5, 1, k.dressDark)
        canvas.fill(10, 12 + lift, 3, 1, k.collar)
        canvas.set(13, 11 + lift, k.dress)
        canvas.fill(14, 11 + lift, 2, 1, k.skin)

        canvas.fill(10, 4 + lift, 2, 5, k.bootDark)
        canvas.fill(8, 5 + lift, 2, 4, k.boot)
        stampHead(&canvas, originX: 7, originY: 13 + lift)
        canvas.set(6, 17 + lift, k.hair)
        canvas.set(5, 16 + lift, k.hair)

        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// Head on the right, matching the Z's that rise from that end when a profile
    /// actor lies down. The broom is laid out under her, straw at the tail.
    private static func buildSleepingWitch(breath: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchSleeperWidth, height: witchSleeperHeight, fill: Palette.clear)
        canvas.fill(0, 1, 2, 5, k.straw)
        canvas.fill(2, 2, 2, 3, k.straw)
        canvas.fill(0, 1, 2, 2, k.strawDark)
        canvas.set(1, 6, k.straw)
        canvas.fill(4, 3, 10, 1, k.stick)
        canvas.fill(14, 4, 8, 1, k.stick)
        canvas.set(9, 2, k.ribbon)
        canvas.set(9, 1, k.ribbon)

        canvas.fill(6, 3 + breath, 7, 3, k.dress)
        canvas.fill(6, 3 + breath, 7, 1, k.dressDark)
        canvas.fill(4, 3 + breath, 2, 3, k.bag)
        canvas.set(5, 6 + breath, k.cat)
        canvas.fill(13, 4 + breath, 4, 3, k.skin)
        canvas.fill(14, 3 + breath, 2, 1, k.skin)
        canvas.set(15, 5 + breath, Palette.ink)
        canvas.fill(14, 6 + breath, 5, 3, k.hair)
        canvas.set(17, 9 + breath, k.bow)
        canvas.set(18, 9 + breath, k.bow)
        canvas.set(16, 8 + breath, k.bow)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// A subagent's witch, three quarters of the size: the same angled broom and
    /// frayed straw, with a shorter body.
    private static func stampSmallBroom(_ canvas: inout PixelCanvas, stickY: Int, frame: Int) {
        let k = kit
        canvas.fill(0, stickY - 2, 2, 5, k.straw)
        canvas.fill(2, stickY - 1, 1, 3, k.straw)
        canvas.fill(0, stickY - 2, 2, 2, k.strawDark)
        canvas.set(3, stickY, k.strawDark)
        canvas.set(0, stickY + 3, k.straw)
        canvas.set(1, stickY - 3, k.strawDark)

        canvas.fill(4, stickY, 7, 1, k.stick)
        canvas.fill(4, stickY - 1, 6, 1, k.stickDark)
        canvas.fill(11, stickY + 1, 4, 1, k.stick)
        canvas.fill(15, stickY + 2, 3, 1, k.stick)

        canvas.set(12, stickY + 1, k.ribbon)
        canvas.set(12, stickY, k.ribbon)
        canvas.set(frame == 0 ? 12 : 13, stickY - 1, k.ribbon)
    }

    private static func buildSittingWitchling(frame: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchlingWidth, height: witchlingHeight, fill: Palette.clear)
        stampSmallBroom(&canvas, stickY: 5, frame: frame)
        canvas.fill(5, 6, 2, 3, k.bag)
        canvas.fill(7, 5, 4, 4, k.dress)
        canvas.fill(7, 5, 4, 1, k.dressDark)
        canvas.fill(8, 8, 3, 1, k.collar)
        canvas.set(11, 7, k.skin)
        canvas.fill(9, 1, 2, 4, k.bootDark)
        canvas.fill(7, 1, 2, 4, k.boot)
        stampHead(&canvas, originX: 5, originY: 8)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildFlyingWitchling(frame: Int) -> SKTexture {
        let k = kit
        var canvas = PixelCanvas(width: witchlingWidth, height: witchlingHeight, fill: Palette.clear)
        let lift = frame == 1 ? 1 : 0
        stampSmallBroom(&canvas, stickY: 5 + lift, frame: frame)
        canvas.fill(5, 6 + lift, 2, 2, k.bag)
        canvas.fill(7, 6 + lift, 4, 3, k.dress)
        canvas.fill(7, 6 + lift, 4, 1, k.dressDark)
        canvas.fill(8, 8 + lift, 3, 1, k.collar)
        canvas.fill(11, 7 + lift, 2, 1, k.skin)
        canvas.fill(8, 1 + lift, 2, 5, k.bootDark)
        canvas.fill(6, 2 + lift, 2, 4, k.boot)
        stampHead(&canvas, originX: 5, originY: 8 + lift)
        canvas.set(4, 12 + lift, k.hair)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }
}
