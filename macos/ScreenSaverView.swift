import ScreenSaver
import WebKit
import Cocoa

@objc(MRXScreenSaverView)
class MRXScreenSaverView: ScreenSaverView {
    private var webView: WKWebView!

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        setupWebView(isPreview: isPreview)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWebView(isPreview: Bool) {
        let mode = isPreview ? "preview" : "screensaver"

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // Inject mode/scene before any page JS runs (file:// query strings are unreliable).
        let bridge = """
        window.__MRX_SCREENSAVER__ = {
          mode: "\(mode)",
          scene: "flipclock"
        };
        """
        config.userContentController.addUserScript(
            WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        addSubview(webView)

        guard let resourceRoot = Bundle(for: type(of: self)).resourceURL else {
            showFallback(message: "MRX ScreenSaver: missing Resources")
            return
        }

        let wwwRoot = resourceRoot.appendingPathComponent("www", isDirectory: true)
        let indexURL = wwwRoot.appendingPathComponent("index.html")

        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            showFallback(message: "MRX ScreenSaver: www/index.html not found\nRebuild with: npm run build:macos-saver")
            return
        }

        // Prefer a query URL when supported; bridge injection is the source of truth.
        var components = URLComponents(url: indexURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "scene", value: "flipclock"),
        ]

        let loadURL = components?.url ?? indexURL
        webView.loadFileURL(loadURL, allowingReadAccessTo: wwwRoot)
    }

    private func showFallback(message: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let label = NSTextField(labelWithString: message)
        label.textColor = .white
        label.alignment = .center
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    override func startAnimation() {
        super.startAnimation()
        webView?.reload()
    }

    override func animateOneFrame() {
        super.animateOneFrame()
    }

    override var hasConfigureSheet: Bool { false }

    override var configureSheet: NSWindow? { nil }
}
