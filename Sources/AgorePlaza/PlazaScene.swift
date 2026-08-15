import SpriteKit
import AgoreCore

public final class PlazaScene: SKScene {
    private let layout: PlazaLayout
    private let anchors: PlazaAnchors
    private var actors: [String: PlazaActor] = [:]
    private var slots: [String: Int] = [:]
    private var sleeper: SKNode?
    private var tickAccum: TimeInterval = 0
    private var lastTime: TimeInterval = 0

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
            let ground = SKSpriteNode(texture: PixelArt.plazaBackground(layout))
            ground.name = "ground"
            ground.size = size
            ground.position = CGPoint(x: size.width / 2, y: size.height / 2)
            ground.zPosition = 0
            ground.alpha = AgoreConstants.groundOpacity
            ground.texture?.filteringMode = .nearest
            addChild(ground)
            addFountain()
        }
        if actors.isEmpty {
            showSleeper()
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
        node.alpha = AgoreConstants.groundOpacity
        node.run(.repeatForever(.animate(
            with: (0..<3).map { PixelArt.fountainFrame($0) },
            timePerFrame: 0.24,
            resize: false,
            restore: true
        )))
        addChild(node)
    }

    public func sync(sessions: [AgentSession]) {
        let incomingIds = Set(sessions.map(\.id))

        for (id, actor) in actors where !incomingIds.contains(id) {
            actor.node.run(.sequence([
                .fadeOut(withDuration: 0.25),
                .removeFromParent(),
            ]))
            actors.removeValue(forKey: id)
            slots.removeValue(forKey: id)
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

        if sessions.isEmpty {
            showSleeper()
        } else {
            hideSleeper()
        }
    }

    private func showSleeper() {
        guard sleeper == nil else { return }
        let node = SKNode()
        node.position = anchors.sleeper
        node.zPosition = 9

        let body = SKSpriteNode(texture: PixelArt.sleeper(frame: 0))
        body.size = CGSize(width: 22, height: 12)
        body.position = CGPoint(x: 0, y: 6)
        body.texture?.filteringMode = .nearest
        body.run(.repeatForever(.animate(
            with: (0..<2).map { PixelArt.sleeper(frame: $0) },
            timePerFrame: 0.9,
            resize: false,
            restore: true
        )))
        node.addChild(body)

        for index in 0..<2 {
            let z = SKSpriteNode(texture: PixelArt.sleepZ())
            z.size = CGSize(width: 6, height: 6)
            z.position = CGPoint(x: -4, y: 12)
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
            node.addChild(z)
        }

        addChild(node)
        sleeper = node
    }

    private func hideSleeper() {
        guard let sleeper else { return }
        self.sleeper = nil
        sleeper.run(.sequence([
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
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
        tickAccum += dt
        guard tickAccum >= 0.18 else { return }
        tickAccum = 0
        for actor in actors.values {
            actor.tick(anchors: anchors)
        }
    }
}
