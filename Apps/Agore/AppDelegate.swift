import AppKit
import AgoreCore
import AgorePlaza

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PresenceStore()
    private let ingest = HookIngestServer()
    private let installer = HookInstaller()
    private let scanner = CursorTranscriptScanner()
    private var windowController: PlazaWindowController?
    private var statusItem: StatusItemController?
    private var scanTimer: Timer?

    private var startsPinned: Bool {
        UserDefaults.standard.bool(forKey: AgoreConstants.alwaysOnTopKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Once the plaza is pinned it is meant to be there on login, so the onboarding
        // window is skipped and the strip comes straight back.
        NSApp.setActivationPolicy(startsPinned ? .accessory : .regular)

        store.open()
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
        if startsPinned {
            setUpStatusItem()
        } else {
            presentPlazaWindow()
        }

        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.scanTranscripts()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        revealPlaza()
        return true
    }

    func revealPlaza() {
        if let statusItem {
            statusItem.showPlaza()
        } else {
            presentPlazaWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        ingest.stop()
    }

    private func presentPlazaWindow() {
        if let windowController {
            windowController.present()
            return
        }
        let controller = PlazaWindowController(
            store: store,
            onInstall: { [weak self] in self?.installHooksIfNeeded() },
            onClose: { [weak self] in self?.moveToMenuBar() }
        )
        windowController = controller
        controller.present()
    }

    private func moveToMenuBar() {
        windowController = nil
        // The policy switch has to wait for the closing window to leave the screen,
        // otherwise the status item lands in a menu bar that is still being rebuilt.
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
            setUpStatusItem()
        }
    }

    private func setUpStatusItem() {
        guard statusItem == nil else { return }
        statusItem = StatusItemController(store: store) { [weak self] in
            self?.installHooksIfNeeded()
        }
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
