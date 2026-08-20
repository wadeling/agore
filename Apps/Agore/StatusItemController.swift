import AppKit
import AgoreCore

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: PlazaPanelController
    private let store: PresenceStore
    private let onInstall: (AgentProvider?) -> Void
    private let onNickname: (String) -> Void
    private let onToken: (String) -> Void
    private let onTheme: (PlazaTheme) -> Void

    init(
        store: PresenceStore,
        onInstall: @escaping (AgentProvider?) -> Void,
        onNickname: @escaping (String) -> Void,
        onToken: @escaping (String) -> Void,
        onTheme: @escaping (PlazaTheme) -> Void
    ) {
        self.store = store
        self.onInstall = onInstall
        self.onNickname = onNickname
        self.onToken = onToken
        self.onTheme = onTheme
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panel = PlazaPanelController(store: store, onInstall: { onInstall(nil) })
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
        menu.addItem(styleItem())
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

        menu.addItem(bridgesItem())

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

    /// One line per agent provider, ticked when Agore is wired into it. Choosing an
    /// unticked one installs the bridge, including for an agent Agore could not find on
    /// the Mac — someone who keeps their config somewhere unusual can still opt in.
    private func bridgesItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Agents", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for status in store.bridges {
            let suffix = status.isDetected ? "" : " (not found)"
            let choice = NSMenuItem(
                title: status.provider.bridgeName + suffix,
                action: #selector(installBridge(_:)),
                keyEquivalent: ""
            )
            choice.target = self
            choice.representedObject = status.provider.rawValue
            choice.state = status.isInstalled ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    /// The styles sit in a submenu, ticked like a radio group so the plaza on screen is
    /// the one marked here.
    private func styleItem() -> NSMenuItem {
        let current = PlazaTheme.current
        let item = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for theme in PlazaTheme.allCases {
            let choice = NSMenuItem(
                title: theme.displayName,
                action: #selector(selectTheme(_:)),
                keyEquivalent: ""
            )
            choice.target = self
            choice.representedObject = theme.rawValue
            choice.state = theme == current ? .on : .off
            submenu.addItem(choice)
        }
        item.submenu = submenu
        return item
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = PlazaTheme(rawValue: raw) else { return }
        onTheme(theme)
    }

    func apply(theme: PlazaTheme) {
        panel.apply(theme: theme)
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

    @objc private func installBridge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = AgentProvider(rawValue: raw) else { return }
        onInstall(provider)
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
