import * as THREE from 'three';
import { mulberry32 } from '../core/noise';
import { heightAt, WATER_LEVEL, ISLAND_RADIUS } from '../world/terrain';

// Светлячки над островом и пылинки, кружащие в свете фонаря.

const glowFrag = /* glsl */ `
  varying float vAlpha;
  varying vec3 vColor;
  void main() {
    float d = length(gl_PointCoord - 0.5);
    float a = 1.0 - smoothstep(0.0, 0.5, d);
    a = a * a;
    gl_FragColor = vec4(vColor * a * vAlpha, 1.0);
  }
`;

export class Fireflies {
  readonly points: THREE.Points;
  private mat: THREE.ShaderMaterial;

  constructor(count: number) {
    const rnd = mulberry32(7);
    const pos: number[] = [];
    const seed: number[] = [];
    let tries = 0;
    while (pos.length / 3 < count && tries++ < count * 50) {
      const a = rnd() * Math.PI * 2;
      const d = Math.sqrt(rnd()) * ISLAND_RADIUS;
      const x = Math.cos(a) * d;
      const z = Math.sin(a) * d;
      const h = heightAt(x, z);
      if (h < WATER_LEVEL + 0.3) continue;
      pos.push(x, h + 0.4 + rnd() * 1.8, z);
      seed.push(rnd() * 100, 0.5 + rnd(), rnd());
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('aSeed', new THREE.Float32BufferAttribute(seed, 3));
    this.mat = new THREE.ShaderMaterial({
      uniforms: { uTime: { value: 0 }, uScale: { value: window.innerHeight } },
      vertexShader: /* glsl */ `
        attribute vec3 aSeed;
        uniform float uTime, uScale;
        varying float vAlpha;
        varying vec3 vColor;
        void main() {
          float t = uTime * 0.25 * aSeed.y + aSeed.x;
          vec3 p = position + vec3(sin(t * 1.3) * 1.2 + sin(t * 3.1) * 0.25, sin(t * 1.7) * 0.35, cos(t * 1.1) * 1.2 + cos(t * 2.3) * 0.25);
          // мигание: долго гаснет, коротко вспыхивает
          float blink = pow(max(0.0, sin(uTime * (0.6 + aSeed.z * 0.8) + aSeed.x * 7.0)), 6.0);
          vAlpha = blink * 1.6 + 0.04;
          vColor = mix(vec3(1.0, 0.85, 0.35), vec3(0.75, 1.0, 0.45), aSeed.z) * 2.2;
          vec4 mv = modelViewMatrix * vec4(p, 1.0);
          gl_PointSize = (0.22 + blink * 0.12) * uScale / -mv.z;
          gl_Position = projectionMatrix * mv;
        }
      `,
      fragmentShader: glowFrag,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
    this.points = new THREE.Points(g, this.mat);
    this.points.frustumCulled = false;
  }

  update(t: number): void {
    this.mat.uniforms.uTime.value = t;
    this.mat.uniforms.uScale.value = window.innerHeight;
  }
}

export class LanternDust {
  readonly points: THREE.Points;
  private mat: THREE.ShaderMaterial;
  private static BOX = 5;

  constructor(count: number) {
    const rnd = mulberry32(17);
    const pos: number[] = [];
    const seed: number[] = [];
    for (let i = 0; i < count; i++) {
      pos.push(rnd() * LanternDust.BOX, rnd() * LanternDust.BOX, rnd() * LanternDust.BOX);
      seed.push(rnd() * 100, rnd(), rnd());
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('aSeed', new THREE.Float32BufferAttribute(seed, 3));
    this.mat = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uLantern: { value: new THREE.Vector3() },
        uScale: { value: window.innerHeight },
        uBox: { value: LanternDust.BOX },
      },
      vertexShader: /* glsl */ `
        attribute vec3 aSeed;
        uniform float uTime, uScale, uBox;
        uniform vec3 uLantern;
        varying float vAlpha;
        varying vec3 vColor;
        void main() {
          // медленный дрейф; пылинки «заворачиваются» в куб вокруг фонаря
          vec3 drift = vec3(sin(uTime * 0.2 + aSeed.x) * 0.3 + uTime * 0.05, sin(uTime * 0.13 + aSeed.x * 2.0) * 0.25 + uTime * 0.02, cos(uTime * 0.17 + aSeed.x) * 0.3);
          vec3 p = mod(position + drift - uLantern + uBox * 0.5, uBox) - uBox * 0.5 + uLantern;
          float d = distance(p, uLantern);
          float lit = 1.0 - smoothstep(0.3, 2.3, d);              // видны только в свете фонаря
          float tw = 0.6 + 0.4 * sin(uTime * (1.0 + aSeed.y * 2.0) + aSeed.x * 5.0);
          vAlpha = lit * tw * 0.9;
          vColor = vec3(1.0, 0.72, 0.42) * 1.4;
          vec4 mv = modelViewMatrix * vec4(p, 1.0);
          gl_PointSize = (0.035 + aSeed.z * 0.03) * uScale / -mv.z;
          gl_Position = projectionMatrix * mv;
        }
      `,
      fragmentShader: glowFrag,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
    this.points = new THREE.Points(g, this.mat);
    this.points.frustumCulled = false;
  }

  update(t: number, lantern: THREE.Vector3): void {
    this.mat.uniforms.uTime.value = t;
    this.mat.uniforms.uLantern.value.copy(lantern);
    this.mat.uniforms.uScale.value = window.innerHeight;
  }
}
