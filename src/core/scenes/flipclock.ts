import { Scene, SceneConfig } from '../scenes/manager';

export class FlipClockScene implements Scene {
  private container: HTMLDivElement;
  private slots: Slot[] = [];
  private amPmElement: HTMLDivElement;
  private dateElement: HTMLDivElement;

  constructor(gl: WebGL2RenderingContext) {
    this.container = document.createElement('div');
    this.container.className = 'flip-clock-container';
    document.body.appendChild(this.container);

    // AM/PM Indicator
    this.amPmElement = document.createElement('div');
    this.amPmElement.className = 'flip-clock-ampm';
    this.container.appendChild(this.amPmElement);

    // Create slots for HH MM SS (6 digits)
    const slotContainer = document.createElement('div');
    slotContainer.className = 'flip-clock-slots';

    this.slots = Array.from({ length: 6 }, () => new Slot(slotContainer));

    // Add separators
    this.slots.forEach((slot, i) => {
      slotContainer.appendChild(slot.element);
      if (i === 1 || i === 3) {
        const separator = document.createElement('div');
        separator.className = 'flip-clock-separator';
        slotContainer.appendChild(separator);
      }
    });

    this.container.appendChild(slotContainer);

    // Date Display
    this.dateElement = document.createElement('div');
    this.dateElement.className = 'flip-clock-date';
    this.container.appendChild(this.dateElement);
  }

  update(time: number, config: SceneConfig) {
    const now = new Date();

    // AM/PM
    const hours24 = now.getHours();
    const ampm = hours24 >= 12 ? 'PM' : 'AM';
    this.amPmElement.innerText = ampm;

    // Time String (HHMMSS)
    const hours = String(hours24 % 12 || 12).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    const secs = String(now.getSeconds()).padStart(2, '0');
    const timeStr = hours + mins + secs;

    for (let i = 0; i < 6; i++) {
      this.slots[i].update(timeStr[i]);
    }

    // Date (MON NOV 27)
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const dayName = days[now.getDay()];
    const monthName = months[now.getMonth()];
    const dateNum = String(now.getDate()).padStart(2, '0');
    this.dateElement.innerText = `${dayName} ${monthName} ${dateNum}`;
  }

  destroy() {
    this.container.remove();
  }
}

class Slot {
  public element: HTMLDivElement;
  private top: HTMLDivElement;
  private bottom: HTMLDivElement;
  private flipCard: HTMLDivElement;
  private currentDigit: string = '';

  constructor(parent: HTMLElement) {
    this.element = document.createElement('div');
    this.element.className = 'flip-slot';

    this.top = document.createElement('div');
    this.top.className = 'flip-card top';
    this.top.innerHTML = `<div class="card-half top">${this.currentDigit}</div>`;

    this.bottom = document.createElement('div');
    this.bottom.className = 'flip-card bottom';
    this.bottom.innerHTML = `<div class="card-half bottom">${this.currentDigit}</div>`;

    this.flipCard = document.createElement('div');
    this.flipCard.className = 'flip-card flip';
    this.flipCard.innerHTML = `<div class="card-half top">${this.currentDigit}</div>`;

    this.element.appendChild(this.top);
    this.element.appendChild(this.bottom);
    this.element.appendChild(this.flipCard);
  }

  update(digit: string) {
    if (this.currentDigit === digit) return;

    const oldDigit = this.currentDigit;
    this.currentDigit = digit;

    this.bottom.querySelector('.card-half')?.textContent = digit;
    this.flipCard.querySelector('.card-half')?.textContent = oldDigit;

    this.flipCard.classList.remove('flipping');
    void this.flipCard.offsetWidth;
    this.flipCard.classList.add('flipping');

    setTimeout(() => {
      this.top.querySelector('.card-half')?.textContent = digit;
      this.flipCard.classList.remove('flipping');
    }, 600);
  }
}
