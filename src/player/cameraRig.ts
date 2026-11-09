import * as THREE from 'three';

// Камера сверху под углом ~50°, плавно следует за героем
// и чуть «заглядывает» вперёд по ходу движения.

export class CameraRig {
  readonly camera: THREE.PerspectiveCamera;
  private focus = new THREE.Vector3();
  private lead = new THREE.Vector3();
  private pitch = THREE.MathUtils.degToRad(50);
  private yaw = THREE.MathUtils.degToRad(20);

  constructor() {
    this.camera = new THREE.PerspectiveCamera(40, window.innerWidth / window.innerHeight, 0.3, 160);
    this.resize();
  }

  private get distance() {
    // в портретной ориентации (телефон) отходим дальше, чтобы видеть больше
    const aspect = window.innerWidth / window.innerHeight;
    return aspect < 1 ? 16 : 12.5;
  }

  resize(): void {
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
  }

  snap(target: THREE.Vector3): void {
    this.focus.copy(target);
    this.apply();
  }

  update(dt: number, target: THREE.Vector3, velocity: THREE.Vector3): void {
    this.lead.lerp(velocity.clone().multiplyScalar(0.6), 1 - Math.exp(-dt * 1.5));
    const want = target.clone().add(this.lead);
    want.y += 0.6;
    this.focus.lerp(want, 1 - Math.exp(-dt * 3.2));
    this.apply();
  }

  private apply() {
    const d = this.distance;
    const off = new THREE.Vector3(
      Math.sin(this.yaw) * Math.cos(this.pitch) * d,
      Math.sin(this.pitch) * d,
      Math.cos(this.yaw) * Math.cos(this.pitch) * d,
    );
    this.camera.position.copy(this.focus).add(off);
    this.camera.lookAt(this.focus);
  }
}
