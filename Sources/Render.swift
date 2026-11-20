import AppKit

// --render <dir>: the pages drawn into pictures, out of sight, from made-up notes in a file of their own
// (to look at the layout without the notes kept on this Mac).

enum Render {
    static func run(into dir: String) {
        let db = NSTemporaryDirectory() + "renote-render-\(getpid()).sqlite"
        try? FileManager.default.removeItem(atPath: db)
        Store.path = db
        let store = Store.shared
        let water = store.spaces[0].id
        let t = now()
        let first = store.add(space: water, title: "On quiet mornings", body: "Knowledge does not arrive complete. It ==settles==, layer by layer.\n⟦drawing {\"w\":600,\"h\":160,\"s\":[{\"p\":[[40,40],[120,100],[220,60],[320,120]]}]}⟧\nAfter the drawing, more words.", createdAt: t, updatedAt: t)
        for (i, title) in ["Reading list", "A quote from the train", "Glossary of brushes", "Facts about tea", "Notes on clarity"].enumerated() {
            store.add(space: water, title: title, body: "Body \(i)", createdAt: t - Int64(i + 1) * 1000, updatedAt: t - Int64(i + 1) * 1000)
        }
        store.add(space: store.spaces[1].id, title: "Plan the week", body: "", createdAt: t, updatedAt: t)

        let sizes: [(String, NSSize)] = [("wide", NSSize(width: 1440, height: 900)), ("small", NSSize(width: 640, height: 420))]
        let routes: [(String, Route)] = [("home", .home), ("space", .space("water", first)), ("note", .note(first)), ("new", .new("fire"))]
        for (sizeName, size) in sizes {
            for (name, route) in routes {
                let w = NoteWindow(frame: NSRect(origin: .zero, size: size))
                w.host.go(route)
                shoot(w, "\(dir)/\(name)-\(sizeName).png")
                if name == "home" && sizeName == "wide" {
                    w.host.showInfo()
                    shoot(w, "\(dir)/info-\(sizeName).png")
                    w.host.close()
                    w.host.saved(for: 60)
                    shoot(w, "\(dir)/saved-\(sizeName).png")
                }
            }
        }
        try? FileManager.default.removeItem(atPath: db)
    }

    private static func shoot(_ w: NoteWindow, _ path: String) {
        let view = w.root
        view.frame = NSRect(origin: .zero, size: w.frame.size)
        view.layoutSubtreeIfNeeded()
        for v in view.allSubviews { v.layoutSubtreeIfNeeded(); v.alphaValue = v.alphaValue == 0 ? 1 : v.alphaValue }
        view.displayIfNeeded()
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        // the glass drawn as a dark grey (the blur isn't drawn out of sight)
        let out = NSImage(size: view.bounds.size)
        out.lockFocus()
        NSColor(white: 0.16, alpha: 1).setFill()
        view.bounds.fill()
        rep.draw(in: view.bounds)
        out.unlockFocus()
        if let tiff = out.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}

extension NSView {
    var allSubviews: [NSView] { subviews + subviews.flatMap(\.allSubviews) }
}
