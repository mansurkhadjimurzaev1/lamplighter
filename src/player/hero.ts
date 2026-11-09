import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { heightAt, WATER_LEVEL } from '../world/terrain';
import type { Collider } from '../world/vegetation';
import type { Input } from './input';

// Герой: путник в капюшоне (KayKit Adventurers, CC0) с анимациями
// «стоит» и «идёт». Ходит медленно — это старый фонарщик.

const WALK_SPEED = 2.1; // м/с
const HERO_HEIGHT = 1.55;
// оружие из пака прячем — у фонарщика только фонарь
const HIDE = ['Knife_Offhand', '1H_Crossbow', '2H_Crossbow', 'Knife', 'Throwable'];

export class Hero {
  readonly root = new THREE.Group();
  private mixer!: THREE.AnimationMixer;
  private idle!: THREE.AnimationAction;
  private walk!: THREE.AnimationAction;
  private hand!: THREE.Object3D;
  private walkWeight = 0;
  private facing = 0;
  /** Пройденное расстояние — для звука шагов. */
  distance = 0;
  speed = 0;

  async load(_castShadows: boolean): Promise<void> {
    const gltf = await new GLTFLoader().loadAsync(import.meta.env.BASE_URL + 'models/hero/Rogue_Hooded.glb');
    const model = gltf.scene;
    const seen = new Set<THREE.Material>();
    model.traverse((o) => {
      if (HIDE.includes(o.name)) o.visible = false;
      const m = o as THREE.Mesh;
      if (m.isMesh) {
        m.castShadow = false; // фонарь в руке: тень героя закрывала бы полкруга света
        m.receiveShadow = true;
        const mat = m.material as THREE.MeshStandardMaterial;
        if (seen.has(mat)) return; // материал общий для всех частей — настраиваем один раз
        seen.add(mat);
        mat.roughness = 0.85;
        mat.metalness = 0;
        mat.color.setRGB(0.78, 0.72, 0.62); // приглушаем яркую зелень плаща — дорожный, выцветший
        mat.emissive.setRGB(0.16, 0.09, 0.045); // тёплый отсвет фонаря на одежде
        mat.emissiveMap = mat.map;
      }
    });
    const box = new THREE.Box3().setFromObject(model);
    model.scale.setScalar(HERO_HEIGHT / (box.max.y - box.min.y));
    this.root.add(model);
    this.hand = model.getObjectByName('handslotr') ?? model.getObjectByName('handslot.r') ?? model.getObjectByName('handr')!;

    this.mixer = new THREE.AnimationMixer(model);
    const clip = (name: string) => THREE.AnimationClip.findByName(gltf.animations, name);
    this.idle = this.mixer.clipAction(clip('Idle'));
    this.walk = this.mixer.clipAction(clip('Walking_A'));
    this.idle.play();
    this.walk.play();
    this.walk.setEffectiveWeight(0);
  }

  /** Мировая позиция руки — туда вешаем фонарь. */
  handPosition(out = new THREE.Vector3()): THREE.Vector3 {
    return this.hand.getWorldPosition(out);
  }

  update(dt: number, input: Input, camera: THREE.Camera, colliders: Collider[]): void {
    // желаемое направление
    const dir = new THREE.Vector3();
    const axis = input.keyAxis();
    if (axis.lengthSq() > 0) {
      // «вверх по экрану» = направление взгляда камеры, спроецированное на землю
      const fwd = new THREE.Vector3();
      camera.getWorldDirection(fwd);
      fwd.y = 0;
      fwd.normalize();
      const right = new THREE.Vector3(-fwd.z, 0, fwd.x);
      dir.addScaledVector(fwd, axis.y).addScaledVector(right, axis.x);
    } else if (input.target) {
      dir.subVectors(input.target, this.root.position);
      dir.y = 0;
      if (dir.length() < 0.25) {
        input.target = null;
        dir.set(0, 0, 0);
      } else dir.normalize();
    }

    const moving = dir.lengthSq() > 0.001;
    const targetSpeed = moving ? WALK_SPEED * Math.min(1, dir.length()) : 0;
    this.speed += (targetSpeed - this.speed) * Math.min(1, dt * 8);

    if (moving) {
      const want = Math.atan2(dir.x, dir.z);
      let diff = want - this.facing;
      diff = Math.atan2(Math.sin(diff), Math.cos(diff));
      this.facing += diff * Math.min(1, dt * 10);
    }

    if (this.speed > 0.01) {
      const d = new THREE.Vector3(Math.sin(this.facing), 0, Math.cos(this.facing)).multiplyScalar(this.speed * dt);
      const before = this.root.position.clone();
      const next = before.clone().add(d);
      this.resolve(next, colliders);
      // не заходить в воду глубже щиколотки
      if (heightAt(next.x, next.z) < WATER_LEVEL - 0.15) {
        next.copy(before);
        input.target = null;
      }
      this.distance += Math.hypot(next.x - before.x, next.z - before.z);
      this.root.position.copy(next);
    }
    this.root.position.y = heightAt(this.root.position.x, this.root.position.z);
    this.root.rotation.y = this.facing;

    // плавный переход «стоит ↔ идёт», темп шага подстраивается под скорость
    const w = THREE.MathUtils.clamp(this.speed / WALK_SPEED, 0, 1);
    this.walkWeight += (w - this.walkWeight) * Math.min(1, dt * 10);
    this.walk.setEffectiveWeight(this.walkWeight);
    this.idle.setEffectiveWeight(1 - this.walkWeight);
    this.walk.timeScale = 0.85 * Math.max(0.4, w);
    this.mixer.update(dt);
  }

  private resolve(p: THREE.Vector3, colliders: Collider[]) {
    const r = 0.3;
    for (const c of colliders) {
      const dx = p.x - c.x;
      const dz = p.z - c.z;
      const d = Math.hypot(dx, dz);
      const min = c.r + r;
      if (d < min && d > 1e-4) {
        p.x = c.x + (dx / d) * min;
        p.z = c.z + (dz / d) * min;
      }
    }
  }
}
