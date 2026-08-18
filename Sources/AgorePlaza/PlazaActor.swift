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
    private var isLeaving = false
    private let nap: SKNode
    private var isSleeping = false

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
        // Blanking the texture is how the standing pose gets out of the sleeper's way,
        // and a nil-textured sprite falls back to drawing this colour.
        node.color = .clear
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

        nap = Self.makeNap(hash: hashValue, small: session.isSubagent, feetY: -node.size.height / 2)
        nap.isHidden = true
        node.addChild(nap)
    }

    /// The lying sprite is a sibling of the standing one rather than a swapped texture:
    /// the node's own position is what the walk actions steer, so the body has to lie
    /// down around it instead of moving it down onto the ground.
    private static func makeNap(hash: Int, small: Bool, feetY: CGFloat) -> SKNode {
        let root = SKNode()
        let scale: CGFloat = small ? 0.75 : 1
        let width = CGFloat(PixelArt.sleeperWidth) * scale
        let height = CGFloat(PixelArt.sleeperHeight) * scale
        root.position = CGPoint(x: 0, y: feetY + height / 2)
        root.zPosition = 1

        let body = SKSpriteNode(texture: PixelArt.sleeper(hash: hash, frame: 0))
        body.size = CGSize(width: width, height: height)
        body.texture?.filteringMode = .nearest
        body.run(.repeatForever(.animate(
            with: (0..<PixelArt.sleeperFrames).map { PixelArt.sleeper(hash: hash, frame: $0) },
            timePerFrame: 0.9,
            resize: false,
            restore: true
        )))
        root.addChild(body)

        // The head lies at the left end of the sprite, so the Z's rise from there.
        let headX = -width / 2 + 5 * scale
        for index in 0..<2 {
            let z = SKSpriteNode(texture: PixelArt.sleepZ())
            z.size = CGSize(width: 6, height: 6)
            z.position = CGPoint(x: headX, y: height / 2)
            z.alpha = 0
            z.texture?.filteringMode = .nearest
            z.run(.repeatForever(.sequence([
                .wait(forDuration: Double(index) * 1.1),
                .group([
                    .sequence([.fadeAlpha(to: 0.85, duration: 0.5), .fadeOut(withDuration: 1.1)]),
                    .moveBy(x: 5, y: 9, duration: 1.6),
                ]),
                .moveBy(x: -5, y: -9, duration: 0),
                .wait(forDuration: 2.2 - Double(index) * 1.1),
            ])))
            root.addChild(z)
        }
        return root
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
        // An idle agent has not left, it is just resting: dimming it says so without
        // taking the pixel person off the plaza.
        node.alpha = session.kind == .idle ? restingAlpha * 0.75 : restingAlpha
        target = anchors.spot(for: session, slot: slot)
        let distance = hypot(target.x - node.position.x, target.y - node.position.y)
        if distance > 4 {
            node.removeAction(forKey: "walk")
            let duration = min(2.8, TimeInterval(distance / 40))
            node.run(.move(to: target, duration: duration), withKey: "walk")
        }
        setSleeping(wantsSleep)
    }

    /// Leaving is losing your place on the roster, not going quiet: the plaza calls this
    /// only once presence is actually gone, and the person walks out through a gate.
    func leave(anchors: PlazaAnchors, completion: @escaping () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        setSleeping(false)
        node.removeAction(forKey: "walk")
        node.run(.sequence([
            .move(to: anchors.exit(near: node.position), duration: 1.2),
            .fadeOut(withDuration: 0.3),
        ])) { [node] in
            node.removeFromParent()
            completion()
        }
    }

    /// An idle agent only lies down once it has reached its bench: sleeping mid-stride
    /// would look like it fainted on the way.
    private var wantsSleep: Bool {
        kind == .idle && !isLeaving && node.action(forKey: "walk") == nil
    }

    /// The standing sprite is blanked rather than hidden, because hiding the node would
    /// take the name label and the Z's down with it.
    private func setSleeping(_ sleeping: Bool) {
        guard sleeping != isSleeping else { return }
        isSleeping = sleeping
        nap.isHidden = !sleeping
        node.texture = sleeping ? nil : standingTexture
    }

    private var standingTexture: SKTexture {
        let moving = node.action(forKey: "walk") != nil || isLeaving
            || kind == .running || kind == .thinking
        // The idle sprite carries the walk cycle, so an agent on its way to bed borrows
        // the waiting pose instead: standing and breathing rather than marching on the spot.
        let visualKind: ActivityKind = kind == .idle ? (moving ? .idle : .waiting) : kind
        return PixelArt.character(
            hash: hashValue,
            kind: visualKind,
            frame: frame,
            small: isSubagent
        )
    }

    func tick(anchors: PlazaAnchors) {
        frame = (frame + 1) % PixelArt.characterFrames
        setSleeping(wantsSleep)
        if !isSleeping {
            let texture = standingTexture
            if node.texture !== texture {
                node.texture = texture
            }
        }
        if kind == .running || kind == .thinking, !isLeaving, node.action(forKey: "walk") == nil {
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
        case .reading, .writing, .waiting, .idle:
            return benches[lane].offsetBy(dx: 0, dy: depth)
        case .thinking, .running:
            return strolls[lane].offsetBy(dx: 0, dy: depth)
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
