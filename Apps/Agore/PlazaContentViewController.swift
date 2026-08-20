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
    private let statusField = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "Connect Agents", target: nil, action: nil)
    private let statusBar = NSView()
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?
    private var isActive = false

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
        let plazaFrame = NSRect(
            x: 0,
            y: AgoreConstants.statusHeight,
            width: size.width,
            height: max(AgoreConstants.plazaHeight, size.height - AgoreConstants.statusHeight)
        )
        self.plazaView = PlazaView(frame: plazaFrame, layout: layout)
        self.plazaView.isPaused = true
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
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        if rounded {
            root.layer?.cornerRadius = AgoreConstants.cornerRadius
            root.layer?.masksToBounds = true
        }

        plazaView.frame = NSRect(
            x: 0,
            y: AgoreConstants.statusHeight,
            width: size.width,
            height: max(AgoreConstants.plazaHeight, size.height - AgoreConstants.statusHeight)
        )
        plazaView.autoresizingMask = [.width, .height]
        root.addSubview(plazaView)

        statusBar.frame = NSRect(x: 0, y: 0, width: size.width, height: AgoreConstants.statusHeight)
        statusBar.wantsLayer = true
        statusBar.autoresizingMask = [.width]

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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        // Presence expires on a clock, not on a store mutation, so departures need a tick
        // of their own or a finished agent lingers on screen.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.resumeIfOnScreen()
            self?.refresh()
        }
        refreshTimer?.tolerance = 0.5
        refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        resumeIfOnScreen()
    }

    /// Both surfaces stay alive for the whole session, so a strip nobody can see would
    /// otherwise keep animating an empty plaza at thirty frames a second. AppKit reports
    /// this for a window that is merely buried too, not only for one ordered out.
    override func viewDidDisappear() {
        super.viewDidDisappear()
        setActive(false)
    }

    /// Going to sleep can be edge driven, but waking up cannot: a resume that never
    /// arrives — an overnight display sleep is enough — leaves the plaza frozen on
    /// whatever pose it held while the status bar beside it keeps counting up, and
    /// nothing else would ever repair it. Two property reads a tick buys that back.
    private func resumeIfOnScreen() {
        guard let window = view.window, window.isVisible else { return }
        guard window.occlusionState.contains(.visible) else { return }
        setActive(true)
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
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        plazaView.isPaused = !active
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
