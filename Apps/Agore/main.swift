import AppKit

// AppKit's @main path goes through NSApplicationMain, which only wires up a delegate
// when a main NIB declares one. Agore has no NIB, so the delegate is set by hand here.
let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.mainMenu = MainActor.assumeIsolated { MainMenu.make() }
application.run()
