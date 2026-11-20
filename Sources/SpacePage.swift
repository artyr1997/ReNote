import AppKit

// A space: its shape with its name on the left, its notes under it (a search over them on top), and the
// note chosen on the right, written in right there. HOME top left, NOVA top right, FULL bottom right (the
// note on the whole page), INFO bottom left. A small window: no shape, the list and the note side by side.

final class SpacePage: Page {
    private let space: Space?
    private var notes: [Note] = []
    private var active: Int64?

    private let home = SideButton("HOME") {}
    private let nova = SideButton("NOVA") {}
    private let full = SideButton("FULL", as: "FULL NOTE") {}
    private let shape: BigShape
    private let compactTitle: NSTextField
    private let search = Field(size: 18, align: .center)
    private let list = NotesList()
    private let listScroll = FadeScroll()
    private let title = Field(size: 18, align: .center)
    private let bodyScroll: FadeScroll
    private let body: NoteText

    private var saving: DispatchWorkItem?

    init(element: String, note: Int64?) {
        space = Store.shared.space(element)
        shape = BigShape(element: element, name: space?.english.uppercased() ?? "")
        compactTitle = label(space?.english.uppercased() ?? "", Fonts.buttons(12), NSColor(white: 1, alpha: 0.48), kern: 3.6, align: .center)
        (bodyScroll, body) = NoteText.make()
        super.init(frame: .zero)
        active = note

        home.action = { [weak self] in self?.host?.go(.home) }
        home.title = "Home (Esc)"
        nova.action = { [weak self] in self?.host?.go(.new(element)) }
        nova.title = "New note (N)"
        full.action = { [weak self] in
            guard let self, let id = self.active else { return }
            self.host?.go(.note(id))
        }
        full.title = "Full note (⌘F)"

        addSubview(shape)
        addSubview(compactTitle)
        search.placeholder = "Search"
        search.toolTip = "Search (/)"
        search.onChange = { [weak self] in self?.refreshList() }
        addSubview(search)
        listScroll.documentView = list
        list.pick = { [weak self] id in self?.select(id) }
        addSubview(listScroll)

        title.placeholder = "Title"
        title.placeholderAlpha = 0.25
        title.maxLength = TITLE_MAX
        title.onChange = { [weak self] in
            self?.changed()
            self?.refreshList()
        }
        addSubview(title)
        body.size = 16
        body.lineHeight = 1.8
        body.onChange = { [weak self] in self?.changed() }
        addSubview(bodyScroll)
        [home, nova, full].forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func appear() {
        reload()
        let initial = notes.first { $0.id == active } ?? notes.first
        active = nil
        if let initial { show(initial) }
        body.disabled = notes.isEmpty
        title.isEnabled = !notes.isEmpty
        title.alphaValue = notes.isEmpty ? 0.3 : 1
        refreshList()
    }

    override func leave() { flush() }

    private func reload() {
        guard let space else { return }
        notes = Store.shared.notes(in: space.id)
    }

    private var filtered: [Note] {
        let q = search.stringValue.lowercased()
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { return notes }
        return notes.filter { $0.title.lowercased().contains(q) || withoutDrawings($0.body).lowercased().contains(q) }
    }

    private func refreshList() {
        list.rows = filtered.map { n in
            (n.id, (n.id == active ? title.stringValue : n.title).isEmpty ? "Untitled" : (n.id == active ? title.stringValue : n.title))
        }
        list.active = active
        list.empty = notes.isEmpty || filtered.isEmpty
        full.isHidden = active == nil || !wide
        needsLayout = true
    }

    // ── the note chosen ──

    private func show(_ note: Note) {
        active = note.id
        title.stringValue = note.title
        body.load(note.body)
        refreshList()
    }

    private func select(_ id: Int64) {
        guard id != active, let note = notes.first(where: { $0.id == id }) else { return }
        flush()
        show(notes.first { $0.id == note.id } ?? note)
    }

    /// written shortly after a change
    private func changed() {
        saving?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saving = nil
            self?.save()
        }
        saving = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func flush() {
        guard let work = saving else { return }
        work.cancel()
        saving = nil
        save()
    }

    private func save() {
        guard let id = active else { return }
        let t = String(title.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TITLE_MAX))
        let b = body.value
        let time = now()
        // the list keeps the text saved, for when it is chosen again
        if let i = notes.firstIndex(where: { $0.id == id }) {
            notes[i].title = t
            notes[i].body = b
            notes[i].updatedAt = time
        }
        Store.shared.update(id, title: t, body: b, updatedAt: time)
    }

    /// ⌘S: saved, the list in order again, SAVED a moment
    private func saveWithToast() {
        saving?.cancel()
        saving = nil
        save()
        reload()
        refreshList()
        host?.saved()
    }

    private func selectRelative(_ delta: Int) {
        let rows = filtered
        guard !rows.isEmpty else { return }
        let i = rows.firstIndex { $0.id == active }
        let next = i.map { ($0 + delta + rows.count) % rows.count } ?? (delta > 0 ? 0 : rows.count - 1)
        select(rows[next].id)
        list.reveal(rows[next].id)
    }

    private func switchSpace(_ delta: Int) {
        guard let space, let i = SPACES.firstIndex(where: { $0.element == space.element }) else { return }
        host?.go(.space(SPACES[(i + delta + SPACES.count) % SPACES.count].element, nil))
    }

    private func confirmDelete() {
        guard let host, active != nil else { return }
        let text = label(tx("Delete this note?"), Fonts.buttons(16), kern: 3.2)
        let yes = BoxButton(tx("YES"), kern: 3.2, pad: NSSize(width: 19.2, height: 6.4)) { [weak self] in self?.delete() }
        let no = BoxButton(tx("NO"), kern: 3.2, pad: NSSize(width: 19.2, height: 6.4)) { [weak self] in self?.host?.close() }
        let buttons = NSStackView(views: [yes, no])
        buttons.spacing = 32
        let content = NSStackView(views: [text, buttons])
        content.orientation = .vertical
        content.spacing = 24
        host.show(content, modal: true) { [weak self] e in
            switch e.keyCode {
            case 36, 76: self?.delete(); return true
            case 53: self?.host?.close(); return true
            default: return false
            }
        }
    }

    private func delete() {
        host?.close()
        guard let id = active else { return }
        saving?.cancel()
        saving = nil
        Store.shared.delete(id)
        active = nil
        title.stringValue = ""
        body.load("")
        appear()
    }

    // ── keys ──

    override func key(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods == .command && e.keyCode == 1 { saveWithToast(); return true }            // ⌘S
        if e.keyCode == 53 { host?.go(.home); return true }                               // Esc
        if mods == .command && e.keyCode == 3 {                                            // ⌘F
            if body.editing, let id = active { host?.go(.note(id)) } else { search.focus() }
            return true
        }
        // in the search: the arrows move through what it found, Enter writes in the one chosen
        if search.editing {
            switch e.keyCode {
            case 125: selectRelative(1); return true
            case 126: selectRelative(-1); return true
            case 36, 76:
                if active != nil { body.focusAtEnd() }
                return true
            default: return false
            }
        }
        if typing || !mods.isEmpty { return false }
        switch e.keyCode {
        case 45: if let space { host?.go(.new(space.element)) }                             // N
        case 14, 36, 76: if active != nil { body.focusAtEnd() } else { return false }      // E / Enter
        case 44: search.focus()                                                             // /
        case 125: selectRelative(1)
        case 126: selectRelative(-1)
        case 123: switchSpace(-1)
        case 124: switchSpace(1)
        case 51, 117: if active != nil { confirmDelete() } else { return false }           // Backspace
        default: return false
        }
        return true
    }

    // ── laid out ──

    override func layout() {
        super.layout()
        place(home, .topLeft)
        place(nova, .topRight)
        place(full, .bottomRight)
        full.isHidden = active == nil || !wide
        shape.isHidden = !wide
        compactTitle.isHidden = wide

        if wide {
            let x = W * 0.28125 - 181.5
            let top = H * 0.0625 + 1
            shape.frame = NSRect(x: x, y: top, width: 398, height: 320)
            search.alignment = .center
            let left = NSRect(x: x, y: top + 264 + 24, width: 398, height: max(0, H - top * 2 - 264 - 24))
            search.frame = NSRect(x: left.minX, y: left.minY, width: left.width, height: 32)
            listScroll.frame = NSRect(x: left.minX + 112, y: left.minY + 32 + 32, width: left.width - 112, height: max(0, left.height - 64))
            let right = NSRect(x: W * 0.5, y: top, width: W * 0.21875 + 181.5, height: max(0, H - top * 2))
            title.frame = NSRect(x: right.minX + 24, y: right.minY, width: right.width - 48, height: 32)
            bodyScroll.frame = NSRect(x: right.minX + 24, y: right.minY + 56, width: right.width - 48, height: max(0, right.height - 56))
        } else {
            compactTitle.frame = NSRect(x: 0, y: 16, width: W, height: 18)
            search.alignment = .left
            let left = NSRect(x: 36, y: 48, width: W * 0.34, height: max(0, H - 48 - 44))
            search.frame = NSRect(x: left.minX + 8, y: left.minY, width: left.width - 8, height: 32)
            listScroll.frame = NSRect(x: left.minX, y: left.minY + 32 + 16, width: left.width, height: max(0, left.height - 48))
            let right = NSRect(x: 36 + W * 0.34 + 12, y: 48, width: max(0, W - (36 + W * 0.34 + 12) - 24), height: max(0, H - 48 - 44))
            title.frame = NSRect(x: right.minX + 24, y: right.minY, width: right.width - 48, height: 28)
            bodyScroll.frame = NSRect(x: right.minX + 24, y: right.minY + 40, width: right.width - 48, height: max(0, right.height - 40))
        }
        list.frame.size.width = listScroll.contentSize.width
        list.layoutRows()
    }
}

/// a space's shape, large, its name in it
final class BigShape: Flipped {
    let element: String
    let name: String

    init(element: String, name: String) {
        self.element = element
        self.name = name
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // its top edge (not its box's) level with HOME and NOVA
        let inset: [String: CGFloat] = ["water": 1, "earth": 2, "fire": 1.67, "air": 1.75]
        let y = -300 * (inset[element] ?? 1) / 16 + 1
        let box = NSRect(x: (bounds.width - 300) / 2, y: y, width: 300, height: 300)
        Shape.draw(element, in: box, stroke: 2)
        let s = attributed(name, Fonts.buttons(20), kern: 6.4)
        let size = s.size()
        s.draw(at: NSPoint(x: box.midX - (size.width - 6.4) / 2, y: box.midY - size.height / 2))
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// a space's notes, by title; the chosen one underlined
final class NotesList: Flipped {
    var rows: [(id: Int64, title: String)] = [] { didSet { layoutRows() } }
    var active: Int64? { didSet { needsDisplay = true } }
    var empty = false { didSet { needsDisplay = true } }
    var pick: ((Int64) -> Void)?

    private let rowH: CGFloat = 20
    private let gap: CGFloat = 16
    private let pad = NSSize(width: 8, height: 4.8)

    func layoutRows() {
        let n = CGFloat(rows.count)
        let h = pad.height * 2 + n * rowH + max(0, n - 1) * gap
        let visible = enclosingScrollView?.contentSize.height ?? 0
        setFrameSize(NSSize(width: enclosingScrollView?.contentSize.width ?? frame.width, height: max(h, visible)))
        needsDisplay = true
    }

    private func rect(_ i: Int) -> NSRect {
        NSRect(x: pad.width, y: pad.height + CGFloat(i) * (rowH + gap), width: bounds.width - pad.width * 2, height: rowH)
    }

    override func draw(_ dirtyRect: NSRect) {
        if empty && rows.isEmpty {
            attributed("No notes yet.", Fonts.words(16), Ink.line.withAlphaComponent(0.5 * 0.4)).draw(at: NSPoint(x: pad.width, y: pad.height))
            return
        }
        for (i, row) in rows.enumerated() {
            let r = rect(i)
            guard r.intersects(dirtyRect) else { continue }
            let on = row.id == active
            var attrs: [NSAttributedString.Key: Any] = [.font: Fonts.words(16), .foregroundColor: on ? Ink.text : Ink.line]
            if on {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                attrs[.underlineColor] = Ink.text
            }
            let p = NSMutableParagraphStyle()
            p.lineBreakMode = .byTruncatingTail
            attrs[.paragraphStyle] = p
            NSAttributedString(string: row.title, attributes: attrs).draw(with: r, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        for i in rows.indices where rect(i).insetBy(dx: 0, dy: -gap / 2).contains(p) {
            return pick?(rows[i].id) ?? ()
        }
    }

    /// the row chosen by key kept in sight, clear of the faded edges
    func reveal(_ id: Int64) {
        guard let i = rows.firstIndex(where: { $0.id == id }) else { return }
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.25
            c.allowsImplicitAnimation = true
            scrollToVisible(rect(i).insetBy(dx: 0, dy: -FadeScroll.fade))
        }
    }
}
