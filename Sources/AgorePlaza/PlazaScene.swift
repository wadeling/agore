import SpriteKit
import AgoreCore

public final class PlazaScene: SKScene {
    private let layout: PlazaLayout
    private var theme: PlazaTheme
    private var geometry: PlazaGeometry
    private var anchors: PlazaAnchors
    private var actors: [String: PlazaActor] = [:]
    private var leaving: [PlazaActor] = []
    private var cats: [PlazaCat] = []
    private var slots: [String: Int] = [:]
    private var tickAccum: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var ground: SKSpriteNode?
    private var period: PlazaPeriod = .current()
    private var periodAccum: TimeInterval = 0

    /// Scenery that a theme owns. Swapping a theme throws all of it away and paints the
    /// new world from scratch, so nothing from the old one is left standing on the beach.
    private static let decorName = "decor"

    public init(layout: PlazaLayout, theme: PlazaTheme = .current) {
        self.layout = layout
        self.theme = theme
        self.geometry = PlazaGeometry(layout: layout, theme: theme)
        self.anchors = PlazaAnchors(geometry: PlazaGeometry(layout: layout, theme: theme))
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
            let ground = SKSpriteNode(texture: PixelArt.plazaBackground(geometry, period: period))
            ground.name = "ground"
            ground.size = size
            ground.position = CGPoint(x: size.width / 2, y: size.height / 2)
            ground.zPosition = 0
            ground.alpha = AgoreConstants.groundOpacity
            ground.texture?.filteringMode = .nearest
            addChild(ground)
            self.ground = ground
            addDecor()
        }
    }

    /// Repaints the plaza in another style. Everyone on stage walks back in from a gate
    /// afterwards, because a bench they were sitting on may now be open water.
    public func apply(theme newTheme: PlazaTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        geometry = PlazaGeometry(layout: layout, theme: newTheme)
        anchors = PlazaAnchors(geometry: geometry)
        for actor in actors.values {
            actor.node.removeAllActions()
            actor.node.removeFromParent()
        }
        for actor in leaving {
            actor.node.removeAllActions()
            actor.node.removeFromParent()
        }
        actors.removeAll()
        leaving.removeAll()
        slots.removeAll()
        // A scene that has not been presented yet has no scenery to replace; the first
        // move into a view paints the new theme instead.
        guard let ground else { return }
        period = .current()
        ground.texture = PixelArt.plazaBackground(geometry, period: period)
        ground.texture?.filteringMode = .nearest
        for child in children where child.name == Self.decorName {
            child.removeAllActions()
            child.removeFromParent()
        }
        cats.removeAll()
        addDecor()
    }

    private func addDecor() {
        addCenterpiece()
        addAmbient()
        addCats()
    }

    private func addCenterpiece() {
        let node = SKSpriteNode(texture: PixelArt.centerpieceFrame(theme: theme, frame: 0))
        node.name = Self.decorName
        node.size = CGSize(width: PixelArt.centerpieceWidth, height: PixelArt.centerpieceHeight)
        node.position = CGPoint(
            x: geometry.centerpieceCenter.x,
            y: geometry.centerpieceCenter.y + CGFloat(PixelArt.centerpieceHeight) / 2 - 4
        )
        node.zPosition = 5
        node.alpha = 0.92
        node.run(.repeatForever(.animate(
            with: (0..<PixelArt.centerpieceFrames).map { PixelArt.centerpieceFrame(theme: theme, frame: $0) },
            timePerFrame: 0.24,
            resize: false,
            restore: true
        )))
        addChild(node)
    }

    private func addCats() {
        for (index, spot) in geometry.catSpots.enumerated() {
            let cat = PlazaCat(variant: index, home: spot, geometry: geometry)
            cat.node.name = Self.decorName
            cats.append(cat)
            addChild(cat.node)
        }
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
        ground.texture = PixelArt.plazaBackground(geometry, period: period)
        ground.texture?.filteringMode = .nearest
    }

    private func addAmbient() {
        for tree in geometry.trees {
            let origin = PixelArt.foliageTop(tree, theme: theme)
            for _ in 0..<(tree.size == 0 ? 1 : 2) {
                let leaf = SKSpriteNode(texture: PixelArt.leaf(theme: theme))
                leaf.name = Self.decorName
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
        let bird = SKSpriteNode(texture: PixelArt.bird(theme: theme, frame: 0))
        bird.name = Self.decorName
        bird.size = CGSize(width: 7, height: 5)
        bird.zPosition = 12
        bird.alpha = 0
        bird.texture?.filteringMode = .nearest
        bird.run(.repeatForever(.animate(
            with: [PixelArt.bird(theme: theme, frame: 0), PixelArt.bird(theme: theme, frame: 1)],
            timePerFrame: 0.18,
            resize: false,
            restore: true
        )))
        addChild(bird)
        flyBird(bird)
    }

    private func flyBird(_ bird: SKSpriteNode) {
        let fromLeft = Bool.random()
        let y = CGFloat.random(in: geometry.birdAltitude)
        let startX: CGFloat = fromLeft ? -8 : CGFloat(geometry.worldWidth) + 8
        let endX: CGFloat = fromLeft ? CGFloat(geometry.worldWidth) + 8 : -8
        bird.xScale = fromLeft ? 1 : -1
        bird.position = CGPoint(x: startX, y: y)
        bird.alpha = 0
        let duration = max(6.5, TimeInterval(geometry.worldWidth) / 38)
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
