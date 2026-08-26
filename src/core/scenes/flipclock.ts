import { Scene, SceneConfig } from '../scenes/manager';

export class FlipClockScene implements Scene {
  private container: HTMLDivElement;
  private slots: Slot[] = [];
  private lastTime: number = 0;

  constructor(gl: WebGL2RenderingContext) {
    this.container = document.createElement('div');
    this.container.className = 'flip-clock-container';
    document.body.appendChild(this.container);

    // Create slots for HH:MM
    this.slots = [
      new Slot(this.container), // H1
      new Slot(this.container), // H2
      new Slot(this.container), // M1
      new Slot(this.container), // M2
    ];

    const colon = document.createElement('div');
    colon.className = 'flip-clock-colon';
    colon.innerText = ':';

    this.container.appendChild(this.slots[0].element);
    this.container.appendChild(this.slots[1].element);
    this.container.appendChild(colon);
    this.container.appendChild(this.slots[2].element);
    this.container.appendChild(this.slots[3].element);
  }

  update(time: number, config: SceneConfig) {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    const timeStr = hours + mins;

    for (let i = 0; i < 4; i++) {
      this.slots[i].update(timeStr[i]);
    }
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

    // 1. Set bottom to new digit
    this.bottom.querySelector('.card-half')?.textContent = digit;

    // 2. Set flip card top to old digit
    this.flipCard.querySelector('.card-half')?.textContent = oldDigit;

    // 3. Trigger animation
    this.flipCard.classList.remove('flipping');
    void this.flipCard.offsetWidth; // force reflow
    this.flipCard.classList.add('flipping');

    // 4. After animation, update top to new digit
    setTimeout(() => {
      this.top.querySelector('.card-half')?.textContent = digit;
      this.flipCard.classList.remove('flipping');
    }, 600);
  }
}
