import AppKit
import AgoreCore
import AgorePlaza

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PresenceStore()
    private let ingest = HookIngestServer()
    private let bridges = AgentBridges()
    private let scanner = CursorTranscriptScanner()
    private let identity = ClientIdentity.load()
    private lazy var plaza = PlazaClient(identity: identity)
    private var windowController: PlazaWindowController?
    private var statusItem: StatusItemController?
    private var scanTimer: Timer?
    private var wakefulness: NSObjectProtocol?

    private var startsPinned: Bool {
        UserDefaults.standard.bool(forKey: AgoreConstants.alwaysOnTopKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Stay a regular app so the Dock icon remains: clicking it opens the square
        // window. The menu bar strip is a second, smaller surface.
        NSApp.setActivationPolicy(.regular)

        // A menu bar app is in the background nearly all the time, and App Nap suspends
        // a napped process down to its timers: the idle sweep, the plaza heartbeat and
        // the strip's animation all stop until the user clicks the icon, which is what
        // made presence sit on a stale activity for as long as nobody looked at it.
        // Idle system sleep stays allowed so the Mac can still doze off on its own.
        wakefulness = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "tracking cursor agent presence"
        )

        store.identity = identity
        store.onInstanceChange = { [plaza] member in
            plaza.publish(member)
        }
        store.onInstanceLeave = { [plaza] memberId in
            plaza.publishLeave(memberId)
        }
        plaza.onInbound = { [store] inbound in
            Task { @MainActor in
                store.applyPlaza(inbound)
            }
        }
        store.open()
        plaza.start()

        ingest.onEvent = { [store] event in
            Task { @MainActor in
                store.apply(event)
            }
        }
        ingest.onReady = { [store] port in
            Task { @MainActor in
                store.ingestPort = port
            }
        }
        do {
            try ingest.start()
        } catch {
            store.statusMessage = "ingest failed"
        }

        installBridges()
        scanTranscripts()
        setUpStatusItem()
        presentPlazaWindow()
        if startsPinned {
            statusItem?.showPlaza()
        }

        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanTranscripts()
                self?.installBridges()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentPlazaWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        plaza.stop()
        ingest.stop()
        if let wakefulness {
            ProcessInfo.processInfo.endActivity(wakefulness)
        }
    }

    func presentPlazaWindow() {
        if let windowController {
            windowController.present()
            return
        }
        let controller = PlazaWindowController(
            store: store,
            onInstall: { [weak self] in self?.installBridges() },
            onClose: {}
        )
        windowController = controller
        controller.present()
    }

    private func setUpStatusItem() {
        guard statusItem == nil else { return }
        statusItem = StatusItemController(
            store: store,
            onInstall: { [weak self] provider in self?.installBridges(provider) },
            onNickname: { [weak self] name in self?.applyNickname(name) },
            onToken: { [weak self] token in self?.applyToken(token) },
            onTheme: { [weak self] theme in self?.applyTheme(theme) }
        )
    }

    /// Both surfaces share one style, so the pick has to land on the strip and the window
    /// alike — and outlive a restart.
    func applyTheme(_ theme: PlazaTheme) {
        guard theme != PlazaTheme.current else { return }
        PlazaTheme.current = theme
        statusItem?.apply(theme: theme)
        windowController?.apply(theme: theme)
    }

    /// Only the floating strip fades; the square window stays solid so it still reads as
    /// a regular document when someone opens it from the Dock.
    func applyOpacity(_ opacity: Double) {
        statusItem?.apply(opacity: opacity)
    }

    /// Renaming republishes every person this client owns, each with the agent it stands
    /// for appended, so there is nothing a separate nick frame could say.
    private func applyNickname(_ name: String) {
        store.renameLocal(to: name)
    }

    private func applyToken(_ token: String) {
        ClientIdentity.plazaToken = token
        plaza.reconnect()
    }

    /// Runs on every scan tick as well as at launch, so an agent installed while Agore
    /// was already sitting in the menu bar gets wired up on its own. Installing is a
    /// no-op once the bridge is current.
    private func installBridges(_ only: AgentProvider? = nil) {
        let statuses = bridges.install(only)
        store.bridges = statuses
        if let failed = statuses.first(where: \.failed) {
            store.statusMessage = "\(failed.provider.rawValue) install failed"
        }
    }

    private func scanTranscripts() {
        let events = scanner.scan()
        Task { @MainActor in
            for event in events {
                store.apply(event)
            }
        }
    }
}
