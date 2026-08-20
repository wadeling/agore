import SpriteKit
import AgoreCore

enum CatPose: Hashable, Sendable {
    case sitting
    case walking
}

extension PixelArt {
    /// Half the height of a person, which is about right for a cat and still leaves room
    /// for an ear, an eye and a tail.
    static let catWidth = 12
    static let catHeight = 11
    /// A subagent's kitten, at the same three quarters that shrinks a subagent person.
    static let kittenWidth = 9
    static let kittenHeight = 8
    static let catSleeperWidth = 13
    static let catSleeperHeight = 8
    static let catVariants = 3
    static let catFrames = 2

    static func catSize(small: Bool) -> CGSize {
        small
            ? CGSize(width: kittenWidth, height: kittenHeight)
            : CGSize(width: catWidth, height: catHeight)
    }

    static func cat(variant: Int, pose: CatPose, frame: Int, small: Bool = false) -> SKTexture {
        let coat = variant.coatIndex
        let step = phase(frame, over: catFrames)
        return cached(.cat(variant: coat, pose: pose, phase: step, small: small)) {
            switch (pose, small) {
            case (.sitting, false): return buildSittingCat(variant: coat, frame: step)
            case (.walking, false): return buildWalkingCat(variant: coat, frame: step)
            case (.sitting, true): return buildSittingKitten(variant: coat, frame: step)
            case (.walking, true): return buildWalkingKitten(variant: coat, frame: step)
            }
        }
    }

    /// A cat curled up asleep, drawn in the same coat as its sitting sprite so the one who
    /// dozed off is still recognisable.
    static func catSleeper(variant: Int, frame: Int) -> SKTexture {
        let coat = variant.coatIndex
        let breath = phase(frame, over: sleeperFrames)
        return cached(.catSleeper(variant: coat, phase: breath)) {
            buildSleepingCat(variant: coat, breath: breath)
        }
    }

    private struct Coat {
        let body: UInt32
        let shade: UInt32
        let belly: UInt32
        let tabby: Bool
    }

    private static func coat(_ variant: Int) -> Coat {
        switch variant {
        case 1:
            return Coat(
                body: Palette.rgba(0xEFA24A, 255),
                shade: Palette.rgba(0xC7762A, 255),
                belly: Palette.rgba(0xFBE2BE, 255),
                tabby: true
            )
        case 2:
            return Coat(
                body: Palette.rgba(0xA9B2BC, 255),
                shade: Palette.rgba(0x7A8592, 255),
                belly: Palette.rgba(0xE4E9EE, 255),
                tabby: true
            )
        default:
            return Coat(
                body: Palette.rgba(0xF6F0E2, 255),
                shade: Palette.rgba(0xD8CEB8, 255),
                belly: Palette.rgba(0xFFFCF4, 255),
                tabby: false
            )
        }
    }

    private static let nose = Palette.rgba(0xE08A8A, 255)

    /// A cat sitting on its haunches, facing right: a wide body, a narrower head stepped
    /// up over the shoulders, and a tail that is the only thing that moves.
    private static func buildSittingCat(variant: Int, frame: Int) -> SKTexture {
        let fur = coat(variant)
        var canvas = PixelCanvas(width: catWidth, height: catHeight, fill: Palette.clear)
        canvas.fill(2, 0, 7, 5, fur.body)
        canvas.fill(5, 5, 5, 4, fur.body)
        // Ears sit on the corners of the head, so the outline only has a single pixel of
        // forehead to fill between them instead of a dark bar across the whole skull.
        canvas.fill(5, 9, 2, 1, fur.body)
        canvas.fill(8, 9, 2, 1, fur.body)

        // The tail rises in the gap behind the head, and stays one pixel wide: outlined on
        // both sides, anything thicker reads as a second head rather than as a tail.
        canvas.fill(1, 4, 1, 4, fur.body)
        canvas.set(frame == 0 ? 2 : 0, 8, fur.body)

        canvas.fill(6, 1, 3, 3, fur.belly)
        canvas.fill(8, 5, 2, 2, fur.belly)
        canvas.fill(2, 0, 2, 1, fur.belly)
        canvas.fill(6, 0, 3, 1, fur.belly)
        // Clearing one pixel where the head meets the shoulders lets the outline draw a
        // neck, which is what stops the whole cat reading as a single loaf.
        canvas.set(5, 5, Palette.clear)
        canvas.fill(2, 1, 1, 3, fur.shade)
        if fur.tabby {
            canvas.set(3, 4, fur.shade)
            canvas.set(5, 4, fur.shade)
            canvas.set(6, 8, fur.shade)
            canvas.set(1, 3, fur.shade)
        }
        canvas.set(7, 7, Palette.ink)
        canvas.set(9, 5, nose)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// The same cat on the move: body level, tail up, legs alternating.
    private static func buildWalkingCat(variant: Int, frame: Int) -> SKTexture {
        let fur = coat(variant)
        var canvas = PixelCanvas(width: catWidth, height: catHeight, fill: Palette.clear)
        canvas.fill(2, 2, 6, 3, fur.body)
        canvas.fill(7, 3, 3, 3, fur.body)
        canvas.set(7, 6, fur.body)
        canvas.set(9, 6, fur.body)
        canvas.fill(1, frame == 0 ? 4 : 3, 1, 3, fur.body)

        for x in (frame == 0 ? [2, 4, 6, 8] : [3, 4, 7, 8]) {
            canvas.fill(x, 0, 1, 3, fur.body)
        }

        canvas.fill(3, 2, 3, 1, fur.belly)
        canvas.fill(9, 3, 1, 2, fur.belly)
        if fur.tabby {
            canvas.set(4, 4, fur.shade)
            canvas.set(6, 4, fur.shade)
            canvas.set(1, 5, fur.shade)
        }
        canvas.set(8, 4, Palette.ink)
        canvas.set(9, 3, nose)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    /// Curled on its side with the tail laid out in front and one closed eye.
    private static func buildSleepingCat(variant: Int, breath: Int) -> SKTexture {
        let fur = coat(variant)
        var canvas = PixelCanvas(width: catSleeperWidth, height: catSleeperHeight, fill: Palette.clear)
        canvas.fill(1, 0, 6, 1, fur.body)
        canvas.ellipse(5, 3, 4, 2, fur.body)
        canvas.disk(4, 3 + breath, 2, fur.body)
        // A blunt head rather than a disk, so the ears have shoulders to stand on and the
        // outline can draw a gap between them.
        canvas.fill(8, 2, 4, 3, fur.body)
        canvas.set(8, 5, fur.body)
        canvas.set(10, 5, fur.body)

        canvas.fill(3, 1, 5, 1, fur.belly)
        if fur.tabby {
            canvas.set(3, 4, fur.shade)
            canvas.set(6, 4, fur.shade)
            canvas.set(4, 0, fur.shade)
        }
        canvas.fill(9, 3, 2, 1, Palette.ink)
        canvas.set(11, 3, nose)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildSittingKitten(variant: Int, frame: Int) -> SKTexture {
        let fur = coat(variant)
        var canvas = PixelCanvas(width: kittenWidth, height: kittenHeight, fill: Palette.clear)
        canvas.fill(1, 0, 5, 3, fur.body)
        canvas.fill(4, 3, 4, 3, fur.body)
        canvas.set(4, 6, fur.body)
        canvas.set(7, 6, fur.body)
        canvas.fill(0, 2, 1, frame == 0 ? 3 : 2, fur.body)

        canvas.fill(4, 0, 2, 1, fur.belly)
        canvas.fill(6, 3, 2, 1, fur.belly)
        if fur.tabby {
            canvas.set(2, 2, fur.shade)
        }
        canvas.set(6, 4, Palette.ink)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }

    private static func buildWalkingKitten(variant: Int, frame: Int) -> SKTexture {
        let fur = coat(variant)
        var canvas = PixelCanvas(width: kittenWidth, height: kittenHeight, fill: Palette.clear)
        canvas.fill(1, 1, 5, 2, fur.body)
        canvas.fill(5, 2, 3, 2, fur.body)
        canvas.set(5, 4, fur.body)
        canvas.set(7, 4, fur.body)
        canvas.fill(0, 2, 1, 2, fur.body)

        for x in (frame == 0 ? [1, 3, 5] : [2, 4, 6]) {
            canvas.set(x, 0, fur.body)
        }
        canvas.fill(6, 2, 2, 1, fur.belly)
        canvas.set(6, 3, Palette.ink)
        canvas.outline(Palette.ink)
        return canvas.texture()
    }
}

private extension Int {
    /// A coat per hash, so an agent keeps the same cat for as long as it is on the plaza.
    var coatIndex: Int {
        let count = PixelArt.catVariants
        return ((self % count) + count) % count
    }
}
