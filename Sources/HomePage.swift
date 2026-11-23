import AppKit
import UniformTypeIdentifiers

// Home: the four spaces in a row, each its shape named under it; a search over every note at the top.
// NOVA top right, IMPR top left, EXPR bottom right, INFO bottom left (the host's).

final class HomePage: Page {
    private let search = Field(size: 18, align: .center)
    private let nova = SideButton("NOVA") {}
    private let impr = SideButton("IMPR") {}
    private let expr = SideButton("EXPR") {}
    private var tiles: [SpaceTile] = []
    private let results = Results()
    private let blur = veil()

    private var notes: [Note] = []
    private var found: [Note] = []
    private var chosen = 0 { didSet { results.chosen = chosen } }

    /// F / B / M / S: Feel, Body, Mind, Soul (the keys where they are, whatever the keyboard's letters)
    private let keys: [UInt16: String] = [3: "water", 11: "earth", 46: "fire", 1: "air"]
    private let letters = ["water": "F", "earth": "B", "fire": "M", "air": "S"]
    private let names = ["water": "FEEL", "earth": "BODY", "fire": "MIND", "air": "SOUL"]

    override init(frame: NSRect) {
        super.init(frame: frame)
        nova.action = { [weak self] in self?.host?.go(.new(nil)) }
        nova.title = "New note"
        impr.action = { [weak self] in self?.importNotes() }
        impr.title = "Import"
        expr.action = { [weak self] in self?.showExport() }
        expr.title = "Export"

        for space in Store.shared.spaces {
            let tile = SpaceTile(element: space.element, name: names[space.element] ?? space.english.uppercased()) { [weak self] in
                self?.host?.go(.space(space.element, nil))
            }
            tiles.append(tile)
            addSubview(tile)
        }
        [nova, impr, expr].forEach(addSubview)

        blur.isHidden = true
        blur.alphaValue = 0.85
        addSubview(blur)
        search.placeholder = "Search"
        search.toolTip = "Search all notes (/)"
        search.onChange = { [weak self] in self?.find() }
        addSubview(search)
        results.isHidden = true
        results.open = { [weak self] i in self?.open(i) }
        results.hover = { [weak self] i in self?.chosen = i }
        addSubview(results)
        blur.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clearSearch)))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func appear() {
        notes = Store.shared.notes()
        let counts = Dictionary(grouping: notes, by: \.spaceId).mapValues(\.count)
        for (tile, space) in zip(tiles, Store.shared.spaces) {
            tile.toolTip = "\(space.english) (\(letters[space.element] ?? "")) — \(counts[space.id] ?? 0) notes"
        }
        find()
    }

    override func layout() {
        super.layout()
        place(impr, .topLeft)
        place(nova, .topRight)
        place(expr, .bottomRight)

        // the spaces between the side buttons, in the middle
        let side = wide ? W * Spacing.x + 64 : 24
        let area = NSRect(x: side, y: 64, width: max(0, W - 2 * side), height: max(0, H - 64 - 44))
        let s = wide ? min(0.13 * W, 0.3 * H) : min(0.17 * W, 0.34 * H)
        let gap = 0.04 * W
        let tileW = max(s, 60), tileH = s + 12 + 18
        let total = CGFloat(tiles.count) * tileW + CGFloat(tiles.count - 1) * gap
        var x = area.midX - total / 2
        for tile in tiles {
            tile.frame = NSRect(x: x, y: area.midY - tileH / 2, width: tileW, height: tileH).integral
            tile.mark = s
            x += tileW + gap
        }

        let top: CGFloat = wide ? 30 : 14
        let width = min(360, W - 160)
        search.frame = NSRect(x: (W - width) / 2, y: top, width: width, height: 32)
        blur.frame = bounds
        let h = results.height(width: width)
        results.frame = NSRect(x: (W - width) / 2, y: top + 32 + 16, width: width, height: h)
    }

    // ── search ──

    private func find() {
        let q = search.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            found = []
        } else {
            found = Array(notes.filter { $0.title.lowercased().contains(q) || withoutDrawings($0.body).lowercased().contains(q) }.prefix(8))
        }
        chosen = 0
        results.rows = found.map { n in (Store.shared.space(id: n.spaceId)?.element ?? "water", n.title.isEmpty ? "Untitled" : n.title) }
        results.isHidden = q.isEmpty
        blur.isHidden = q.isEmpty
        needsLayout = true
    }

    @objc private func clearSearch() {
        search.stringValue = ""
        find()
    }

    private func open(_ i: Int) {
        guard i < found.count, let space = Store.shared.space(id: found[i].spaceId) else { return }
        host?.go(.space(space.element, found[i].id))
    }

    // ── keys ──

    override func key(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
        if search.editing {
            let count = found.count
            switch e.keyCode {
            case 125 where count > 0: chosen = (chosen + 1) % count; return true
            case 126 where count > 0: chosen = (chosen - 1 + count) % count; return true
            case 36, 76: if count > 0 { open(chosen) }; return true
            case 53:
                clearSearch()
                window?.makeFirstResponder(nil)
                return true
            default: return false
            }
        }
        if typing || !mods.isEmpty { return false }
        if e.keyCode == 44 { // /
            search.focus()
            return true
        }
        if let element = keys[e.keyCode] {
            host?.go(.space(element, nil))
            return true
        }
        return false
    }

    // ── export and import: one JSON file of every note ──

    private func showExport() {
        guard let host else { return }
        let stats = Store.shared.stats()
        var views: [NSView] = [host.heading(tx("EXPORT")), host.divider()]
        views.append(contentsOf: host.counts(stats))
        views.append(host.divider())
        views.append(BoxButton(tx("EXPORT"), size: 16, kern: 4.8, pad: NSSize(width: 32, height: 8)) { [weak self] in self?.export() })
        host.show(host.stack(views, spacing: 24, center: true), modal: true) { [weak self] e in
            switch e.keyCode {
            case 36, 76: self?.export(); return true
            case 53: self?.host?.close(); return true
            default: return false
            }
        }
    }

    private func export() {
        let spaces = Store.shared.spaces
        func js(_ s: String) -> String {
            let e = JSONEncoder()
            e.outputFormatting = .withoutEscapingSlashes
            return (try? e.encode(s)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        }
        let notes = Store.shared.notes().map { n -> String in
            let element = spaces.first { $0.id == n.spaceId }?.element ?? "water"
            return """
                    {
                      "spaceElement": \(js(element)),
                      "title": \(js(n.title)),
                      "body": \(js(n.body)),
                      "createdAt": \(n.createdAt),
                      "updatedAt": \(n.updatedAt)
                    }
                """
        }
        let json = """
            {
              "version": 1,
              "exportedAt": \(now()),
              "notes": [
            \(notes.joined(separator: ",\n"))
              ]
            }
            """
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: TimeZone(identifier: "UTC")!, formatOptions: [.withFullDate])
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "renote-backup-\(day).json"
        panel.allowedContentTypes = [.json]
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] answer in
            guard answer == .OK, let url = panel.url else { return }
            try? json.write(to: url, atomically: true, encoding: .utf8)
            self?.host?.close()
        }
    }

    private func importNotes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] answer in
            guard answer == .OK, let url = panel.url, let data = try? Data(contentsOf: url),
                  let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let list = parsed["notes"] as? [[String: Any]] else { return }
            let spaces = Store.shared.spaces
            guard let first = spaces.first else { return }
            let time = now()
            Store.shared.addMany(list.map { n in
                let space = spaces.first { $0.element == n["spaceElement"] as? String } ?? first
                return (space.id, n["title"] as? String ?? "Untitled", n["body"] as? String ?? "",
                        (n["createdAt"] as? NSNumber)?.int64Value ?? time, (n["updatedAt"] as? NSNumber)?.int64Value ?? time)
            })
            self?.appear()
        }
    }
}

/// a space on the home page: its shape, its name under it; a click opens it
final class SpaceTile: Flipped {
    let element: String
    let name: String
    let action: () -> Void
    var mark: CGFloat = 100 { didSet { needsDisplay = true } }
    private var hover = false { didSet { needsDisplay = true } }

    init(element: String, name: String, _ action: @escaping () -> Void) {
        self.element = element
        self.name = name
        self.action = action
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = hover ? 1 : 0.8
        let side = mark * 0.64
        let rect = NSRect(x: bounds.midX - side / 2, y: mark / 2 - side / 2, width: side, height: side)
        Shape.draw(element, in: rect, stroke: 2, color: Ink.line.withAlphaComponent(0.5 * alpha))
        let s = attributed(name, Fonts.buttons(12), Ink.text.withAlphaComponent(0.8 * alpha), kern: 3.6)
        let size = s.size()
        s.draw(at: NSPoint(x: bounds.midX - (size.width - 3.6) / 2, y: mark + 12))
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hover = true }
    override func mouseExited(with event: NSEvent) { hover = false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action() }
    }
}

/// the notes found: each its space's shape and its title, the chosen one's shape filled
final class Results: Flipped {
    var rows: [(element: String, title: String)] = [] { didSet { needsDisplay = true; updateTrackingAreas() } }
    var chosen = 0 { didSet { needsDisplay = true } }
    var open: ((Int) -> Void)?
    var hover: ((Int) -> Void)?

    private let pad = NSSize(width: 24, height: 20)
    private let rowH: CGFloat = 20
    private let gap: CGFloat = 12

    func height(width: CGFloat) -> CGFloat {
        let n = CGFloat(max(1, rows.count))
        return pad.height * 2 + n * rowH + (n - 1) * gap
    }

    override func draw(_ dirtyRect: NSRect) {
        Ink.paper.setFill()
        bounds.fill()
        let frame = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        frame.lineWidth = 2
        Ink.line.setStroke()
        frame.stroke()
        if rows.isEmpty {
            let s = attributed("Nothing found.", Fonts.words(16), Ink.line.withAlphaComponent(0.5 * 0.4))
            s.draw(at: NSPoint(x: (bounds.width - s.size().width) / 2, y: pad.height))
            return
        }
        for (i, row) in rows.enumerated() {
            let y = pad.height + CGFloat(i) * (rowH + gap)
            let alpha: CGFloat = i == chosen ? 1 : 0.8
            let color = Ink.line.withAlphaComponent(0.5 * alpha)
            Shape.draw(row.element, in: NSRect(x: pad.width, y: y + 3, width: 14, height: 14), stroke: 1.5, filled: i == chosen, color: color)
            let s = attributed(row.title, Fonts.words(16), color, align: .left)
            s.draw(with: NSRect(x: pad.width + 14 + 12, y: y, width: bounds.width - pad.width * 2 - 26, height: rowH),
                   options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    private func row(at point: NSPoint) -> Int? {
        let i = Int((point.y - pad.height + gap / 2) / (rowH + gap))
        return i >= 0 && i < rows.count ? i : nil
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        if let i = row(at: convert(event.locationInWindow, from: nil)) { hover?(i) }
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if let i = row(at: convert(event.locationInWindow, from: nil)) { open?(i) }
    }
}
