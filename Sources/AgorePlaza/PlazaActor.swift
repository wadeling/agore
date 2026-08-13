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
        label.text = session.displayName
        bubble.isHidden = session.kind != .waiting
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
        frame += 1
        let moving = node.action(forKey: "walk") != nil || kind == .running || kind == .thinking
        let visualKind = moving && kind == .idle ? .thinking : kind
        let texture = PixelArt.character(
            hash: hashValue,
            kind: visualKind,
            frame: frame,
            small: isSubagent
        )
        node.texture = texture
        // Busy agents pace the plaza; seated ones stay put and breathe instead.
        if kind == .running || kind == .thinking, node.action(forKey: "walk") == nil {
            let wander = CGPoint(
                x: node.position.x + CGFloat.random(in: -26...26),
                y: node.position.y + CGFloat.random(in: -3...3)
            )
            node.run(.move(to: anchors.walkable(wander), duration: 1.4), withKey: "walk")
        }
    }
}

struct PlazaAnchors {
    /// The strip is one row deep, so slots are spread along x and only shift slightly in y.
    static let restingY = CGFloat(PixelArt.groundY + PixelArt.characterHeight / 2)
    static let strollingY = restingY - 3

    /// Slots alternate left and right of the fountain, so the first arrivals frame it
    /// instead of standing in the water.
    static let lanes: [CGFloat] = [138, 222, 92, 268, 46, 314, 20, 340]

    let benches: [CGPoint] = PlazaAnchors.lanes.map {
        CGPoint(x: $0, y: PlazaAnchors.restingY)
    }
    let strolls: [CGPoint] = PlazaAnchors.lanes.map {
        CGPoint(x: $0 + 10, y: PlazaAnchors.strollingY)
    }
    let exits: [CGPoint] = [
        CGPoint(x: 8, y: PlazaAnchors.restingY),
        CGPoint(x: CGFloat(PixelArt.worldWidth) - 8, y: PlazaAnchors.restingY),
    ]

    static let fountainZone: ClosedRange<CGFloat> = 156...204

    /// Keeps a wandering actor on the floor and out of the basin.
    func walkable(_ point: CGPoint) -> CGPoint {
        var x = min(max(point.x, 20), CGFloat(PixelArt.worldWidth) - 20)
        if PlazaAnchors.fountainZone.contains(x) {
            x = x < CGFloat(PixelArt.fountainCenterX)
                ? PlazaAnchors.fountainZone.lowerBound
                : PlazaAnchors.fountainZone.upperBound
        }
        let y = min(
            max(point.y, PlazaAnchors.strollingY - 2),
            PlazaAnchors.restingY + 2
        )
        return CGPoint(x: x, y: y)
    }

    func spawn() -> CGPoint {
        exits.randomElement() ?? CGPoint(x: 8, y: PlazaAnchors.restingY)
    }

    func spot(for session: AgentSession, slot: Int) -> CGPoint {
        let lane = slot % PlazaAnchors.lanes.count
        // Past the first eight the plaza fills a second row nearer the viewer instead of
        // stacking newcomers on top of the agents already there.
        let row = (slot / PlazaAnchors.lanes.count) % 2
        let depth = CGFloat(row) * -4
        switch session.kind {
        case .reading, .writing, .waiting:
            return benches[lane].offsetBy(dy: depth)
        case .thinking, .running:
            return strolls[lane].offsetBy(dy: depth)
        case .idle:
            return exit(near: benches[lane])
        }
    }

    func exit(near point: CGPoint) -> CGPoint {
        exits.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? exits[0]
    }
}

private extension CGPoint {
    func offsetBy(dy: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y + dy)
    }
}
