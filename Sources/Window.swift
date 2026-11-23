import AppKit

// The window: no title bar, no rim, no shadow; glass (the system's blur of what is behind it) with the
// page on it. ReDesk draws its opening and closing, lays one glass under windows it joins, pins one (⌃⌥P),
// hides and shows the app's windows: it says so with distributed notifications (Desk below).

enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

enum Route {
    case home
    /// a space's page, a note in it chosen
    case space(String, Int64?)
    /// a note on the whole page
    case note(Int64)
    /// a new note, in a space chosen beforehand
    case new(String?)
}

/// what the window shows: one page at a time
class Page: Flipped {
    weak var host: Host?

    /// a key pressed: whether the page took it
    func key(_ e: NSEvent) -> Bool { false }
    /// the page is shown now
    func appear() {}
    /// the page goes: what is typed is kept
    func leave() {}
    /// the window became the one in use, or stopped being it
    func focusChanged(_ focused: Bool) {}

    var wide: Bool { host?.wide ?? true }
    var W: CGFloat { bounds.width }
    var H: CGFloat { bounds.height }

    /// whether something is being typed in (a line or a note's text)
    var typing: Bool { window?.firstResponder is NSTextView }

    func place(_ b: SideButton, _ c: Corner) { host?.place(b, c, in: self) }
}

// ── the window ──

final class NoteWindow: NSWindow {
    let host = Host()
    let root: Root
    private var closing = false

    init(frame: NSRect) {
        root = Root(host: host)
        super.init(contentRect: frame, styleMask: [.borderless, .resizable, .miniaturizable, .closable], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        title = "ReNote"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 360, height: 240)
        appearance = NSAppearance(named: .darkAqua)
        contentView = root
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: self, queue: .main) { [weak self] _ in self?.host.focusChanged(true) }
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: self, queue: .main) { [weak self] _ in self?.host.focusChanged(false) }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // a window ReDesk tiles as any other
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .standardWindow }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, host.key(event) { return }
        super.sendEvent(event)
    }

    /// shown softly: ReDesk draws the opening, then says to show it; without ReDesk it fades in
    func open() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if Desk.tell("open", self) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if let self, self.alphaValue < 0.01 { Fade.windows([self], to: 1) }
            }
        } else {
            Fade.windows([self], to: 1, duration: 0.3, timing: .easeOut)
        }
    }

    /// a window asked to close fades out first, then goes (ReDesk draws the closing under it)
    override func close() {
        host.page?.leave()
        if closing || !isVisible || alphaValue < 0.01 { return super.close() }
        closing = true
        _ = Desk.tell("close", self)
        Fade.windows([self], to: 0) { [weak self] in self?.close() }
    }

    override func performClose(_ sender: Any?) { close() }
}

enum Fade {
    static let seconds = 0.4

    static func windows(_ windows: [NSWindow], to alpha: CGFloat, duration: Double = seconds,
                        timing: CAMediaTimingFunctionName = .easeInEaseOut, done: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = duration
            c.timingFunction = CAMediaTimingFunction(name: timing)
            for w in windows { w.animator().alphaValue = alpha }
        }, completionHandler: done)
    }
}

/// the window's content: its glass, and the page on it
final class Root: Flipped {
    let glass = NSVisualEffectView()
    let host: Host

    /// joined to others (Flush): ReDesk lays one glass under them all, the window drops its own
    var shared = false {
        didSet {
            glass.isHidden = shared
            // a window with nothing under it lets a click through to the desktop, where macOS takes it for a click on
            // the wallpaper and slides every window aside: a wash too faint to see keeps the clicks the window's
            wantsLayer = true
            layer?.backgroundColor = shared ? NSColor(white: 0, alpha: 0.01).cgColor : nil
        }
    }

    init(host: Host) {
        self.host = host
        super.init(frame: .zero)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .darkAqua)
        glass.autoresizingMask = [.width, .height]
        addSubview(glass)
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// ── the page's host: the page, INFO, the popups, the marks in the corner ──

final class Host: Flipped {
    private(set) var page: Page?
    private var history: [Route] = []
    private(set) var route: Route = .home

    private let info = SideButton("INFO") {}
    private let marks = Marks()
    private let strip = DragStrip()
    private var popup: Popup?

    var wide: Bool { bounds.width >= 760 && bounds.height >= 560 }
    var focused = true

    var pinned = false { didSet { marks.pinned = pinned } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        info.action = { [weak self] in self?.showInfo() }
        info.title = "Info"
        addSubview(info)
        addSubview(strip)
        addSubview(marks)
    }

    required init?(coder: NSCoder) { fatalError() }

    // ── pages ──

    func go(_ to: Route, remember: Bool = true) {
        page?.leave()
        if remember, page != nil { history.append(route) }
        route = to
        let next: Page
        switch to {
        case .home: next = HomePage()
        case .space(let element, let note): next = SpacePage(element: element, note: note)
        case .note(let id): next = EditPage(note: id)
        case .new(let element): next = EditPage(newIn: element)
        }
        next.host = self
        page?.removeFromSuperview()
        page = next
        next.frame = bounds
        next.autoresizingMask = [.width, .height]
        addSubview(next, positioned: .below, relativeTo: info)
        next.layoutSubtreeIfNeeded()
        next.needsLayout = true
        // as the pages faded in
        next.alphaValue = 0
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.3
            c.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            next.animator().alphaValue = 1
        }
        next.appear()
        layoutCorners()
    }

    /// to the page before this one (home when there is none)
    func back() {
        go(history.popLast() ?? .home, remember: false)
    }

    // ── its pieces laid out ──

    override func layout() {
        super.layout()
        layoutCorners()
        popup?.frame = bounds
    }

    private func layoutCorners() {
        if let page { place(info, .bottomLeft, in: self); _ = page }
        strip.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 28)
        marks.frame = NSRect(x: 14, y: 14, width: 13, height: 40)
    }

    /// a side button in its corner, as in every Re app (gone in a small window: the keys only)
    func place(_ b: SideButton, _ c: Corner, in view: NSView) {
        let W = view.bounds.width, H = view.bounds.height
        b.isHidden = !wide
        b.top = c == .topLeft || c == .topRight
        let h = b.intrinsicContentSize.height
        let left = c == .topLeft || c == .bottomLeft
        let x = left ? W * Spacing.x - 28 : W - (W * Spacing.x - 28) - SideButton.width
        let y = b.top ? H * Spacing.y + 8 : H - H * Spacing.y - h
        b.frame = NSRect(x: x, y: y, width: SideButton.width, height: h)
    }

    func focusChanged(_ focused: Bool) {
        self.focused = focused
        marks.focused = focused
        page?.focusChanged(focused)
    }

    // ── keys ──

    func key(_ e: NSEvent) -> Bool {
        if let popup {
            if popup.key(e) { return true }
            if popup.modal { return true }
        }
        let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods == .command && e.keyCode == 45 { // ⌘N: another window
            (NSApp.delegate as? AppDelegate)?.newWindow(from: window)
            return true
        }
        if mods == .command && e.keyCode == 13 { // ⌘W: this one closes
            window?.close()
            return true
        }
        return page?.key(e) ?? false
    }

    // ── popups: the page blurred behind, a pane in the middle ──

    func show(_ content: NSView, modal: Bool, keys: ((NSEvent) -> Bool)? = nil) {
        close()
        let p = Popup(content: content, modal: modal)
        p.keys = keys
        p.onClose = { [weak self] in self?.close() }
        p.frame = bounds
        addSubview(p, positioned: .below, relativeTo: strip)
        popup = p
    }

    func close() {
        popup?.removeFromSuperview()
        popup = nil
    }

    var popupShown: Bool { popup != nil }

    // ── INFO: how many notes, where, and the keys ──

    func showInfo() {
        if popupShown { return close() }
        let stats = Store.shared.stats()
        let shortcuts: [(String, String)] = [
            ("⌘ + N", "New window"),
            ("⌘ + S", "Save"),
            ("⌘ + B", "Highlight selected text"),
            ("⌘ + D", "Draw"),
            ("Esc", "Back / Close"),
            ("F / B / M / S", "Open Feel / Body / Mind / Soul"),
            ("N", "New note"),
            ("E / Enter", "Edit note"),
            ("/", "Search"),
            ("⌘ + F", "Search / Full mode while editing"),
            ("↑ / ↓", "Navigate notes"),
            ("← / →", "Switch space"),
            ("Option + ← / →", "Switch space (new / full note)"),
            ("Backspace", "Delete note"),
        ]
        var views: [NSView] = [heading("RE:NOTE"), divider()]
        views.append(contentsOf: counts(stats))
        views.append(divider())
        let keys = shortcuts.map { k, d in
            row(label(tx(k), Fonts.buttons(11), Ink.text.withAlphaComponent(0.6), kern: 0.55),
                label(tx(d), Fonts.words(14), align: .right))
        }
        views.append(stack(keys, spacing: 9.6))
        views.append(divider())
        views.append(label(tx("local · private · offline"), Fonts.words(13), Ink.text.withAlphaComponent(0.4), kern: 1.3))
        show(stack(views, spacing: 24, center: true), modal: false) { [weak self] e in
            if e.keyCode == 53 { self?.close(); return true }
            return false
        }
    }

    // ── pieces of popups ──

    func heading(_ s: String) -> NSView { label(s, Fonts.buttons(18), kern: 7.2) }

    func divider() -> NSView {
        let line = Flipped()
        line.wantsLayer = true
        line.layer?.backgroundColor = Ink.line.withAlphaComponent(0.5 * 0.3).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    /// "{n} notes", and each space's
    func counts(_ stats: (total: Int, bySpace: [String: Int])) -> [NSView] {
        let total = label(tx(stats.total == 1 ? "{n} note" : "{n} notes", ["n": stats.total]), Fonts.words(32), kern: 1.6)
        let rows = SPACES.map { s -> NSView in
            let shape = ShapeView(s.element)
            shape.translatesAutoresizingMaskIntoConstraints = false
            shape.widthAnchor.constraint(equalToConstant: 12).isActive = true
            shape.heightAnchor.constraint(equalToConstant: 12).isActive = true
            let name = label(s.english.uppercased(), Fonts.buttons(13), kern: 2.6)
            let left = NSStackView(views: [shape, name])
            left.spacing = 12
            left.alignment = .centerY
            return row(left, label("\(stats.bySpace[s.english] ?? 0)", Fonts.words(18), Ink.text.withAlphaComponent(0.6)))
        }
        return [total, stack(rows, spacing: 8)]
    }

    func row(_ left: NSView, _ right: NSView) -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let r = NSStackView(views: [left, spacer, right])
        r.orientation = .horizontal
        r.alignment = .centerY
        r.spacing = 16
        right.setContentCompressionResistancePriority(.required, for: .horizontal)
        left.setContentCompressionResistancePriority(.required, for: .horizontal)
        return r
    }

    /// pieces one under another; lines and rows as wide as the pane
    func stack(_ views: [NSView], spacing: CGFloat, center: Bool = false) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.spacing = spacing
        s.alignment = center ? .centerX : .leading
        for v in views where v is NSStackView || v.className.hasSuffix("Flipped") {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
        }
        return s
    }
}

/// a pane in the middle, the page blurred behind; a click beside it closes it
final class Popup: Flipped {
    let modal: Bool
    var keys: ((NSEvent) -> Bool)?
    var onClose: (() -> Void)?
    private let pane = Flipped()
    private let marks = CornerMarks()
    private let content: NSView
    private let scroll = FadeScroll()
    private let page = Flipped()

    init(content: NSView, modal: Bool) {
        self.content = content
        self.modal = modal
        super.init(frame: .zero)
        let blur = veil()
        blur.autoresizingMask = [.width, .height]
        blur.alphaValue = 0.85
        addSubview(blur)
        let paneBlur = veil()
        paneBlur.autoresizingMask = [.width, .height]
        pane.addSubview(paneBlur)
        pane.wantsLayer = true
        pane.layer?.backgroundColor = Ink.pane.cgColor
        // taller than the window allows: it scrolls, its lines fading at the edges
        page.addSubview(content)
        scroll.documentView = page
        pane.addSubview(scroll)
        addSubview(pane)
        // no frame round the pane: a + at each of its corners
        addSubview(marks)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        subviews.first?.frame = bounds
        let fit = content.fittingSize
        let w = max(280, fit.width + 96), h = min(fit.height + 80, bounds.height * 0.8)
        pane.frame = NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h).integral
        marks.frame = bounds
        marks.pane = pane.frame
        pane.subviews.first?.frame = pane.bounds
        scroll.frame = NSRect(x: 2, y: 2, width: pane.bounds.width - 4, height: pane.bounds.height - 4)
        page.frame = NSRect(x: 0, y: 0, width: scroll.bounds.width, height: fit.height + 76)
        content.frame = NSRect(x: 46, y: 38, width: w - 96, height: fit.height)
    }

    func key(_ e: NSEvent) -> Bool { keys?(e) ?? false }

    override func mouseDown(with event: NSEvent) {
        if !pane.frame.contains(convert(event.locationInWindow, from: nil)) { onClose?() }
    }
}

/// In the corner where macOS has its buttons: a diamond while this window is the focused one, and P while
/// ReDesk has it pinned (⌃⌥P), under the diamond or in its place.
final class Marks: Flipped {
    var focused = true { didSet { needsDisplay = true } }
    var pinned = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let ink = NSColor(white: 1, alpha: 0.8 * 0.9)
        var y: CGFloat = 0
        if focused {
            ink.setFill()
            let c = NSPoint(x: 6.5, y: 6.5)
            let d: CGFloat = 9 / 2 * sqrt(2)
            let p = NSBezierPath()
            p.move(to: NSPoint(x: c.x, y: c.y - d)); p.line(to: NSPoint(x: c.x + d, y: c.y))
            p.line(to: NSPoint(x: c.x, y: c.y + d)); p.line(to: NSPoint(x: c.x - d, y: c.y)); p.close()
            p.fill()
            y = 13 + 6
        }
        if pinned {
            let s = attributed("P", Fonts.buttons(15), ink)
            s.draw(at: NSPoint(x: (13 - s.size().width) / 2, y: y - 2))
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// an invisible strip along the top: the window moves with it
final class DragStrip: Flipped {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
            return
        }
        window?.performDrag(with: event)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// ── ReDesk ──

enum Desk {
    static let id = "com.artursavytskyi.redesk"

    static var running: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty }

    /// Tells ReDesk a window opens or closes ("open" / "close"), so it draws that; whether ReDesk is there to.
    static func tell(_ kind: String, _ window: NSWindow) -> Bool {
        guard running else { return false }
        DistributedNotificationCenter.default().postNotificationName(
            .init("com.artursavytskyi.re.opening"), object: "\(kind) \(getpid()) \(window.windowNumber)",
            userInfo: nil, deliverImmediately: true)
        return true
    }

    private static var windows: [NoteWindow] { NSApp.windows.compactMap { $0 as? NoteWindow } }

    /// once, at start
    static func listen() {
        let center = DistributedNotificationCenter.default()
        // "hide" / "show" / "close" all the app's windows, "hide <pid>" this app alone,
        // "hide-window <pid> <n>" / "show-window …" one window out of sight on another desktop, or back
        // a window closed is no longer put away (a closed window stays in NSApp.windows)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            if let w = note.object as? NSWindow { putAway[w.windowNumber] = nil }
        }
        center.addObserver(forName: .init("com.artursavytskyi.re.windows"), object: nil, queue: .main) { note in
            guard let said = note.object as? String else { return }
            let words = said.split(separator: " ").map(String.init)
            let me = "\(getpid())"
            if words.count == 3, words[0] == "hide-window" || words[0] == "show-window" {
                guard words[1] == me, let n = Int(words[2]), let w = NSApp.window(withWindowNumber: n) else { return }
                if words[0] == "hide-window" {
                    putAway[n] = w
                    Fade.windows([w], to: 0) {
                        // shown again before it was done fading: it stays
                        guard putAway[n] != nil else { return }
                        w.orderOut(nil)
                        w.alphaValue = 1
                    }
                } else {
                    putAway[n] = nil
                    w.alphaValue = 0
                    w.orderFront(nil)
                    Fade.windows([w], to: 1)
                }
                return
            }
            if said == "hide \(me)" {
                if !NSApp.isHidden { NSApp.hide(nil) }
                return
            }
            switch said {
            case "hide": if !NSApp.isHidden { NSApp.hide(nil) }
            case "show": if NSApp.isHidden { NSApp.unhideWithoutActivation() }
            case "close":
                let all = windows
                for w in all { w.host.page?.leave() }
                Fade.windows(all.filter(\.isVisible), to: 0) { for w in all { w.close() } }
            default: break
            }
        }

        // which window ReDesk pinned (⌃⌥P), and which it joined (Flush) under one glass
        center.addObserver(forName: .init("com.artursavytskyi.re.corners"), object: nil, queue: .main) { note in
            guard let info = note.userInfo else { return }
            func number(_ key: String) -> Double { (info[key] as? NSNumber)?.doubleValue ?? -1 }
            guard Int32(number("pid")) == getpid() else { return }
            let top = NSScreen.screens.first?.frame.maxY ?? 0
            let near = { (a: Double, b: Double) in abs(a - b) < 24 }
            for w in windows {
                let f = w.frame
                if near(f.minX, number("x")) && near(top - f.maxY, number("y")) && near(f.width, number("w")) && near(f.height, number("h")) {
                    w.host.pinned = number("pinned") == 1
                    w.root.shared = number("shared") == 1
                }
            }
        }

        // the app shown again: its windows fade in
        let local = NotificationCenter.default
        local.addObserver(forName: NSApplication.willUnhideNotification, object: nil, queue: .main) { _ in
            for w in NSApp.windows { w.alphaValue = 0 }
        }
        local.addObserver(forName: NSApplication.didUnhideNotification, object: nil, queue: .main) { _ in
            Fade.windows(NSApp.windows, to: 1)
        }
    }
}

/// hide: (⌘H, ReDesk's Hide Windows): the windows fade out first
final class ReApp: NSApplication {
    private var hiding = false

    override func hide(_ sender: Any?) {
        if hiding { return super.hide(sender) }
        hiding = true
        Fade.windows(windows.filter(\.isVisible), to: 0) { [weak self] in
            guard let self else { return }
            self.hide(sender)
            for w in self.windows { w.alphaValue = 1 }
            self.hiding = false
        }
    }
}

/// The windows put away on another of ReDesk's desktops, by number, held here: out of sight, nothing else
/// keeps one (AppKit lets it go, and it never comes back); and the last of them would count as the last
/// window closed and quit the app: they keep it running.
var putAway: [Int: NSWindow] = [:]

/// a pane's four corners marked with a thin + instead of a frame round it (as ReDesk marks windows' corners)
final class CornerMarks: NSView {
    static let arm: CGFloat = 7
    /// the pane it marks, in this view's coordinates
    var pane: NSRect = .zero { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath()
        let a = Self.arm
        for p in [NSPoint(x: pane.minX, y: pane.minY), NSPoint(x: pane.maxX, y: pane.minY),
                  NSPoint(x: pane.minX, y: pane.maxY), NSPoint(x: pane.maxX, y: pane.maxY)] {
            let x = p.x.rounded() + 0.25, y = p.y.rounded() - 0.25
            path.move(to: NSPoint(x: x - a, y: y)); path.line(to: NSPoint(x: x + a, y: y))
            path.move(to: NSPoint(x: x, y: y - a)); path.line(to: NSPoint(x: x, y: y + a))
        }
        path.lineWidth = 1.5
        NSColor(white: 1, alpha: 0.5).setStroke()
        path.stroke()
    }
}
