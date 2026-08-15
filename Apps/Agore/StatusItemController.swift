import AppKit
import AgoreCore

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: PlazaPanelController
    private let store: PresenceStore
    private let onInstall: () -> Void
    private let onNickname: (String) -> Void
    private let onToken: (String) -> Void

    init(
        store: PresenceStore,
        onInstall: @escaping () -> Void,
        onNickname: @escaping (String) -> Void,
        onToken: @escaping (String) -> Void
    ) {
        self.store = store
        self.onInstall = onInstall
        self.onNickname = onNickname
        self.onToken = onToken
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

        let nick = NSMenuItem(
            title: "Nickname…",
            action: #selector(editNickname),
            keyEquivalent: ""
        )
        nick.target = self
        menu.addItem(nick)

        let token = NSMenuItem(
            title: "Plaza Token…",
            action: #selector(editToken),
            keyEquivalent: ""
        )
        token.target = self
        menu.addItem(token)

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

    @objc private func editNickname() {
        prompt(
            title: "Nickname",
            info: "Shown under your pixel person on every plaza.",
            value: ClientIdentity.displayName,
            secure: false
        ) { [weak self] text in
            self?.onNickname(text)
        }
    }

    @objc private func editToken() {
        prompt(
            title: "Plaza Token",
            info: "Must match AGORE_TOKEN on the plaza server.",
            value: ClientIdentity.plazaToken,
            secure: true
        ) { [weak self] text in
            self?.onToken(text)
        }
    }

    private func prompt(title: String, info: String, value: String, secure: Bool, submit: @escaping (String) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field: NSTextField
        if secure {
            field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        } else {
            field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        }
        field.stringValue = value
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            submit(field.stringValue)
        }
    }
}
