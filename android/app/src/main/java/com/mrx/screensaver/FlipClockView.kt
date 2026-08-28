package com.mrx.screensaver

import android.content.Context
import android.graphics.*
import android.text.TextPaint
import android.util.AttributeSet
import android.view.Choreographer
import android.view.View
import java.util.Calendar
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Flipqlo-style flip clock.
 * Landscape: HH : MM : SS in a row (reference image).
 * Portrait: hours, minutes, seconds stacked vertically with AM/PM on hours.
 */
class FlipClockView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : View(context, attrs, defStyleAttr) {

    private val digits = Array(6) { FlipDigitState() }
    private var lastSyncUnix = 0.0
    private val flipDurationMs = 720L

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#0A0A0A") }
    private val cardFace = Color.parseColor("#1C1C1C")
    private val cardHi = Color.parseColor("#252525")
    private val cardLo = Color.parseColor("#171717")
    private val digitColor = Color.parseColor("#E0E0E0")
    private val colonColor = Color.parseColor("#3A3A3A")
    private val mutedColor = Color.parseColor("#8C8C8C")

    private val digitPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = digitColor
        typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = mutedColor
        typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
        textAlign = Paint.Align.LEFT
    }
    private val brandPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#59FFFFFF")
        typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)
        letterSpacing = 0.28f
    }

    private val cardPath = Path()
    private val clipPath = Path()
    private val matrix = Matrix()

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            syncClock(false)
            advanceAnimations()
            invalidate()
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    private var running = false

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        start()
    }

    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }

    fun start() {
        if (running) return
        running = true
        lastSyncUnix = 0.0
        syncClock(true)
        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    fun stop() {
        if (!running) return
        running = false
        Choreographer.getInstance().removeFrameCallback(frameCallback)
    }

    private fun syncClock(immediate: Boolean) {
        val cal = Calendar.getInstance()
        val h24 = cal.get(Calendar.HOUR_OF_DAY)
        val h12 = if (h24 % 12 == 0) 12 else h24 % 12
        val mins = cal.get(Calendar.MINUTE)
        val secs = cal.get(Calendar.SECOND)
        val key = String.format("%02d%02d%02d", h12, mins, secs)

        val nowUnix = System.currentTimeMillis() / 1000.0
        val elapsed = if (lastSyncUnix > 0) nowUnix - lastSyncUnix else 0.0
        lastSyncUnix = nowUnix

        if (immediate) {
            for (i in 0 until 6) {
                val d = digits[i]
                val v = key[i].digitToInt()
                d.current = v
                d.oldDigit = v
                d.newDigit = v
                d.isFlipping = false
                d.progress = 0f
            }
            return
        }

        val singleTick = elapsed in 0.0..1.15
        for (i in 0 until 6) {
            val target = key[i].digitToInt()
            val d = digits[i]
            if (d.isFlipping) continue
            if (d.current == target) continue
            val next = if (singleTick) target else (d.current + 1) % 10
            beginFlip(d, next)
        }
    }

    private fun beginFlip(d: FlipDigitState, next: Int) {
        d.oldDigit = d.current
        d.newDigit = next
        d.progress = 0f
        d.isFlipping = true
        d.flipStartMs = System.currentTimeMillis()
    }

    private fun advanceAnimations() {
        val now = System.currentTimeMillis()
        for (d in digits) {
            if (!d.isFlipping) continue
            val p = min(1f, (now - d.flipStartMs).toFloat() / flipDurationMs)
            d.progress = p
            if (p >= 1f) {
                d.isFlipping = false
                d.progress = 0f
                d.current = d.newDigit
                d.oldDigit = d.newDigit
            }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)
        if (width < 4 || height < 4) return

        val landscape = width > height
        if (landscape) drawLandscape(canvas) else drawPortrait(canvas)
    }

    private fun drawLandscape(canvas: Canvas) {
        val pad = width * 0.06f
        val availW = width - pad * 2
        val availH = height * 0.55f
        val groupH = min(availH, availW / 5.2f)
        val cardH = groupH
        val cardW = cardH * 0.72f
        val inter = cardH * 0.045f
        val groupGap = cardH * 0.14f
        val colonW = cardH * 0.16f
        val totalW = cardW * 6 + inter * 3 + groupGap * 2 + colonW * 2
        var x = (width - totalW) / 2f
        val y = (height - cardH) / 2f

        for (g in 0 until 3) {
            drawDigitCard(canvas, g * 2, x, y, cardW, cardH)
            x += cardW + inter
            drawDigitCard(canvas, g * 2 + 1, x, y, cardW, cardH)
            x += cardW
            if (g < 2) {
                x += groupGap
                drawColon(canvas, x, y, colonW, cardH)
                x += colonW + groupGap
            }
        }

        brandPaint.textSize = cardH * 0.1f
        canvas.drawText("MRX", pad, height - pad * 0.6f, brandPaint)
    }

    private fun drawPortrait(canvas: Canvas) {
        val pad = width * 0.08f
        val availW = width - pad * 2
        val groupH = min(availW * 0.28f, height / 4.2f)
        val cardH = groupH
        val cardW = cardH * 0.72f
        val inter = cardH * 0.05f
        val pairW = cardW * 2 + inter
        val rowGap = cardH * 0.22f
        val totalH = cardH * 3 + rowGap * 2
        var y = (height - totalH) / 2f
        val x = (width - pairW) / 2f

        val cal = Calendar.getInstance()
        val ampm = if (cal.get(Calendar.HOUR_OF_DAY) >= 12) "PM" else "AM"

        // Hours row + AM/PM
        drawDigitCard(canvas, 0, x, y, cardW, cardH)
        drawDigitCard(canvas, 1, x + cardW + inter, y, cardW, cardH)
        labelPaint.textSize = cardH * 0.14f
        canvas.drawText(ampm, x + pairW + cardH * 0.06f, y + cardH * 0.38f, labelPaint)
        y += cardH + rowGap

        // Minutes
        drawDigitCard(canvas, 2, x, y, cardW, cardH)
        drawDigitCard(canvas, 3, x + cardW + inter, y, cardW, cardH)
        y += cardH + rowGap

        // Seconds
        drawDigitCard(canvas, 4, x, y, cardW, cardH)
        drawDigitCard(canvas, 5, x + cardW + inter, y, cardW, cardH)

        brandPaint.textSize = cardH * 0.12f
        canvas.drawText("MRX FLIP CLOCK", pad, height - pad * 0.5f, brandPaint)
    }

    private fun drawDigitCard(
        canvas: Canvas,
        index: Int,
        x: Float,
        y: Float,
        w: Float,
        h: Float,
    ) {
        val st = digits[index]
        val anim = st.isFlipping
        val progress = if (anim) st.progress else 0f
        val oldD = if (anim) st.oldDigit else st.current
        val newD = if (anim) st.newDigit else st.current
        val half = h / 2f
        val cr = h * 0.05f

        val save = canvas.save()
        roundRect(cardPath, x, y, w, h, cr)
        canvas.clipPath(cardPath)

        fillCardFace(canvas, x, y, w, h, half)

        digitPaint.textSize = h * 0.66f

        if (!anim) {
            drawClippedDigit(canvas, newD, x, y, w, h, x, y, w, half)
            drawClippedDigit(canvas, newD, x, y, w, h, x, y + half, w, half)
        } else {
            drawClippedDigit(canvas, newD, x, y, w, h, x, y, w, half)
            drawClippedDigit(canvas, oldD, x, y, w, h, x, y + half, w, half)

            if (progress < 0.5f) {
                val t = progress / 0.5f
                val angle = t * (Math.PI / 2).toFloat()
                val sy = max(0f, cos(angle))
                val sx = 1f - (1f - sy) * 0.18f
                val shade = sin(angle) * 0.42f
                if (sy > 0.04f) {
                    drawFlap(canvas, true, oldD, x, y, w, h, half, sy, sx, shade)
                }
            } else {
                val t = (progress - 0.5f) / 0.5f
                val angle = t * (Math.PI / 2).toFloat()
                val sy = max(0f, sin(angle))
                val sx = 1f - (1f - sy) * 0.18f
                val shade = cos(angle) * 0.42f
                if (sy > 0.04f) {
                    drawFlap(canvas, false, newD, x, y, w, h, half, sy, sx, shade)
                }
            }
        }

        canvas.restoreToCount(save)

        val divY = y + half
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0F0F0F")
            strokeWidth = 2f
        }
        canvas.drawLine(x, divY, x + w, divY, line)
    }

    private fun drawFlap(
        canvas: Canvas,
        isTop: Boolean,
        digit: Int,
        x: Float,
        y: Float,
        w: Float,
        h: Float,
        half: Float,
        sy: Float,
        sx: Float,
        shade: Float,
    ) {
        val clipY = if (isTop) y else y + half
        val hinge = y + half
        val cx = x + w / 2f

        val save = canvas.save()
        canvas.clipRect(x, clipY, x + w, clipY + half)
        matrix.reset()
        matrix.postTranslate(cx, hinge)
        matrix.postScale(sx, sy)
        matrix.postTranslate(-cx, -hinge)
        canvas.concat(matrix)

        val face = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isTop) cardHi else cardLo
        }
        canvas.drawRect(x, clipY, x + w, clipY + half, face)
        drawClippedDigit(canvas, digit, x, y, w, h, x, clipY, w, half)

        if (shade > 0.01f) {
            val g = LinearGradient(
                x, clipY, x, clipY + half,
                if (isTop) Color.argb((shade * 140).toInt(), 0, 0, 0) else Color.TRANSPARENT,
                if (isTop) Color.TRANSPARENT else Color.argb((shade * 140).toInt(), 0, 0, 0),
                Shader.TileMode.CLAMP,
            )
            canvas.drawRect(x, clipY, x + w, clipY + half, Paint().apply { shader = g })
        }
        canvas.restoreToCount(save)
    }

    private fun drawClippedDigit(
        canvas: Canvas,
        digit: Int,
        cardX: Float,
        cardY: Float,
        cardW: Float,
        cardH: Float,
        clipX: Float,
        clipY: Float,
        clipW: Float,
        clipH: Float,
    ) {
        val save = canvas.save()
        canvas.clipRect(clipX, clipY, clipX + clipW, clipY + clipH)
        val text = digit.toString()
        val fm = digitPaint.fontMetrics
        val tx = cardX + cardW / 2f
        val ty = cardY + cardH / 2f - (fm.ascent + fm.descent) / 2f
        canvas.drawText(text, tx, ty, digitPaint)
        canvas.restoreToCount(save)
    }

    private fun fillCardFace(canvas: Canvas, x: Float, y: Float, w: Float, h: Float, half: Float) {
        canvas.drawRect(x, y, x + w, y + h, Paint().apply { color = cardFace })
        canvas.drawRect(x, y, x + w, y + half, Paint().apply { color = cardHi })
        canvas.drawRect(x, y + half, x + w, y + h, Paint().apply { color = cardLo })
    }

    private fun drawColon(canvas: Canvas, x: Float, y: Float, colonW: Float, cardH: Float) {
        val r = cardH * 0.035f
        val cx = x + colonW / 2f
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colonColor }
        canvas.drawCircle(cx, y + cardH * 0.35f, r, p)
        canvas.drawCircle(cx, y + cardH * 0.65f, r, p)
    }

    private fun roundRect(path: Path, x: Float, y: Float, w: Float, h: Float, r: Float) {
        path.reset()
        path.addRoundRect(RectF(x, y, x + w, y + h), r, r, Path.Direction.CW)
    }
}
