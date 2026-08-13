import AppKit
import AgoreCore

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: PlazaPanelController
    private let store: PresenceStore
    private let onInstall: () -> Void

    init(store: PresenceStore, onInstall: @escaping () -> Void) {
        self.store = store
        self.onInstall = onInstall
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panel = PlazaPanelController(store: store, onInstall: onInstall)
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.image
            button.toolTip = "Agore — click to show the plaza, right-click for options"
            button.target = self
            button.action = #selector(buttonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if panel.isPinned {
            showPlaza()
        }
    }

    @objc private func buttonClicked() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showMenu()
        } else {
            panel.toggle(relativeTo: statusItem.button)
        }
    }

    func showPlaza() {
        panel.show(relativeTo: statusItem.button)
    }

    private func showMenu() {
        let menu = NSMenu()

        let pin = NSMenuItem(
            title: "Always on Top",
            action: #selector(togglePinned),
            keyEquivalent: "t"
        )
        pin.target = self
        pin.state = panel.isPinned ? .on : .off
        menu.addItem(pin)

        let visibility = NSMenuItem(
            title: panel.isVisible ? "Hide Plaza" : "Show Plaza",
            action: #selector(toggleVisibility),
            keyEquivalent: ""
        )
        visibility.target = self
        menu.addItem(visibility)

        menu.addItem(.separator())

        let hooks = NSMenuItem(
            title: store.hooksInstalled ? "Hooks Installed" : "Install Hooks",
            action: store.hooksInstalled ? nil : #selector(installHooks),
            keyEquivalent: ""
        )
        hooks.target = self
        menu.addItem(hooks)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Agore",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Handing the menu to the status item lines it up under the icon; clearing it
        // afterwards keeps the plain left-click as a show/hide toggle.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePinned() {
        panel.setPinned(!panel.isPinned)
        if panel.isPinned, !panel.isVisible {
            showPlaza()
        }
    }

    @objc private func toggleVisibility() {
        panel.toggle(relativeTo: statusItem.button)
    }

    @objc private func installHooks() {
        onInstall()
    }
}
