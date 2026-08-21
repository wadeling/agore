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
    private let theme: PlazaTheme
    private let geometry: PlazaGeometry
    private var names: (short: String, full: String)
    private var isHovered = false
    private var kind: ActivityKind
    private var frame = 0
    private var target: CGPoint
    private var isLeaving = false
    private let nap: SKNode
    private var isSleeping = false

    init(session: AgentSession, position: CGPoint, theme: PlazaTheme, geometry: PlazaGeometry) {
        self.id = session.id
        self.isSubagent = session.isSubagent
        self.kind = session.kind
        self.hashValue = session.id.hashValue
        self.target = position
        self.theme = theme
        self.geometry = geometry
        self.names = (session.displayName, session.fullName)
        self.restingAlpha = session.source == .demo ? 0.55 : 1
        let size = PixelArt.actorSize(theme: theme, small: session.isSubagent)
        let texture = PixelArt.actorBody(
            theme: theme,
            hash: hashValue,
            kind: session.kind,
            moving: false,
            frame: 0,
            small: session.isSubagent
        )
        node = SKSpriteNode(texture: texture)
        node.texture?.filteringMode = .nearest
        // Blanking the texture is how the standing pose gets out of the sleeper's way,
        // and a nil-textured sprite falls back to drawing this colour.
        node.color = .clear
        node.size = size
        node.position = position
        node.alpha = restingAlpha
        node.zPosition = 10 + (session.isSubagent ? 1 : 0)

        label = SKLabelNode(fontNamed: "Menlo")
        // The world is drawn two or three times over, so the name is measured against the
        // twelve-pixel figure it belongs to rather than against the screen.
        label.fontSize = 6
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .center
        label.fontColor = NSColor(calibratedWhite: 0.15, alpha: 1)
        label.position = CGPoint(x: 0, y: -(size.height / 2 + Self.labelGap(for: theme)))
        label.text = session.displayName
        label.zPosition = 2
        node.addChild(label)

        bubble = SKSpriteNode(texture: PixelArt.bubble())
        bubble.size = CGSize(width: 14, height: 12)
        bubble.position = CGPoint(x: size.width / 2 + 2, y: size.height / 2 + 2)
        bubble.zPosition = 3
        bubble.isHidden = session.kind != .waiting
        bubble.texture?.filteringMode = .nearest
        bubble.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1, duration: 0.7),
            .moveBy(x: 0, y: -1, duration: 0.7),
        ])))
        node.addChild(bubble)

        nap = Self.makeNap(
            theme: theme,
            hash: hashValue,
            small: session.isSubagent,
            feetY: -size.height / 2
        )
        nap.isHidden = true
        node.addChild(nap)
    }

    /// The lying sprite is a sibling of the standing one rather than a swapped texture:
    /// the node's own position is what the walk actions steer, so the body has to lie
    /// down around it instead of moving it down onto the ground.
    private static func makeNap(theme: PlazaTheme, hash: Int, small: Bool, feetY: CGFloat) -> SKNode {
        let root = SKNode()
        let scale: CGFloat = small ? 0.75 : 1
        let base = PixelArt.actorSleeperSize(theme: theme)
        let width = base.width * scale
        let height = base.height * scale
        root.position = CGPoint(x: 0, y: feetY + height / 2)
        root.zPosition = 1

        let body = SKSpriteNode(texture: PixelArt.actorSleeper(theme: theme, hash: hash, frame: 0))
        body.size = CGSize(width: width, height: height)
        body.texture?.filteringMode = .nearest
        body.run(.repeatForever(.animate(
            with: (0..<PixelArt.sleeperFrames).map {
                PixelArt.actorSleeper(theme: theme, hash: hash, frame: $0)
            },
            timePerFrame: 0.9,
            resize: false,
            restore: true
        )))
        root.addChild(body)

        // A sleeper's head is at the left end for a person or rabbit and the right
        // for a curled cat, and the Z's rise from whichever end that is.
        let headX = theme.actorsTurnToWalk
            ? width / 2 - 4 * scale
            : -width / 2 + 5 * scale
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

    /// World pixels between the figure's feet and the top of the name. Rabbits sit on
    /// a busy field, so the label tucks in tighter than a person on marble. A witch's
    /// broom already fills the gap, so the name sits closer still.
    private static func labelGap(for theme: PlazaTheme) -> CGFloat {
        switch theme {
        case .antonovka, .koriko: return 0
        case .agora, .seaside: return 2
        }
    }

    func apply(_ session: AgentSession, anchors: PlazaAnchors, slot: Int) {
        kind = session.kind
        names = (session.displayName, session.fullName)
        // Assigning it re-rasterises the label, and apply() runs on every refresh.
        if label.text != wantedName {
            label.text = wantedName
        }
        let hidesBubble = session.kind != .waiting
        if bubble.isHidden != hidesBubble {
            bubble.isHidden = hidesBubble
        }
        // An idle agent has not left, it is just resting: dimming it says so without
        // taking anyone off the plaza.
        node.alpha = session.kind == .idle ? restingAlpha * 0.75 : restingAlpha
        target = anchors.spot(for: session, slot: slot)
        let distance = hypot(target.x - node.position.x, target.y - node.position.y)
        if distance > 4 {
            node.removeAction(forKey: "walk")
            face(towards: target)
            let duration = min(2.8, TimeInterval(distance / 40))
            node.run(.move(to: target, duration: duration), withKey: "walk")
        }
        setSleeping(wantsSleep)
        keepNameInFrame()
    }

    private var wantedName: String {
        isHovered ? names.full : names.short
    }

    /// Whether the pointer is on this one. The name it wears is cut down to keep the plaza
    /// readable, so resting on a person spells it out — and lifts them over the neighbours
    /// whose names the longer one now overlaps.
    func contains(_ point: CGPoint) -> Bool {
        node.frame.insetBy(dx: -2, dy: -2).contains(point)
            || label.frame.offsetBy(dx: node.position.x, dy: node.position.y).contains(point)
    }

    func setHovered(_ hovered: Bool) {
        guard hovered != isHovered else { return }
        isHovered = hovered
        label.text = wantedName
        node.zPosition = (isSubagent ? 11 : 10) + (hovered ? 10 : 0)
        keepNameInFrame()
    }

    /// A name is far wider than the person wearing it, and one that says which agent it is
    /// wider still, so the people at either end of the plaza would have half of theirs cut
    /// off by the frame. The name slides along rather than the person moving in.
    private func keepNameInFrame() {
        let margin = label.frame.width / 2 + 1
        let low = margin - node.position.x
        let high = CGFloat(geometry.worldWidth) - margin - node.position.x
        // A name wider than the whole plaza has nowhere to go; centre it and let it spill.
        let offset = low > high ? (low + high) / 2 : min(max(0, low), high)
        // Turning around mirrors the whole node, so the offset has to be mirrored back.
        let local = offset * node.xScale
        if abs(label.position.x - local) > 0.5 {
            label.position.x = local
        }
    }

    /// Leaving is losing your place on the roster, not going quiet: the plaza calls this
    /// only once presence is actually gone, and the actor walks out through a gate.
    func leave(anchors: PlazaAnchors, completion: @escaping () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        setSleeping(false)
        node.removeAction(forKey: "walk")
        let gate = anchors.exit(near: node.position)
        face(towards: gate)
        node.run(.sequence([
            .move(to: gate, duration: 1.2),
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
        node.texture = sleeping ? nil : bodyTexture
    }

    /// A cat or a witch is drawn in profile and has to turn around to walk the other
    /// way, while a person or rabbit is drawn face-on and reads the same either way.
    /// Turning mirrors the whole node, so the name mirrors itself back to stay readable.
    private func face(towards point: CGPoint) {
        guard theme.actorsTurnToWalk, point.x != node.position.x else { return }
        let facing: CGFloat = point.x > node.position.x ? 1 : -1
        guard node.xScale != facing else { return }
        node.xScale = facing
        label.xScale = facing
    }

    private var bodyTexture: SKTexture {
        let moving = node.action(forKey: "walk") != nil || isLeaving
            || kind == .running || kind == .thinking
        return PixelArt.actorBody(
            theme: theme,
            hash: hashValue,
            kind: kind,
            moving: moving,
            frame: frame,
            small: isSubagent
        )
    }

    func tick(anchors: PlazaAnchors) {
        frame = (frame + 1) % PixelArt.characterFrames
        setSleeping(wantsSleep)
        if !isSleeping {
            let texture = bodyTexture
            if node.texture !== texture {
                node.texture = texture
            }
        }
        if kind == .running || kind == .thinking, !isLeaving, node.action(forKey: "walk") == nil {
            let wander = CGPoint(
                x: node.position.x + CGFloat.random(in: -26...26),
                y: node.position.y + CGFloat.random(in: anchors.geometry.isStrip ? -3...3 : -18...18)
            )
            let step = anchors.walkable(wander)
            face(towards: step)
            node.run(.move(to: step, duration: 1.4), withKey: "walk")
        }
        keepNameInFrame()
    }

}

struct PlazaAnchors {
    let geometry: PlazaGeometry
    let benches: [CGPoint]
    let strolls: [CGPoint]
    let exits: [CGPoint]

    init(geometry: PlazaGeometry) {
        self.geometry = geometry
        benches = geometry.restSpots
        strolls = geometry.strollSpots
        exits = geometry.exits
    }

    func walkable(_ point: CGPoint) -> CGPoint {
        var x = min(max(point.x, 24), CGFloat(geometry.worldWidth) - 24)
        let y = min(max(point.y, geometry.walkMinY), geometry.walkMaxY)
        if geometry.centerpieceZoneX.contains(x), geometry.centerpieceZoneY.contains(y) {
            x = x < geometry.centerpieceCenter.x
                ? geometry.centerpieceZoneX.lowerBound
                : geometry.centerpieceZoneX.upperBound
        }
        return CGPoint(x: x, y: y)
    }

    func spawn() -> CGPoint {
        exits.randomElement() ?? CGPoint(x: 24, y: geometry.walkMinY)
    }

    func spot(for session: AgentSession, slot: Int) -> CGPoint {
        let lane = slot % benches.count
        let row = (slot / benches.count) % 2
        let depth = CGFloat(row) * (geometry.isStrip ? -4 : 16)
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
