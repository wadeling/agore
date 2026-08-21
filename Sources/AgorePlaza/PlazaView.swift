import AppKit
import SpriteKit
import AgoreCore

public final class PlazaView: SKView {
    public let plazaScene: PlazaScene
    private let layout: PlazaLayout
    private var isStrip: Bool { layout == .strip }
    /// Window-level pause (hidden / occluded). A visible strip keeps drawing even
    /// when nobody is looking at it; only a buried window stands still.
    private var windowPaused = true
    /// The strip's status line watches the same pointer the scene does, because a
    /// non-frontmost panel does not always deliver mouse-moved events to its parent.
    public var onPointerChange: (() -> Void)?

    public init(frame frameRect: NSRect, layout: PlazaLayout, theme: PlazaTheme = .current) {
        plazaScene = PlazaScene(layout: layout, theme: theme)
        self.layout = layout
        super.init(frame: frameRect)
        ignoresSiblingOrder = true
        allowsTransparency = layout == .strip
        showsFPS = false
        showsNodeCount = false
        // Two SKViews on one display do not share it fairly. Measured: with the strip
        // asking for 30fps the courtyard went whole half-minutes without a single frame.
        // The strip stays at 8fps whether or not anyone is looking — enough for
        // clouds and sleepers to keep moving without a 60Hz link.
        preferredFramesPerSecond = layout.framesPerSecond
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
        window?.acceptsMouseMovedEvents = true
        applyRunState()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        attachSceneIfNeeded()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        plazaScene.pointerInside = true
        applyRunState()
        onPointerChange?()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        plazaScene.pointerInside = false
        plazaScene.hover(nil)
        applyRunState()
        onPointerChange?()
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        plazaScene.refreshHover()
        onPointerChange?()
    }

    public func apply(theme: PlazaTheme) {
        plazaScene.apply(theme: theme)
        applyRunState()
    }

    public func setBackdropOpacity(_ alpha: CGFloat) {
        plazaScene.setBackdropOpacity(alpha)
    }

    /// The view and the scene each hold their own pause flag, and SpriteKit sets them
    /// itself when the window is occluded or the display sleeps. Clearing only one of
    /// them leaves every action standing still, so both move together.
    public func setPaused(_ paused: Bool) {
        windowPaused = paused
        applyRunState()
    }

    public var isPlazaPaused: Bool {
        isPaused || plazaScene.isPaused
    }

    /// A visible strip keeps its display link at 8fps. Courtyard windows keep
    /// drawing whenever they are on screen.
    func applyRunState() {
        refreshPointerInside()
        let run = !windowPaused
        isPaused = !run
        plazaScene.isPaused = !run
    }

    public func sync(store: PresenceStore) {
        attachSceneIfNeeded()
        plazaScene.sync(sessions: store.plazaMembers().map { $0.asSession() })
        applyRunState()
    }

    private func refreshPointerInside() {
        guard isStrip, !windowPaused, let window, window.isVisible else {
            if !isStrip { return }
            plazaScene.pointerInside = false
            return
        }
        let inView = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        plazaScene.pointerInside = bounds.contains(inView)
        onPointerChange?()
    }

    private func attachSceneIfNeeded() {
        guard scene == nil, bounds.width > 1, bounds.height > 1 else { return }
        presentScene(plazaScene)
    }
}
