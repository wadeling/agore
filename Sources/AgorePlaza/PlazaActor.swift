import SpriteKit
import AgoreCore

final class PlazaActor {
    let id: String
    let node: SKSpriteNode
    let label: SKLabelNode
    let bubble: SKSpriteNode
    let isSubagent: Bool
    private let hashValue: Int
    private let restingAlpha: CGFloat
    private var kind: ActivityKind
    private var frame = 0
    private var target: CGPoint

    init(session: AgentSession, position: CGPoint) {
        self.id = session.id
        self.isSubagent = session.isSubagent
        self.kind = session.kind
        self.hashValue = session.id.hashValue
        self.target = position
        self.restingAlpha = session.source == .demo ? 0.55 : 1
        let texture = PixelArt.character(hash: hashValue, kind: session.kind, frame: 0, small: session.isSubagent)
        node = SKSpriteNode(texture: texture)
        node.texture?.filteringMode = .nearest
        node.size = session.isSubagent ? CGSize(width: 12, height: 16) : CGSize(width: 16, height: 20)
        node.position = position
        node.alpha = restingAlpha
        node.zPosition = 10 + (session.isSubagent ? 1 : 0)

        label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 8
        label.fontColor = NSColor(calibratedWhite: 0.15, alpha: 1)
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -12)
        label.text = session.displayName
        label.zPosition = 2
        node.addChild(label)

        bubble = SKSpriteNode(texture: PixelArt.bubble())
        bubble.size = CGSize(width: 14, height: 12)
        bubble.position = CGPoint(x: 10, y: 12)
        bubble.zPosition = 3
        bubble.isHidden = session.kind != .waiting
        bubble.texture?.filteringMode = .nearest
        bubble.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1, duration: 0.7),
            .moveBy(x: 0, y: -1, duration: 0.7),
        ])))
        node.addChild(bubble)
    }

    func apply(_ session: AgentSession, anchors: PlazaAnchors, slot: Int) {
        kind = session.kind
        // Assigning either one re-rasterises the label, and apply() runs on every refresh.
        if label.text != session.displayName {
            label.text = session.displayName
        }
        let hidesBubble = session.kind != .waiting
        if bubble.isHidden != hidesBubble {
            bubble.isHidden = hidesBubble
        }
        if session.kind != .idle {
            node.alpha = restingAlpha
            node.removeAction(forKey: "leave")
        }
        target = anchors.spot(for: session, slot: slot)
        let distance = hypot(target.x - node.position.x, target.y - node.position.y)
        if distance > 4 {
            node.removeAction(forKey: "walk")
            let duration = min(2.8, TimeInterval(distance / 40))
            node.run(.move(to: target, duration: duration), withKey: "walk")
        }
        if session.kind == .idle {
            let exit = anchors.exit(near: node.position)
            node.removeAction(forKey: "walk")
            node.run(.sequence([
                .move(to: exit, duration: 1.6),
                .fadeOut(withDuration: 0.3),
            ]), withKey: "leave")
        }
    }

    func tick(anchors: PlazaAnchors) {
        frame = (frame + 1) % PixelArt.characterFrames
        let moving = node.action(forKey: "walk") != nil || kind == .running || kind == .thinking
        let visualKind = moving && kind == .idle ? .thinking : kind
        let texture = PixelArt.character(
            hash: hashValue,
            kind: visualKind,
            frame: frame,
            small: isSubagent
        )
        if node.texture !== texture {
            node.texture = texture
        }
        if kind == .running || kind == .thinking, node.action(forKey: "walk") == nil {
            let wander = CGPoint(
                x: node.position.x + CGFloat.random(in: -26...26),
                y: node.position.y + CGFloat.random(in: anchors.layout == .strip ? -3...3 : -18...18)
            )
            node.run(.move(to: anchors.walkable(wander), duration: 1.4), withKey: "walk")
        }
    }
}

struct PlazaAnchors {
    let layout: PlazaLayout
    let benches: [CGPoint]
    let strolls: [CGPoint]
    let exits: [CGPoint]
    let sleeper: CGPoint

    init(layout: PlazaLayout) {
        self.layout = layout
        switch layout {
        case .strip:
            let restY = CGFloat(layout.groundY + PixelArt.characterHeight / 2)
            let lanes: [CGFloat] = [138, 222, 92, 268, 46, 314, 20, 340]
            benches = lanes.map { CGPoint(x: $0, y: restY) }
            strolls = lanes.map { CGPoint(x: $0 + 10, y: restY - 3) }
            exits = [
                CGPoint(x: 8, y: restY),
                CGPoint(x: CGFloat(layout.worldWidth) - 8, y: restY),
            ]
            sleeper = CGPoint(x: 138, y: CGFloat(layout.groundY))
        case .courtyard:
            // Keep the first arrivals around the fountain, well inside the frame.
            benches = [
                CGPoint(x: 88, y: 100),
                CGPoint(x: 152, y: 100),
                CGPoint(x: 72, y: 128),
                CGPoint(x: 168, y: 128),
                CGPoint(x: 96, y: 156),
                CGPoint(x: 144, y: 156),
                CGPoint(x: 80, y: 72),
                CGPoint(x: 160, y: 72),
            ]
            strolls = [
                CGPoint(x: 100, y: 112),
                CGPoint(x: 140, y: 112),
                CGPoint(x: 64, y: 100),
                CGPoint(x: 176, y: 100),
                CGPoint(x: 108, y: 148),
                CGPoint(x: 132, y: 148),
                CGPoint(x: 96, y: 80),
                CGPoint(x: 144, y: 80),
            ]
            exits = [
                CGPoint(x: 24, y: 32),
                CGPoint(x: 216, y: 32),
                CGPoint(x: 24, y: 168),
                CGPoint(x: 216, y: 168),
            ]
            sleeper = CGPoint(x: 88, y: 72)
        }
    }

    func walkable(_ point: CGPoint) -> CGPoint {
        var x = min(max(point.x, 24), CGFloat(layout.worldWidth) - 24)
        var y = min(max(point.y, layout.walkMinY), layout.walkMaxY)
        if layout.fountainZoneX.contains(x), layout.fountainZoneY.contains(y) {
            x = x < layout.fountainCenter.x
                ? layout.fountainZoneX.lowerBound
                : layout.fountainZoneX.upperBound
        }
        return CGPoint(x: x, y: y)
    }

    func spawn() -> CGPoint {
        exits.randomElement() ?? CGPoint(x: 24, y: layout.walkMinY)
    }

    func spot(for session: AgentSession, slot: Int) -> CGPoint {
        let lane = slot % benches.count
        let row = (slot / benches.count) % 2
        let depth = CGFloat(row) * (layout == .strip ? -4 : 16)
        switch session.kind {
        case .reading, .writing, .waiting:
            return benches[lane].offsetBy(dx: 0, dy: depth)
        case .thinking, .running:
            return strolls[lane].offsetBy(dx: 0, dy: depth)
        case .idle:
            return exit(near: benches[lane])
        }
    }

    func exit(near point: CGPoint) -> CGPoint {
        exits.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? exits[0]
    }
}

private extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
