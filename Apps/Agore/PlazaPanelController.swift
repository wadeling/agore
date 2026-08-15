import AppKit
import AgoreCore

/// A borderless, translucent strip that hangs off the menu bar icon. A popover cannot be
/// used here: its chrome is drawn by the system and it dismisses itself as soon as it
/// loses focus, which rules out staying on screen all day.
@MainActor
final class PlazaPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let content: PlazaContentViewController
    private var clickMonitor: Any?
    private var isPositioning = false
    private var keepsUserOrigin = false

    private(set) var isPinned: Bool

    init(store: PresenceStore, onInstall: @escaping () -> Void) {
        content = PlazaContentViewController(store: store, onInstall: onInstall)
        isPinned = UserDefaults.standard.bool(forKey: AgoreConstants.alwaysOnTopKey)

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: AgoreConstants.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.contentViewController = content
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle(relativeTo button: NSStatusBarButton?) {
        if panel.isVisible {
            hide()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton?) {
        if !keepsUserOrigin {
            position(below: button)
        }
        panel.orderFrontRegardless()
        content.refresh()
        startClickMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        stopClickMonitor()
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        UserDefaults.standard.set(pinned, forKey: AgoreConstants.alwaysOnTopKey)
        if pinned {
            stopClickMonitor()
        } else if panel.isVisible {
            startClickMonitor()
        }
    }

    private func position(below button: NSStatusBarButton?) {
        let size = AgoreConstants.panelSize
        var origin = CGPoint(x: 0, y: 0)
        if let button, let window = button.window {
            let onScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
            origin = CGPoint(x: onScreen.midX - size.width / 2, y: onScreen.minY - size.height - 6)
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            let frame = screen.visibleFrame
            origin = CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 6)
        }
        if let screen = button?.window?.screen ?? NSScreen.main {
            let limits = screen.visibleFrame
            origin.x = min(max(origin.x, limits.minX + 8), limits.maxX - size.width - 8)
            origin.y = max(origin.y, limits.minY + 8)
        }
        isPositioning = true
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        isPositioning = false
    }

    /// Unpinned, the strip behaves like a popover and steps aside on the next click
    /// elsewhere. Global monitors never see clicks aimed at our own status item, so
    /// toggling from the menu bar does not fight with this.
    private func startClickMonitor() {
        guard !isPinned, clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, !self.isPinned, self.panel.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.hide()
                }
            }
            _ = event
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
    }

    func windowDidMove(_ notification: Notification) {
        guard !isPositioning else { return }
        keepsUserOrigin = true
    }
}
