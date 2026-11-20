import AppKit

// A note's text: plain words, a highlight kept in them as ==marked words== and a drawing as a line of its
// own, ⟦drawing {"w":…,"h":…,"s":[…]}⟧: how wide the place was when drawn (it grows and shrinks with the
// text, its lines with it), how tall, and its strokes (rounded to a tenth), so the note stays one text.

// ── drawings ──

struct Stroke {
    var rub: Bool
    var points: [CGPoint]
}

struct Drawing {
    var w: CGFloat
    var h: CGFloat
    var strokes: [Stroke]

    /// the pen's line and the rubber's, in the drawing's own pixels
    static let pen: CGFloat = 1.5
    static let rub: CGFloat = 14
    /// a new drawing's height, and how much it grows when drawn near its bottom
    static let height: CGFloat = 220
    static let grow: CGFloat = 120

    /// a drawing's line in a note's text, with the line's end after it
    static let pattern = try! NSRegularExpression(pattern: "⟦drawing (\\{.*?\\})⟧\\n?")

    func encode() -> String {
        func n(_ v: CGFloat) -> String {
            let r = (v * 10).rounded() / 10
            return r == r.rounded() ? String(Int(r)) : String(Double(r))
        }
        let strokes = strokes.map { s -> String in
            let points = s.points.map { "[\(n($0.x)),\(n($0.y))]" }.joined(separator: ",")
            return "{" + (s.rub ? "\"k\":\"rub\"," : "") + "\"p\":[\(points)]}"
        }
        return "{\"w\":\(Int(w.rounded())),\"h\":\(Int(h.rounded())),\"s\":[\(strokes.joined(separator: ","))]}"
    }

    static func decode(_ json: String) -> Drawing {
        guard let d = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] else {
            return Drawing(w: 600, h: height, strokes: [])
        }
        var strokes: [Stroke] = ((d["s"] as? [[String: Any]]) ?? []).map { s in
            let points = ((s["p"] as? [[Double]]) ?? []).compactMap { $0.count >= 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
            return Stroke(rub: (s["k"] as? String) == "rub", points: points)
        }
        if let w = d["w"] as? Double, let h = d["h"] as? Double, w > 0, h > 0 {
            return Drawing(w: w, h: h, strokes: strokes)
        }
        // drawn before on a page of its own (from its middle): moved to start at its top left
        let all = strokes.flatMap(\.points)
        guard let minX = all.map(\.x).min(), let minY = all.map(\.y).min(),
              let maxX = all.map(\.x).max(), let maxY = all.map(\.y).max() else { return Drawing(w: 600, h: height, strokes: []) }
        let pad: CGFloat = 16
        for i in strokes.indices { strokes[i].points = strokes[i].points.map { CGPoint(x: $0.x - minX + pad, y: $0.y - minY + pad) } }
        return Drawing(w: max(900, maxX - minX + 2 * pad), h: maxY - minY + 2 * pad, strokes: strokes)
    }

    /// a stroke: a curve through the middles of its points, round at its ends
    static func draw(_ s: Stroke, in c: CGContext) {
        guard let first = s.points.first else { return }
        c.setBlendMode(s.rub ? .clear : .normal)
        c.setStrokeColor(Ink.drawing.cgColor)
        c.setFillColor(Ink.drawing.cgColor)
        let width = s.rub ? rub : pen
        if s.points.count == 1 {
            c.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
            return
        }
        c.setLineWidth(width)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.beginPath()
        c.move(to: first)
        let pts = s.points
        for i in 1..<pts.count {
            let p = pts[i - 1], q = pts[i]
            if i == 1 { c.addLine(to: CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)); continue }
            c.addQuadCurve(to: CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2), control: p)
        }
        c.addLine(to: pts[pts.count - 1])
        c.strokePath()
        c.setBlendMode(.normal)
    }
}

/// a note's words, without its drawings (for search)
func withoutDrawings(_ text: String) -> String {
    Drawing.pattern.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
}

/// A drawing between the words: a line of its own, as wide as the text, drawn on right there with the pen
/// (dragged), or rubbed out with ⌥. No frame: while the pointer is over it its corners are marked with a thin +.
final class DrawingCell: NSTextAttachmentCell {
    var drawing: Drawing { didSet { picture = nil } }
    /// the stroke being drawn
    var live: Stroke?
    var hover = false
    weak var text: NoteText?
    private var picture: (width: CGFloat, image: NSImage)?

    /// the room above and under it
    static let margin: CGFloat = 0.9 * 16

    init(_ drawing: Drawing) {
        self.drawing = drawing
        super.init(textCell: "")
    }

    required init(coder: NSCoder) { fatalError() }

    private func width(in container: NSTextContainer) -> CGFloat {
        max(40, container.size.width - 2 * container.lineFragmentPadding)
    }

    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect,
                            glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        let w = width(in: textContainer)
        return NSRect(x: 0, y: -4, width: w, height: drawing.h * w / drawing.w + 2 * Self.margin)
    }

    override func cellSize() -> NSSize { NSSize(width: drawing.w, height: drawing.h + 2 * Self.margin) }

    private func image(width: CGFloat) -> NSImage {
        if live == nil, let picture, picture.width == width { return picture.image }
        let scale = width / drawing.w
        let size = NSSize(width: width, height: drawing.h * scale)
        let strokes = drawing.strokes + (live.map { [$0] } ?? [])
        let image = NSImage(size: size, flipped: true) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.scaleBy(x: scale, y: scale)
            for s in strokes { Drawing.draw(s, in: c) }
            return true
        }
        if live == nil { picture = (width, image) }
        return image
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let content = cellFrame.insetBy(dx: 0, dy: Self.margin)
        image(width: content.width).draw(in: content, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        guard hover, text?.isEditable == true else { return }
        // its corners marked with a +, as ReDesk marks the windows'
        Ink.line.withAlphaComponent(0.5 * 0.9).setFill()
        for corner in [NSPoint(x: content.minX, y: content.minY), NSPoint(x: content.maxX, y: content.minY),
                       NSPoint(x: content.minX, y: content.maxY), NSPoint(x: content.maxX, y: content.maxY)] {
            NSRect(x: corner.x - 7.5, y: corner.y - 0.5, width: 15, height: 1).fill()
            NSRect(x: corner.x - 0.5, y: corner.y - 7.5, width: 1, height: 15).fill()
        }
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func wantsToTrackMouse(for theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, atCharacterIndex charIndex: Int) -> Bool {
        text?.isEditable == true
    }

    /// a stroke drawn while the button is down: the pen, or the rubber with ⌥
    override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?,
                             atCharacterIndex charIndex: Int, untilMouseUp flag: Bool) -> Bool {
        guard let view = controlView, let text, text.isEditable, let window = view.window else { return false }
        let content = cellFrame.insetBy(dx: 0, dy: Self.margin)
        let scale = content.width / drawing.w
        func at(_ e: NSEvent) -> CGPoint {
            let p = view.convert(e.locationInWindow, from: nil)
            return CGPoint(x: (p.x - content.minX) / scale, y: (p.y - content.minY) / scale)
        }
        var stroke = Stroke(rub: theEvent.modifierFlags.contains(.option), points: [at(theEvent)])
        live = stroke
        view.setNeedsDisplay(cellFrame)
        while let e = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if e.type == .leftMouseUp { break }
            let p = at(e)
            let last = stroke.points[stroke.points.count - 1]
            if hypot(p.x - last.x, p.y - last.y) * scale < 0.8 { continue }
            stroke.points.append(p)
            live = stroke
            view.setNeedsDisplay(cellFrame)
            view.displayIfNeeded()
        }
        live = nil
        var next = drawing
        next.strokes.append(stroke)
        // drawn near its bottom: more room under it
        let lowest = stroke.points.map(\.y).max() ?? 0
        if !stroke.rub && lowest > next.h - 40 { next.h = ceil(lowest + Drawing.grow) }
        text.change(self, to: next)
        return true
    }
}

// ── the text ──

final class NoteText: NSTextView {
    static let mark = NSAttributedString.Key("reMark")

    var size: CGFloat = 16 { didSet { restyle() } }
    var lineHeight: CGFloat = 1.8 { didSet { restyle() } }
    var placeholder = "" { didSet { needsDisplay = true } }
    var onChange: (() -> Void)?
    var disabled = false {
        didSet {
            isEditable = !disabled
            isSelectable = !disabled
            enclosingScrollView?.alphaValue = disabled ? 0.3 : 1
        }
    }
    private var hovered: DrawingCell?

    /// the text in its scroll, its lines fading at the edges
    static func make() -> (FadeScroll, NoteText) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let text = NoteText(frame: NSRect(x: 0, y: 0, width: 100, height: 100), textContainer: container)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = .zero
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.setUp()
        let scroll = FadeScroll()
        scroll.documentView = text
        return (scroll, text)
    }

    private func setUp() {
        drawsBackground = false
        isRichText = true
        importsGraphics = false
        allowsUndo = true
        usesFontPanel = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticLinkDetectionEnabled = false
        smartInsertDeleteEnabled = false
        insertionPointColor = Ink.text
        // room for a highlight's line at the edge
        textContainer?.lineFragmentPadding = 8
        textContainerInset = .zero
        selectedTextAttributes = [.backgroundColor: NSColor(white: 1, alpha: 0.22)]
        restyle()
    }

    var attrs: [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = size * lineHeight
        return [.font: Fonts.words(size), .foregroundColor: Ink.text, .paragraphStyle: p]
    }

    static let marked: [NSAttributedString.Key: Any] = [
        mark: true, .underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: Ink.text,
    ]

    private func restyle() {
        typingAttributes = attrs
        guard let s = textStorage, s.length > 0 else { return }
        s.beginEditing()
        for (k, v) in attrs { s.addAttribute(k, value: v, range: NSRange(location: 0, length: s.length)) }
        s.endEditing()
    }

    // ── to and from the note's text ──

    /// the text as the note keeps it
    var value: String { Self.serialize(textStorage ?? NSAttributedString()) }

    /// another note's text: its history starts fresh
    func load(_ text: String) {
        textStorage?.setAttributedString(render(text))
        typingAttributes = attrs
        undoManager?.removeAllActions(withTarget: self)
        undoManager?.removeAllActions()
        setSelectedRange(NSRange(location: 0, length: 0))
        needsDisplay = true
    }

    /// the words as they are written, the drawings as drawings
    func render(_ text: String) -> NSMutableAttributedString {
        let out = NSMutableAttributedString()
        let ns = text as NSString
        var last = 0
        for m in Drawing.pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out.append(words(ns.substring(with: NSRange(location: last, length: m.range.location - last))))
            out.append(drawing(Drawing.decode(ns.substring(with: m.range(at: 1)))))
            last = m.range.location + m.range.length
        }
        out.append(words(ns.substring(from: last)))
        return out
    }

    private static let markPattern = try! NSRegularExpression(pattern: "==([\\s\\S]+?)==")

    private func words(_ text: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let ns = text as NSString
        var last = 0
        for m in Self.markPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out.append(NSAttributedString(string: ns.substring(with: NSRange(location: last, length: m.range.location - last)), attributes: attrs))
            out.append(NSAttributedString(string: ns.substring(with: m.range(at: 1)), attributes: attrs.merging(Self.marked) { $1 }))
            last = m.range.location + m.range.length
        }
        out.append(NSAttributedString(string: ns.substring(from: last), attributes: attrs))
        return out
    }

    private func drawing(_ d: Drawing) -> NSAttributedString {
        let cell = DrawingCell(d)
        cell.text = self
        let attachment = NSTextAttachment()
        attachment.attachmentCell = cell
        let s = NSMutableAttributedString(attachment: attachment)
        s.addAttributes(attrs, range: NSRange(location: 0, length: s.length))
        return s
    }

    static func serialize(_ s: NSAttributedString, range: NSRange? = nil, withMarks: Bool = true) -> String {
        var out = ""
        var marked: String?
        func close() {
            if let m = marked, !m.isEmpty { out += withMarks ? "==" + m + "==" : m }
            marked = nil
        }
        let ns = s.string as NSString
        s.enumerateAttributes(in: range ?? NSRange(location: 0, length: s.length)) { a, r, _ in
            if let cell = (a[.attachment] as? NSTextAttachment)?.attachmentCell as? DrawingCell {
                close()
                guard withMarks else { return }
                for _ in 0..<r.length {
                    if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
                    out += "⟦drawing \(cell.drawing.encode())⟧\n"
                }
                return
            }
            let piece = ns.substring(with: r).replacingOccurrences(of: "\u{FFFC}", with: "")
            if a[mark] != nil {
                marked = (marked ?? "") + piece
            } else {
                close()
                out += piece
            }
        }
        close()
        return out
    }

    // ── changes ──

    override func didChangeText() {
        super.didChangeText()
        onChange?()
    }

    /// ⌘B: the words chosen highlighted, or, the caret (or the words) in a highlight, that highlight gone
    func toggleMark() {
        guard isEditable, let s = textStorage else { return }
        let r = selectedRange()
        var run = NSRange()
        let probe = r.location < s.length ? r.location : r.location - 1
        let inMark = probe >= 0 && probe < s.length && s.attribute(Self.mark, at: probe, longestEffectiveRange: &run,
                                                                   in: NSRange(location: 0, length: s.length)) != nil
        if inMark && (r.length == 0 || NSIntersectionRange(run, r) == r) {
            guard shouldChangeText(in: run, replacementString: nil) else { return }
            s.beginEditing()
            for k in Self.marked.keys { s.removeAttribute(k, range: run) }
            s.endEditing()
            typingAttributes = attrs
        } else if r.length > 0 {
            guard shouldChangeText(in: r, replacementString: nil) else { return }
            s.beginEditing()
            s.addAttributes(Self.marked, range: r)
            s.endEditing()
        } else {
            return
        }
        didChangeText()
    }

    /// ⌘D / DRAW: a new, empty drawing where the caret is (a line of its own), as wide as the text
    func draw() {
        guard isEditable, let s = textStorage, let container = textContainer else { return }
        window?.makeFirstResponder(self)
        let width = max(200, container.size.width - 2 * container.lineFragmentPadding)
        let r = selectedRange()
        let piece = NSMutableAttributedString()
        if r.location > 0 && (s.string as NSString).character(at: r.location - 1) != 10 {
            piece.append(NSAttributedString(string: "\n", attributes: attrs))
        }
        piece.append(drawing(Drawing(w: width, h: Drawing.height, strokes: [])))
        guard shouldChangeText(in: r, replacementString: piece.string) else { return }
        s.replaceCharacters(in: r, with: piece)
        didChangeText()
        setSelectedRange(NSRange(location: r.location + piece.length, length: 0))
    }

    /// a drawing drawn on (or back as it was, ⌘Z)
    func change(_ cell: DrawingCell, to next: Drawing) {
        let before = cell.drawing
        undoManager?.registerUndo(withTarget: self) { $0.change(cell, to: before) }
        cell.drawing = next
        if let s = textStorage {
            s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, r, stop in
                if (v as? NSTextAttachment)?.attachmentCell === cell {
                    layoutManager?.invalidateLayout(forCharacterRange: r, actualCharacterRange: nil)
                    stop.pointee = true
                }
            }
        }
        needsDisplay = true
        onChange?()
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods == .command && event.keyCode == 2 { return draw() }        // ⌘D
        if mods == .command && event.keyCode == 11 { return toggleMark() } // ⌘B
        if mods == .control && event.keyCode == 16 { undoManager?.redo(); return } // ⌃Y
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if window?.firstResponder === self && mods == .command && (event.keyCode == 2 || event.keyCode == 11) {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // ── copied and pasted as the note's text: highlights and drawings go with it ──

    override func copy(_ sender: Any?) {
        guard let s = textStorage, selectedRange().length > 0 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.serialize(s, range: selectedRange()), forType: .string)
    }

    override func cut(_ sender: Any?) {
        guard isEditable, selectedRange().length > 0 else { return }
        copy(sender)
        insertText("", replacementRange: selectedRange())
    }

    override func paste(_ sender: Any?) {
        guard isEditable, let s = textStorage, let text = NSPasteboard.general.string(forType: .string) else { return }
        let piece = render(text)
        let r = selectedRange()
        guard shouldChangeText(in: r, replacementString: piece.string) else { return }
        s.replaceCharacters(in: r, with: piece)
        didChangeText()
        setSelectedRange(NSRange(location: r.location + piece.length, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    override func pasteAsPlainText(_ sender: Any?) { paste(sender) }
    override func pasteAsRichText(_ sender: Any?) { paste(sender) }
    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }

    // ── the placeholder, gone while it is typed in ──

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        needsDisplay = true
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        needsDisplay = true
        return ok
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if (textStorage?.length ?? 0) == 0, !placeholder.isEmpty, window?.firstResponder !== self {
            let pad = textContainer?.lineFragmentPadding ?? 0
            let s = attributed(placeholder, Fonts.words(size), Ink.line.withAlphaComponent(0.5 * 0.25))
            s.draw(at: NSPoint(x: textContainerOrigin.x + pad, y: textContainerOrigin.y + (size * lineHeight - s.size().height)))
        }
    }

    // ── a drawing under the pointer: its corners marked, the pointer a cross ──

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.userInfo?["drawings"] != nil { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: ["drawings": true]))
    }

    private func cell(at point: NSPoint) -> DrawingCell? {
        guard let layout = layoutManager, let container = textContainer, let s = textStorage, s.length > 0 else { return nil }
        let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layout.glyphIndex(for: p, in: container)
        let char = layout.characterIndexForGlyph(at: glyph)
        guard char < s.length, let cell = (s.attribute(.attachment, at: char, effectiveRange: nil) as? NSTextAttachment)?.attachmentCell as? DrawingCell else { return nil }
        let rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        return rect.contains(p) ? cell : nil
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let over = cell(at: convert(event.locationInWindow, from: nil))
        if over !== hovered {
            hovered?.hover = false
            over?.hover = true
            hovered = over
            needsDisplay = true
        }
        if over != nil && isEditable { NSCursor.crosshair.set() }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hovered?.hover = false
        hovered = nil
        needsDisplay = true
    }

    /// the caret at the end, ready to write
    func focusAtEnd() {
        window?.makeFirstResponder(self)
        let end = textStorage?.length ?? 0
        setSelectedRange(NSRange(location: end, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    /// whether it is being typed in now
    var editing: Bool { window?.firstResponder === self }
}
