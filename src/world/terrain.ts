import * as THREE from 'three';
import { Noise2D, smoothstep } from '../core/noise';

// ── Рельеф острова ──────────────────────────────────────────────
// Остров ~80×80 м с центром в (0,0). Вода на высоте 0.

export const ISLAND_RADIUS = 40;
export const WATER_LEVEL = 0;
const TERRAIN_SIZE = 140; // меш больше острова, чтобы склоны уходили под воду

const hillNoise = new Noise2D(7);
const coastNoise = new Noise2D(13);
const surfNoise = new Noise2D(29);

/** Высота земли в точке (x, z). */
export function heightAt(x: number, z: number): number {
  const d = Math.hypot(x, z);
  // береговая линия «гуляет», чтобы остров не был идеальным кругом
  const coast = ISLAND_RADIUS * (0.88 + 0.16 * coastNoise.fbm(x * 0.03, z * 0.03, 3));
  const island = smoothstep(coast + 3, coast - 9, d); // 1 — суша, 0 — море
  const hills = hillNoise.fbm(x * 0.035, z * 0.035, 4); // крупные холмы
  const bumps = hillNoise.fbm(x * 0.18 + 40, z * 0.18, 2) * 0.25; // мелкие неровности
  const centre = smoothstep(26, 0, d) * 1.6; // мягкое возвышение к центру
  const land = 1.0 + centre + (hills * 0.5 + 0.5) * 3.2 + bumps;
  return island * land - (1 - island) * 3.5;
}

/** Нормаль (через центральные разности). */
export function normalAt(x: number, z: number, out = new THREE.Vector3()): THREE.Vector3 {
  const e = 0.25;
  const hx = heightAt(x + e, z) - heightAt(x - e, z);
  const hz = heightAt(x, z + e) - heightAt(x, z - e);
  return out.set(-hx, 2 * e, -hz).normalize();
}

export type Surface = 'grass' | 'dirt' | 'rock' | 'water';

/** Веса материалов (трава, земля, камень) — одинаковы для шейдера, травы и звука шагов. */
export function surfaceWeights(x: number, z: number): [number, number, number] {
  const h = heightAt(x, z);
  const slope = 1 - normalAt(x, z, tmpN).y; // 0 — ровно, ~0.3+ — круто
  const n = surfNoise.fbm(x * 0.08, z * 0.08, 3);
  const n2 = surfNoise.fbm(x * 0.4 + 11, z * 0.4, 2);

  let rock = smoothstep(0.1, 0.22, slope + n2 * 0.04);
  rock = Math.max(rock, smoothstep(0.55, 0.75, n * 0.8 + n2 * 0.25) * 0.9); // каменистые плеши
  let dirt = smoothstep(0.9, 0.25, h) ; // берег — голая земля
  dirt = Math.max(dirt, smoothstep(0.15, 0.45, -n + n2 * 0.2)); // тропинки и проплешины
  dirt *= 1 - rock;
  const grass = Math.max(0, 1 - rock - dirt);
  const sum = grass + dirt + rock;
  return [grass / sum, dirt / sum, rock / sum];
}
const tmpN = new THREE.Vector3();

export function surfaceAt(x: number, z: number): Surface {
  if (heightAt(x, z) < WATER_LEVEL + 0.08) return 'water';
  const [g, d, r] = surfaceWeights(x, z);
  if (r >= g && r >= d) return 'rock';
  if (d >= g) return 'dirt';
  return 'grass';
}

// ── Меш и шейдер смешивания текстур ─────────────────────────────

function loadTex(loader: THREE.TextureLoader, url: string, srgb: boolean): THREE.Texture {
  const t = loader.load(url);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export function createTerrain(): THREE.Mesh {
  const segs = 280;
  const geo = new THREE.PlaneGeometry(TERRAIN_SIZE, TERRAIN_SIZE, segs, segs);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position as THREE.BufferAttribute;
  const weights = new Float32Array(pos.count * 3);
  const uv = geo.attributes.uv as THREE.BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    pos.setY(i, heightAt(x, z));
    const w = surfaceWeights(x, z);
    weights.set(w, i * 3);
    uv.setXY(i, x * 0.25, -z * 0.25); // uv = мировые координаты (нужно для касательного базиса нормалей)
  }
  geo.setAttribute('aWeights', new THREE.BufferAttribute(weights, 3));
  geo.computeVertexNormals();

  const loader = new THREE.TextureLoader();
  const base = import.meta.env.BASE_URL + 'textures/ground/';
  const tex = {
    grassC: loadTex(loader, base + 'Grass004_color.jpg', true),
    grassN: loadTex(loader, base + 'Grass004_normal.jpg', false),
    dirtC: loadTex(loader, base + 'Ground037_color.jpg', true),
    dirtN: loadTex(loader, base + 'Ground037_normal.jpg', false),
    rockC: loadTex(loader, base + 'Rock030_color.jpg', true),
    rockN: loadTex(loader, base + 'Rock030_normal.jpg', false),
  };

  const mat = new THREE.MeshStandardMaterial({
    roughness: 0.95,
    metalness: 0,
    normalMap: tex.grassN, // заглушка: включает код нормалей в шейдере, сам сэмплинг заменяем ниже
    normalScale: new THREE.Vector2(1, 1),
  });

  mat.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, {
      tGrassC: { value: tex.grassC }, tGrassN: { value: tex.grassN },
      tDirtC: { value: tex.dirtC }, tDirtN: { value: tex.dirtN },
      tRockC: { value: tex.rockC }, tRockN: { value: tex.rockN },
    });
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nattribute vec3 aWeights;\nvarying vec3 vW;\nvarying vec3 vWorldP;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvW = aWeights;\nvWorldP = (modelMatrix * vec4(position,1.0)).xyz;');

    const common = /* glsl */ `
      uniform sampler2D tGrassC, tGrassN, tDirtC, tDirtN, tRockC, tRockN;
      varying vec3 vW;
      varying vec3 vWorldP;
      // Две выборки разного масштаба — убирают заметный повтор текстуры
      vec4 sampleTwo(sampler2D t, vec2 p, float s) {
        vec2 q = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
        return mix(texture2D(t, p * s), texture2D(t, q * s * 0.37 + 0.31), 0.35);
      }
      // Резкость перехода с учётом «высоты» текстур — края выглядят естественнее
      vec3 blendW(vec3 w, vec3 hgt) {
        vec3 b = w + hgt * 0.35;
        float m = max(b.x, max(b.y, b.z)) - 0.22;
        vec3 r = max(b - m, 0.0);
        return r / (r.x + r.y + r.z + 1e-4);
      }
      vec3 gW;
    `;
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\n' + common)
      .replace(
        '#include <map_fragment>',
        /* glsl */ `
        vec2 wp = vWorldP.xz;
        // текстуры, которых в этой точке почти нет, не читаем вовсе — экономия на каждом пикселе
        vec4 cG = vW.x > 0.004 ? sampleTwo(tGrassC, wp, 0.32) : vec4(0.0);
        vec4 cD = vW.y > 0.004 ? sampleTwo(tDirtC, wp, 0.28) : vec4(0.0);
        vec4 cR = vW.z > 0.004 ? sampleTwo(tRockC, wp, 0.2) : vec4(0.0);
        gW = blendW(vW, vec3(dot(cG.rgb, vec3(0.33)), dot(cD.rgb, vec3(0.33)), dot(cR.rgb, vec3(0.33))));
        vec3 col = cG.rgb * vec3(0.85, 1.0, 0.8) * gW.x + cD.rgb * gW.y + cR.rgb * gW.z;
        // крупные пятна вариации цвета
        float macro = texture2D(tDirtC, wp * 0.013).r;
        col *= mix(0.75, 1.15, macro);
        diffuseColor.rgb *= col;
        `,
      )
      .replace(
        '#include <normal_fragment_maps>',
        THREE.ShaderChunk.normal_fragment_maps.replace(
          'vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;',
          `vec3 mapN = vec3(0.0);
           if (gW.x > 0.01) mapN += texture2D(tGrassN, wp * 0.32).xyz * gW.x;
           if (gW.y > 0.01) mapN += texture2D(tDirtN, wp * 0.28).xyz * gW.y;
           if (gW.z > 0.01) mapN += texture2D(tRockN, wp * 0.2).xyz * gW.z;
           mapN = mapN / max(gW.x * step(0.01, gW.x) + gW.y * step(0.01, gW.y) + gW.z * step(0.01, gW.z), 1e-3) * 2.0 - 1.0;`,
        ),
      )
      .replace(
        '#include <roughnessmap_fragment>',
        '#include <roughnessmap_fragment>\nroughnessFactor = 0.95 - gW.z * 0.25;',
      );
  };

  const mesh = new THREE.Mesh(geo, mat);
  mesh.receiveShadow = true;
  mesh.name = 'terrain';
  return mesh;
}
