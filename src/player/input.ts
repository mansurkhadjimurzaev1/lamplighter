import * as THREE from 'three';

// Ввод: WASD/стрелки на ПК, тап (или клик) по земле — идти в точку.

export class Input {
  private keys = new Set<string>();
  /** Точка, куда идти после тапа/клика (null — нет цели). */
  target: THREE.Vector3 | null = null;
  onToggleFps: () => void = () => {};

  private raycaster = new THREE.Raycaster();
  private down: { x: number; y: number; t: number; id: number } | null = null;

  constructor(
    dom: HTMLElement,
    private camera: THREE.Camera,
    private ground: () => THREE.Object3D,
  ) {
    window.addEventListener('keydown', (e) => {
      if (e.code === 'KeyF' && !e.repeat) this.onToggleFps();
      this.keys.add(e.code);
      if (this.isMoveKey(e.code)) this.target = null; // клавиатура отменяет «идти в точку»
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());

    dom.addEventListener('pointerdown', (e) => {
      this.down = { x: e.clientX, y: e.clientY, t: performance.now(), id: e.pointerId };
    });
    dom.addEventListener('pointerup', (e) => {
      if (!this.down || this.down.id !== e.pointerId) return;
      const moved = Math.hypot(e.clientX - this.down.x, e.clientY - this.down.y);
      if (moved < 20) this.pick(e.clientX, e.clientY);
      this.down = null;
    });
    dom.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  private isMoveKey(c: string) {
    return ['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(c);
  }

  private pick(cx: number, cy: number) {
    const ndc = new THREE.Vector2((cx / window.innerWidth) * 2 - 1, -(cy / window.innerHeight) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const hit = this.raycaster.intersectObject(this.ground(), false)[0];
    if (hit) this.target = hit.point.clone();
  }

  /** Направление с клавиатуры в плоскости экрана: x — вправо, y — «вверх по экрану». */
  keyAxis(): THREE.Vector2 {
    const k = this.keys;
    const v = new THREE.Vector2(
      (k.has('KeyD') || k.has('ArrowRight') ? 1 : 0) - (k.has('KeyA') || k.has('ArrowLeft') ? 1 : 0),
      (k.has('KeyW') || k.has('ArrowUp') ? 1 : 0) - (k.has('KeyS') || k.has('ArrowDown') ? 1 : 0),
    );
    return v.lengthSq() > 1 ? v.normalize() : v;
  }
}
