import AppKit
import AgoreCore

enum MainMenu {
    /// The style submenu is rebuilt every time it opens, because the same choice is also
    /// offered from the status item and whichever menu is opened second has to agree.
    @MainActor private static let styleMenuDelegate = StyleMenuDelegate()

    @MainActor static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(appItem())
        menu.addItem(editItem())
        menu.addItem(viewItem())
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

    @MainActor private static func viewItem() -> NSMenuItem {
        let style = NSMenu(title: "Style")
        style.delegate = styleMenuDelegate
        let styleItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        styleItem.submenu = style

        let view = NSMenu()
        view.addItem(styleItem)
        let item = NSMenuItem()
        item.submenu = view
        item.title = "View"
        return item
    }
}

@MainActor
private final class StyleMenuDelegate: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let current = PlazaTheme.current
        for theme in PlazaTheme.allCases {
            let item = NSMenuItem(
                title: theme.displayName,
                action: #selector(NSApplication.selectPlazaTheme(_:)),
                keyEquivalent: ""
            )
            item.representedObject = theme.rawValue
            item.state = theme == current ? .on : .off
            menu.addItem(item)
        }
    }
}

extension NSApplication {
    @MainActor
    @objc func showPlazaWindow() {
        (delegate as? AppDelegate)?.presentPlazaWindow()
    }

    @MainActor
    @objc func selectPlazaTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = PlazaTheme(rawValue: raw) else { return }
        (delegate as? AppDelegate)?.applyTheme(theme)
    }
}
