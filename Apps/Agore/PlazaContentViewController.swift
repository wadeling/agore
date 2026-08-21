import AppKit
import Combine
import AgoreCore
import AgorePlaza

final class PlazaContentViewController: NSViewController {
    let plazaView: PlazaView
    var hint: String?

    private let store: PresenceStore
    private let onInstall: () -> Void
    private let contentSize: CGSize
    private let rounded: Bool
    /// The courtyard is a document: it only needs to move while Agore is frontmost.
    /// The strip is a companion overlay, so it keeps ticking while you work elsewhere.
    private let pausesWhenInactive: Bool
    /// The strip is too short to spare a permanent chrome band; the courtyard has room
    /// and keeps the line in view.
    private let hidesStatusUntilHover: Bool
    private let statusField = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "Connect Agents", target: nil, action: nil)
    private let statusBar = NSView()
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?
    private var isActive = false
    private var statusRevealed = false

    init(
        store: PresenceStore,
        onInstall: @escaping () -> Void,
        size: CGSize = AgoreConstants.panelSize,
        layout: PlazaLayout = .strip,
        rounded: Bool = true
    ) {
        self.store = store
        self.onInstall = onInstall
        self.contentSize = size
        self.rounded = rounded
        self.pausesWhenInactive = layout == .courtyard
        self.hidesStatusUntilHover = layout == .strip
        self.plazaView = PlazaView(
            frame: Self.plazaFrame(size: size, overlayStatus: layout == .strip),
            layout: layout
        )
        self.plazaView.setPaused(true)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
    }

    override func loadView() {
        let size = contentSize
        let root: NSView
        if hidesStatusUntilHover {
            let hover = StatusHoverView(frame: NSRect(origin: .zero, size: size))
            hover.bandHeight = AgoreConstants.statusHeight
            hover.onBand = { [weak self] _ in
                self?.syncStatusHoverFromPointer()
            }
            root = hover
        } else {
            root = NSView(frame: NSRect(origin: .zero, size: size))
        }
        root.wantsLayer = true
        if rounded {
            root.layer?.cornerRadius = AgoreConstants.cornerRadius
            root.layer?.masksToBounds = true
        }

        plazaView.frame = Self.plazaFrame(size: size, overlayStatus: hidesStatusUntilHover)
        plazaView.autoresizingMask = [.width, .height]
        root.addSubview(plazaView)

        statusBar.frame = NSRect(x: 0, y: 0, width: size.width, height: AgoreConstants.statusHeight)
        statusBar.wantsLayer = true
        statusBar.autoresizingMask = [.width]
        if hidesStatusUntilHover {
            statusBar.alphaValue = 0
            statusBar.isHidden = true
        }

        statusField.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        statusField.textColor = NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 0.95)
        statusField.backgroundColor = .clear
        statusField.frame = NSRect(x: 8, y: 2, width: size.width - 120, height: 14)
        statusField.autoresizingMask = [.width]
        statusBar.addSubview(statusField)

        actionButton.bezelStyle = .inline
        actionButton.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
        actionButton.target = self
        actionButton.action = #selector(installTapped)
        actionButton.frame = NSRect(x: size.width - 104, y: 1, width: 96, height: 16)
        actionButton.autoresizingMask = [.minXMargin]
        statusBar.addSubview(actionButton)

        root.addSubview(statusBar)
        view = root
        preferredContentSize = size
        applyChrome()
        if hidesStatusUntilHover {
            plazaView.onPointerChange = { [weak self] in
                self?.syncStatusHoverFromPointer()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        observeRunningState()
        // Presence expires on a clock, not on a store mutation, so departures need a tick
        // of their own or a finished agent lingers on screen. The same tick also matches
        // the pause flag to the window, but only a plaza that should be running is
        // allowed to wake — an occluded courtyard used to get unpaused from here.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.syncRunning()
            self?.refresh()
            self?.syncStatusHoverFromPointer()
        }
        refreshTimer?.tolerance = 0.5
        refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        syncRunning()
        syncStatusHoverFromPointer()
    }

    /// Both surfaces stay alive for the whole session, so a strip nobody can see would
    /// otherwise keep animating an empty plaza. AppKit reports this for a window that
    /// is merely buried too, not only for one ordered out.
    override func viewDidDisappear() {
        super.viewDidDisappear()
        setActive(false)
        setStatusRevealed(false)
    }

    /// SpriteKit pauses an occluded window on its own and does not always hand it back,
    /// and a display that slept overnight never posts the occlusion event we would
    /// resume from. Matching the pause flag to `shouldRun` covers both: a buried or
    /// background courtyard stays still, a frontmost one that SpriteKit froze starts
    /// again, and an occluded one is never woken just because the timer fired.
    private func observeRunningState() {
        let windowNotes: [Notification.Name] = [
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
        ]
        for name in windowNotes {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] note in
                    guard let self, note.object as? NSWindow === self.view.window else { return }
                    self.syncRunning()
                }
                .store(in: &cancellables)
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.syncRunning() }
                .store(in: &cancellables)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.syncRunning() }
                .store(in: &cancellables)
        }
    }

    private var shouldRun: Bool {
        guard let window = view.window, window.isVisible, !window.isMiniaturized else { return false }
        guard window.occlusionState.contains(.visible) else { return false }
        if pausesWhenInactive, !NSApp.isActive { return false }
        return true
    }

    private func syncRunning() {
        setActive(shouldRun)
    }

    private static func plazaFrame(size: CGSize, overlayStatus: Bool) -> NSRect {
        if overlayStatus {
            return NSRect(origin: .zero, size: size)
        }
        return NSRect(
            x: 0,
            y: AgoreConstants.statusHeight,
            width: size.width,
            height: max(AgoreConstants.plazaHeight, size.height - AgoreConstants.statusHeight)
        )
    }

    private func setStatusRevealed(_ revealed: Bool) {
        guard hidesStatusUntilHover, revealed != statusRevealed else { return }
        statusRevealed = revealed
        if revealed {
            statusBar.isHidden = false
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = revealed ? 0.12 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            statusBar.animator().alphaValue = revealed ? 1 : 0
        }, completionHandler: { [weak self] in
            guard let self, !self.statusRevealed else { return }
            self.statusBar.isHidden = true
        })
    }

    /// Screen location rather than hit-testing: once the bar is showing it sits on
    /// top of the plaza, and a mouse-exited from the SKView would otherwise hide it
    /// while the pointer is still on the line.
    private func syncStatusHoverFromPointer() {
        guard hidesStatusUntilHover else { return }
        guard let window = view.window, window.isVisible else {
            setStatusRevealed(false)
            return
        }
        let point = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        setStatusRevealed(view.bounds.contains(point) && point.y <= AgoreConstants.statusHeight)
    }

    func apply(theme: PlazaTheme) {
        plazaView.apply(theme: theme)
        refresh()
    }

    func setOpacity(_ opacity: Double) {
        applyChrome(PanelOpacity.visuals(for: opacity))
    }

    /// The square window stays a solid card. The strip's fill, floor and status bar all
    /// move together so 100% is actually opaque instead of a faded window over a glass floor.
    private func applyChrome(_ visuals: PanelOpacity.Visuals? = nil) {
        let fill: CGFloat
        let bar: CGFloat
        let ground: CGFloat
        if rounded {
            let visuals = visuals ?? PanelOpacity.visuals(for: PanelOpacity.current)
            fill = CGFloat(visuals.fillAlpha)
            bar = CGFloat(visuals.barAlpha)
            ground = CGFloat(visuals.groundAlpha)
        } else {
            fill = 0.92
            bar = 0.55
            ground = AgoreConstants.groundOpacity
        }
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.16, alpha: fill).cgColor
        statusBar.layer?.backgroundColor = NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.10, alpha: bar).cgColor
        plazaView.setBackdropOpacity(ground)
    }

    /// A scene left paused renders nothing that was added while it slept, so becoming
    /// active has to redraw from the store rather than wait for the next event.
    ///
    /// SpriteKit also pauses the plaza behind our back — an occluded window is enough —
    /// and it does not always hand it back. Our own flag then says the plaza is running
    /// while every action on it stands still, so what the view actually holds decides
    /// whether there is work to do, not the flag.
    func setActive(_ active: Bool) {
        let drifted = plazaView.isPlazaPaused == active
        guard active != isActive || drifted else { return }
        isActive = active
        plazaView.setPaused(!active)
        if active {
            refresh()
        }
    }

    func refresh() {
        plazaView.sync(store: store)
        let time = store.lastEventAt.map(Self.clock.string(from:)) ?? "--:--"
        let live = store.plazaMembers().count
        let population = "\(live) person\(live == 1 ? "" : "s")"
        let activity = store.localActivity().rawValue
        statusField.stringValue = [population, activity, plazaLabel(store.plazaLink), store.bridges.summary, time, hint]
            .compactMap { $0 }
            .joined(separator: " · ")
        actionButton.isHidden = !store.bridges.needsInstall
    }

    private func plazaLabel(_ state: PlazaLinkState) -> String {
        switch state {
        case .online: return "plaza on"
        case .connecting: return "plaza connecting"
        case .unauthorized: return "plaza unauthorized"
        case .offline: return "plaza offline"
        }
    }

    @objc private func installTapped() {
        onInstall()
        refresh()
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// Tracking lives on the root rather than the status bar so a hidden bar cannot
/// swallow clicks, and so the pointer still counts when Agore is not frontmost.
private final class StatusHoverView: NSView {
    var bandHeight: CGFloat = 0
    var onBand: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        report(event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        report(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onBand?(false)
    }

    private func report(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onBand?(location.y <= bandHeight)
    }
}
