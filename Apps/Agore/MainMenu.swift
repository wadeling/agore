import AppKit

enum MainMenu {
    static func make() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Show Plaza",
            action: #selector(NSApplication.showPlaza),
            keyEquivalent: "0"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Agore",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let appItem = NSMenuItem()
        appItem.submenu = appMenu

        let menu = NSMenu()
        menu.addItem(appItem)
        return menu
    }
}

extension NSApplication {
    @MainActor
    @objc func showPlaza() {
        (delegate as? AppDelegate)?.revealPlaza()
    }
}
