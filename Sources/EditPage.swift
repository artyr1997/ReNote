import AppKit

// A note on the whole page (FULL), or a new one (NOVA): its title on top, the text under it, written in at
// once; under it the space it is in, < and > to move it to another. BACK top left, NOVA top right, DRAW
// bottom right (a drawing where the caret is, ⌘D), INFO bottom left. Kept as it is written.

final class EditPage: Page {
    /// the note written in: nil for a new one until something is typed
    private var noteId: Int64?
    private let isNew: Bool
    /// the space the note was in when opened (BACK goes there)
    private var openedIn: String?
    private var spaceIndex = 0

    private let back = SideButton("BACK") {}
    private let nova = SideButton("NOVA") {}
    private let drawButton = SideButton("DRAW") {}
    private let title = Field(size: 18, align: .center)
    private let bodyScroll: FadeScroll
    private let body: NoteText
    private let selector = Flipped()
    private let prev: WordButton
    private let next: WordButton
    private let mark = ShapeView("water")

    private var saving: DispatchWorkItem?

    private var spaces: [Space] { Store.shared.spaces }
    private var space: Space? { spaces.indices.contains(spaceIndex) ? spaces[spaceIndex] : spaces.first }

    init(note id: Int64) {
        isNew = false
        (bodyScroll, body) = NoteText.make()
        prev = WordButton("<", font: Fonts.buttons(32)) {}
        next = WordButton(">", font: Fonts.buttons(32)) {}
        super.init(frame: .zero)
        noteId = id
        if let note = Store.shared.note(id) {
            spaceIndex = spaces.firstIndex { $0.id == note.spaceId } ?? 0
            openedIn = Store.shared.space(id: note.spaceId)?.element
            title.stringValue = note.title
            body.load(note.body)
        }
        setUp()
    }

    init(newIn element: String?) {
        isNew = true
        (bodyScroll, body) = NoteText.make()
        prev = WordButton("<", font: Fonts.buttons(32)) {}
        next = WordButton(">", font: Fonts.buttons(32)) {}
        super.init(frame: .zero)
        if let element, let i = spaces.firstIndex(where: { $0.element == element }) { spaceIndex = i }
        setUp()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setUp() {
        back.action = { [weak self] in self?.goBack() }
        back.title = "Back (Esc)"
        nova.action = { [weak self] in self?.newNote() }
        nova.title = "New note"
        drawButton.action = { [weak self] in self?.body.draw() }
        drawButton.title = "Draw (⌘D)"

        title.placeholder = "Title"
        title.placeholderAlpha = 0.25
        title.maxLength = TITLE_MAX
        title.onChange = { [weak self] in self?.changed() }
        addSubview(title)
        body.size = 16
        body.lineHeight = 1.85
        body.placeholder = "Begin writing…"
        body.onChange = { [weak self] in self?.changed() }
        addSubview(bodyScroll)

        prev.action = { [weak self] in self?.step(-1) }
        next.action = { [weak self] in self?.step(1) }
        prev.toolTip = "Previous space (⌥←)"
        next.toolTip = "Next space (⌥→)"
        mark.element = space?.element ?? "water"
        mark.toolTip = space?.english
        selector.addSubview(prev)
        selector.addSubview(mark)
        selector.addSubview(next)
        addSubview(selector)
        [back, nova, drawButton].forEach(addSubview)
    }

    override func appear() {
        // opens straight into writing, the caret at the end
        DispatchQueue.main.async { [weak self] in self?.body.focusAtEnd() }
    }

    override func leave() { flush() }

    override func focusChanged(_ focused: Bool) {
        // the space switch only in the window in use
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.15
            selector.animator().alphaValue = focused ? 1 : 0
        }
    }

    // ── the space ──

    private func step(_ delta: Int) {
        guard !spaces.isEmpty else { return }
        spaceIndex = (spaceIndex + delta + spaces.count) % spaces.count
        mark.element = space?.element ?? "water"
        mark.toolTip = space?.english
        changed()
    }

    // ── kept as it is written ──

    private func changed() {
        saving?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saving = nil
            self?.persist()
        }
        saving = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func flush() {
        guard let work = saving else { return }
        work.cancel()
        saving = nil
        persist()
    }

    /// a new note is made with the first thing typed (or with ⌘S), then kept up to date
    private func persist(force: Bool = false) {
        guard let space else { return }
        let t = String(title.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TITLE_MAX))
        let b = body.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = now()
        if let id = noteId {
            Store.shared.update(id, space: space.id, title: t, body: b, updatedAt: time)
        } else if isNew {
            if !force && t.isEmpty && b.isEmpty { return }
            noteId = Store.shared.add(space: space.id, title: t, body: b, createdAt: time, updatedAt: time)
        }
    }

    /// ⌘S: saved, then the space's page
    private func save() {
        saving?.cancel()
        saving = nil
        persist(force: true)
        host?.go(.space(space?.element ?? "water", nil))
    }

    private func goBack() {
        if isNew {
            host?.back()
        } else if let openedIn {
            host?.go(.space(openedIn, nil))
        } else {
            host?.go(.home)
        }
    }

    /// NOVA: a new note; here, a fresh one on the same page (this one kept)
    private func newNote() {
        guard isNew else {
            host?.go(.new(space?.element))
            return
        }
        flush()
        noteId = nil
        title.stringValue = ""
        body.load("")
        body.focusAtEnd()
    }

    // ── keys ──

    override func key(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods == .command && e.keyCode == 1 { save(); return true }   // ⌘S
        if e.keyCode == 53 { goBack(); return true }                     // Esc
        if mods == .option && e.keyCode == 123 { step(-1); return true } // ⌥←
        if mods == .option && e.keyCode == 124 { step(1); return true }  // ⌥→
        return false
    }

    // ── laid out ──

    override func layout() {
        super.layout()
        place(back, .topLeft)
        place(nova, .topRight)
        place(drawButton, .bottomRight)

        let block: NSRect
        let arrowSize: CGFloat
        if wide {
            // the page at most 1280 wide, in the middle
            let pageW = min(W, 1280), pageX = (W - pageW) / 2
            let x = pageX + Spacing.inner(pageW)
            block = NSRect(x: x, y: 0, width: max(0, pageW - 2 * Spacing.inner(pageW)), height: H)
            title.frame = NSRect(x: block.minX + 40, y: 30, width: block.width - 80, height: 32)
            bodyScroll.frame = NSRect(x: block.minX + 40, y: 78, width: block.width - 80, height: max(0, H - 78 - 86))
            arrowSize = 32
        } else {
            block = NSRect(x: 24, y: 0, width: max(0, W - 48), height: H)
            title.frame = NSRect(x: block.minX + 40, y: 12, width: block.width - 80, height: 28)
            bodyScroll.frame = NSRect(x: block.minX + 40, y: 52, width: block.width - 80, height: max(0, H - 104))
            arrowSize = 24
        }
        let arrowW = arrowSize * 0.6 + 16, rowH = arrowSize + 16
        let selectorW = arrowW * 2 + 48 + 16
        selector.frame = NSRect(x: block.midX - selectorW / 2, y: H - (wide ? 30 : 6) - rowH, width: selectorW, height: rowH)
        prev.font = Fonts.buttons(arrowSize)
        next.font = Fonts.buttons(arrowSize)
        prev.frame = NSRect(x: 0, y: 0, width: arrowW, height: rowH)
        next.frame = NSRect(x: selectorW - arrowW, y: 0, width: arrowW, height: rowH)
        mark.frame = NSRect(x: (selectorW - 20) / 2, y: (rowH - 20) / 2, width: 20, height: 20)
    }
}
