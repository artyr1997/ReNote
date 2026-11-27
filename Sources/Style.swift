import AppKit
import CoreText

// The look: glass, as every Re app on the desk. The window is the system's blur of what is behind it, the
// words on it in the desk's white ink; the buttons in Noto Sans JP, the words in M PLUS 1p.

enum Ink {
    /// the words (as --text on glass)
    static let text = NSColor(white: 1, alpha: 0.8)
    /// lines, frames, quieter words (as --line)
    static let line = NSColor(white: 1, alpha: 0.5)
    /// what is written in something inked: a dark solid (as --bg)
    static let paper = NSColor(red: 0x1f / 255, green: 0x20 / 255, blue: 0x23 / 255, alpha: 1)
    /// the popups' pane over the blur
    static let pane = NSColor(white: 0, alpha: 0.32)
    /// a drawing's lines: the desk's white
    static let drawing = NSColor(red: 0xf4 / 255, green: 0xf4 / 255, blue: 0xf4 / 255, alpha: 1)
}

enum Fonts {
    private static func descriptor(_ name: String, _ ext: String) -> CTFontDescriptor? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "fonts"),
              let all = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return nil }
        return all.first
    }

    /// Noto Sans JP: its Latin letters, the Japanese ones after them
    private static let noto: CTFontDescriptor? = {
        guard let latin = descriptor("noto-sans-jp-latin-400-normal", "woff") else { return nil }
        guard let japanese = descriptor("noto-sans-jp-japanese-400-normal", "woff") else { return latin }
        return CTFontDescriptorCreateCopyWithAttributes(latin, [kCTFontCascadeListAttribute: [japanese]] as CFDictionary)
    }()

    private static let mplus: CTFontDescriptor? = descriptor("MPLUS1p", "ttf")

    private static var cache: [String: NSFont] = [:]

    private static func font(_ d: CTFontDescriptor?, _ key: String, _ size: CGFloat, fallback: NSFont) -> NSFont {
        let id = "\(key)-\(size)"
        if let f = cache[id] { return f }
        let f = d.map { CTFontCreateWithFontDescriptor($0, size, nil) as NSFont } ?? fallback
        cache[id] = f
        return f
    }

    /// the buttons' lettering
    static func buttons(_ size: CGFloat) -> NSFont {
        font(noto, "noto", size, fallback: .systemFont(ofSize: size, weight: .light))
    }

    /// the words
    static func words(_ size: CGFloat) -> NSFont {
        font(mplus, "mplus", size, fallback: .systemFont(ofSize: size))
    }
}

// ── the desk's language: ReDesk's Settings › Language (English or Japanese) ──

final class Lang {
    static let shared = Lang()
    static let changed = Notification.Name("ReNote.language")

    private(set) var japanese = false

    // four characters each, as the English words are four letters
    private let words: [String: String] = [
        "INFO": "詳細情報", "DEL": "削除する", "NOVA": "新規作成", "BACK": "前に戻る", "DRAW": "お絵描き",
        "FULL": "全画面化", "IMPR": "読み込み", "EXPR": "書き出し", "HOME": "ホームへ", "EXIT": "編集終了",
        "SAVE": "保存する", "FULL NOTE": "全文表示", "NEXT SPACE": "次の場所", "NEXT": "次の曲へ",
    ]

    // the popups' words
    private let texts: [String: String] = [
        "{n} note": "ノート {n}",
        "{n} notes": "ノート {n}",
        "local · private · offline": "ローカル · 非公開 · オフライン",
        "EXPORT": "書き出し",
        "Delete this note?": "このノートを削除しますか？",
        "YES": "はい",
        "NO": "いいえ",
        "SAVED": "保存しました",
        "New window": "新しいウィンドウ",
        "Save": "保存",
        "Highlight selected text": "選んだ文字をハイライト",
        "Back / Close": "戻る / 閉じる",
        "Open Feel / Body / Mind / Soul": "Feel / Body / Mind / Soul を開く",
        "New note": "新しいノート",
        "Edit note": "ノートを編集",
        "Search": "検索",
        "Search / Full mode while editing": "検索 / 編集中は全画面",
        "Navigate notes": "ノートを移動",
        "Switch space": "スペースを切り替え",
        "Switch space (new / full note)": "スペースを切り替え（新規 / 全文で）",
        "Delete note": "ノートを削除",
        "Draw": "お絵描き",
    ]

    // The language turning, as on a departures board: each letter runs through others (Latin and katakana)
    // before it stops at its new one, the first soonest, the next a little later.
    private let pool = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private let step = 55.0, settle = 260.0, stagger = 110.0, length = 1200.0
    private var frame = -1
    private var timer: Timer?

    /// a button's word in the desk's language; `as` names it where the same word means another thing
    func t(_ word: String, as key: String? = nil) -> String {
        let target = japanese ? (words[key ?? word] ?? word) : word
        guard frame >= 0 else { return target }
        let elapsed = Double(frame) * step
        var out = ""
        for (i, letter) in target.enumerated() {
            if letter == " " || elapsed >= settle + Double(i) * stagger {
                out.append(letter)
                continue
            }
            var hash = Int32(truncatingIfNeeded: frame &* 31 &+ i &* 17)
            for unit in (key ?? word).utf16 { hash = hash &* 33 &+ Int32(unit) }
            out.append(pool[Int(hash.magnitude % UInt32(pool.count))])
        }
        return out
    }

    /// the popups' words (any length); {name} in them is filled from `values`
    func tx(_ text: String, _ values: [String: Any] = [:]) -> String {
        var out = japanese ? (texts[text] ?? text) : text
        for (key, value) in values { out = out.replacingOccurrences(of: "{\(key)}", with: "\(value)") }
        return out
    }

    private func set(_ code: String, animate: Bool) {
        let ja = code == "ja"
        if animate && ja != japanese && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { turn() }
        japanese = ja
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    private func turn() {
        timer?.invalidate()
        frame = 0
        timer = Timer.scheduledTimer(withTimeInterval: step / 1000, repeats: true) { [weak self] t in
            guard let self else { return t.invalidate() }
            if Double(self.frame + 1) * self.step > self.length {
                self.frame = -1
                t.invalidate()
                self.timer = nil
            } else {
                self.frame += 1
            }
            NotificationCenter.default.post(name: Self.changed, object: nil)
        }
    }

    /// once, at start: the language ReDesk keeps (in Application Support/ReSpace/language, a file of the suite's
    /// own: ReDesk's settings are another app's data to macOS, which would ask each time), and its word when it changes
    func follow() {
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ReSpace/language")
        let kept = (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        set(kept.flatMap { $0.isEmpty ? nil : $0 } ?? "en", animate: false)
        DistributedNotificationCenter.default().addObserver(forName: .init("com.artursavytskyi.re.language"), object: nil, queue: .main) { [weak self] note in
            self?.set(note.object as? String ?? "en", animate: true)
        }
    }
}

func t(_ word: String, as key: String? = nil) -> String { Lang.shared.t(word, as: key) }
func tx(_ text: String, _ values: [String: Any] = [:]) -> String { Lang.shared.tx(text, values) }
