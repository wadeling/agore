import SpriteKit
import AgoreCore

enum PenguinPose: Hashable, Sendable {
    case sitting
    case waddling
}

extension PixelArt {
    /// A chunky profile penguin, no outline: navy oval, white belly, orange
    /// beak and feet. Tall enough to read at 2×, short enough that a row of
    /// them does not hide the ice behind.
    static let penguinWidth = 16
    static let penguinHeight = 17
    static let chickWidth = 12
    static let chickHeight = 13
    static let penguinSleeperWidth = 16
    static let penguinSleeperHeight = 17
    static let penguinVariants = 3
    static let penguinFrames = 2

    static func penguinSize(small: Bool) -> CGSize {
        small
            ? CGSize(width: chickWidth, height: chickHeight)
            : CGSize(width: penguinWidth, height: penguinHeight)
    }

    static func penguin(variant: Int, pose: PenguinPose, frame: Int, small: Bool = false) -> SKTexture {
        let kit = variant.penguinIndex
        let step = phase(frame, over: penguinFrames)
        return cached(.penguin(variant: kit, pose: pose, phase: step, small: small)) {
            switch (pose, small) {
            case (.sitting, false): return buildStandingPenguin(variant: kit, frame: step, asleep: false)
            case (.waddling, false): return buildWaddlingPenguin(variant: kit, frame: step)
            case (.sitting, true): return buildStandingChick(variant: kit, frame: step, asleep: false)
            case (.waddling, true): return buildWaddlingChick(variant: kit, frame: step)
            }
        }
    }

    /// Still on its feet: the same silhouette as the standing sprite, eyes
    /// shut and a slow breath, so a nap does not look like a faint.
    static func penguinSleeper(variant: Int, frame: Int) -> SKTexture {
        let kit = variant.penguinIndex
        let breath = phase(frame, over: sleeperFrames)
        return cached(.penguinSleeper(variant: kit, phase: breath)) {
            buildStandingPenguin(variant: kit, frame: breath, asleep: true)
        }
    }

    private struct Kit {
        let body: UInt32
        let shade: UInt32
        let belly: UInt32
        let bellyShade: UInt32
        let beak: UInt32
        let beakDark: UInt32
        let feet: UInt32
        let feetDark: UInt32
        let eye: UInt32
        let flipper: UInt32
        let scarf: UInt32?
    }

    private static func kit(_ variant: Int) -> Kit {
        let beak = Palette.rgba(0xF07030, 255)
        let beakDark = Palette.rgba(0xC04820, 255)
        switch variant {
        case 1:
            return Kit(
                body: Palette.rgba(0x1A2848, 255),
                shade: Palette.rgba(0x121C34, 255),
                belly: Palette.rgba(0xF4F2EA, 255),
                bellyShade: Palette.rgba(0xC4CCD4, 255),
                beak: beak,
                beakDark: beakDark,
                feet: beak,
                feetDark: beakDark,
                eye: Palette.rgba(0x101820, 255),
                flipper: Palette.rgba(0x8AA0B8, 255),
                scarf: Palette.rgba(0xC43030, 255)
            )
        case 2:
            return Kit(
                body: Palette.rgba(0x2A2428, 255),
                shade: Palette.rgba(0x1A1618, 255),
                belly: Palette.rgba(0xF6F0E0, 255),
                bellyShade: Palette.rgba(0xD0C8B8, 255),
                beak: Palette.rgba(0xE87830, 255),
                beakDark: Palette.rgba(0xC05818, 255),
                feet: Palette.rgba(0xE87830, 255),
                feetDark: Palette.rgba(0xC05818, 255),
                eye: Palette.rgba(0x141014, 255),
                flipper: Palette.rgba(0xC8B8A0, 255),
                scarf: nil
            )
        default:
            // The reference: muted navy, white belly with a cool grey shade,
            // orange beak and feet, no outline.
            return Kit(
                body: Palette.rgba(0x2A3548, 255),
                shade: Palette.rgba(0x1E2838, 255),
                belly: Palette.rgba(0xFFFFFF, 255),
                bellyShade: Palette.rgba(0xC5D0D8, 255),
                beak: beak,
                beakDark: beakDark,
                feet: beak,
                feetDark: beakDark,
                eye: Palette.rgba(0x1A2030, 255),
                flipper: Palette.rgba(0x8AA8B8, 255),
                scarf: nil
            )
        }
    }

    private static func buildStandingPenguin(variant: Int, frame: Int, asleep: Bool) -> SKTexture {
        let look = kit(variant)
        var canvas = PixelCanvas(width: penguinWidth, height: penguinHeight, fill: Palette.clear)
        let twitch = frame == 0 ? 0 : 1
        let breath = asleep ? twitch : 0
        paintProfile(
            &canvas,
            look: look,
            ox: 2,
            oy: breath,
            flipperLift: asleep ? 0 : twitch,
            frontFootY: 0,
            backFootY: 0,
            asleep: asleep
        )
        return canvas.texture()
    }

    /// A waddle: the body leans, the far foot comes off the ice, and the near
    /// flipper ticks so the walk is a rock rather than a stride.
    private static func buildWaddlingPenguin(variant: Int, frame: Int) -> SKTexture {
        let look = kit(variant)
        var canvas = PixelCanvas(width: penguinWidth, height: penguinHeight, fill: Palette.clear)
        let left = frame == 0
        paintProfile(
            &canvas,
            look: look,
            ox: 2 + (left ? -1 : 1),
            oy: 0,
            flipperLift: left ? 1 : 0,
            frontFootY: left ? 1 : 0,
            backFootY: left ? 0 : 1,
            asleep: false
        )
        return canvas.texture()
    }

    private static func buildStandingChick(variant: Int, frame: Int, asleep: Bool) -> SKTexture {
        let look = kit(variant)
        var canvas = PixelCanvas(width: chickWidth, height: chickHeight, fill: Palette.clear)
        let twitch = frame == 0 ? 0 : 1
        paintChickProfile(
            &canvas,
            look: look,
            ox: 1,
            oy: asleep ? twitch : 0,
            flipperLift: asleep ? 0 : twitch,
            frontFootY: 0,
            backFootY: 0,
            asleep: asleep
        )
        return canvas.texture()
    }

    private static func buildWaddlingChick(variant: Int, frame: Int) -> SKTexture {
        let look = kit(variant)
        var canvas = PixelCanvas(width: chickWidth, height: chickHeight, fill: Palette.clear)
        let left = frame == 0
        paintChickProfile(
            &canvas,
            look: look,
            ox: 1 + (left ? -1 : 1),
            oy: 0,
            flipperLift: left ? 1 : 0,
            frontFootY: left ? 1 : 0,
            backFootY: left ? 0 : 1,
            asleep: false
        )
        return canvas.texture()
    }

    /// Facing right. The node flips when the penguin walks the other way.
    private static func paintProfile(
        _ canvas: inout PixelCanvas,
        look: Kit,
        ox: Int,
        oy: Int,
        flipperLift: Int,
        frontFootY: Int,
        backFootY: Int,
        asleep: Bool
    ) {
        canvas.fill(ox - 1, 7 + oy + flipperLift, 2, 3, look.body)
        canvas.fill(ox + 2, 16 + oy, 5, 1, look.body)
        canvas.fill(ox + 1, 14 + oy, 7, 2, look.body)
        canvas.fill(ox + 1, 13 + oy, 8, 1, look.body)
        canvas.fill(ox + 1, 5 + oy, 8, 8, look.body)
        canvas.fill(ox, 6 + oy, 10, 5, look.body)
        canvas.fill(ox + 2, 4 + oy, 6, 2, look.body)
        canvas.fill(ox + 3, 3 + oy, 5, 1, look.body)
        canvas.set(ox, 5 + oy, look.shade)
        canvas.fill(ox + 3, 6 + oy, 5, 5, look.belly)
        canvas.fill(ox + 3, 6 + oy, 1, 5, look.bellyShade)
        canvas.fill(ox + 4, 6 + oy, 4, 1, look.bellyShade)
        canvas.set(ox + 7, 7 + oy, look.bellyShade)
        if let scarf = look.scarf {
            canvas.fill(ox + 2, 11 + oy, 7, 1, scarf)
        }
        canvas.fill(ox + 8, 12 + oy, 3, 1, look.beak)
        canvas.fill(ox + 8, 11 + oy, 2, 1, look.beakDark)
        if asleep {
            canvas.fill(ox + 5, 14 + oy, 2, 1, look.shade)
        } else {
            canvas.set(ox + 6, 14 + oy, look.eye)
        }
        canvas.fill(ox + 9, 6 + oy + flipperLift, 2, 3, look.flipper)
        canvas.fill(ox + 2, backFootY + 1, 3, 1, look.feet)
        canvas.fill(ox + 2, backFootY, 3, 1, look.feetDark)
        canvas.fill(ox + 5, frontFootY + 1, 3, 1, look.feet)
        canvas.fill(ox + 5, frontFootY, 3, 1, look.feetDark)
    }

    private static func paintChickProfile(
        _ canvas: inout PixelCanvas,
        look: Kit,
        ox: Int,
        oy: Int,
        flipperLift: Int,
        frontFootY: Int,
        backFootY: Int,
        asleep: Bool
    ) {
        canvas.fill(ox - 1, 5 + oy + flipperLift, 2, 2, look.body)
        canvas.fill(ox + 1, 11 + oy, 5, 2, look.body)
        canvas.fill(ox + 1, 10 + oy, 6, 1, look.body)
        canvas.fill(ox + 1, 3 + oy, 6, 7, look.body)
        canvas.fill(ox, 4 + oy, 8, 4, look.body)
        canvas.fill(ox + 2, 2 + oy, 4, 2, look.body)
        canvas.fill(ox + 2, 4 + oy, 4, 4, look.belly)
        canvas.fill(ox + 2, 4 + oy, 1, 4, look.bellyShade)
        canvas.fill(ox + 3, 4 + oy, 3, 1, look.bellyShade)
        if let scarf = look.scarf {
            canvas.fill(ox + 1, 8 + oy, 5, 1, scarf)
        }
        canvas.fill(ox + 6, 9 + oy, 2, 1, look.beak)
        canvas.set(ox + 6, 8 + oy, look.beakDark)
        if asleep {
            canvas.fill(ox + 4, 11 + oy, 2, 1, look.shade)
        } else {
            canvas.set(ox + 5, 11 + oy, look.eye)
        }
        canvas.fill(ox + 7, 4 + oy + flipperLift, 2, 2, look.flipper)
        canvas.fill(ox + 1, backFootY + 1, 2, 1, look.feet)
        canvas.fill(ox + 1, backFootY, 2, 1, look.feetDark)
        canvas.fill(ox + 3, frontFootY + 1, 2, 1, look.feet)
        canvas.fill(ox + 3, frontFootY, 2, 1, look.feetDark)
    }
}

private extension Int {
    var penguinIndex: Int {
        let count = PixelArt.penguinVariants
        return ((self % count) + count) % count
    }
}
