// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use tauri::Manager;

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    use std::env;

    let args: Vec<String> = env::args().collect();

    // Windows .scr protocol: /s run, /c configure, /p <HWND> preview
    let (mode, is_fullscreen, is_borderless, is_topmost) = if args.iter().any(|a| a.eq_ignore_ascii_case("/s")) {
        ("screensaver", true, true, true)
    } else if args.iter().any(|a| a.eq_ignore_ascii_case("/p")) {
        ("preview", false, true, false)
    } else if args.iter().any(|a| a.eq_ignore_ascii_case("/c")) {
        ("settings", false, false, false)
    } else {
        ("screensaver", false, false, false)
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .invoke_handler(tauri::generate_handler![greet])
        .setup(move |app| {
            let window = app.get_webview_window("main").expect("main window");

            let _ = window.eval(&format!(
                "window.__MRX_SCREENSAVER__ = Object.assign(window.__MRX_SCREENSAVER__ || {{}}, {{ mode: '{}', scene: 'flipclock' }});",
                mode
            ));

            if is_fullscreen {
                let _ = window.set_fullscreen(true);
            }
            if is_borderless {
                let _ = window.set_decorations(false);
            }
            if is_topmost {
                let _ = window.set_always_on_top(true);
            }

            // Full-screen saver: maximize + cover the display.
            if mode == "screensaver" && is_fullscreen {
                let _ = window.maximize();
                let _ = window.set_fullscreen(true);
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
