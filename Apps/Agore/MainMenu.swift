import AppKit

enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(appItem())
        menu.addItem(editItem())
        return menu
    }

    private static func appItem() -> NSMenuItem {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Show Plaza",
            action: #selector(NSApplication.showPlazaWindow),
            keyEquivalent: "0"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Agore",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        let item = NSMenuItem()
        item.submenu = appMenu
        return item
    }

    /// Without an Edit menu, AppKit never wires Cmd+V, so the token field cannot paste.
    private static func editItem() -> NSMenuItem {
        let edit = NSMenu()
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let item = NSMenuItem()
        item.submenu = edit
        item.title = "Edit"
        return item
    }
}

extension NSApplication {
    @MainActor
    @objc func showPlazaWindow() {
        (delegate as? AppDelegate)?.presentPlazaWindow()
    }
}
