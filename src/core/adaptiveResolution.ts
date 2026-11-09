import type * as THREE from 'three';

// Адаптивное разрешение: следим за временем кадра и плавно меняем
// чёткость картинки, чтобы держать ~60 fps на любом устройстве.

export class AdaptiveResolution {
  private samples: number[] = [];
  private cooldown = 2; // секунды до первой подстройки (даём сцене прогреться)
  current: number;

  constructor(
    private renderer: THREE.WebGLRenderer,
    private maxRatio: number,
    private onChange: () => void,
    private minRatio = 0.6,
  ) {
    this.current = maxRatio;
  }

  update(dt: number): void {
    this.samples.push(dt);
    if (this.samples.length > 40) this.samples.shift();
    this.cooldown -= dt;
    if (this.cooldown > 0 || this.samples.length < 30) return;

    const sorted = [...this.samples].sort((a, b) => a - b);
    const typical = sorted[Math.floor(sorted.length * 0.5)] * 1000; // мс, медиана

    let next = this.current;
    if (typical > 18.5) next = this.current * 0.85; // медленно — снижаем чёткость
    else if (typical < 14.5) next = this.current * 1.08; // запас есть — повышаем
    next = Math.min(this.maxRatio, Math.max(this.minRatio, next));

    if (Math.abs(next - this.current) > 0.02) {
      this.current = next;
      this.renderer.setPixelRatio(next);
      this.onChange();
      this.samples.length = 0;
      this.cooldown = 1.2;
    }
  }
}
