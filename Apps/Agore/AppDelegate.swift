import AppKit
import AgoreCore
import AgorePlaza

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PresenceStore()
    private let ingest = HookIngestServer()
    private let installer = HookInstaller()
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

        installHooksIfNeeded()
        scanTranscripts()
        setUpStatusItem()
        presentPlazaWindow()
        if startsPinned {
            statusItem?.showPlaza()
        }

        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.scanTranscripts()
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
            onInstall: { [weak self] in self?.installHooksIfNeeded() },
            onClose: {}
        )
        windowController = controller
        controller.present()
    }

    private func setUpStatusItem() {
        guard statusItem == nil else { return }
        statusItem = StatusItemController(
            store: store,
            onInstall: { [weak self] in self?.installHooksIfNeeded() },
            onNickname: { [weak self] name in self?.applyNickname(name) },
            onToken: { [weak self] token in self?.applyToken(token) }
        )
    }

    private func applyNickname(_ name: String) {
        store.renameLocal(to: name)
        plaza.sendNick(ClientIdentity.displayName)
    }

    private func applyToken(_ token: String) {
        ClientIdentity.plazaToken = token
        plaza.reconnect()
    }

    private func installHooksIfNeeded() {
        do {
            try installer.ensureInstalled()
            store.hooksInstalled = installer.isInstalled
        } catch {
            store.hooksInstalled = false
            store.statusMessage = "hooks install failed"
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
