import SpriteKit
import AgoreCore

/// Scenery that moves on its own. No agent is behind a cat, so it only has to look like
/// it lives here: sit, flick its tail, and every so often wander a few pixels along the
/// ground before settling again.
final class PlazaCat {
    let node: SKSpriteNode
    private let variant: Int
    private let home: CGPoint
    private let geometry: PlazaGeometry

    init(variant: Int, home: CGPoint, geometry: PlazaGeometry) {
        self.variant = variant
        self.home = home
        self.geometry = geometry
        node = SKSpriteNode(texture: PixelArt.cat(variant: variant, pose: .sitting, frame: 0))
        node.size = CGSize(width: PixelArt.catWidth, height: PixelArt.catHeight)
        node.position = home
        // Under the people, over the paving: a cat should never hide an agent.
        node.zPosition = 9
        node.texture?.filteringMode = .nearest
        node.xScale = Bool.random() ? 1 : -1
        settle()
    }

    private func settle() {
        node.removeAction(forKey: "pose")
        node.run(.repeatForever(.animate(
            with: (0..<PixelArt.catFrames).map { PixelArt.cat(variant: variant, pose: .sitting, frame: $0) },
            timePerFrame: 0.9,
            resize: false,
            restore: true
        )), withKey: "pose")
        node.run(.sequence([
            .wait(forDuration: Double.random(in: 9...24)),
            .run { [weak self] in self?.wander() },
        ]), withKey: "plan")
    }

    private func wander() {
        let target = nextSpot()
        let distance = hypot(target.x - node.position.x, target.y - node.position.y)
        guard distance > 2 else {
            settle()
            return
        }
        if target.x != node.position.x {
            node.xScale = target.x > node.position.x ? 1 : -1
        }
        node.removeAction(forKey: "pose")
        node.run(.repeatForever(.animate(
            with: (0..<PixelArt.catFrames).map { PixelArt.cat(variant: variant, pose: .walking, frame: $0) },
            timePerFrame: 0.22,
            resize: false,
            restore: true
        )), withKey: "pose")
        node.run(.sequence([
            .move(to: target, duration: TimeInterval(distance / 11)),
            .run { [weak self] in self?.settle() },
        ]), withKey: "plan")
    }

    /// A cat keeps to its own corner of the plaza, and never strays onto the water or
    /// out through the scenery.
    private func nextSpot() -> CGPoint {
        let reach: CGFloat = geometry.isStrip ? 14 : 26
        let sway: CGFloat = geometry.isStrip ? 1 : 6
        let x = min(max(home.x + CGFloat.random(in: -reach...reach), 8), CGFloat(geometry.worldWidth) - 8)
        let ceiling = CGFloat(geometry.horizonY) - 2
        let y = min(max(home.y + CGFloat.random(in: -sway...sway), 4), ceiling)
        return CGPoint(x: x, y: y)
    }
}
