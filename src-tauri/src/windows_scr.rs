//! Windows .scr preview (/p <HWND>) — embed WebView into the desk.cpl monitor widget.

#[cfg(windows)]
pub fn parse_preview_hwnd(args: &[String]) -> Option<isize> {
    let mut i = 0;
    while i < args.len() {
        let lower = args[i].to_ascii_lowercase();
        if lower == "/p" {
            if let Some(next) = args.get(i + 1) {
                if let Ok(h) = next.trim_start_matches(':').parse::<isize>() {
                    return Some(h);
                }
            }
        } else if let Some(rest) = lower.strip_prefix("/p:") {
            if let Ok(h) = rest.parse::<isize>() {
                return Some(h);
            }
        } else if lower.starts_with("/p") && lower.len() > 2 {
            if let Ok(h) = lower[2..].parse::<isize>() {
                return Some(h);
            }
        }
        i += 1;
    }
    None
}

#[cfg(not(windows))]
pub fn parse_preview_hwnd(_args: &[String]) -> Option<isize> {
    None
}

#[cfg(windows)]
pub fn embed_preview(window: &tauri::WebviewWindow, parent: isize) -> Result<(), String> {
    use windows_sys::Win32::Foundation::RECT;
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        GetClientRect, GetWindowLongPtrW, SetParent, SetWindowLongPtrW, SetWindowPos, ShowWindow,
        GWL_STYLE, HWND_TOP, SWP_NOZORDER, SWP_SHOWWINDOW, SW_SHOW, WS_CAPTION, WS_CHILD, WS_POPUP,
        WS_VISIBLE,
    };

    let hwnd = window.hwnd().map_err(|e| e.to_string())? as isize;
    if parent == 0 {
        return Err("preview parent HWND is null".into());
    }

    unsafe {
        let mut style = GetWindowLongPtrW(hwnd, GWL_STYLE);
        style &= !(WS_POPUP | WS_CAPTION) as isize;
        style |= (WS_CHILD | WS_VISIBLE) as isize;
        SetWindowLongPtrW(hwnd, GWL_STYLE, style);
        SetParent(hwnd, parent);

        let mut rect = RECT {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
        };
        if GetClientRect(parent, &mut rect) == 0 {
            return Err("GetClientRect failed for preview parent".into());
        }
        let w = rect.right - rect.left;
        let h = rect.bottom - rect.top;
        if w <= 0 || h <= 0 {
            return Err("preview parent has zero size".into());
        }
        SetWindowPos(
            hwnd,
            HWND_TOP,
            0,
            0,
            w,
            h,
            SWP_NOZORDER | SWP_SHOWWINDOW,
        );
        ShowWindow(hwnd, SW_SHOW);
    }
    Ok(())
}

#[cfg(not(windows))]
pub fn embed_preview(_window: &tauri::WebviewWindow, _parent: isize) -> Result<(), String> {
    Ok(())
}
