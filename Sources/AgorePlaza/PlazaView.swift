import AppKit
import SpriteKit
import AgoreCore

public final class PlazaView: SKView {
    public let plazaScene = PlazaScene()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        ignoresSiblingOrder = true
        allowsTransparency = true
        showsFPS = false
        showsNodeCount = false
        preferredFramesPerSecond = 30
        presentScene(plazaScene)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func sync(store: PresenceStore) {
        plazaScene.sync(sessions: store.activeSessions())
    }
}
