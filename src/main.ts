import * as THREE from 'three';
import { quality } from './core/quality';
import { createTerrain, surfaceAt, heightAt } from './world/terrain';
import { Water } from './world/water';
import { Grass } from './world/grass';
import { Vegetation, occlusion } from './world/vegetation';
import { Hero } from './player/hero';
import { Lantern } from './player/lantern';
import { Input } from './player/input';
import { CameraRig } from './player/cameraRig';
import { Post } from './fx/post';
import { Fireflies, LanternDust } from './fx/particles';
import { Soundscape } from './audio/soundscape';
import { FpsMeter } from './ui/fps';
import { showTitle } from './ui/titleScreen';
import { AdaptiveResolution } from './core/adaptiveResolution';

// ── Рендерер и сцена ────────────────────────────────────────────
// MSAA не нужен: картинка всё равно идёт через пост-обработку
const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(quality.pixelRatio);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.info.autoReset = false;
renderer.shadowMap.enabled = quality.shadows;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

const NIGHT = new THREE.Color(0x070a1a);
const scene = new THREE.Scene();
scene.background = NIGHT;
scene.fog = new THREE.FogExp2(0x0a0d22, 0.034);

// Слабый лунный свет сквозь Пелену + холодное небо
scene.add(new THREE.HemisphereLight(0x34448a, 0x0d0918, 0.9));
const moon = new THREE.DirectionalLight(0x8394e8, 0.5);
moon.position.set(-30, 50, -20);
scene.add(moon);
// ?bright — отладочный режим: светло, чтобы разглядеть сцену
if (new URLSearchParams(location.search).has('bright')) {
  scene.add(new THREE.AmbientLight(0xffffff, 2.5));
  scene.fog = null;
}

const rig = new CameraRig();
const post = new Post(renderer, scene, rig.camera, quality.bloom);
post.fade = 0;

// ── Мир ─────────────────────────────────────────────────────────
const terrain = createTerrain();
scene.add(terrain);
const water = new Water();
scene.add(water.mesh);
const grass = new Grass(quality.grassPerSquareMeter);
scene.add(grass.group);
const vegetation = new Vegetation();
const fireflies = new Fireflies(quality.fireflies);
scene.add(fireflies.points);
const dust = new LanternDust(quality.dust);
scene.add(dust.points);

// ── Герой ───────────────────────────────────────────────────────
const hero = new Hero();
const lantern = new Lantern(quality.shadows, quality.shadowMapSize);
scene.add(lantern.pivot);
const input = new Input(renderer.domElement, rig.camera, () => terrain);
const sound = new Soundscape();
const adaptive = new AdaptiveResolution(renderer, quality.pixelRatio, () => post.resize(renderer));
if (new URLSearchParams(location.search).has('fixedres')) adaptive.update = () => {};
const fps = new FpsMeter(() => `\n${quality.level} · ${renderer.info.render.calls} draw · ${adaptive.current.toFixed(2)}x`);
input.onToggleFps = () => fps.toggle();

const title = showTitle(() => {
  sound.start();
  started = true;
});
let started = false;

await Promise.all([vegetation.load(quality.shadows), hero.load(quality.shadows)]);
scene.add(vegetation.group);
scene.add(hero.root);
hero.root.position.set(0, 0, 4);
rig.snap(hero.root.position);
// прогреваем шейдеры заранее, чтобы не было рывка на первом кадре
renderer.compile(scene, rig.camera);
title.setReady();
// для автоматических проверок
(window as unknown as { __game: unknown }).__game = { hero, input, heightAt, get started() { return started; } };

// ── Цикл ────────────────────────────────────────────────────────
const clock = new THREE.Clock();
const handPos = new THREE.Vector3();
const lastPos = new THREE.Vector3().copy(hero.root.position);
const velocity = new THREE.Vector3();
let fade = 0;
let nextStepAt = 0.65;

renderer.setAnimationLoop(() => {
  const rawDt = clock.getDelta();
  const dt = Math.min(rawDt, 0.05);
  const t = clock.elapsedTime;

  if (started) hero.update(dt, input, rig.camera, vegetation.colliders);
  else hero.update(dt, { keyAxis: () => new THREE.Vector2(), target: null } as unknown as Input, rig.camera, []);

  velocity.subVectors(hero.root.position, lastPos).divideScalar(Math.max(dt, 1e-3));
  lastPos.copy(hero.root.position);

  hero.handPosition(handPos);
  lantern.update(dt, t, handPos);
  rig.update(dt, hero.root.position, velocity);
  rig.camera.updateMatrixWorld();
  occlusion.uHeroView.value.copy(hero.root.position).setY(hero.root.position.y + 0.8).applyMatrix4(rig.camera.matrixWorldInverse);

  // шаги — каждые ~0.65 м пройденного пути
  if (hero.distance >= nextStepAt) {
    nextStepAt = hero.distance + 0.62 + Math.random() * 0.06;
    sound.step(surfaceAt(hero.root.position.x, hero.root.position.z));
  }
  sound.update(dt);

  grass.update(t, hero.root.position);
  water.update(t, lantern.worldPosition);
  fireflies.update(t);
  dust.update(t, lantern.worldPosition);

  // плавное появление из темноты после старта
  fade = Math.min(1, fade + dt * (started ? 0.35 : 0.12));
  post.fade = started ? fade : Math.min(fade, 0.45);
  renderer.info.reset();
  post.render(t);
  fps.update(dt);
  if (started) adaptive.update(rawDt);
});

window.addEventListener('resize', () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
  rig.resize();
  post.resize(renderer);
});
