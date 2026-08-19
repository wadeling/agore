import SpriteKit
import AgoreCore

public final class PlazaScene: SKScene {
    private let layout: PlazaLayout
    private let anchors: PlazaAnchors
    private var actors: [String: PlazaActor] = [:]
    private var leaving: [PlazaActor] = []
    private var slots: [String: Int] = [:]
    private var tickAccum: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var ground: SKSpriteNode?
    private var period: PlazaPeriod = .current()
    private var periodAccum: TimeInterval = 0

    public init(layout: PlazaLayout) {
        self.layout = layout
        self.anchors = PlazaAnchors(layout: layout)
        super.init(size: layout.worldSize)
        // Strip is 2x, courtyard is 3x of an integer world, so aspectFit stays crisp.
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = .clear
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        if childNode(withName: "ground") == nil {
            period = .current()
            let ground = SKSpriteNode(texture: PixelArt.plazaBackground(layout, period: period))
            ground.name = "ground"
            ground.size = size
            ground.position = CGPoint(x: size.width / 2, y: size.height / 2)
            ground.zPosition = 0
            ground.alpha = AgoreConstants.groundOpacity
            ground.texture?.filteringMode = .nearest
            addChild(ground)
            self.ground = ground
            addFountain()
            addAmbient()
        }
    }

    private func addFountain() {
        let node = SKSpriteNode(texture: PixelArt.fountainFrame(0))
        node.size = CGSize(width: PixelArt.fountainWidth, height: PixelArt.fountainHeight)
        node.position = CGPoint(
            x: layout.fountainCenter.x,
            y: layout.fountainCenter.y + CGFloat(PixelArt.fountainHeight) / 2 - 4
        )
        node.zPosition = 5
        node.alpha = 0.92
        node.run(.repeatForever(.animate(
            with: (0..<3).map { PixelArt.fountainFrame($0) },
            timePerFrame: 0.24,
            resize: false,
            restore: true
        )))
        addChild(node)
    }

    public func sync(sessions: [AgentSession]) {
        refreshPeriod()
        let incomingIds = Set(sessions.map(\.id))

        for (id, actor) in actors where !incomingIds.contains(id) {
            actors.removeValue(forKey: id)
            slots.removeValue(forKey: id)
            leaving.append(actor)
            actor.leave(anchors: anchors) { [weak self] in
                self?.leaving.removeAll { $0 === actor }
            }
        }

        for session in sessions {
            let slot = slot(for: session.id)
            if let actor = actors[session.id] {
                actor.apply(session, anchors: anchors, slot: slot)
            } else {
                let start = anchors.spawn()
                let actor = PlazaActor(session: session, position: start)
                actors[session.id] = actor
                addChild(actor.node)
                actor.apply(session, anchors: anchors, slot: slot)
            }
        }
    }

    private func slot(for id: String) -> Int {
        if let slot = slots[id] { return slot }
        let taken = Set(slots.values)
        var candidate = 0
        while taken.contains(candidate) { candidate += 1 }
        slots[id] = candidate
        return candidate
    }

    public override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = currentTime - lastTime
        lastTime = currentTime
        periodAccum += dt
        if periodAccum >= 30 {
            periodAccum = 0
            refreshPeriod()
        }
        tickAccum += dt
        guard tickAccum >= 0.18 else { return }
        tickAccum = 0
        for actor in actors.values {
            actor.tick(anchors: anchors)
        }
        for actor in leaving {
            actor.tick(anchors: anchors)
        }
    }

    private func refreshPeriod() {
        let next = PlazaPeriod.current()
        guard next != period, let ground else { return }
        period = next
        ground.texture = PixelArt.plazaBackground(layout, period: period)
        ground.texture?.filteringMode = .nearest
    }

    private func addAmbient() {
        for tree in layout.oliveTrees {
            let canopy = [3, 5, 7][min(max(tree.size, 0), 2)]
            let origin = CGPoint(
                x: CGFloat(tree.x),
                y: CGFloat(tree.y + canopy * 2 + 3)
            )
            for _ in 0..<(tree.size == 0 ? 1 : 2) {
                let leaf = SKSpriteNode(texture: PixelArt.leaf())
                leaf.size = CGSize(width: 3, height: 3)
                leaf.zPosition = 6
                leaf.alpha = 0
                leaf.texture?.filteringMode = .nearest
                addChild(leaf)
                dropLeaf(leaf, origin: origin)
            }
        }
        addBird()
    }

    private func dropLeaf(_ leaf: SKSpriteNode, origin: CGPoint) {
        leaf.position = origin
        leaf.zRotation = 0
        leaf.alpha = 0
        let drift = CGFloat.random(in: -12...16)
        let fall = CGFloat.random(in: 10...22)
        leaf.run(.sequence([
            .wait(forDuration: Double.random(in: 2.5...9)),
            .fadeAlpha(to: AgoreConstants.groundOpacity, duration: 0.15),
            .group([
                .moveBy(x: drift, y: -fall, duration: Double.random(in: 2.8...4.4)),
                .rotate(byAngle: CGFloat.random(in: 1.2...2.8), duration: 3.6),
            ]),
            .fadeOut(withDuration: 0.35),
            .run { [weak self] in
                self?.dropLeaf(leaf, origin: origin)
            },
        ]))
    }

    private func addBird() {
        let bird = SKSpriteNode(texture: PixelArt.bird(0))
        bird.size = CGSize(width: 7, height: 5)
        bird.zPosition = 12
        bird.alpha = 0
        bird.texture?.filteringMode = .nearest
        bird.run(.repeatForever(.animate(
            with: [PixelArt.bird(0), PixelArt.bird(1)],
            timePerFrame: 0.18,
            resize: false,
            restore: true
        )))
        addChild(bird)
        flyBird(bird)
    }

    private func flyBird(_ bird: SKSpriteNode) {
        let fromLeft = Bool.random()
        let y = CGFloat.random(in: layout.birdAltitude)
        let startX: CGFloat = fromLeft ? -8 : CGFloat(layout.worldWidth) + 8
        let endX: CGFloat = fromLeft ? CGFloat(layout.worldWidth) + 8 : -8
        bird.xScale = fromLeft ? 1 : -1
        bird.position = CGPoint(x: startX, y: y)
        bird.alpha = 0
        let duration = max(6.5, TimeInterval(layout.worldWidth) / 38)
        bird.run(.sequence([
            .wait(forDuration: Double.random(in: 8...16)),
            .fadeAlpha(to: 0.9, duration: 0.2),
            .moveTo(x: endX, duration: duration),
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in
                self?.flyBird(bird)
            },
        ]))
    }
}
