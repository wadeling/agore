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
        // Two SKViews on one display do not share it fairly. Measured: with the strip
        // asking for 30fps the courtyard went whole half-minutes without a single frame,
        // while the strip kept every one of its own; at 20fps for the strip the courtyard
        // holds 60 foreground and background alike. The strip can afford it — nothing in
        // it moves faster than an actor tick every 0.18s — and the window is the surface
        // being looked at, so it gets the display.
        preferredFramesPerSecond = layout == .strip ? 20 : 60
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

    /// The view and the scene each hold their own pause flag, and SpriteKit sets them
    /// itself when the window is occluded or the display sleeps. Clearing only one of
    /// them leaves every action standing still, so both move together.
    public func setPaused(_ paused: Bool) {
        isPaused = paused
        plazaScene.isPaused = paused
    }

    public var isPlazaPaused: Bool {
        isPaused || plazaScene.isPaused
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
