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
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .utilityWindow
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        content.setActive(false)
        content.setOpacity(PanelOpacity.current)
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
        // A remembered origin is only worth keeping while the screen it was dropped on
        // is still there; otherwise the strip would open on a display that went away.
        if !keepsUserOrigin || !isOnScreen(panel.frame) {
            position(below: button)
        }
        panel.orderFrontRegardless()
        content.setActive(true)
        startClickMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        content.setActive(false)
        stopClickMonitor()
    }

    func apply(theme: PlazaTheme) {
        content.apply(theme: theme)
    }

    func setOpacity(_ opacity: Double) {
        content.setOpacity(opacity)
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
        let anchor = menuBarAnchor(button)
        let screen = anchor?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let limits = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        var origin = CGPoint(
            x: (anchor?.rect.midX ?? limits.midX) - size.width / 2,
            y: (anchor?.rect.minY ?? limits.maxY) - size.height - 6
        )
        // Clamping on its own is what used to fling the strip into the corner: an origin
        // computed from a bogus anchor lands far below the screen and the floor catches
        // it there. Anything unusable now falls back to the top of the screen instead.
        origin.x = min(max(origin.x, limits.minX + 8), max(limits.minX + 8, limits.maxX - size.width - 8))
        origin.y = min(max(origin.y, limits.minY + 8), max(limits.minY + 8, limits.maxY - size.height - 6))
        isPositioning = true
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        isPositioning = false
    }

    /// The status item does not always sit where its button claims. While the icon is
    /// collapsed behind the notch, hidden by a menu bar manager, or simply not laid out
    /// yet, the conversion yields an empty rect at the origin — which is not a place to
    /// hang a window off.
    private func menuBarAnchor(_ button: NSStatusBarButton?) -> (rect: CGRect, screen: NSScreen)? {
        guard let button, let window = button.window else { return nil }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard rect.width > 1, rect.height > 1 else { return nil }
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) else { return nil }
        guard rect.maxY >= screen.frame.maxY - 40 else { return nil }
        return (rect, screen)
    }

    private func isOnScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame.insetBy(dx: 20, dy: 20)) }
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

    /// AppKit posts this for display reconfiguration and for our own placement too, so a
    /// held mouse button is what separates "the user put it here" from "the system did".
    func windowDidMove(_ notification: Notification) {
        guard !isPositioning, NSEvent.pressedMouseButtons != 0 else { return }
        keepsUserOrigin = true
    }
}
