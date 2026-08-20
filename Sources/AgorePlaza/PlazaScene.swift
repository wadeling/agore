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
    private var clouds: [DriftingCloud] = []
    private var birdNode: SKSpriteNode?
    private var birdFlight: BirdFlight?
    private var slots: [String: Int] = [:]
    private var hovered: String?
    private var ground: SKSpriteNode?
    private var period: PlazaPeriod = .current()
    private var backdropOpacity: CGFloat = AgoreConstants.groundOpacity
    /// Frame times, not counts: everything below reads the clock the frame arrived
    /// with, so a window macOS has throttled to a frame a second still animates in
    /// step with real time instead of in slow motion.
    private var now: TimeInterval = 0
    private var skyEpoch: TimeInterval = 0
    private var lastTickAt: TimeInterval = 0
    private var lastPeriodAt: TimeInterval = 0

    /// Scenery that a theme owns. Swapping a theme throws all of it away and paints the
    /// new world from scratch, so nothing from the old one is left standing on the beach.
    private static let decorName = "decor"

    private struct DriftingCloud {
        let node: SKSpriteNode
        let spec: CloudSpec
        let origin: Double
    }

    private struct BirdFlight {
        let from: Double
        let to: Double
        let startedAt: TimeInterval
        let seconds: TimeInterval
    }

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
            ground.alpha = backdropOpacity
            ground.texture?.filteringMode = .nearest
            addChild(ground)
            self.ground = ground
            addDecor()
        }
    }

    /// How solid the floor is. One hundred percent opacity on the strip turns this up
    /// to fully opaque; the designed 0.7 is what 80% looks like.
    public func setBackdropOpacity(_ alpha: CGFloat) {
        backdropOpacity = alpha
        ground?.alpha = alpha
        for cloud in clouds {
            cloud.node.alpha = alpha
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
        hovered = nil
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
        clouds.removeAll()
        birdNode = nil
        birdFlight = nil
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

    /// Strays, not agents. On the shore the agents are cats themselves, so the geometry
    /// hands back no spots there and the only cats on the sand have names under them.
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
            if hovered == id { hovered = nil }
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
                let actor = PlazaActor(session: session, position: start, theme: theme, geometry: geometry)
                actors[session.id] = actor
                addChild(actor.node)
                actor.apply(session, anchors: anchors, slot: slot)
            }
        }
    }

    /// The pointer is read off the screen rather than waited for as an event: the plaza is
    /// usually a panel of an app that is not frontmost, and mouse-moved events reach it
    /// only once something has brought it forward.
    private func refreshHover() {
        guard let view = view, let window = view.window, window.isVisible else {
            hover(nil)
            return
        }
        let inView = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        hover(view.bounds.contains(inView) ? convertPoint(fromView: inView) : nil)
    }

    /// Spells out the name of whoever the pointer is resting on, and shortens everyone
    /// else's back. Pass nil when the pointer is off the plaza.
    private func hover(_ point: CGPoint?) {
        // Topmost first, so the one drawn over the others is the one that answers.
        let found = point.flatMap { point in
            actors.values
                .filter { $0.contains(point) }
                .max { $0.node.zPosition < $1.node.zPosition }
        }
        guard found?.id != hovered else { return }
        hovered = found?.id
        for actor in actors.values {
            actor.setHovered(actor === found)
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
        now = currentTime
        if skyEpoch == 0 { skyEpoch = currentTime }
        if lastTickAt == 0 { lastTickAt = currentTime }
        if lastPeriodAt == 0 { lastPeriodAt = currentTime }
        if currentTime - lastPeriodAt >= 30 {
            lastPeriodAt = currentTime
            refreshPeriod()
        }
        driftClouds(elapsed: currentTime - skyEpoch)
        stepBird()
        guard currentTime - lastTickAt >= 0.18 else { return }
        lastTickAt = currentTime
        refreshHover()
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
        for cloud in clouds {
            cloud.node.texture = PixelArt.cloud(cloud.spec, period: period)
            cloud.node.texture?.filteringMode = .nearest
        }
    }

    private func addAmbient() {
        addClouds()
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

    /// The same lumps the background used to paint, now sliding themselves. Speed
    /// belongs to the cloud's size; wrapping keeps the sky from thinning out.
    private func addClouds() {
        let scale = viewPixelScale()
        for spec in geometry.clouds {
            let node = SKSpriteNode(texture: PixelArt.cloud(spec, period: period))
            node.name = Self.decorName
            node.size = PixelArt.cloudSpriteSize(spec)
            var position = PixelArt.cloudPosition(spec)
            position.x = CGFloat(CloudDrift.snapped(Double(position.x), scale: scale))
            position.y = CGFloat(CloudDrift.snapped(Double(position.y), scale: scale))
            node.position = position
            node.zPosition = 1
            node.xScale = spec.flipped ? -1 : 1
            node.alpha = backdropOpacity
            node.texture?.filteringMode = .nearest
            addChild(node)
            clouds.append(DriftingCloud(node: node, spec: spec, origin: Double(position.x)))
        }
        // A rebuilt sky starts its own clock, or the new clouds would jump straight
        // to wherever the old ones had drifted to.
        skyEpoch = now
    }

    private func driftClouds(elapsed: TimeInterval) {
        let scale = viewPixelScale()
        for cloud in clouds {
            cloud.node.position.x = CGFloat(CloudDrift.drifted(
                origin: cloud.origin,
                elapsed: elapsed,
                pixelsPerSecond: CloudDrift.pixelsPerSecond(
                    size: cloud.spec.size,
                    worldWidth: geometry.worldWidth,
                    isStrip: geometry.isStrip
                ),
                spriteWidth: Double(cloud.node.size.width),
                worldWidth: geometry.worldWidth,
                scale: scale
            ))
        }
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
        birdNode = bird
        flyBird(bird)
    }

    private func flyBird(_ bird: SKSpriteNode) {
        birdFlight = nil
        let fromLeft = Bool.random()
        let scale = viewPixelScale()
        let y = CloudDrift.snapped(
            Double(CGFloat.random(in: geometry.birdAltitude)),
            scale: scale
        )
        let margin = 8.0
        let from = fromLeft ? -margin : Double(geometry.worldWidth) + margin
        let to = fromLeft ? Double(geometry.worldWidth) + margin : -margin
        bird.xScale = fromLeft ? 1 : -1
        bird.position = CGPoint(x: CGFloat(from), y: CGFloat(y))
        bird.alpha = 0
        bird.run(.sequence([
            .wait(forDuration: Double.random(in: 8...16)),
            .fadeAlpha(to: 0.9, duration: 0.2),
            .run { [weak self] in
                guard let self else { return }
                self.birdFlight = BirdFlight(
                    from: from,
                    to: to,
                    startedAt: self.now,
                    seconds: CloudDrift.birdFlightSeconds(worldWidth: self.geometry.worldWidth)
                )
            },
        ]))
    }

    private func stepBird() {
        guard let flight = birdFlight, let bird = birdNode else { return }
        let progress = min(1, max(0, (now - flight.startedAt) / flight.seconds))
        let x = flight.from + (flight.to - flight.from) * progress
        bird.position.x = CGFloat(CloudDrift.snapped(x, scale: viewPixelScale()))
        guard progress >= 1 else { return }
        birdFlight = nil
        bird.run(.sequence([
            .fadeOut(withDuration: 0.2),
            .run { [weak self, weak bird] in
                guard let self, let bird else { return }
                self.flyBird(bird)
            },
        ]))
    }

    /// The real view-to-world ratio, so a resized window still hops on its own
    /// pixel grid rather than the designed 2× / 3×.
    private func viewPixelScale() -> Double {
        guard let view, view.bounds.width > 1, size.width > 0 else {
            return Double(geometry.layout.pixelScale)
        }
        return Double(view.bounds.width / size.width)
    }
}
