use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    use std::env;

    let args: Vec<String> = env::args().collect();

    // Windows .scr protocol: /s run, /c configure, /p <HWND> preview
    let is_s = args.iter().any(|a| a.eq_ignore_ascii_case("/s"));
    let is_p = args.iter().any(|a| a.eq_ignore_ascii_case("/p"));
    let is_c = args.iter().any(|a| a.eq_ignore_ascii_case("/c"));

    // Preview HWND mode: exit (can't embed Tauri into the tiny preview well).
    if is_p && !is_s {
        return;
    }

    // Configure: open Windows screen saver CPL, then exit.
    if is_c && !is_s {
        #[cfg(target_os = "windows")]
        {
            let _ = std::process::Command::new("control")
                .arg("desk.cpl,,1")
                .spawn();
        }
        return;
    }

    // /s or double-click → full screensaver
    let run_fullscreen = is_s || (!is_p && !is_c);
    let exit_on_input = Arc::new(AtomicBool::new(run_fullscreen));

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .setup({
            let exit_on_input = Arc::clone(&exit_on_input);
            move |app| {
                let window = app.get_webview_window("main").expect("main window");

                let _ = window.eval(
                    "window.__MRX_SCREENSAVER__ = Object.assign(window.__MRX_SCREENSAVER__ || {}, { mode: 'screensaver', scene: 'flipclock' });",
                );

                if run_fullscreen {
                    let _ = window.set_decorations(false);
                    let _ = window.set_always_on_top(true);
                    let _ = window.maximize();
                    let _ = window.set_fullscreen(true);
                }

                // Exit on mouse/key after grace period (proper .scr behavior).
                // Uses window.close() — no custom command permission needed.
                if exit_on_input.load(Ordering::SeqCst) {
                    let _ = window.eval(
                        r#"(function () {
  let armed = false;
  setTimeout(function () { armed = true; }, 900);
  async function quit() {
    if (!armed) return;
    armed = false;
    try {
      var w = window.__TAURI__ && window.__TAURI__.webviewWindow
        && window.__TAURI__.webviewWindow.getCurrentWebviewWindow
        && window.__TAURI__.webviewWindow.getCurrentWebviewWindow();
      if (w && w.close) { await w.close(); return; }
    } catch (e) {}
    try { window.close(); } catch (e2) {}
  }
  window.addEventListener('mousemove', quit);
  window.addEventListener('mousedown', quit);
  window.addEventListener('keydown', quit);
  window.addEventListener('touchstart', quit);
})();"#,
                    );
                }

                Ok(())
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
