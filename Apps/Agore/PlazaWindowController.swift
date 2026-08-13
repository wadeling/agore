import AppKit
import AgoreCore

final class PlazaWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(store: PresenceStore, onInstall: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let content = PlazaContentViewController(store: store, onInstall: onInstall)
        content.hint = "close to keep Agore in the menu bar"

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AgoreConstants.panelSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Agore"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = content
        window.setContentSize(AgoreConstants.panelSize)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
