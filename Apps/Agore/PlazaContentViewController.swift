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
    private let actionButton = NSButton(title: "Install Hooks", target: nil, action: nil)
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?

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
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.16, alpha: rounded ? 0 : 0.92).cgColor
        if rounded {
            root.layer?.backgroundColor = .clear
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

        let bar = NSView(frame: NSRect(x: 0, y: 0, width: size.width, height: AgoreConstants.statusHeight))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.10, alpha: 0.55).cgColor
        bar.autoresizingMask = [.width]

        statusField.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        statusField.textColor = NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 0.95)
        statusField.backgroundColor = .clear
        statusField.frame = NSRect(x: 8, y: 2, width: size.width - 120, height: 14)
        statusField.autoresizingMask = [.width]
        bar.addSubview(statusField)

        actionButton.bezelStyle = .inline
        actionButton.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
        actionButton.target = self
        actionButton.action = #selector(installTapped)
        actionButton.frame = NSRect(x: size.width - 104, y: 1, width: 96, height: 16)
        actionButton.autoresizingMask = [.minXMargin]
        bar.addSubview(actionButton)

        root.addSubview(bar)
        view = root
        preferredContentSize = size
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
            self?.refresh()
        }
        refreshTimer?.tolerance = 0.5
        refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        plazaView.isPaused = false
        refresh()
    }

    func refresh() {
        plazaView.sync(store: store)
        let hooks = store.hooksInstalled ? "hooks on" : "hooks off"
        let time = store.lastEventAt.map(Self.clock.string(from:)) ?? "--:--"
        let live = store.plazaMembers().count
        let population = live == 0 ? "waiting for cursor" : "\(live) person\(live == 1 ? "" : "s")"
        statusField.stringValue = [population, plazaLabel(store.plazaLink), hooks, time, hint]
            .compactMap { $0 }
            .joined(separator: " · ")
        actionButton.isHidden = store.hooksInstalled
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
