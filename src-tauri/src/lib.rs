// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    use std::env;

    let args: Vec<String> = env::args().collect();

    let (mode, is_fullscreen, is_borderless, is_topmost) = if args.contains(&"/s".to_string()) {
        ("screensaver", true, true, true)
    } else if args.contains(&"/p".to_string()) {
        ("preview", false, true, false)
    } else if args.contains(&"/c".to_string()) {
        ("settings", false, false, false)
    } else {
        ("screensaver", false, false, false) // Default for dev
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .invoke_handler(tauri::generate_handler![greet])
        .setup(move |app| {
            let window = app.get_webview_window("main").unwrap();

            if is_fullscreen {
                window.set_fullscreen(Some(tauri::Fullscreen::Maximized)).unwrap();
            }
            if is_borderless {
                window.set_decorations(false).unwrap();
            }
            if is_topmost {
                window.set_always_on_top(true).unwrap();
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
