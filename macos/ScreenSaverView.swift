import ScreenSaver
import Cocoa
import CoreText
import QuartzCore

/**
 Native Flipqlo-style flip clock for macOS ScreenSaver.
 WKWebView is unreliable in legacyScreenSaver (Sonoma+): black screen / frozen rAF.
 This draws with Core Graphics only.
 */
@objc(MRXScreenSaverView)
public final class MRXScreenSaverView: ScreenSaverView {
    private struct DigitState {
        var current: Int = 0
        var oldDigit: Int = 0
        var newDigit: Int = 0
        var progress: Double = 0
        var isFlipping: Bool = false
        var start: TimeInterval = 0
    }

    private var digits: [DigitState] = Array(repeating: DigitState(), count: 6)
    private var lastTimeKey = ""
    private var ampm = "AM"
    private var dateLabel = ""
    private let flipDuration: TimeInterval = 0.6
    private let isPreviewMode: Bool

    // Colors (Flipqlo tokens)
    private let bgColor = NSColor(calibratedWhite: 0.04, alpha: 1)
    private let cardFace = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.11, alpha: 1)
    private let cardHighlight = NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.14, alpha: 1)
    private let cardLowlight = NSColor(calibratedRed: 0.086, green: 0.086, blue: 0.086, alpha: 1)
    private let digitColor = NSColor(calibratedWhite: 0.847, alpha: 1)
    private let mutedColor = NSColor(calibratedWhite: 0.55, alpha: 1)
    private let colonColor = NSColor(calibratedWhite: 0.23, alpha: 1)
    private let dividerColor = NSColor(calibratedWhite: 0.06, alpha: 1)

    public override init?(frame: NSRect, isPreview: Bool) {
        self.isPreviewMode = isPreview
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0 / 30.0
        syncClock(immediate: true)
    }

    public required init?(coder: NSCoder) {
        self.isPreviewMode = false
        super.init(coder: coder)
    }

    public override func startAnimation() {
        super.startAnimation()
        ensureFullSize()
        syncClock(immediate: true)
        needsDisplay = true
    }

    public override func stopAnimation() {
        super.stopAnimation()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureFullSize()
        needsDisplay = true
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    public override func layout() {
        super.layout()
        ensureFullSize()
    }

    public override func animateOneFrame() {
        ensureFullSize()
        syncClock(immediate: false)
        advanceAnimations()
        needsDisplay = true
    }

    public override var hasConfigureSheet: Bool { false }
    public override var configureSheet: NSWindow? { nil }

    public override func draw(_ dirtyRect: NSRect) {
        ensureFullSize()
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Always paint the actual view bounds (after ensureFullSize).
        let rect = bounds
        guard rect.width > 1, rect.height > 1 else { return }
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(rect)
        drawClock(in: ctx, bounds: rect)
    }

    // MARK: - Layout helpers

    private func ensureFullSize() {
        if bounds.width > 1, bounds.height > 1 { return }
        let target = window?.screen?.frame.size
            ?? NSScreen.main?.frame.size
            ?? NSSize(width: 1920, height: 1080)
        if target.width > 1, target.height > 1 {
            setFrameSize(target)
        }
    }

    // MARK: - Clock state

    private func syncClock(immediate: Bool) {
        let now = Date()
        let cal = Calendar.current
        let h24 = cal.component(.hour, from: now)
        let mins = cal.component(.minute, from: now)
        let secs = cal.component(.second, from: now)

        ampm = h24 >= 12 ? "PM" : "AM"
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        let key = String(format: "%02d%02d%02d", h12, mins, secs)

        let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        dateLabel = "\(days[cal.component(.weekday, from: now) - 1])  \(months[cal.component(.month, from: now) - 1])  \(String(format: "%02d", cal.component(.day, from: now)))"

        if key == lastTimeKey { return }
        lastTimeKey = key

        let values: [Int] = key.compactMap { Int(String($0)) }
        let t = CACurrentMediaTime()
        for i in 0..<6 {
            let next = values[i]
            if immediate || digits[i].current == next {
                digits[i] = DigitState(current: next, oldDigit: next, newDigit: next, progress: 0, isFlipping: false, start: t)
            } else {
                let old = digits[i].isFlipping ? digits[i].newDigit : digits[i].current
                digits[i] = DigitState(current: next, oldDigit: old, newDigit: next, progress: 0, isFlipping: true, start: t)
            }
        }
    }

    private func advanceAnimations() {
        let now = CACurrentMediaTime()
        for i in 0..<6 {
            guard digits[i].isFlipping else { continue }
            let p = min(1.0, (now - digits[i].start) / flipDuration)
            digits[i].progress = p
            if p >= 1 {
                digits[i].isFlipping = false
                digits[i].progress = 0
                digits[i].oldDigit = digits[i].newDigit
                digits[i].current = digits[i].newDigit
            }
        }
    }

    // MARK: - Drawing

    private func drawClock(in ctx: CGContext, bounds: CGRect) {
        let cardH = min(bounds.height * 0.32, bounds.width * 0.22)
        let cardW = cardH * 0.75
        let cr = cardH * 0.04
        let interGap = cardH * 0.03
        let groupGap = cardH * 0.06
        let colonW = cardH * 0.25
        let fontSize = cardH * 0.68

        var totalW: CGFloat = 0
        for g in 0..<3 {
            totalW += cardW + interGap + cardW
            if g < 2 { totalW += groupGap + colonW + groupGap }
        }

        var x = (bounds.width - totalW) / 2
        let y = bounds.midY - cardH / 2

        // AM/PM top-left of assembly
        drawText(
            ampm,
            in: ctx,
            at: CGPoint(x: x + 8, y: y + cardH + 18),
            fontSize: max(14, cardH * 0.12),
            color: mutedColor,
            align: .left
        )

        for g in 0..<3 {
            let d0 = g * 2
            let d1 = g * 2 + 1
            drawDigitCard(ctx, x: x, y: y, w: cardW, h: cardH, cr: cr, fontSize: fontSize, index: d0)
            x += cardW + interGap
            drawDigitCard(ctx, x: x, y: y, w: cardW, h: cardH, cr: cr, fontSize: fontSize, index: d1)
            x += cardW
            if g < 2 {
                x += groupGap
                drawColon(ctx, x: x, y: y, colonW: colonW, cardH: cardH)
                x += colonW + groupGap
            }
        }

        // Date
        drawText(
            dateLabel,
            in: ctx,
            at: CGPoint(x: bounds.midX, y: y - cardH * 0.35),
            fontSize: max(16, cardH * 0.14),
            color: mutedColor,
            align: .center
        )

        // MRX credit
        drawText(
            "MRX",
            in: ctx,
            at: CGPoint(x: bounds.midX + totalW / 2, y: y - cardH * 0.55),
            fontSize: max(12, cardH * 0.08),
            color: NSColor(calibratedWhite: 0.35, alpha: 1),
            align: .right
        )
    }

    private func drawDigitCard(
        _ ctx: CGContext,
        x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, cr: CGFloat,
        fontSize: CGFloat, index: Int
    ) {
        let half = h / 2
        let state = digits[index]
        let animating = state.isFlipping
        let progress = animating ? state.progress : 0
        let oldD = animating ? state.oldDigit : state.current
        let newD = animating ? state.newDigit : state.current

        // Card background with rounded clip
        ctx.saveGState()
        let cardRect = CGRect(x: x, y: y, width: w, height: h)
        let path = CGPath(roundedRect: cardRect, cornerWidth: cr, cornerHeight: cr, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(cardFace.cgColor)
        ctx.fill(cardRect)
        ctx.setFillColor(cardHighlight.cgColor)
        ctx.fill(CGRect(x: x, y: y + half, width: w, height: half))
        ctx.setFillColor(cardLowlight.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: w, height: half))
        ctx.restoreGState()

        if !animating {
            drawClippedDigit(ctx, digit: newD, card: cardRect, clip: CGRect(x: x, y: y + half, width: w, height: half), fontSize: fontSize)
            drawClippedDigit(ctx, digit: newD, card: cardRect, clip: CGRect(x: x, y: y, width: w, height: half), fontSize: fontSize)
        } else {
            // Static: NEW top, OLD bottom (AppKit Y grows upward)
            drawClippedDigit(ctx, digit: newD, card: cardRect, clip: CGRect(x: x, y: y + half, width: w, height: half), fontSize: fontSize)
            drawClippedDigit(ctx, digit: oldD, card: cardRect, clip: CGRect(x: x, y: y, width: w, height: half), fontSize: fontSize)

            if progress < 0.5 {
                let phase = progress / 0.5
                let eased = phase * phase
                let scaleY = 1 - eased
                if scaleY > 0.02 {
                    ctx.saveGState()
                    ctx.clip(to: CGRect(x: x, y: y + half, width: w, height: half))
                    ctx.translateBy(x: x + w / 2, y: y + half)
                    ctx.scaleBy(x: 1, y: scaleY)
                    ctx.translateBy(x: -(x + w / 2), y: -(y + half))
                    ctx.setFillColor(cardHighlight.cgColor)
                    ctx.fill(CGRect(x: x, y: y + half, width: w, height: half))
                    drawClippedDigit(ctx, digit: oldD, card: cardRect, clip: CGRect(x: x, y: y + half, width: w, height: half), fontSize: fontSize)
                    ctx.setFillColor(NSColor(calibratedWhite: 0, alpha: CGFloat(eased * 0.35)).cgColor)
                    ctx.fill(CGRect(x: x, y: y + half, width: w, height: half))
                    ctx.restoreGState()
                }
            } else {
                let phase = (progress - 0.5) / 0.5
                let eased = 1 - (1 - phase) * (1 - phase)
                let scaleY = eased
                if scaleY > 0.02 {
                    ctx.saveGState()
                    ctx.clip(to: CGRect(x: x, y: y, width: w, height: half))
                    ctx.translateBy(x: x + w / 2, y: y + half)
                    ctx.scaleBy(x: 1, y: scaleY)
                    ctx.translateBy(x: -(x + w / 2), y: -(y + half))
                    ctx.setFillColor(cardLowlight.cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: w, height: half))
                    drawClippedDigit(ctx, digit: newD, card: cardRect, clip: CGRect(x: x, y: y, width: w, height: half), fontSize: fontSize)
                    ctx.setFillColor(NSColor(calibratedWhite: 0, alpha: CGFloat((1 - eased) * 0.35)).cgColor)
                    ctx.fill(CGRect(x: x, y: y, width: w, height: half))
                    ctx.restoreGState()
                }
            }
        }

        // Divider on top (at seam)
        let divY = y + half
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: x, y: divY - 1))
        ctx.addLine(to: CGPoint(x: x + w, y: divY - 1))
        ctx.strokePath()
        ctx.setStrokeColor(dividerColor.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: x, y: divY))
        ctx.addLine(to: CGPoint(x: x + w, y: divY))
        ctx.strokePath()
    }

    /// Draw digit centered in full card, clipped to half — Flipqlo DrawClippedDigit.
    private func drawClippedDigit(
        _ ctx: CGContext,
        digit: Int,
        card: CGRect,
        clip: CGRect,
        fontSize: CGFloat
    ) {
        ctx.saveGState()
        ctx.clip(to: clip)

        let text = "\(digit)" as CFString
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: digitColor,
        ]
        let attr = NSAttributedString(string: text as String, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let tx = card.midX - bounds.width / 2 - bounds.origin.x
        let ty = card.midY - bounds.height / 2 - bounds.origin.y
        ctx.textPosition = CGPoint(x: tx, y: ty)
        CTLineDraw(line, ctx)

        ctx.restoreGState()
    }

    private func drawColon(_ ctx: CGContext, x: CGFloat, y: CGFloat, colonW: CGFloat, cardH: CGFloat) {
        let r = cardH * 0.035
        let cx = x + colonW / 2
        ctx.setFillColor(colonColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - r, y: y + cardH * 0.35 - r, width: r * 2, height: r * 2))
        ctx.fillEllipse(in: CGRect(x: cx - r, y: y + cardH * 0.65 - r, width: r * 2, height: r * 2))
    }

    private enum Align { case left, center, right }

    private func drawText(
        _ string: String,
        in ctx: CGContext,
        at point: CGPoint,
        fontSize: CGFloat,
        color: NSColor,
        align: Align
    ) {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attr = NSAttributedString(string: string, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        var x = point.x
        switch align {
        case .left: break
        case .center: x -= bounds.width / 2
        case .right: x -= bounds.width
        }
        ctx.textPosition = CGPoint(x: x - bounds.origin.x, y: point.y - bounds.origin.y)
        CTLineDraw(line, ctx)
    }
}
