import * as THREE from 'three';
import { WATER_LEVEL, heightAt } from './terrain';

// Тёмная вода вокруг острова: почти чёрная, с мелкой рябью,
// в которой отражаются блики фонаря и луны.

function makeRippleNormalMap(size = 256): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const ctx = c.getContext('2d')!;
  const img = ctx.createImageData(size, size);
  // сумма периодических синусоид → бесшовная карта высот, из неё нормали
  const h = new Float32Array(size * size);
  const waves: [number, number, number, number][] = [];
  for (let i = 0; i < 14; i++) {
    const a = Math.random() * Math.PI * 2;
    const k = 1 + Math.floor(Math.random() * 7);
    waves.push([Math.round(Math.cos(a) * k), Math.round(Math.sin(a) * k), Math.random() * 6.28, 1 / k]);
  }
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++) {
      let v = 0;
      for (const [kx, ky, ph, amp] of waves) v += Math.sin(((kx * x + ky * y) / size) * Math.PI * 2 + ph) * amp;
      h[y * size + x] = v;
    }
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++) {
      const l = h[y * size + ((x - 1 + size) % size)];
      const r = h[y * size + ((x + 1) % size)];
      const d = h[((y - 1 + size) % size) * size + x];
      const u = h[((y + 1) % size) * size + x];
      const n = new THREE.Vector3((l - r) * 2, (d - u) * 2, 1).normalize();
      const i = (y * size + x) * 4;
      img.data[i] = (n.x * 0.5 + 0.5) * 255;
      img.data[i + 1] = (n.y * 0.5 + 0.5) * 255;
      img.data[i + 2] = (n.z * 0.5 + 0.5) * 255;
      img.data[i + 3] = 255;
    }
  ctx.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(90, 90);
  return t;
}

export class Water {
  readonly mesh: THREE.Mesh;
  private normal: THREE.CanvasTexture;
  private lantern = { value: new THREE.Vector3(0, -100, 0) };
  private time = { value: 0 };

  constructor() {
    this.normal = makeRippleNormalMap();
    const mat = new THREE.MeshStandardMaterial({
      color: 0x02040c,
      roughness: 0.4,
      metalness: 0,
      normalMap: this.normal,
      normalScale: new THREE.Vector2(0.18, 0.18),
      transparent: true,
      opacity: 0.93,
    });
    // карта глубины: высоты дна в текстуре — прозрачное мелководье у берега
    const N = 256;
    const SPAN = 100;
    const data = new Uint8Array(N * N);
    for (let j = 0; j < N; j++)
      for (let i = 0; i < N; i++) {
        const x = (i / (N - 1) - 0.5) * SPAN;
        const z = (j / (N - 1) - 0.5) * SPAN;
        const depth = WATER_LEVEL - heightAt(x, z); // >0 — под водой
        data[j * N + i] = Math.round(THREE.MathUtils.clamp(depth / 2, 0, 1) * 255);
      }
    const depthTex = new THREE.DataTexture(data, N, N, THREE.RedFormat, THREE.UnsignedByteType);
    depthTex.magFilter = depthTex.minFilter = THREE.LinearFilter;
    depthTex.needsUpdate = true;

    mat.onBeforeCompile = (shader) => {
      shader.uniforms.tDepth = { value: depthTex };
      shader.uniforms.uLantern = this.lantern;
      shader.uniforms.uTime = this.time;
      shader.uniforms.uSpan = { value: SPAN };
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nvarying vec3 vWW;')
        .replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\nvWW = (modelMatrix * vec4(transformed, 1.0)).xyz;');
      shader.fragmentShader = shader.fragmentShader
        .replace('#include <common>', '#include <common>\nvarying vec3 vWW;\nuniform sampler2D tDepth;\nuniform vec3 uLantern;\nuniform float uTime, uSpan;')
        .replace(
          '#include <opaque_fragment>',
          `
          vec2 duv = vWW.xz / uSpan + 0.5;
          float depth = (duv.x < 0.0 || duv.x > 1.0 || duv.y < 0.0 || duv.y > 1.0) ? 2.0 : texture2D(tDepth, duv).r * 2.0;
          // у самого берега вода прозрачная, дальше — тёмная
          diffuseColor.a *= smoothstep(0.0, 0.55, depth);
          // тонкая светлая кромка прибоя
          float edge = (1.0 - smoothstep(0.0, 0.12, abs(depth - 0.06))) * (0.6 + 0.4 * sin(uTime * 1.3 + vWW.x * 2.0 + vWW.z * 1.7));
          outgoingLight += vec3(0.05, 0.07, 0.12) * edge;
          // дрожащее отражение фонаря на воде
          vec2 dl = vWW.xz - uLantern.xz;
          float shimmer = 0.55 + 0.45 * sin(vWW.x * 7.0 + uTime * 2.1) * sin(vWW.z * 6.0 - uTime * 1.7);
          float glow = exp(-dot(dl, dl) * 0.35) * shimmer;
          outgoingLight += vec3(1.0, 0.5, 0.18) * glow * 0.45;
          diffuseColor.a = max(diffuseColor.a, glow * 0.6 * smoothstep(0.0, 0.3, depth));
          #include <opaque_fragment>`,
        );
    };

    const geo = new THREE.PlaneGeometry(400, 400);
    geo.rotateX(-Math.PI / 2);
    this.mesh = new THREE.Mesh(geo, mat);
    this.mesh.position.y = WATER_LEVEL;
    this.mesh.receiveShadow = false;
    this.mesh.renderOrder = 1;
  }

  update(t: number, lantern: THREE.Vector3): void {
    this.time.value = t;
    this.lantern.value.copy(lantern);
    this.normal.offset.set(t * 0.004, t * 0.0027);
  }
}
