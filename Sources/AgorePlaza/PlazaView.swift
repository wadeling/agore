import AppKit
import SpriteKit
import AgoreCore

public final class PlazaView: SKView {
    public let plazaScene: PlazaScene
    private let isStrip: Bool
    /// Window-level pause (hidden / occluded). The strip may still rest on top of
    /// this when nobody on stage is moving.
    private var windowPaused = true
    /// An idle strip still has to paint once when it appears, or SpriteKit would
    /// leave a blank metal view until someone walked.
    private var needsFirstFrame = true
    /// The strip's status line watches the same pointer the scene does, because a
    /// non-frontmost panel does not always deliver mouse-moved events to its parent.
    public var onPointerChange: (() -> Void)?

    public init(frame frameRect: NSRect, layout: PlazaLayout, theme: PlazaTheme = .current) {
        plazaScene = PlazaScene(layout: layout, theme: theme)
        isStrip = layout == .strip
        super.init(frame: frameRect)
        ignoresSiblingOrder = true
        allowsTransparency = layout == .strip
        showsFPS = false
        showsNodeCount = false
        // Two SKViews on one display do not share it fairly. Measured: with the strip
        // asking for 30fps the courtyard went whole half-minutes without a single frame.
        // The strip now draws only while someone is moving, and then at 8fps — an idle
        // pinned strip used to keep a 60Hz display link alive for a 20fps Metal present,
        // which is what held Activity Monitor at 3–4%.
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
        needsFirstFrame = true
        applyRunState()
    }

    public func setBackdropOpacity(_ alpha: CGFloat) {
        plazaScene.setBackdropOpacity(alpha)
    }

    /// The view and the scene each hold their own pause flag, and SpriteKit sets them
    /// itself when the window is occluded or the display sleeps. Clearing only one of
    /// them leaves every action standing still, so both move together.
    public func setPaused(_ paused: Bool) {
        if windowPaused && !paused { needsFirstFrame = true }
        windowPaused = paused
        applyRunState()
    }

    public var isPlazaPaused: Bool {
        isPaused || plazaScene.isPaused
    }

    /// A pinned strip that is only showing sleepers does not need a display link.
    /// Courtyard windows keep drawing whenever they are on screen.
    func applyRunState() {
        refreshPointerInside()
        let run = !windowPaused && (!isStrip || plazaScene.needsAnimation || needsFirstFrame)
        isPaused = !run
        plazaScene.isPaused = !run
    }

    func consumeFirstFrame() {
        needsFirstFrame = false
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
