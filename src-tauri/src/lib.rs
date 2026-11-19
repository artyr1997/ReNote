//! ReNote desktop: the Svelte UI from the web app in a native window,
//! with notes stored by Rust in SQLite instead of the browser's IndexedDB.
//! The UI reaches these commands through src/lib/store.ts.

mod db;


use db::{Db, NewNote, NewSpace, Note, NoteChanges, Space};
use std::sync::Mutex;
use tauri::{Manager, State};

type DbState<'a> = State<'a, Mutex<Db>>;
type CmdResult<T> = Result<T, String>;

fn err(e: impl std::fmt::Display) -> String {
    e.to_string()
}

#[tauri::command]
fn is_initialized(db: DbState) -> CmdResult<bool> {
    db.lock().map_err(err)?.is_initialized().map_err(err)
}

#[tauri::command]
fn seed_spaces(db: DbState, spaces: Vec<NewSpace>) -> CmdResult<()> {
    db.lock().map_err(err)?.seed_spaces(&spaces).map_err(err)
}

#[tauri::command]
fn get_spaces(db: DbState) -> CmdResult<Vec<Space>> {
    db.lock().map_err(err)?.get_spaces().map_err(err)
}

#[tauri::command]
fn get_notes(db: DbState, space_id: Option<i64>) -> CmdResult<Vec<Note>> {
    db.lock().map_err(err)?.get_notes(space_id).map_err(err)
}

#[tauri::command]
fn get_note(db: DbState, id: i64) -> CmdResult<Option<Note>> {
    db.lock().map_err(err)?.get_note(id).map_err(err)
}

#[tauri::command]
fn add_note(db: DbState, note: NewNote) -> CmdResult<i64> {
    db.lock().map_err(err)?.add_note(&note).map_err(err)
}

#[tauri::command]
fn add_notes(db: DbState, notes: Vec<NewNote>) -> CmdResult<()> {
    db.lock().map_err(err)?.add_notes(&notes).map_err(err)
}

#[tauri::command]
fn update_note(db: DbState, id: i64, changes: NoteChanges) -> CmdResult<()> {
    db.lock().map_err(err)?.update_note(id, &changes).map_err(err)
}

#[tauri::command]
fn delete_note(db: DbState, id: i64) -> CmdResult<()> {
    db.lock().map_err(err)?.delete_note(id).map_err(err)
}

/// Writes an export to the path the user picked in the save dialog.
#[tauri::command]
fn write_text_file(path: String, contents: String) -> CmdResult<()> {
    std::fs::write(path, contents).map_err(err)
}

/// No title bar at all (decorations are off in tauri.conf.json): macOS rims every titled window with
/// a light line that can't be turned off. The window is clear instead, its page is rounded here like a
/// window's corners, and the UI draws its own close / minimise / zoom buttons. No shadow either
/// (tauri.conf.json).
#[cfg(target_os = "macos")]
fn round_window(window: &tauri::WebviewWindow) {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;

    let _ = window.with_webview(|platform| {
        let view = platform.inner() as *mut AnyObject;
        if view.is_null() {
            return;
        }
        // SAFETY: `inner()` is the live WKWebView (an NSView); this runs on the main thread.
        unsafe {
            let _: () = msg_send![view, setWantsLayer: true];
            let layer: *mut AnyObject = msg_send![view, layer];
            if !layer.is_null() {
                let _: () = msg_send![layer, setCornerRadius: 12.0f64];
                let _: () = msg_send![layer, setMasksToBounds: true];
            }
        }
    });
}

/// The window starts hidden (tauri.conf.json) and fades in once the interface has drawn itself
/// (window_ready), so the app opens softly instead of appearing empty.
#[cfg(target_os = "macos")]
fn fade_in(window: &tauri::Window) {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};

    if window.is_visible().unwrap_or(true) {
        return;
    }
    let Ok(ns_window) = window.ns_window() else {
        let _ = window.show();
        return;
    };
    let ns_window = ns_window as *mut AnyObject;
    // SAFETY: the live NSWindow of `window`, on the main thread (see reveal).
    unsafe {
        let _: () = msg_send![ns_window, setAlphaValue: 0.0f64];
    }
    let _ = window.show();
    let _ = window.set_focus();
    // ReDesk draws the opening (its Opening.swift: the corners' +, then the glass, then the window growing
    // to its height) and says "show-window" when the interface is to come: it fades in then
    // (fade_windows_in_and_out). Should ReDesk not be there, or not answer, at once.
    // SAFETY: the live NSWindow, on the main thread
    if unsafe { tell_desk(ns_window, "open") } {
        let target = window.clone();
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_millis(2000));
            let window = target.clone();
            let _ = target.run_on_main_thread(move || {
                let Ok(ns_window) = window.ns_window() else { return };
                // SAFETY: the live NSWindow, on the main thread
                unsafe {
                    let alpha: f64 = msg_send![ns_window as *mut AnyObject, alphaValue];
                    if alpha < 0.01 {
                        fade_windows(&[ns_window as *mut AnyObject], 1.0, None);
                    }
                }
            });
        });
        return;
    }
    unsafe {
        let _: () = msg_send![class!(NSAnimationContext), beginGrouping];
        let context: *mut AnyObject = msg_send![class!(NSAnimationContext), currentContext];
        let _: () = msg_send![context, setDuration: 0.3f64];
        let name: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"easeOut".as_ptr()];
        let timing: *mut AnyObject = msg_send![class!(CAMediaTimingFunction), functionWithName: name];
        let _: () = msg_send![context, setTimingFunction: timing];
        let animator: *mut AnyObject = msg_send![ns_window, animator];
        let _: () = msg_send![animator, setAlphaValue: 1.0f64];
        let _: () = msg_send![class!(NSAnimationContext), endGrouping];
    }
}

/// Tells ReDesk a window opens or closes ("open" / "close"), so it draws that (Opening.swift); whether
/// ReDesk is there to.
#[cfg(target_os = "macos")]
unsafe fn tell_desk(ns_window: *mut objc2::runtime::AnyObject, kind: &str) -> bool {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    let desk: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"com.artursavytskyi.redesk".as_ptr()];
    let running: *mut AnyObject = msg_send![class!(NSRunningApplication), runningApplicationsWithBundleIdentifier: desk];
    let count: usize = msg_send![running, count];
    if count == 0 {
        return false;
    }
    let number: isize = msg_send![ns_window, windowNumber];
    let Ok(text) = std::ffi::CString::new(format!("{kind} {} {number}", std::process::id())) else { return false };
    let object: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: text.as_ptr()];
    let name: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"com.artursavytskyi.re.opening".as_ptr()];
    let center: *mut AnyObject = msg_send![class!(NSDistributedNotificationCenter), defaultCenter];
    let _: () = msg_send![center, postNotificationName: name, object: object, userInfo: std::ptr::null::<AnyObject>(), deliverImmediately: true];
    true
}

/// Fades the window in on the main thread; `after` waits first (the fallback, should the interface never say it is ready).
fn reveal(window: &tauri::Window, after: std::time::Duration) {
    let window = window.clone();
    std::thread::spawn(move || {
        std::thread::sleep(after);
        let target = window.clone();
        let _ = window.run_on_main_thread(move || {
            #[cfg(target_os = "macos")]
            fade_in(&target);
            #[cfg(not(target_os = "macos"))]
            let _ = target.show();
        });
    });
}

/// The interface has drawn itself (main.ts): the window can fade in.
#[tauri::command]
fn window_ready(webview: tauri::Webview) {
    // the webview's window: ReSurf's holds its tabs' webviews too
    reveal(&webview.window(), std::time::Duration::ZERO);
}

/// How long the windows take to fade out (hiding, closing) and in (showing again).
#[cfg(target_os = "macos")]
const FADE_SECONDS: f64 = 0.4;

/// `windows` animated to `alpha` over FADE_SECONDS, then `done`.
#[cfg(target_os = "macos")]
unsafe fn fade_windows(windows: &[*mut objc2::runtime::AnyObject], alpha: f64, done: Option<&block2::Block<dyn Fn()>>) {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    let _: () = msg_send![class!(NSAnimationContext), beginGrouping];
    let context: *mut AnyObject = msg_send![class!(NSAnimationContext), currentContext];
    let _: () = msg_send![context, setDuration: FADE_SECONDS];
    let name: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"easeInEaseOut".as_ptr()];
    let timing: *mut AnyObject = msg_send![class!(CAMediaTimingFunction), functionWithName: name];
    let _: () = msg_send![context, setTimingFunction: timing];
    if let Some(done) = done {
        let _: () = msg_send![context, setCompletionHandler: done];
    }
    for &window in windows {
        let animator: *mut AnyObject = msg_send![window, animator];
        let _: () = msg_send![animator, setAlphaValue: alpha];
    }
    let _: () = msg_send![class!(NSAnimationContext), endGrouping];
}

/// all of the app's NSWindows
#[cfg(target_os = "macos")]
unsafe fn app_windows() -> Vec<*mut objc2::runtime::AnyObject> {
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    let app: *mut AnyObject = msg_send![class!(NSApplication), sharedApplication];
    let windows: *mut AnyObject = msg_send![app, windows];
    let count: usize = msg_send![windows, count];
    (0..count).map(|i| msg_send![windows, objectAtIndex: i]).collect()
}

/// NSApplication's own hide:, kept to be called once the windows have faded out
#[cfg(target_os = "macos")]
static HIDE: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// hide: (⌘H, the Hide menu item, ReDesk's Hide / Show Windows): the windows fade out first
#[cfg(target_os = "macos")]
unsafe extern "C-unwind" fn fading_hide(this: *mut objc2::runtime::AnyObject, sel: objc2::runtime::Sel, sender: *mut objc2::runtime::AnyObject) {
    use block2::RcBlock;
    let this = this as usize;
    let sender = sender as usize;
    let done = RcBlock::new(move || {
        // SAFETY: HIDE holds NSApplication's hide:, which takes these arguments
        unsafe {
            let hide: unsafe extern "C-unwind" fn(*mut objc2::runtime::AnyObject, objc2::runtime::Sel, *mut objc2::runtime::AnyObject) =
                std::mem::transmute(HIDE.load(std::sync::atomic::Ordering::Relaxed));
            hide(this as *mut _, sel, sender as *mut _);
            // hidden now: back to whole, for when the app shows again (which fades them in)
            for window in app_windows() {
                let _: () = objc2::msg_send![window, setAlphaValue: 1.0f64];
            }
        }
    });
    // SAFETY: on the main thread, as hide: is
    unsafe { fade_windows(&app_windows(), 0.0, Some(&done)) };
}

/// Windows fade out when the app hides and when one closes, and fade in when the app shows again.
/// ReDesk's Hide / Show Windows and Close All Windows ask with a distributed notification, "hide", "show" or "close".
#[cfg(target_os = "macos")]
fn fade_windows_in_and_out() {
    use block2::RcBlock;
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send, sel};
    use std::ffi::CStr;

    // SAFETY: AppKit's own objects, on the main thread (setup); hide: keeps its signature
    unsafe {
        let method = objc2::ffi::class_getInstanceMethod(class!(NSApplication), sel!(hide:));
        if !method.is_null() {
            let ours: objc2::runtime::Imp = std::mem::transmute(fading_hide as *const ());
            // only once: a second time would keep fading_hide as the "original"
            if HIDE.load(std::sync::atomic::Ordering::Relaxed) == 0 {
                if let Some(old) = objc2::ffi::method_setImplementation(method, ours) {
                    HIDE.store(old as usize, std::sync::atomic::Ordering::Relaxed);
                }
            }
        }

        let center: *mut AnyObject = msg_send![class!(NSNotificationCenter), defaultCenter];
        let null = std::ptr::null::<AnyObject>();
        let will = RcBlock::new(|_: *mut AnyObject| {
            for window in app_windows() {
                let _: () = msg_send![window, setAlphaValue: 0.0f64];
            }
        });
        let did = RcBlock::new(|_: *mut AnyObject| fade_windows(&app_windows(), 1.0, None));
        let will_name: *mut AnyObject =
            msg_send![class!(NSString), stringWithUTF8String: c"NSApplicationWillUnhideNotification".as_ptr()];
        let did_name: *mut AnyObject =
            msg_send![class!(NSString), stringWithUTF8String: c"NSApplicationDidUnhideNotification".as_ptr()];
        let _: *mut AnyObject = msg_send![center, addObserverForName: will_name, object: null, queue: null, usingBlock: &*will];
        let _: *mut AnyObject = msg_send![center, addObserverForName: did_name, object: null, queue: null, usingBlock: &*did];

        let desk = RcBlock::new(|note: *mut AnyObject| {
            let object: *mut AnyObject = msg_send![note, object];
            if object.is_null() {
                return;
            }
            let text: *const std::os::raw::c_char = msg_send![object, UTF8String];
            if text.is_null() {
                return;
            }
            let app: *mut AnyObject = msg_send![class!(NSApplication), sharedApplication];
            let hidden: bool = msg_send![app, isHidden];
            let said = CStr::from_ptr(text).to_bytes();
            // "hide-window <pid> <number>" / "show-window …": one window of this app, out of sight on another
            // of ReDesk's desktops (it fades out, then goes), or back (it fades in); its app's others stay
            if let Ok(words) = std::str::from_utf8(said) {
                let one = words.strip_prefix("hide-window ").map(|rest| (true, rest)).or_else(|| words.strip_prefix("show-window ").map(|rest| (false, rest)));
                if let Some((hide, rest)) = one {
                    let mut parts = rest.split(' ');
                    let pid = parts.next().and_then(|p| p.parse::<u32>().ok());
                    let number = parts.next().and_then(|n| n.parse::<isize>().ok());
                    if let (Some(pid), Some(number)) = (pid, number) {
                        if pid == std::process::id() {
                            let window: *mut AnyObject = msg_send![app, windowWithWindowNumber: number];
                            if !window.is_null() {
                                if hide {
                                    let gone = window as usize;
                                    let done = RcBlock::new(move || {
                                        let window = gone as *mut AnyObject;
                                        let _: () = msg_send![window, orderOut: std::ptr::null::<AnyObject>()];
                                        let _: () = msg_send![window, setAlphaValue: 1.0f64];
                                    });
                                    fade_windows(&[window], 0.0, Some(&done));
                                } else {
                                    let _: () = msg_send![window, setAlphaValue: 0.0f64];
                                    let _: () = msg_send![window, orderFront: std::ptr::null::<AnyObject>()];
                                    fade_windows(&[window], 1.0, None);
                                }
                            }
                        }
                    }
                    return;
                }
            }
            // "hide <pid>": this app alone (ReDesk's own desktops)
            let mine = format!("hide {}", std::process::id());
            if said == mine.as_bytes() {
                if !hidden {
                    let _: () = msg_send![app, hide: null];
                }
                return;
            }
            match said {
                b"hide" if !hidden => {
                    let _: () = msg_send![app, hide: null];
                }
                b"show" if hidden => {
                    let _: () = msg_send![app, unhideWithoutActivation];
                }
                b"close" => {
                    let windows = app_windows();
                    let shown: Vec<_> = windows.iter().copied().filter(|&w| msg_send![w, isVisible]).collect();
                    let gone = windows.iter().map(|&w| w as usize).collect::<Vec<_>>();
                    let done = RcBlock::new(move || {
                        for &window in &gone {
                            let _: () = msg_send![window as *mut AnyObject, close];
                        }
                    });
                    fade_windows(&shown, 0.0, Some(&done));
                }
                _ => {}
            }
        });
        let distributed: *mut AnyObject = msg_send![class!(NSDistributedNotificationCenter), defaultCenter];
        let name: *mut AnyObject =
            msg_send![class!(NSString), stringWithUTF8String: c"com.artursavytskyi.re.windows".as_ptr()];
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: *mut AnyObject = msg_send![distributed, addObserverForName: name, object: null, queue: queue, usingBlock: &*desk];
    }
}

/// The app, for ReDesk's word on which corners to round (listen_for_desk_corners).
#[cfg(target_os = "macos")]
static DESK_APP: std::sync::OnceLock<tauri::AppHandle> = std::sync::OnceLock::new();

/// ReDesk's Flush tiling: the windows side by side as one, so only the outer corners of them all are
/// round. ReDesk says, for each window, which corners (1 top left, 2 top right, 4 bottom left, 8 bottom
/// right) and which of its edges touch another window (1 top, 2 right, 4 bottom, 8 left): the window
/// rounds only those corners (no window has a rim or a shadow anyway).
#[cfg(target_os = "macos")]
fn listen_for_desk_corners(app: &tauri::AppHandle) {
    use block2::RcBlock;
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};
    use tauri::Manager;

    let _ = DESK_APP.set(app.clone());
    let handler = RcBlock::new(|note: *mut AnyObject| {
        // SAFETY: on the main queue; the userInfo ReDesk sends holds numbers only
        unsafe {
            let info: *mut AnyObject = msg_send![note, userInfo];
            if info.is_null() {
                return;
            }
            let number = |key: &std::ffi::CStr| -> f64 {
                let key: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: key.as_ptr()];
                let value: *mut AnyObject = msg_send![info, objectForKey: key];
                if value.is_null() { -1.0 } else { msg_send![value, doubleValue] }
            };
            if number(c"pid") as u32 != std::process::id() {
                return;
            }
            let corners = number(c"corners") as u32;
            // pinned by ReDesk (⌃⌥P): the page writes P in its top left corner
            let pinned = number(c"pinned") == 1.0;
            // joined (Flush) on glass: ReDesk lays one glass under them all, the window drops its own
            let shared = number(c"shared") == 1.0;
            let Some(app) = DESK_APP.get() else { return };
            // which of the app's windows it is: the one with that frame
            let near = |a: f64, b: f64| (a - b).abs() < 24.0;
            for window in app.webview_windows().into_values() {
                let scale = window.scale_factor().unwrap_or(1.0);
                let (Ok(at), Ok(size)) = (window.outer_position(), window.outer_size()) else { continue };
                if near(at.x as f64 / scale, number(c"x")) && near(at.y as f64 / scale, number(c"y"))
                    && near(size.width as f64 / scale, number(c"w")) && near(size.height as f64 / scale, number(c"h"))
                {
                    set_corners(&window, corners);
                    let _ = tauri::Emitter::emit_to(app, window.label(), "pinned", pinned);
                    let _ = tauri::Emitter::emit_to(app, window.label(), "glass-shared", shared);
                }
            }
        }
    });
    // SAFETY: AppKit's own objects, on the main thread (setup); the center keeps the block
    unsafe {
        let center: *mut AnyObject = msg_send![class!(NSDistributedNotificationCenter), defaultCenter];
        let name: *mut AnyObject =
            msg_send![class!(NSString), stringWithUTF8String: c"com.artursavytskyi.re.corners".as_ptr()];
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: *mut AnyObject = msg_send![center, addObserverForName: name, object: std::ptr::null::<AnyObject>(),
                                          queue: queue, usingBlock: &*handler];
    }
}

/// Only `corners` round (the view's layer). No rim and no shadow, alone or not.
#[cfg(target_os = "macos")]
fn set_corners(window: &tauri::WebviewWindow, corners: u32) {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;

    let _ = window.with_webview(move |platform| {
        let view = platform.inner() as *mut AnyObject;
        if view.is_null() {
            return;
        }
        // SAFETY: the live WKWebView, on the main thread
        unsafe {
            let layer: *mut AnyObject = msg_send![view, layer];
            if layer.is_null() {
                return;
            }
            // the layer's own corners (CACornerMask: min X min Y 1, max X min Y 2, min X max Y 4, max X max Y 8);
            // its min Y is at the top when its contents are flipped
            let flipped: bool = msg_send![layer, contentsAreFlipped];
            let (top_left, top_right, bottom_left, bottom_right) = if flipped { (1, 2, 4, 8) } else { (4, 8, 1, 2) };
            let mut mask: usize = 0;
            if corners & 1 != 0 { mask |= top_left; }
            if corners & 2 != 0 { mask |= top_right; }
            if corners & 4 != 0 { mask |= bottom_left; }
            if corners & 8 != 0 { mask |= bottom_right; }
            let _: () = msg_send![layer, setMaskedCorners: mask];
        }
    });
}

/// A window asked to close fades out first, then goes.
fn fade_on_close(window: &tauri::Window, event: &tauri::WindowEvent) {
    #[cfg(target_os = "macos")]
    if let tauri::WindowEvent::CloseRequested { api, .. } = event {
        let Ok(ns_window) = window.ns_window() else { return };
        api.prevent_close();
        let target = window.clone();
        let done = block2::RcBlock::new(move || {
            let _ = target.destroy();
        });
        // SAFETY: the live NSWindow of `window`, on the main thread (window events are). ReDesk draws the
        // closing under it (the glass going back to a quarter of its height, then the corners' + going)
        unsafe {
            tell_desk(ns_window as *mut objc2::runtime::AnyObject, "close");
            fade_windows(&[ns_window as *mut objc2::runtime::AnyObject], 0.0, Some(&done))
        };
    }
}


// ── more windows: ⌘N ──

/// Windows opened so far (the first is "main"): the next one's label.
static WINDOW_COUNT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(1);

/// ⌘N: another window, as the first one is (tauri.conf.json): the size of the one in front, a little
/// lower and to the right of it. It fades in once its interface has drawn itself (window_ready).
#[tauri::command]
async fn new_window(app: tauri::AppHandle) -> Result<(), String> {
    use tauri::Manager;
    let n = WINDOW_COUNT.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1;
    let mut config = app.config().app.windows.first().cloned().ok_or("No window to copy")?;
    config.label = format!("w{n}");
    let windows = app.webview_windows();
    let front = windows.values().find(|w| w.is_focused().unwrap_or(false)).or_else(|| windows.values().next());
    let mut place = None;
    if let Some(front) = front {
        let scale = front.scale_factor().unwrap_or(1.0);
        if let (Ok(at), Ok(size)) = (front.outer_position(), front.inner_size()) {
            config.center = false;
            config.width = size.width as f64 / scale;
            config.height = size.height as f64 / scale;
            place = Some((at.x as f64 / scale + 28.0, at.y as f64 / scale + 28.0));
        }
    }
    let mut builder = tauri::WebviewWindowBuilder::from_config(&app, &config).map_err(|e| e.to_string())?;
    if let Some((x, y)) = place {
        builder = builder.position(x, y);
    }
    let window = builder.build().map_err(|e| e.to_string())?;
    #[cfg(target_os = "macos")]
    round_window(&window);
    reveal(&window.as_ref().window(), std::time::Duration::from_secs(3));
    Ok(())
}

// ── the desk's language: ReDesk's Settings › Language (English or Japanese) ──

/// The language ReDesk keeps ("en" or "ja"), read from its settings.
#[tauri::command]
fn desk_language() -> String {
    std::process::Command::new("/usr/bin/defaults")
        .args(["read", "com.artursavytskyi.redesk", "language"])
        .output()
        .ok()
        .map(|out| String::from_utf8_lossy(&out.stdout).trim().to_string())
        .filter(|l| l == "ja")
        .unwrap_or_else(|| "en".into())
}

#[cfg(target_os = "macos")]
static LANGUAGE_APP: std::sync::OnceLock<tauri::AppHandle> = std::sync::OnceLock::new();

/// ReDesk says when its language changes (a distributed notification, the language as its object): every
/// window gets a `language` event and writes its buttons in it.
#[cfg(target_os = "macos")]
fn listen_for_desk_language(app: &tauri::AppHandle) {
    use block2::RcBlock;
    use objc2::runtime::AnyObject;
    use objc2::{class, msg_send};

    let _ = LANGUAGE_APP.set(app.clone());
    let handler = RcBlock::new(|note: *mut AnyObject| {
        // SAFETY: on the main queue; the object ReDesk sends is a string
        unsafe {
            let object: *mut AnyObject = msg_send![note, object];
            let language = if object.is_null() {
                "en".to_string()
            } else {
                let utf8: *const std::ffi::c_char = msg_send![object, UTF8String];
                if utf8.is_null() { "en".into() } else { std::ffi::CStr::from_ptr(utf8).to_string_lossy().into_owned() }
            };
            if let Some(app) = LANGUAGE_APP.get() {
                let _ = tauri::Emitter::emit(app, "language", language);
            }
        }
    });
    // SAFETY: AppKit's own objects, on the main thread (setup); the center keeps the block
    unsafe {
        let center: *mut AnyObject = msg_send![class!(NSDistributedNotificationCenter), defaultCenter];
        let name: *mut AnyObject =
            msg_send![class!(NSString), stringWithUTF8String: c"com.artursavytskyi.re.language".as_ptr()];
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: *mut AnyObject = msg_send![center, addObserverForName: name, object: std::ptr::null::<AnyObject>(),
                                          queue: queue, usingBlock: &*handler];
    }
}


// ── glass: ReDesk's Settings › Glass windows (an experiment) ──

/// The window as glass, or paper again: the system's blur of what is behind it (the dark HUD material, as
/// the desk's white words read on it) under the page, inside the web view, so its rounded corners round it
/// too. The page itself goes clear (html.glass in app.css). `sharp`: on glass the window's corners are square.
#[tauri::command]
// (the webview that asks, not its window: ReSurf's window holds the tabs' webviews too, and a command
// can't take such a window as a WebviewWindow)
fn set_glass(webview: tauri::Webview, on: bool, sharp: bool) {
    #[cfg(target_os = "macos")]
    let _ = webview.with_webview(move |platform| {
        use objc2::runtime::AnyObject;
        use objc2::{class, msg_send};
        let view = platform.inner() as *mut AnyObject;
        if view.is_null() {
            return;
        }
        // SAFETY: the live WKWebView and AppKit's own classes, on the main thread
        unsafe {
            let layer: *mut AnyObject = msg_send![view, layer];
            if !layer.is_null() {
                let _: () = msg_send![layer, setCornerRadius: if sharp { 0.0f64 } else { 12.0f64 }];
            }
            let name: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"re-glass".as_ptr()];
            let subviews: *mut AnyObject = msg_send![view, subviews];
            let count: usize = msg_send![subviews, count];
            let mut glass: *mut AnyObject = std::ptr::null_mut();
            for i in 0..count {
                let sub: *mut AnyObject = msg_send![subviews, objectAtIndex: i];
                let id: *mut AnyObject = msg_send![sub, identifier];
                if !id.is_null() && msg_send![id, isEqualToString: name] {
                    glass = sub;
                    break;
                }
            }
            if !on {
                if !glass.is_null() {
                    let _: () = msg_send![glass, removeFromSuperview];
                }
                return;
            }
            if !glass.is_null() {
                return;
            }
            let effect: *mut AnyObject = msg_send![class!(NSVisualEffectView), alloc];
            let effect: *mut AnyObject = msg_send![effect, init];
            let _: () = msg_send![effect, setIdentifier: name];
            let _: () = msg_send![effect, setMaterial: 13isize]; // NSVisualEffectMaterialHUDWindow
            let _: () = msg_send![effect, setBlendingMode: 0isize]; // behind the window
            let _: () = msg_send![effect, setState: 1isize]; // always active
            let dark: *mut AnyObject = msg_send![class!(NSString), stringWithUTF8String: c"NSAppearanceNameDarkAqua".as_ptr()];
            let appearance: *mut AnyObject = msg_send![class!(NSAppearance), appearanceNamed: dark];
            let _: () = msg_send![effect, setAppearance: appearance];
            let _: () = msg_send![effect, setTranslatesAutoresizingMaskIntoConstraints: false];
            // under the page
            let _: () = msg_send![view, addSubview: effect, positioned: -1isize, relativeTo: std::ptr::null::<AnyObject>()];
            for edge in [c"leadingAnchor", c"trailingAnchor", c"topAnchor", c"bottomAnchor"] {
                let sel = objc2::runtime::Sel::register(edge);
                let a: *mut AnyObject = msg_send![effect, performSelector: sel];
                let b: *mut AnyObject = msg_send![view, performSelector: sel];
                let c: *mut AnyObject = msg_send![a, constraintEqualToAnchor: b];
                let _: () = msg_send![c, setActive: true];
            }
            let _: () = msg_send![effect, release];
        }
    });
}


#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .on_window_event(fade_on_close)
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            #[cfg(target_os = "macos")]
            fade_windows_in_and_out();
            #[cfg(target_os = "macos")]
            listen_for_desk_corners(app.handle());
            listen_for_desk_language(app.handle());
            #[cfg(target_os = "macos")]
            // ~/Library/Application Support/<identifier>/renote.sqlite on macOS
            let dir = app.path().app_data_dir()?;
            std::fs::create_dir_all(&dir)?;
            let db = Db::open(&dir.join("renote.sqlite"))?;
            app.manage(Mutex::new(db));

            #[cfg(target_os = "macos")]
            if let Some(window) = app.get_webview_window("main") {
                round_window(&window);
                reveal(&window.as_ref().window(), std::time::Duration::from_secs(3));
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            desk_language,
            set_glass,
            window_ready,
            new_window,
            is_initialized,
            seed_spaces,
            get_spaces,
            get_notes,
            get_note,
            add_note,
            add_notes,
            update_note,
            delete_note,
            write_text_file,
        ])
        .run(tauri::generate_context!())
        .expect("error while running ReNote");
}
