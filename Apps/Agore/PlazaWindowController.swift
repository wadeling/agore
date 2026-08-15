import AppKit
import AgoreCore

final class PlazaWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void

    init(store: PresenceStore, onInstall: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let content = PlazaContentViewController(
            store: store,
            onInstall: onInstall,
            size: AgoreConstants.windowSize,
            layout: .courtyard,
            rounded: false
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AgoreConstants.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Agore"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.contentViewController = content
        window.setContentSize(AgoreConstants.windowSize)
        window.minSize = NSSize(width: 480, height: 480)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.16, alpha: 1)
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        window.setContentSize(AgoreConstants.windowSize)
        centerOnScreen(window)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // After the window attaches to a screen, origin (0,0) is no longer sticky.
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            self?.centerOnScreen(window)
        }
    }

    private func centerOnScreen(_ window: NSWindow) {
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.size = window.frameRect(forContentRect: NSRect(origin: .zero, size: AgoreConstants.windowSize)).size
        frame.origin = CGPoint(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2
        )
        window.setFrame(frame, display: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
