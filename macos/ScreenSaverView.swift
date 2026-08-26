import ScreenSaver
import WebKit

class MRXScreenSaverView: ScreenSaverView {
    private var webView: WKWebView!

    override init(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setupWebView(isPreview: isPreview)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWebView(isPreview: Bool) {
        let webConfiguration = WKWebViewConfiguration()

        // Create the webview
        webView = WKWebView(frame: self.bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground") // Transparent background

        self.addSubview(webView)

        // Load the bundled Tauri assets
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("www/index.html") {
            let mode = isPreview ? "preview" : "screensaver"
            var request = URLRequest(url: bundleURL)

            // We append the mode as a query parameter to match our frontend logic
            let urlWithParams = bundleURL.appendingPathComponent("?mode=\(mode)")
            webView.loadFileURL(urlWithParams, allowingReadAccessTo: Bundle.main.resourceURL!)
        }
    }

    override func animateOneFrame() {
        // WKWebView handles its own animation loop via JS/WebGL
        // We just need to tell the system we are still animating
        super.animateOneFrame()
    }

    override func hasConfigureSheet() -> Bool {
        return true
    }

    override func configureSheet() -> NSWindow? {
        // In a real app, this would return a window hosting the settings UI
        // For now, we can return nil or a simple alert
        return nil
    }
}
