import AppKit

// ReNote: just notes, in four spaces (Feel, Body, Mind, Soul). A native Mac app on the ReSpace desk.

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // the distances from the windows' edges, as set with ReDesk's keys
        Spacing.start()
        // keys of one's own, as set in ReDesk's keys popup (⌘/)
        OwnKeys.start(app: "ReNote", standard: [
            "newWindow": .init(45, "n"), "save": .init(1, "s"), "highlight": .init(11, "b"), "draw": .init(2, "d"), "undo": .init(6, "z"),
        ])
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.mainMenu = menu()
        Lang.shared.follow()
        Desk.listen()
        _ = Store.shared
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(1440, screen.width), height: min(900, screen.height))
        open(NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height))
    }

    @discardableResult
    func open(_ frame: NSRect) -> NoteWindow {
        let w = NoteWindow(frame: frame)
        w.host.go(.home)
        w.open()
        return w
    }

    /// ⌘N: another window, the size of the one in front, a little lower and to the right of it
    func newWindow(from front: NSWindow?) {
        let frame = front?.frame ?? NSRect(x: 200, y: 200, width: 1440, height: 900)
        open(frame.offsetBy(dx: 28, dy: -28))
    }

    // quits when its last window is closed, not when its windows are put away on another of ReDesk's desktops
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { putAway.isEmpty }

    func applicationWillTerminate(_ notification: Notification) {
        for case let w as NoteWindow in NSApp.windows { w.host.page?.leave() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, NSApp.windows.compactMap({ $0 as? NoteWindow }).isEmpty { newWindow(from: nil) }
        return true
    }

    /// the menu: what the keys need (⌘Z, ⌘C, ⌘V, ⌘H, ⌘Q…)
    private func menu() -> NSMenu {
        let bar = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Hide ReNote", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(.separator())
        app.addItem(withTitle: "Quit ReNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        bar.addItem(withTitle: "ReNote", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        bar.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        bar.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = window
        NSApp.windowsMenu = window
        return bar
    }
}

let app = ReApp.shared
if let i = CommandLine.arguments.firstIndex(of: "--render"), i + 1 < CommandLine.arguments.count {
    Render.run(into: CommandLine.arguments[i + 1])
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
