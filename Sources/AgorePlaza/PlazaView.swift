import AppKit
import SpriteKit
import AgoreCore

public final class PlazaView: SKView {
    public let plazaScene: PlazaScene

    public init(frame frameRect: NSRect, layout: PlazaLayout, theme: PlazaTheme = .current) {
        plazaScene = PlazaScene(layout: layout, theme: theme)
        super.init(frame: frameRect)
        ignoresSiblingOrder = true
        allowsTransparency = layout == .strip
        showsFPS = false
        showsNodeCount = false
        preferredFramesPerSecond = 30
        // A zero-size first layout makes SpriteKit compute an empty visible rect;
        // the big ground sprite still intersects it, but the 16×20 actors get culled.
        shouldCullNonVisibleNodes = false
        if frameRect.width > 1, frameRect.height > 1 {
            presentScene(plazaScene)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachSceneIfNeeded()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        attachSceneIfNeeded()
    }

    public func apply(theme: PlazaTheme) {
        plazaScene.apply(theme: theme)
    }

    public func setBackdropOpacity(_ alpha: CGFloat) {
        plazaScene.setBackdropOpacity(alpha)
    }

    public func sync(store: PresenceStore) {
        attachSceneIfNeeded()
        plazaScene.sync(sessions: store.plazaMembers().map { $0.asSession() })
    }

    private func attachSceneIfNeeded() {
        guard scene == nil, bounds.width > 1, bounds.height > 1 else { return }
        presentScene(plazaScene)
    }
}
