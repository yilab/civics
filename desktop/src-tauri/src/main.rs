// Civics Audio Prep — desktop shell (Tauri). The UI is the shared web app
// (desktop/dist, built from ../web/src with native-speech.js swapped in);
// this side provides the OS text-to-speech engine (word-boundary karaoke
// events) and the OS media session (headset / lock-screen buttons).
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod media;
mod speech;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            speech::tts_voices,
            speech::tts_speak,
            speech::tts_stop,
            media::media_update,
        ])
        .setup(|app| {
            use tauri::Manager;
            let handle = app.handle().clone();
            speech::spawn_worker(handle.clone());
            // SMTC needs the window handle on Windows; MPRIS ignores it.
            #[cfg(windows)]
            let hwnd = app
                .get_webview_window("main")
                .and_then(|w| w.hwnd().ok())
                .map(|h| h.0 as usize as *mut std::ffi::c_void);
            #[cfg(not(windows))]
            let hwnd = None;
            if let Err(e) = media::init(handle, hwnd) {
                eprintln!("media controls unavailable: {e}"); // media keys are optional
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
