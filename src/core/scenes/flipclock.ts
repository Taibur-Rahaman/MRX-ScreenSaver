import { Scene, SceneConfig } from '../scenes/manager';

const FLIP_DURATION = 620;

export class FlipClockScene implements Scene {
  private container: HTMLDivElement;
  private slots: Slot[] = [];
  private amPmElement: HTMLDivElement;
  private dateElement: HTMLDivElement;
  private brandElement: HTMLAnchorElement;

  constructor(_gl: WebGL2RenderingContext) {
    this.container = document.createElement('div');
    this.container.className = 'flip-clock-container';
    document.body.appendChild(this.container);

    this.brandElement = document.createElement('a');
    this.brandElement.className = 'flip-clock-brand';
    this.brandElement.href = 'https://github.com/Taibur-Rahaman/';
    this.brandElement.target = '_blank';
    this.brandElement.rel = 'noopener noreferrer';
    this.brandElement.textContent = 'MRX';
    this.brandElement.setAttribute('aria-label', 'MRX on GitHub');
    this.container.appendChild(this.brandElement);

    this.amPmElement = document.createElement('div');
    this.amPmElement.className = 'flip-clock-ampm';
    this.container.appendChild(this.amPmElement);

    const slotContainer = document.createElement('div');
    slotContainer.className = 'flip-clock-slots';

    this.slots = Array.from({ length: 6 }, () => new Slot());

    this.slots.forEach((slot, i) => {
      slotContainer.appendChild(slot.element);
      if (i === 1 || i === 3) {
        const separator = document.createElement('div');
        separator.className = 'flip-clock-separator';
        slotContainer.appendChild(separator);
      }
    });

    this.container.appendChild(slotContainer);

    this.dateElement = document.createElement('div');
    this.dateElement.className = 'flip-clock-date';
    this.container.appendChild(this.dateElement);
  }

  update(_time: number, _config: SceneConfig) {
    const now = new Date();
    const hours24 = now.getHours();
    this.amPmElement.textContent = hours24 >= 12 ? 'PM' : 'AM';

    const hours = String(hours24 % 12 || 12).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    const secs = String(now.getSeconds()).padStart(2, '0');
    const timeStr = `${hours}${mins}${secs}`;

    for (let i = 0; i < this.slots.length; i++) {
      this.slots[i].update(timeStr[i]);
    }

    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    this.dateElement.textContent = `${days[now.getDay()]} ${months[now.getMonth()]} ${String(now.getDate()).padStart(2, '0')}`;
  }

  destroy() {
    this.container.remove();
  }
}

class Slot {
  public element: HTMLDivElement;
  private top: HTMLDivElement;
  private bottom: HTMLDivElement;
  private flip: HTMLDivElement;
  private currentDigit = '';
  private animationToken = 0;

  constructor() {
    this.element = document.createElement('div');
    this.element.className = 'flip-slot';

    this.top = this.createCard('top', '');
    this.bottom = this.createCard('bottom', '');

    this.flip = this.createCard('flip', '');
    this.flip.querySelector('.card-half')?.classList.add('top');

    this.element.appendChild(this.bottom);
    this.element.appendChild(this.top);
    this.element.appendChild(this.flip);
  }

  private createCard(type: 'top' | 'bottom' | 'flip', digit: string): HTMLDivElement {
    const card = document.createElement('div');
    card.className = `flip-card ${type}`;

    const half = document.createElement('div');
    half.className = 'card-half';
    half.textContent = digit;
    card.appendChild(half);

    return card;
  }

  private setText(card: HTMLDivElement, digit: string) {
    const half = card.querySelector('.card-half');
    if (half) half.textContent = digit;
  }

  update(digit: string) {
    if (this.currentDigit === digit) return;

    if (!this.currentDigit) {
      this.currentDigit = digit;
      this.setText(this.top, digit);
      this.setText(this.bottom, digit);
      this.setText(this.flip, digit);
      return;
    }

    const oldDigit = this.currentDigit;
    this.currentDigit = digit;
    const token = ++this.animationToken;

    this.setText(this.top, oldDigit);
    this.setText(this.bottom, digit);
    this.setText(this.flip, oldDigit);

    this.flip.classList.remove('flipping');
    void this.flip.offsetWidth;
    this.flip.classList.add('flipping');

    window.setTimeout(() => {
      if (token !== this.animationToken) return;
      this.setText(this.top, digit);
      this.setText(this.flip, digit);
      this.flip.classList.remove('flipping');
    }, FLIP_DURATION);
  }
}
