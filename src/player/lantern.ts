import * as THREE from 'three';
import { Noise2D } from '../core/noise';

// Фонарь: латунный каркас, стекло, живой огонёк и тёплый PointLight.
// Висит на ручке и раскачивается как маятник, когда герой идёт.

const flickerNoise = new Noise2D(5);

export class Lantern {
  /** Точка подвеса (ставится в руку героя каждый кадр). */
  readonly pivot = new THREE.Group();
  /** Сам фонарь — качается относительно точки подвеса. */
  private body = new THREE.Group();
  readonly light: THREE.PointLight;
  private flame: THREE.Mesh;
  private glass: THREE.Mesh;
  private flameMat: THREE.MeshBasicMaterial;

  private swing = new THREE.Vector2(); // наклон по x/z
  private swingVel = new THREE.Vector2();
  private lastPivot = new THREE.Vector3();
  private lastVel = new THREE.Vector3();
  private baseIntensity = 30;

  constructor(shadows: boolean, shadowMapSize: number) {
    const brass = new THREE.MeshStandardMaterial({ color: 0x6b4a26, metalness: 0.85, roughness: 0.38 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x2a2018, metalness: 0.6, roughness: 0.55 });

    // ручка-дужка
    const handle = new THREE.Mesh(new THREE.TorusGeometry(0.055, 0.007, 6, 16, Math.PI), dark);
    handle.position.y = -0.04;
    this.body.add(handle);
    // крышка
    const cap = new THREE.Mesh(new THREE.ConeGeometry(0.085, 0.07, 8), brass);
    cap.position.y = -0.125;
    const capRing = new THREE.Mesh(new THREE.CylinderGeometry(0.085, 0.085, 0.015, 8), brass);
    capRing.position.y = -0.165;
    // основание
    const base = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.09, 0.035, 8), brass);
    base.position.y = -0.36;
    // стойки каркаса — отбрасывают тени-полосы на землю
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
      const bar = new THREE.Mesh(new THREE.BoxGeometry(0.01, 0.18, 0.01), dark);
      bar.position.set(Math.cos(a) * 0.072, -0.255, Math.sin(a) * 0.072);
      this.body.add(bar);
    }
    // стекло
    this.glass = new THREE.Mesh(
      new THREE.CylinderGeometry(0.066, 0.066, 0.18, 12, 1, true),
      new THREE.MeshStandardMaterial({
        color: 0xffc27a, emissive: 0xff8a2a, emissiveIntensity: 1.2,
        transparent: true, opacity: 0.45, roughness: 0.1, side: THREE.DoubleSide, depthWrite: false,
      }),
    );
    this.glass.position.y = -0.255;
    // огонёк (яркий → светится через bloom)
    this.flameMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 3.2, 1.1) });
    this.flame = new THREE.Mesh(new THREE.SphereGeometry(0.022, 10, 8), this.flameMat);
    this.flame.scale.set(1, 1.9, 1);
    this.flame.position.y = -0.26;
    this.body.add(cap, capRing, base, this.glass, this.flame);

    this.light = new THREE.PointLight(0xff9a45, this.baseIntensity, 0, 1.45);
    this.light.position.y = -0.24;
    this.light.castShadow = shadows;
    this.light.shadow.mapSize.set(shadowMapSize, shadowMapSize);
    this.light.shadow.camera.near = 0.05;
    this.light.shadow.camera.far = 22;
    this.light.shadow.bias = -0.002;
    this.light.shadow.radius = 3;
    this.body.add(this.light);

    this.pivot.add(this.body);
  }

  /** Обновление: качание + мерцание. pivotWorld — точка в руке героя. */
  update(dt: number, t: number, pivotWorld: THREE.Vector3): void {
    // ускорение руки раскачивает фонарь
    const vel = pivotWorld.clone().sub(this.lastPivot).divideScalar(Math.max(dt, 1e-3));
    if (this.lastPivot.lengthSq() === 0) vel.set(0, 0, 0);
    const acc = vel.clone().sub(this.lastVel).divideScalar(Math.max(dt, 1e-3)).clampLength(0, 40);
    this.lastPivot.copy(pivotWorld);
    this.lastVel.copy(vel);

    const k = 38; // жёсткость маятника
    const damp = 3.2;
    this.swingVel.x += (-k * this.swing.x - damp * this.swingVel.x - acc.z * 0.6) * dt;
    this.swingVel.y += (-k * this.swing.y - damp * this.swingVel.y + acc.x * 0.6) * dt;
    this.swing.addScaledVector(this.swingVel, dt);
    this.swing.clampLength(0, 0.6);

    this.pivot.position.copy(pivotWorld);
    this.body.rotation.set(this.swing.x, 0, this.swing.y);

    // мерцание: медленное «дыхание» + быстрая дрожь пламени
    const slow = flickerNoise.get(t * 0.7, 0.3);
    const fast = flickerNoise.get(t * 9, 4.1) * 0.6 + flickerNoise.get(t * 23, 8.7) * 0.4;
    const f = 1 + slow * 0.1 + fast * 0.09;
    this.light.intensity = this.baseIntensity * f;
    this.flame.scale.set(1 + fast * 0.15, 1.9 + fast * 0.5 + slow * 0.2, 1 + fast * 0.15);
    this.flameMat.color.setRGB(6 * f, 3.2 * f, 1.1 * f);
    // свет чуть «гуляет» внутри стекла — тени живые
    this.light.position.set(fast * 0.006, -0.24 + slow * 0.005, flickerNoise.get(t * 11, 2) * 0.006);
  }

  get worldPosition(): THREE.Vector3 {
    return this.light.getWorldPosition(new THREE.Vector3());
  }
}
