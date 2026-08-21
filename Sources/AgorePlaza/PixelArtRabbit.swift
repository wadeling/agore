import SpriteKit
import AgoreCore

enum RabbitPose: Hashable, Sendable {
    case sitting
    case walking
}

extension PixelArt {
    /// Tall enough for the ears, still shorter than a person so a row of rabbits
    /// does not hide the sunflower field behind them.
    static let rabbitWidth = 12
    static let rabbitHeight = 16
    static let bunnyWidth = 9
    static let bunnyHeight = 12
    static let rabbitSleeperWidth = 16
    static let rabbitSleeperHeight = 10
    static let rabbitVariants = 3
    static let rabbitFrames = 2

    static func rabbitSize(small: Bool) -> CGSize {
        small
            ? CGSize(width: bunnyWidth, height: bunnyHeight)
            : CGSize(width: rabbitWidth, height: rabbitHeight)
    }

    static func rabbit(variant: Int, pose: RabbitPose, frame: Int, small: Bool = false) -> SKTexture {
        let kit = variant.outfitIndex
        let step = phase(frame, over: rabbitFrames)
        return cached(.rabbit(variant: kit, pose: pose, phase: step, small: small)) {
            switch (pose, small) {
            case (.sitting, false): return buildSittingRabbit(variant: kit, frame: step)
            case (.walking, false): return buildHoppingRabbit(variant: kit, frame: step)
            case (.sitting, true): return buildSittingBunny(variant: kit, frame: step)
            case (.walking, true): return buildHoppingBunny(variant: kit, frame: step)
            }
        }
    }

    static func rabbitSleeper(variant: Int, frame: Int) -> SKTexture {
        let kit = variant.outfitIndex
        let breath = phase(frame, over: sleeperFrames)
        return cached(.rabbitSleeper(variant: kit, phase: breath)) {
            buildSleepingRabbit(variant: kit, breath: breath)
        }
    }

    private struct Outfit {
        let fur: UInt32
        let shade: UInt32
        let shirt: UInt32
        let bow: UInt32
        let ear: UInt32
        let blush: UInt32
    }

    private static func outfit(_ variant: Int) -> Outfit {
        let blush = Palette.rgba(0xF08090, 255)
        let ear = Palette.rgba(0xF4A0A8, 255)
        switch variant {
        case 1:
            // The mural astronaut, as a second coat: pink suit, white helmet patch.
            return Outfit(
                fur: Palette.rgba(0xF6F0E2, 255),
                shade: Palette.rgba(0xD8CEB8, 255),
                shirt: Palette.rgba(0xE87890, 255),
                bow: Palette.rgba(0xF6F0E2, 255),
                ear: ear,
                blush: blush
            )
        case 2:
            return Outfit(
                fur: Palette.rgba(0xF0D8B0, 255),
                shade: Palette.rgba(0xD4B48A, 255),
                shirt: Palette.rgba(0xE8B030, 255),
                bow: Palette.rgba(0x3D8A4A, 255),
                ear: ear,
                blush: blush
            )
        default:
            // The reference: white fur, navy shirt, red bow.
            return Outfit(
                fur: Palette.rgba(0xF6F0E2, 255),
                shade: Palette.rgba(0xD8CEB8, 255),
                shirt: Palette.rgba(0x2C4A8C, 255),
                bow: Palette.rgba(0xE03030, 255),
                ear: ear,
                blush: blush
            )
        }
    }

    /// Face-on, ears up, the little rabbit from the stop: a round head, a bow, and a
    /// shirt. The ears twitch so a waiting rabbit still reads as alive.
    private static func buildSittingRabbit(variant: Int, frame: Int) -> SKTexture {
        let kit = outfit(variant)
        var canvas = PixelCanvas(width: rabbitWidth, height: rabbitHeight, fill: Palette.clear)
        let twitch = frame == 0 ? 0 : 1
        canvas.fill(3, 11 + twitch, 2, 3, kit.fur)
        canvas.fill(7, 11 + twitch, 2, 3, kit.fur)
        canvas.set(4, 12 + twitch, kit.ear)
        canvas.set(7, 12 + twitch, kit.ear)
        canvas.fill(4, 9, 4, 3, kit.fur)
        canvas.fill(3, 8, 6, 3, kit.fur)
        canvas.set(4, 10, Palette.ink)
        canvas.set(7, 10, Palette.ink)
        canvas.set(3, 9, kit.blush)
        canvas.set(8, 9, kit.blush)
        canvas.set(5, 8, kit.shade)
        canvas.fill(4, 7, 4, 1, kit.bow)
        canvas.set(3, 7, kit.bow)
        canvas.set(8, 7, kit.bow)
        canvas.fill(3, 3, 6, 4, kit.shirt)
        canvas.set(2, 5, kit.fur)
        canvas.set(9, 5, kit.fur)
        canvas.fill(4, 2, 4, 1, kit.fur)
        canvas.fill(3, 0, 2, 3, kit.fur)
        canvas.fill(7, 0, 2, 3, kit.fur)
        canvas.set(3, 0, kit.shade)
        canvas.set(8, 0, kit.shade)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// A hop rather than a walk: squash on the ground, then stretch with the feet
    /// off it, ears following the bounce.
    private static func buildHoppingRabbit(variant: Int, frame: Int) -> SKTexture {
        let kit = outfit(variant)
        var canvas = PixelCanvas(width: rabbitWidth, height: rabbitHeight, fill: Palette.clear)
        let up = frame == 1
        let lift = up ? 1 : 0
        canvas.fill(3, 11 + lift, 2, up ? 3 : 2, kit.fur)
        canvas.fill(7, 11 + lift, 2, up ? 3 : 2, kit.fur)
        canvas.set(4, 12 + lift, kit.ear)
        canvas.set(7, 12 + lift, kit.ear)
        if !up {
            canvas.set(2, 12, kit.fur)
            canvas.set(9, 12, kit.fur)
        }
        canvas.fill(4, 9 + lift, 4, 3, kit.fur)
        canvas.fill(3, 8 + lift, 6, 2, kit.fur)
        canvas.set(4, 10 + lift, Palette.ink)
        canvas.set(7, 10 + lift, Palette.ink)
        canvas.set(3, 9 + lift, kit.blush)
        canvas.set(8, 9 + lift, kit.blush)
        canvas.fill(4, 7 + lift, 4, 1, kit.bow)
        canvas.set(3, 7 + lift, kit.bow)
        canvas.set(8, 7 + lift, kit.bow)
        canvas.fill(3, 3 + lift, 6, 4, kit.shirt)
        canvas.set(2, 5 + lift, kit.fur)
        canvas.set(9, 5 + lift, kit.fur)
        canvas.fill(4, 2 + lift, 4, 1, kit.fur)
        if up {
            canvas.fill(4, 1, 2, 2, kit.fur)
            canvas.fill(7, 1, 2, 2, kit.fur)
        } else {
            canvas.fill(3, 0, 3, 3, kit.fur)
            canvas.fill(6, 0, 3, 3, kit.fur)
        }
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// On its side, ears flopped left, the same bow still showing so the one who
    /// dozed off is still recognisable.
    private static func buildSleepingRabbit(variant: Int, breath: Int) -> SKTexture {
        let kit = outfit(variant)
        var canvas = PixelCanvas(width: rabbitSleeperWidth, height: rabbitSleeperHeight, fill: Palette.clear)
        canvas.fill(1, 4 + breath, 3, 2, kit.fur)
        canvas.fill(2, 6 + breath, 2, 2, kit.fur)
        canvas.set(2, 7 + breath, kit.ear)
        canvas.ellipse(8, 3 + breath, 5, 2, kit.fur)
        canvas.fill(4, 2 + breath, 4, 4, kit.fur)
        canvas.fill(5, 3 + breath, 5, 2, kit.shirt)
        canvas.fill(6, 3 + breath, 2, 1, kit.bow)
        canvas.fill(3, 3 + breath, 2, 1, Palette.ink)
        canvas.set(4, 2 + breath, kit.blush)
        canvas.fill(11, 2, 3, 2, kit.fur)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildSittingBunny(variant: Int, frame: Int) -> SKTexture {
        let kit = outfit(variant)
        var canvas = PixelCanvas(width: bunnyWidth, height: bunnyHeight, fill: Palette.clear)
        let twitch = frame == 0 ? 0 : 1
        canvas.set(2, 10 + twitch, kit.fur)
        canvas.set(6, 10 + twitch, kit.fur)
        canvas.fill(2, 8, 2, 3, kit.fur)
        canvas.fill(5, 8, 2, 3, kit.fur)
        canvas.set(3, 9, kit.ear)
        canvas.set(5, 9, kit.ear)
        canvas.fill(2, 6, 5, 3, kit.fur)
        canvas.set(3, 7, Palette.ink)
        canvas.set(5, 7, Palette.ink)
        canvas.set(2, 6, kit.blush)
        canvas.set(6, 6, kit.blush)
        canvas.fill(3, 5, 3, 1, kit.bow)
        canvas.fill(2, 2, 5, 3, kit.shirt)
        canvas.fill(2, 0, 2, 2, kit.fur)
        canvas.fill(5, 0, 2, 2, kit.fur)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildHoppingBunny(variant: Int, frame: Int) -> SKTexture {
        let kit = outfit(variant)
        var canvas = PixelCanvas(width: bunnyWidth, height: bunnyHeight, fill: Palette.clear)
        let up = frame == 1
        let lift = up ? 1 : 0
        canvas.set(2, 10 + lift, kit.fur)
        canvas.set(6, 10 + lift, kit.fur)
        canvas.fill(2, 8 + lift, 2, 2, kit.fur)
        canvas.fill(5, 8 + lift, 2, 2, kit.fur)
        canvas.fill(2, 6 + lift, 5, 3, kit.fur)
        canvas.set(3, 7 + lift, Palette.ink)
        canvas.set(5, 7 + lift, Palette.ink)
        canvas.fill(3, 5 + lift, 3, 1, kit.bow)
        canvas.fill(2, 2 + lift, 5, 3, kit.shirt)
        if up {
            canvas.fill(3, 1, 1, 1, kit.fur)
            canvas.fill(5, 1, 1, 1, kit.fur)
        } else {
            canvas.fill(2, 0, 2, 2, kit.fur)
            canvas.fill(5, 0, 2, 2, kit.fur)
        }
        canvas.outline(Palette.ink)
        return canvas.texture()
    }
}

private extension Int {
    var outfitIndex: Int {
        let count = PixelArt.rabbitVariants
        return ((self % count) + count) % count
    }
}
