//! PAD: the trackpad as a drawing tablet. A stylus (or a finger) on it is read where it touches, through
//! macOS's MultitouchSupport (a private framework, opened at run time, as drawing and gesture apps do), and
//! sent to the windows as `pad` events: each contact's place on the trackpad (0…1 from its bottom left),
//! how big the touch is, and whether it touches. While PAD is on, the pointer stays where it is
//! (CGAssociateMouseAndMouseCursorPosition), so the trackpad only draws.

use serde::Serialize;
use std::ffi::{c_void, CString};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::OnceLock;
use tauri::{AppHandle, Emitter};

#[repr(C)]
#[derive(Clone, Copy)]
struct Point {
    x: f32,
    y: f32,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct Readout {
    pos: Point,
    vel: Point,
}

/// One contact, as MultitouchSupport hands it over (96 bytes).
#[repr(C)]
#[derive(Clone, Copy)]
struct Finger {
    frame: i32,
    timestamp: f64,
    identifier: i32,
    /// 1 not tracking, 2 start in range, 3 hover, 4 make touch, 5 touching, 6 break touch, 7 linger, 0 out
    state: i32,
    finger_id: i32,
    hand_id: i32,
    normalized: Readout,
    size: f32,
    pressure: i32,
    angle: f32,
    major: f32,
    minor: f32,
    mm: Readout,
    unknown: [i32; 2],
    density: f32,
}

const _: () = assert!(std::mem::size_of::<Finger>() == 96);

/// What the windows get of a contact.
#[derive(Serialize, Clone)]
pub struct Contact {
    id: i32,
    /// 0…1, from the left
    x: f32,
    /// 0…1, from the top
    y: f32,
    /// how big the touch is: a light stylus small, pressed harder (or a finger) bigger
    size: f32,
    /// touching (not just near)
    down: bool,
}

type Callback = extern "C" fn(*mut c_void, *const Finger, i32, f64, i32) -> i32;

struct Api {
    device: usize,
    register: extern "C" fn(*mut c_void, Callback),
    unregister: extern "C" fn(*mut c_void, Callback),
    start: extern "C" fn(*mut c_void, i32),
    stop: extern "C" fn(*mut c_void),
}

static API: OnceLock<Option<Api>> = OnceLock::new();
static APP: OnceLock<AppHandle> = OnceLock::new();
static ON: AtomicBool = AtomicBool::new(false);
/// frames without a contact in a row: one empty frame is sent, then quiet
static EMPTY: AtomicUsize = AtomicUsize::new(0);

fn api() -> Option<&'static Api> {
    API.get_or_init(|| unsafe {
        // SAFETY: the system's own framework and its documented-by-use C functions
        let path = CString::new("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport").ok()?;
        let lib = libc::dlopen(path.as_ptr(), libc::RTLD_NOW);
        if lib.is_null() {
            return None;
        }
        let sym = |name: &str| {
            let name = CString::new(name).ok()?;
            let f = libc::dlsym(lib, name.as_ptr());
            (!f.is_null()).then_some(f)
        };
        let create: extern "C" fn() -> *mut c_void = std::mem::transmute(sym("MTDeviceCreateDefault")?);
        let device = create();
        if device.is_null() {
            return None;
        }
        Some(Api {
            device: device as usize,
            register: std::mem::transmute(sym("MTRegisterContactFrameCallback")?),
            unregister: std::mem::transmute(sym("MTUnregisterContactFrameCallback")?),
            start: std::mem::transmute(sym("MTDeviceStart")?),
            stop: std::mem::transmute(sym("MTDeviceStop")?),
        })
    })
    .as_ref()
}

extern "C" fn frame(_device: *mut c_void, data: *const Finger, count: i32, _time: f64, _frame: i32) -> i32 {
    if !ON.load(Ordering::Relaxed) || data.is_null() && count > 0 {
        return 0;
    }
    let fingers = if count > 0 { unsafe { std::slice::from_raw_parts(data, count as usize) } } else { &[] };
    let contacts: Vec<Contact> = fingers
        .iter()
        .filter(|f| (3..=7).contains(&f.state))
        .map(|f| Contact {
            id: f.identifier,
            x: f.normalized.pos.x.clamp(0.0, 1.0),
            y: (1.0 - f.normalized.pos.y).clamp(0.0, 1.0),
            size: f.size,
            down: f.state == 4 || f.state == 5,
        })
        .collect();
    if contacts.is_empty() {
        if EMPTY.fetch_add(1, Ordering::Relaxed) > 0 {
            return 0;
        }
    } else {
        EMPTY.store(0, Ordering::Relaxed);
    }
    if let Some(app) = APP.get() {
        let _ = app.emit("pad", contacts);
    }
    0
}

#[cfg(target_os = "macos")]
#[link(name = "CoreGraphics", kind = "framework")]
unsafe extern "C" {
    fn CGAssociateMouseAndMouseCursorPosition(connected: u32) -> i32;
}

/// PAD on: the trackpad draws, the pointer stays. False when the trackpad can't be read.
#[tauri::command]
pub fn pad_start(app: AppHandle) -> bool {
    let _ = APP.set(app);
    let Some(api) = api() else { return false };
    if !ON.swap(true, Ordering::Relaxed) {
        (api.register)(api.device as *mut c_void, frame);
        (api.start)(api.device as *mut c_void, 0);
    }
    // SAFETY: a plain CoreGraphics call
    #[cfg(target_os = "macos")]
    unsafe {
        CGAssociateMouseAndMouseCursorPosition(0);
    }
    true
}

/// PAD off: the trackpad moves the pointer again.
#[tauri::command]
pub fn pad_stop() {
    #[cfg(target_os = "macos")]
    unsafe {
        CGAssociateMouseAndMouseCursorPosition(1);
    }
    if ON.swap(false, Ordering::Relaxed) {
        if let Some(api) = api() {
            (api.stop)(api.device as *mut c_void);
            (api.unregister)(api.device as *mut c_void, frame);
        }
    }
}
