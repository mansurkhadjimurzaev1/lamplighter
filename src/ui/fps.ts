// Счётчик кадров в секунду (клавиша F или ?fps в адресе).

export class FpsMeter {
  private el = document.createElement('div');
  private frames = 0;
  private acc = 0;
  visible = new URLSearchParams(location.search).has('fps');

  constructor(private extra: () => string = () => '') {
    Object.assign(this.el.style, {
      position: 'fixed', top: '10px', left: '10px', padding: '4px 8px',
      font: '12px ui-monospace, Menlo, monospace', color: '#ffd9a0',
      background: 'rgba(10,10,25,0.6)', borderRadius: '4px', zIndex: '20',
      pointerEvents: 'none', whiteSpace: 'pre',
    });
    document.body.appendChild(this.el);
    this.apply();
  }

  toggle(): void {
    this.visible = !this.visible;
    this.apply();
  }

  private apply() {
    this.el.style.display = this.visible ? 'block' : 'none';
  }

  update(dt: number): void {
    this.frames++;
    this.acc += dt;
    if (this.acc >= 0.5) {
      this.el.textContent = `${Math.round(this.frames / this.acc)} fps${this.extra()}`;
      this.frames = 0;
      this.acc = 0;
    }
  }
}
