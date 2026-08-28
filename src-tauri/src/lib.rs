use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::Manager;
use tauri::webview::PageLoadEvent;

mod windows_scr;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ScrMode {
    Configure,
    Preview,
    Run,
}

fn parse_scr_mode(args: &[String]) -> ScrMode {
    let mut has_s = false;
    let mut has_c = false;
    let mut has_p = false;

    for arg in args.iter().skip(1) {
        let lower = arg.to_ascii_lowercase();
        if lower == "/s" || lower.starts_with("/s") {
            has_s = true;
        }
        if lower == "/c" || lower.starts_with("/c") {
            has_c = true;
        }
        if lower == "/p" || lower.starts_with("/p") {
            has_p = true;
        }
    }

    if has_s {
        ScrMode::Run
    } else if has_p {
        ScrMode::Preview
    } else if has_c {
        ScrMode::Configure
    } else {
        ScrMode::Run
    }
}

fn schedule_preview_embed(window: tauri::WebviewWindow, parent: isize) {
    std::thread::spawn(move || {
        for attempt in 0..12 {
            if windows_scr::embed_preview(&window, parent).is_ok() {
                return;
            }
            std::thread::sleep(std::time::Duration::from_millis(80 + attempt * 60));
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    use std::env;

    let args: Vec<String> = env::args().collect();
    let mode = parse_scr_mode(&args);

    if mode == ScrMode::Configure {
        #[cfg(target_os = "windows")]
        {
            let _ = std::process::Command::new("control")
                .arg("desk.cpl,,1")
                .spawn();
        }
        return;
    }

    let preview_hwnd = if mode == ScrMode::Preview {
        windows_scr::parse_preview_hwnd(&args)
    } else {
        None
    };

    let run_fullscreen = mode == ScrMode::Run;
    let exit_on_input = Arc::new(AtomicBool::new(run_fullscreen));
    let injected_mode = if mode == ScrMode::Preview {
        "preview"
    } else {
        "screensaver"
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .on_page_load({
            let injected_mode = injected_mode.to_string();
            move |webview, payload| {
                if webview.label() != "main" {
                    return;
                }
                if payload.event() != PageLoadEvent::Finished {
                    return;
                }

                let config_js = format!(
                    "window.__MRX_SCREENSAVER__ = Object.assign(window.__MRX_SCREENSAVER__ || {{}}, {{ mode: '{injected_mode}', scene: 'flipclock' }});"
                );
                let _ = webview.eval(&config_js);

                let Some(window) = webview.get_webview_window("main") else {
                    return;
                };

                if run_fullscreen {
                    let _ = window.set_fullscreen(true);
                    let _ = window.set_focus();
                } else if let Some(hwnd) = preview_hwnd {
                    let _ = window.set_fullscreen(false);
                    schedule_preview_embed(window, hwnd);
                }
            }
        })
        .setup({
            let exit_on_input = Arc::clone(&exit_on_input);
            move |app| {
                let window = app.get_webview_window("main").expect("main window");
                let _ = window.set_decorations(false);

                if run_fullscreen {
                    let _ = window.set_always_on_top(true);
                }

                if exit_on_input.load(Ordering::SeqCst) {
                    let _ = window.eval(
                        r#"(function () {
  let armed = false;
  setTimeout(function () { armed = true; }, 900);
  async function quit() {
    if (!armed) return;
    armed = false;
    try {
      var t = window.__TAURI__;
      var w = t && t.webviewWindow && t.webviewWindow.getCurrentWebviewWindow
        && t.webviewWindow.getCurrentWebviewWindow();
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
