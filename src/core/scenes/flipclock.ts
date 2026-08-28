import { Scene, SceneConfig } from '../scenes/manager';

/** Flipqlo-aligned design tokens (shared/design-tokens.json). */
const TOKENS = {
  flipDurationMs: 720,
  flapShadowMaxAlpha: 0.55,
  cardCornerRadiusPct: 0.04,
  cardAspectRatio: 0.75,
  digitToCardHeight: 0.68,
  colonWidthToCard: 0.25,
  interDigitGapPct: 0.03,
  groupGapPct: 0.06,
  clockToScreenPct: 0.317, // 0.352 × 0.9 — inset so fullscreen doesn't crop edges
  background: '#0A0A0A',
  cardFace: '#1C1C1C',
  cardHighlight: '#252525',
  cardLowlight: '#171717',
  digitColor: '#E0E0E0',
  dividerLine: '#0F0F0F',
  dividerShadow: '#000000',
  colonColor: '#3A3A3A',
} as const;

interface DigitState {
  currentDigit: number;
  oldDigit: number;
  newDigit: number;
  progress: number;
  isFlipping: boolean;
  flipStartTime: number;
}


function createDigitState(digit = 0): DigitState {
  return {
    currentDigit: digit,
    oldDigit: digit,
    newDigit: digit,
    progress: 0,
    isFlipping: false,
    flipStartTime: 0,
  };
}

/**
 * Flip-clock scene using Flipqlo's rendering model:
 * per-digit flip state, clipped full-card glyphs, and
 * center-seam scaleY flaps (not whole-card rotateX).
 */
export class FlipClockScene implements Scene {
  private container: HTMLDivElement;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private amPmElement: HTMLDivElement;
  private dateElement: HTMLDivElement;
  private brandElement: HTMLAnchorElement;

  private digits: DigitState[] = Array.from({ length: 6 }, () => createDigitState());
  private lastTimeKey = '';
  private resizeObserver: ResizeObserver;
  private dpr = 1;
  private onResize = () => this.layoutCanvas();

  /** Optional override `HHMMSS` for visual testing via `window.__flipClockForceTime`. */
  private forcedTime: string | null = null;

  constructor(_gl: WebGL2RenderingContext | null) {
    this.container = document.createElement('div');
    this.container.className = 'flip-clock-container';
    document.body.appendChild(this.container);

    this.brandElement = document.createElement('a');
    this.brandElement.className = 'flip-clock-brand';
    this.brandElement.textContent = 'MRX';
    this.brandElement.href = 'https://github.com/Taibur-Rahaman/';
    this.brandElement.target = '_blank';
    this.brandElement.rel = 'noopener noreferrer';
    this.brandElement.setAttribute('aria-label', 'MRX on GitHub');
    this.container.appendChild(this.brandElement);

    this.amPmElement = document.createElement('div');
    this.amPmElement.className = 'flip-clock-ampm';
    this.amPmElement.setAttribute('aria-label', 'AM or PM');
    this.container.appendChild(this.amPmElement);

    this.canvas = document.createElement('canvas');
    this.canvas.className = 'flip-clock-canvas';
    this.canvas.setAttribute('aria-label', 'Flip clock');
    this.container.appendChild(this.canvas);

    const ctx = this.canvas.getContext('2d');
    if (!ctx) {
      throw new Error('2D canvas context unavailable');
    }
    this.ctx = ctx;

    this.dateElement = document.createElement('div');
    this.dateElement.className = 'flip-clock-date';
    this.container.appendChild(this.dateElement);

    this.resizeObserver = new ResizeObserver(() => this.layoutCanvas());
    this.resizeObserver.observe(document.body);
    this.layoutCanvas();

    (window as unknown as { __MRX_ON_RESIZE__?: () => void }).__MRX_ON_RESIZE__ = this.onResize;
    window.addEventListener('resize', this.onResize);

    // Seed digits immediately so the first paint is correct (no flash of zeros).
    this.syncClock(true);

    Object.defineProperty(window, '__flipClockForceTime', {
      configurable: true,
      enumerable: false,
      get: () => this.forcedTime,
      set: (value: string | null) => {
        const next = value && /^\d{6}$/.test(value) ? value : null;
        const wasForced = this.forcedTime !== null;
        this.forcedTime = next;
        if (next === null) {
          this.lastTimeKey = '';
          this.syncClock(true);
        } else if (!wasForced) {
          this.lastTimeKey = '';
          this.syncClock(true);
        } else {
          // Animate transition between forced times (for visual QA).
          this.syncClock(false);
        }
        this.render();
      },
    });

    // Visual QA: set per-digit flip progress without relying on rAF timing.
    (window as unknown as { __flipClockDebug?: unknown }).__flipClockDebug = {
      getDigits: () =>
        this.digits.map((d) => ({
          current: d.currentDigit,
          old: d.oldDigit,
          new: d.newDigit,
          progress: d.progress,
          isFlipping: d.isFlipping,
        })),
      /** Jump all active flips to a progress value in [0,1] and redraw. */
      setProgress: (progress: number) => {
        const p = Math.min(1, Math.max(0, progress));
        for (const d of this.digits) {
          if (!d.isFlipping) continue;
          d.progress = p;
          if (p >= 1) {
            d.isFlipping = false;
            d.progress = 0;
            d.oldDigit = d.newDigit;
            d.currentDigit = d.newDigit;
          }
        }
        this.render();
      },
      /** Begin flips from fromHHMMSS → toHHMMSS, then set progress. */
      transitionAt: (from: string, to: string, progress: number) => {
        this.forcedTime = from;
        this.lastTimeKey = '';
        this.syncClock(true);
        this.forcedTime = to;
        this.syncClock(false);
        const p = Math.min(1, Math.max(0, progress));
        const now = performance.now();
        for (const d of this.digits) {
          if (!d.isFlipping) continue;
          d.progress = p;
          // Keep RAF-driven advanceAnimations from drifting away from the forced frame.
          d.flipStartTime = now - p * TOKENS.flipDurationMs;
        }
        this.render();
        return this.digits.map((d) => ({
          current: d.currentDigit,
          old: d.oldDigit,
          new: d.newDigit,
          progress: d.progress,
          isFlipping: d.isFlipping,
        }));
      },
    };
  }

  private layoutCanvas() {
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    if (vw <= 0 || vh <= 0) {
      requestAnimationFrame(() => this.layoutCanvas());
      return;
    }

    this.dpr = Math.min(window.devicePixelRatio || 1, 2);

    const maxFill = 0.9; // keep ~10% margin from display edges
    let cardH = vh * TOKENS.clockToScreenPct;
    const measureWidth = (h: number) => {
      const cardW = h * TOKENS.cardAspectRatio;
      const interGap = h * TOKENS.interDigitGapPct;
      const groupGap = h * TOKENS.groupGapPct;
      const colonW = h * TOKENS.colonWidthToCard;
      let totalW = 0;
      for (let g = 0; g < 3; g++) {
        totalW += cardW + interGap + cardW;
        if (g < 2) totalW += groupGap + colonW + groupGap;
      }
      return { totalW, cardW, interGap, groupGap, colonW };
    };

    let dims = measureWidth(cardH);
    // Date + brand sit below the canvas — reserve vertical headroom.
    const verticalExtra = cardH * 0.28;
    const scale = Math.min(
      1,
      (vw * maxFill) / dims.totalW,
      (vh * maxFill) / (cardH + verticalExtra),
    );
    if (scale < 1) {
      cardH *= scale;
      dims = measureWidth(cardH);
    }

    const totalW = dims.totalW;

    const cssW = Math.ceil(totalW);
    const cssH = Math.ceil(cardH);

    this.canvas.style.width = `${cssW}px`;
    this.canvas.style.height = `${cssH}px`;
    this.canvas.width = Math.ceil(cssW * this.dpr);
    this.canvas.height = Math.ceil(cssH * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);

    this.render();
  }

  private readTimeParts(): { digits: number[]; ampm: string; dateLabel: string } {
    let hours24: number;
    let mins: number;
    let secs: number;

    if (this.forcedTime && /^\d{6}$/.test(this.forcedTime)) {
      hours24 = parseInt(this.forcedTime.slice(0, 2), 10);
      mins = parseInt(this.forcedTime.slice(2, 4), 10);
      secs = parseInt(this.forcedTime.slice(4, 6), 10);
    } else {
      const now = new Date();
      hours24 = now.getHours();
      mins = now.getMinutes();
      secs = now.getSeconds();
    }

    const ampm = hours24 >= 12 ? 'PM' : 'AM';
    const hours12 = hours24 % 12 || 12;
    const timeStr =
      String(hours12).padStart(2, '0') +
      String(mins).padStart(2, '0') +
      String(secs).padStart(2, '0');

    const digits = timeStr.split('').map((c) => parseInt(c, 10));

    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const source = this.forcedTime ? new Date() : new Date();
    // Keep calendar date from real now even when forcing clock digits.
    const dayName = days[source.getDay()];
    const monthName = months[source.getMonth()];
    const dateNum = String(source.getDate()).padStart(2, '0');

    return {
      digits,
      ampm,
      dateLabel: `${dayName} ${monthName} ${dateNum}`,
    };
  }

  /** Apply wall-clock digits; start independent flips for changed slots. */
  private syncClock(immediate: boolean) {
    const { digits, ampm, dateLabel } = this.readTimeParts();
    const key = digits.join('');
    this.amPmElement.textContent = ampm;
    this.dateElement.textContent = dateLabel;

    if (key === this.lastTimeKey) return;
    this.lastTimeKey = key;

    const now = performance.now();
    for (let i = 0; i < 6; i++) {
      const next = digits[i];
      const state = this.digits[i];
      if (immediate) {
        state.currentDigit = next;
        state.oldDigit = next;
        state.newDigit = next;
        state.isFlipping = false;
        state.progress = 0;
        continue;
      }
      if (state.currentDigit === next) {
        if (!state.isFlipping) {
          state.oldDigit = next;
          state.newDigit = next;
          state.progress = 0;
        }
        continue;
      }

      state.oldDigit = state.isFlipping ? state.newDigit : state.currentDigit;
      state.newDigit = next;
      state.isFlipping = true;
      state.progress = 0;
      state.flipStartTime = now;
    }
  }

  private advanceAnimations(now: number) {
    for (let i = 0; i < 6; i++) {
      const state = this.digits[i];
      if (!state.isFlipping) continue;

      state.progress = Math.min(1, (now - state.flipStartTime) / TOKENS.flipDurationMs);
      if (state.progress >= 1) {
        state.isFlipping = false;
        state.progress = 0;
        state.oldDigit = state.newDigit;
        state.currentDigit = state.newDigit;
      }
    }
  }

  update(_time: number, _config: SceneConfig) {
    this.syncClock(false);
    this.advanceAnimations(performance.now());
    this.render();
  }

  destroy() {
    this.resizeObserver.disconnect();
    window.removeEventListener('resize', this.onResize);
    try {
      delete (window as unknown as { __MRX_ON_RESIZE__?: unknown }).__MRX_ON_RESIZE__;
      delete (window as unknown as { __flipClockForceTime?: unknown }).__flipClockForceTime;
      delete (window as unknown as { __flipClockDebug?: unknown }).__flipClockDebug;
    } catch {
      /* ignore */
    }
    this.container.remove();
  }

  // ── Rendering (Flipqlo model) ──────────────────────────────────────

  private render() {
    const cssW = this.canvas.clientWidth;
    const cssH = this.canvas.clientHeight;
    if (cssW <= 0 || cssH <= 0) return;

    const ctx = this.ctx;
    ctx.clearRect(0, 0, cssW, cssH);

    const cardH = cssH;
    const cardW = cardH * TOKENS.cardAspectRatio;
    const cr = cardH * TOKENS.cardCornerRadiusPct;
    const interGap = cardH * TOKENS.interDigitGapPct;
    const groupGap = cardH * TOKENS.groupGapPct;
    const colonW = cardH * TOKENS.colonWidthToCard;
    const fontSize = cardH * TOKENS.digitToCardHeight;

    let x = 0;
    const y = 0;
    const groups = 3;

    for (let g = 0; g < groups; g++) {
      const d0 = g * 2;
      const d1 = g * 2 + 1;

      this.drawDigitCard(x, y, cardW, cardH, cr, fontSize, d0);
      x += cardW + interGap;
      this.drawDigitCard(x, y, cardW, cardH, cr, fontSize, d1);
      x += cardW;

      if (g < groups - 1) {
        x += groupGap;
        this.drawColon(x, y, colonW, cardH);
        x += colonW + groupGap;
      }
    }
  }

  private drawDigitCard(
    x: number,
    y: number,
    w: number,
    h: number,
    cr: number,
    fontSize: number,
    digitIndex: number,
  ) {
    const ctx = this.ctx;
    const halfH = h / 2;
    const state = this.digits[digitIndex];
    const animating = state.isFlipping;
    const progress = animating ? state.progress : 0;
    const oldDigit = animating ? state.oldDigit : state.currentDigit;
    const newDigit = animating ? state.newDigit : state.currentDigit;
    const oldStr = String(oldDigit);
    const newStr = String(newDigit);

    // 1. Card background (subtle top/bottom tonal split inside rounded card)
    ctx.save();
    this.roundRectPath(x, y, w, h, cr);
    ctx.clip();
    ctx.fillStyle = TOKENS.cardFace;
    ctx.fillRect(x, y, w, h);
    ctx.fillStyle = TOKENS.cardHighlight;
    ctx.fillRect(x, y, w, halfH);
    ctx.fillStyle = TOKENS.cardLowlight;
    ctx.fillRect(x, y + halfH, w, halfH);
    // Soft inner edge highlight on upper lip
    const edgeGrad = ctx.createLinearGradient(x, y, x, y + 6);
    edgeGrad.addColorStop(0, 'rgba(255,255,255,0.06)');
    edgeGrad.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = edgeGrad;
    ctx.fillRect(x, y, w, 6);
    ctx.restore();

    if (!animating) {
      this.drawClippedDigit(x, y, w, h, x, y, w, halfH, newStr, fontSize);
      this.drawClippedDigit(x, y, w, h, x, y + halfH, w, halfH, newStr, fontSize);
    } else {
      // 2. Static layers behind flaps
      // Top: NEW digit top (revealed as old top folds away)
      this.drawClippedDigit(x, y, w, h, x, y, w, halfH, newStr, fontSize);
      // Bottom: OLD digit bottom (covered as new bottom unfolds)
      this.drawClippedDigit(x, y, w, h, x, y + halfH, w, halfH, oldStr, fontSize);

      // 3. Flipqlo two-phase foreshortening (physical rotateX ≈ cos/sin, not flat ease)
      if (progress < 0.5) {
        const t = progress / 0.5;
        const angle = t * (Math.PI / 2); // 0 → 90°
        const scaleY = Math.max(0, Math.cos(angle)); // 1 → 0
        const scaleX = 1 - (1 - scaleY) * 0.18;
        const shade = Math.sin(angle) * TOKENS.flapShadowMaxAlpha;
        // Cast shadow onto the static bottom half
        if (shade > 0.02) {
          const cast = ctx.createLinearGradient(x, y + halfH, x, y + h);
          cast.addColorStop(0, `rgba(0,0,0,${shade * 0.55})`);
          cast.addColorStop(1, 'rgba(0,0,0,0)');
          ctx.fillStyle = cast;
          ctx.fillRect(x, y + halfH, w, halfH);
        }
        if (scaleY > 0.04) {
          this.drawFlap(x, y, w, h, halfH, true, oldStr, fontSize, scaleY, scaleX, shade);
        }
        if (scaleY < 0.22) {
          const thick = Math.max(2, halfH * 0.05 * (1 - scaleY / 0.22));
          ctx.fillStyle = 'rgba(82,82,82,0.95)';
          ctx.fillRect(x, y + halfH - thick * 0.5, w, thick);
        }
      } else {
        const t = (progress - 0.5) / 0.5;
        const angle = t * (Math.PI / 2); // 0 → 90°
        const scaleY = Math.max(0, Math.sin(angle)); // 0 → 1
        const scaleX = 1 - (1 - scaleY) * 0.18;
        const shade = Math.cos(angle) * TOKENS.flapShadowMaxAlpha;
        if (shade > 0.02) {
          const cast = ctx.createLinearGradient(x, y, x, y + halfH);
          cast.addColorStop(0, 'rgba(0,0,0,0)');
          cast.addColorStop(1, `rgba(0,0,0,${shade * 0.45})`);
          ctx.fillStyle = cast;
          ctx.fillRect(x, y, w, halfH);
        }
        if (scaleY > 0.04) {
          this.drawFlap(x, y, w, h, halfH, false, newStr, fontSize, scaleY, scaleX, shade);
        }
        if (scaleY < 0.22) {
          const thick = Math.max(2, halfH * 0.05 * (1 - scaleY / 0.22));
          ctx.fillStyle = 'rgba(70,70,70,0.9)';
          ctx.fillRect(x, y + halfH - thick * 0.5, w, thick);
        }
      }
    }

    // 4. Divider last — always on top
    const divY = y + halfH;
    ctx.strokeStyle = TOKENS.dividerShadow;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, divY + 1);
    ctx.lineTo(x + w, divY + 1);
    ctx.stroke();

    ctx.strokeStyle = TOKENS.dividerLine;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, divY);
    ctx.lineTo(x + w, divY);
    ctx.stroke();
  }

  /** Center-hinged flap with perspective squeeze + edge gradient shade. */
  private drawFlap(
    x: number,
    y: number,
    w: number,
    h: number,
    halfH: number,
    isTop: boolean,
    digit: string,
    fontSize: number,
    scaleY: number,
    scaleX: number,
    shade: number,
  ) {
    const ctx = this.ctx;
    const clipY = isTop ? y : y + halfH;
    const hinge = y + halfH;

    ctx.save();
    ctx.beginPath();
    ctx.rect(x, clipY, w, halfH);
    ctx.clip();
    ctx.translate(x + w / 2, hinge);
    ctx.scale(scaleX, scaleY);
    ctx.translate(-(x + w / 2), -hinge);

    ctx.fillStyle = isTop ? TOKENS.cardHighlight : TOKENS.cardLowlight;
    ctx.fillRect(x, clipY, w, halfH);
    this.drawClippedDigit(x, y, w, h, x, clipY, w, halfH, digit, fontSize);

    if (shade > 0.01) {
      const grad = ctx.createLinearGradient(x, clipY, x, clipY + halfH);
      if (isTop) {
        grad.addColorStop(0, `rgba(0,0,0,${Math.min(0.65, shade)})`);
        grad.addColorStop(1, 'rgba(0,0,0,0)');
      } else {
        grad.addColorStop(0, 'rgba(0,0,0,0)');
        grad.addColorStop(1, `rgba(0,0,0,${Math.min(0.65, shade)})`);
      }
      ctx.fillStyle = grad;
      ctx.fillRect(x, clipY, w, halfH);
    }

    const rim = Math.max(1, halfH * 0.035);
    ctx.fillStyle = `rgba(255,255,255,${(isTop ? 0.1 : 0.06) * scaleY})`;
    if (isTop) ctx.fillRect(x, y, w, rim);
    else ctx.fillRect(x, y + h - rim, w, rim);

    ctx.restore();
  }

  /**
   * Flipqlo DrawClippedDigit: glyph is positioned relative to the FULL card;
   * only the clip rectangle changes between top and bottom halves.
   */
  private drawClippedDigit(
    cardX: number,
    cardY: number,
    cardW: number,
    cardH: number,
    clipX: number,
    clipY: number,
    clipW: number,
    clipH: number,
    digit: string,
    fontSize: number,
  ) {
    const ctx = this.ctx;
    ctx.save();
    ctx.beginPath();
    ctx.rect(clipX, clipY, clipW, clipH);
    ctx.clip();

    ctx.fillStyle = TOKENS.digitColor;
    ctx.font = `700 ${fontSize}px "JetBrains Mono", "Roboto Mono", "Segoe UI", system-ui, sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    // Same origin for top and bottom — clip alone selects the half.
    ctx.fillText(digit, cardX + cardW / 2, cardY + cardH / 2);
    ctx.restore();
  }

  private drawColon(x: number, y: number, colonW: number, cardH: number) {
    const ctx = this.ctx;
    const r = cardH * 0.035;
    const cx = x + colonW / 2;
    ctx.fillStyle = TOKENS.colonColor;
    ctx.beginPath();
    ctx.arc(cx, y + cardH * 0.35, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx, y + cardH * 0.65, r, 0, Math.PI * 2);
    ctx.fill();
  }

  private roundRectPath(x: number, y: number, w: number, h: number, r: number) {
    const ctx = this.ctx;
    const radius = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.arcTo(x + w, y, x + w, y + h, radius);
    ctx.arcTo(x + w, y + h, x, y + h, radius);
    ctx.arcTo(x, y + h, x, y, radius);
    ctx.arcTo(x, y, x + w, y, radius);
    ctx.closePath();
  }
}
