import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { mulberry32, Noise2D } from '../core/noise';
import { heightAt, normalAt, surfaceWeights, WATER_LEVEL, ISLAND_RADIUS } from './terrain';

// Деревья, камни, кусты (CC0, Quaternius). Каждая модель рисуется
// через InstancedMesh — сотни объектов за пару вызовов отрисовки.

export interface Collider { x: number; z: number; r: number }

interface Kind {
  files: string[];
  height: [number, number]; // желаемая высота модели, м
  count: number;
  collide: number; // радиус столкновения (доля от ширины), 0 — проходимо
  where: (x: number, z: number, rnd: () => number) => boolean;
  sink?: number; // насколько утопить в землю
  tilt?: number;
  shadow?: boolean;
}

const forest = new Noise2D(51);
const forestDensity = (x: number, z: number) => forest.fbm(x * 0.045, z * 0.045, 3) * 0.5 + 0.5;
const awayFromStart = (x: number, z: number, r: number) => Math.hypot(x, z) > r;

const KINDS: Kind[] = [
  {
    files: ['PineTree_1', 'PineTree_2', 'PineTree_3', 'PineTree_4', 'PineTree_5'],
    height: [5, 8.5], count: 150, collide: 0.09, shadow: true,
    where: (x, z, rnd) => awayFromStart(x, z, 10) && forestDensity(x, z) > 0.42 + rnd() * 0.25,
  },
  {
    files: ['CommonTree_1', 'CommonTree_2', 'CommonTree_3', 'CommonTree_4'],
    height: [3.5, 5.5], count: 28, collide: 0.08, shadow: true,
    where: (x, z, rnd) => awayFromStart(x, z, 11) && forestDensity(x, z) > 0.35 + rnd() * 0.3,
  },
  {
    files: ['CommonTree_Dead_1', 'CommonTree_Dead_3', 'BirchTree_Dead_2'],
    height: [3.5, 5.5], count: 22, collide: 0.07, shadow: true,
    where: (x, z) => awayFromStart(x, z, 8) && forestDensity(x, z) < 0.5,
  },
  {
    files: ['Rock_1', 'Rock_2', 'Rock_3', 'Rock_4', 'Rock_5'],
    height: [0.4, 1.6], count: 70, collide: 0.35, sink: 0.15, tilt: 0.3, shadow: true,
    where: (x, z) => surfaceWeights(x, z)[2] > 0.25 || heightAt(x, z) < 0.6,
  },
  {
    files: ['Rock_Moss_1', 'Rock_Moss_2', 'Rock_Moss_4', 'Rock_Moss_6'],
    height: [0.5, 1.8], count: 55, collide: 0.35, sink: 0.15, tilt: 0.3, shadow: true,
    where: (x, z) => awayFromStart(x, z, 3) && surfaceWeights(x, z)[0] > 0.3,
  },
  {
    files: ['Bush_1', 'Bush_2', 'BushBerries_1'],
    height: [0.6, 1.2], count: 90, collide: 0, sink: 0.05, shadow: true,
    where: (x, z, rnd) => forestDensity(x, z) > 0.3 + rnd() * 0.3,
  },
  {
    files: ['Plant_1', 'Plant_2', 'Plant_3', 'Plant_5'],
    height: [0.3, 0.7], count: 160, collide: 0,
    where: (x, z) => surfaceWeights(x, z)[0] > 0.5,
  },
  {
    files: ['TreeStump_Moss', 'WoodLog_Moss'],
    height: [0.4, 0.7], count: 18, collide: 0.3, sink: 0.05, shadow: true,
    where: (x, z) => awayFromStart(x, z, 4) && forestDensity(x, z) > 0.4,
  },
  {
    files: ['Flowers'],
    height: [0.25, 0.4], count: 40, collide: 0,
    where: (x, z) => surfaceWeights(x, z)[0] > 0.7,
  },
];

interface Part { geometry: THREE.BufferGeometry; material: THREE.Material }

const CHUNK = 16;

/** Разбираем GLB на (геометрия + материал), нормализуем размер: высота = 1, основание на y = 0. */
function extractParts(root: THREE.Object3D): { parts: Part[]; width: number } {
  root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(root);
  const size = box.getSize(new THREE.Vector3());
  const norm = new THREE.Matrix4()
    .makeScale(1 / size.y, 1 / size.y, 1 / size.y)
    .multiply(new THREE.Matrix4().makeTranslation(-(box.min.x + box.max.x) / 2, -box.min.y, -(box.min.z + box.max.z) / 2));
  const parts: Part[] = [];
  root.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh) return;
    const mats = Array.isArray(m.material) ? m.material : [m.material];
    const g = m.geometry.clone();
    g.applyMatrix4(new THREE.Matrix4().multiplyMatrices(norm, m.matrixWorld));
    if (mats.length === 1) parts.push({ geometry: g, material: mats[0] });
    else
      for (const grp of g.groups) {
        const sub = g.clone();
        sub.setIndex(Array.from(g.index!.array.slice(grp.start, grp.start + grp.count)));
        sub.clearGroups();
        parts.push({ geometry: sub, material: mats[grp.materialIndex ?? 0] });
      }
  });
  return { parts, width: Math.max(size.x, size.z) / size.y };
}

/** Позиция героя в пространстве камеры — для «растворения» загораживающих объектов. */
export const occlusion = { uHeroView: { value: new THREE.Vector3(0, 0, -10) } };

/** Добавляем материалам деталь: затемнение у земли (как AO) и пятна оттенка по миру. */
const rockTex = (() => {
  const t = new THREE.TextureLoader().load(import.meta.env.BASE_URL + 'textures/ground/Rock030_color.jpg');
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
})();

function enrichMaterial(src: THREE.Material): THREE.Material {
  const mat = (src as THREE.MeshStandardMaterial).clone();
  mat.roughness = 0.9;
  mat.metalness = 0;
  const kind = /rock|stone/i.test(src.name) ? 1 : /wood|bark|trunk/i.test(src.name) ? 2 : 0;
  mat.defines = { ...mat.defines, SURF_KIND: kind };
  if (location.search.includes('debugn')) mat.defines.DEBUG_N = 1;
  // у каждого типа поверхности — своя версия шейдера (иначе Three.js переиспользует одну)
  mat.customProgramCacheKey = () => 'veg-' + kind;
  mat.onBeforeCompile = (shader) => {
    shader.uniforms.uHeroView = occlusion.uHeroView;
    shader.uniforms.tRock = { value: rockTex };
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vWP;\nvarying vec3 vWN;\nvarying float vLocalY;')
      .replace(
        '#include <worldpos_vertex>',
        `#include <worldpos_vertex>
         vec4 wpp = vec4(transformed, 1.0);
         #ifdef USE_INSTANCING
           wpp = instanceMatrix * wpp;
         #endif
         vWP = (modelMatrix * wpp).xyz;
         mat3 nm = mat3(modelMatrix);
         #ifdef USE_INSTANCING
           nm = nm * mat3(instanceMatrix);
         #endif
         vWN = normalize(nm * objectNormal);
         vLocalY = position.y;`,
      );
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vWP;\nvarying vec3 vWN;\nvarying float vLocalY;\nuniform vec3 uHeroView;\nuniform sampler2D tRock;\n' + HASH_GLSL)
      .replace(
        '#include <clipping_planes_fragment>',
        `#include <clipping_planes_fragment>
         // всё, что ближе к камере, чем герой, и закрывает его, — растворяется сеточкой
         vec3 P = -vViewPosition;
         if (P.z > uHeroView.z + 0.6) {
           vec2 a = P.xy / -P.z;
           vec2 b = uHeroView.xy / -uHeroView.z;
           float hide = 1.0 - smoothstep(0.12, 0.24, length(a - b));
           if (hide > 0.0 && hash12(floor(gl_FragCoord.xy)) < hide * 0.85) discard;
         }`,
      )
      .replace(
        '#include <color_fragment>',
        `#include <color_fragment>
         float ao = mix(0.35, 1.0, smoothstep(0.0, 0.35, vLocalY));
         float n = vnoise(vWP.xz * 1.7 + vWP.y * 0.9) * 0.6 + vnoise(vWP.xz * 6.0 + vWP.y * 4.0) * 0.4;
         diffuseColor.rgb *= ao * mix(0.78, 1.18, n);
         #if SURF_KIND == 1
           // камень: настоящая текстура, наложенная с трёх сторон (без развёртки)
           vec3 bw = pow(abs(normalize(vWN)), vec3(4.0)); bw /= bw.x + bw.y + bw.z;
           vec3 tc = texture2D(tRock, vWP.zy * 0.45).rgb * bw.x + texture2D(tRock, vWP.xz * 0.45).rgb * bw.y + texture2D(tRock, vWP.xy * 0.45).rgb * bw.z;
           diffuseColor.rgb = mix(diffuseColor.rgb, tc * 0.75 * ao, 0.85);
           #ifdef DEBUG_N
           diffuseColor.rgb = normalize(vWN) * 0.5 + 0.5;
           #endif
           // мох на верхних гранях
           float moss = smoothstep(0.55, 0.9, normalize(vWN).y + (n - 0.5) * 0.5);
           diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.06, 0.1, 0.035) * mix(0.7, 1.3, n), moss * 0.7);
         #elif SURF_KIND == 2
           // кора: продольные волокна
           float fib = vnoise(vec2(atan(vWN.z, vWN.x) * 6.0, vWP.y * 0.8)) * 0.5 + vnoise(vWP.xz * 30.0 + vWP.y * 2.0) * 0.5;
           diffuseColor.rgb *= mix(0.6, 1.25, fib);
         #endif`,
      );
  };
  return mat;
}

const HASH_GLSL = /* glsl */ `
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
  return mix(mix(hash12(i), hash12(i+vec2(1,0)), f.x), mix(hash12(i+vec2(0,1)), hash12(i+vec2(1,1)), f.x), f.y); }
`;

export class Vegetation {
  readonly group = new THREE.Group();
  readonly colliders: Collider[] = [];

  async load(castShadows: boolean): Promise<void> {
    const loader = new GLTFLoader();
    const base = import.meta.env.BASE_URL + 'models/nature/';
    const rnd = mulberry32(2024);
    const occupied: Collider[] = [];

    const allFiles = [...new Set(KINDS.flatMap((k) => k.files))];
    const loaded = new Map<string, { parts: Part[]; width: number }>();
    await Promise.all(
      allFiles.map(async (f) => {
        const gltf = await loader.loadAsync(base + f + '.glb');
        const ex = extractParts(gltf.scene);
        ex.parts.forEach((p) => (p.material = enrichMaterial(p.material)));
        loaded.set(f, ex);
      }),
    );

    for (const kind of KINDS) {
      // раскладываем экземпляры по файлам модели
      const perFile = new Map<string, THREE.Matrix4[]>();
      let placed = 0;
      for (let attempt = 0; attempt < kind.count * 30 && placed < kind.count; attempt++) {
        const a = rnd() * Math.PI * 2;
        const d = Math.sqrt(rnd()) * (ISLAND_RADIUS + 2);
        const x = Math.cos(a) * d;
        const z = Math.sin(a) * d;
        const h = heightAt(x, z);
        if (h < WATER_LEVEL + 0.3) continue;
        if (!kind.where(x, z, rnd)) continue;
        const file = kind.files[Math.floor(rnd() * kind.files.length)];
        const model = loaded.get(file)!;
        const height = kind.height[0] + rnd() * (kind.height[1] - kind.height[0]);
        const radius = Math.max(0.3, model.width * height * (kind.collide || 0.15));
        if (occupied.some((c) => Math.hypot(c.x - x, c.z - z) < c.r + radius)) continue;
        occupied.push({ x, z, r: radius });
        if (kind.collide > 0) this.colliders.push({ x, z, r: radius });

        const n = normalAt(x, z);
        const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), n.multiplyScalar(kind.tilt ?? 0.15).add(new THREE.Vector3(0, 1, 0)).normalize());
        q.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), rnd() * Math.PI * 2));
        if (kind.tilt) q.multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler((rnd() - 0.5) * kind.tilt, 0, (rnd() - 0.5) * kind.tilt)));
        const s = height * (0.9 + rnd() * 0.2);
        const m = new THREE.Matrix4().compose(
          new THREE.Vector3(x, h - (kind.sink ?? 0.08) * height, z),
          q,
          new THREE.Vector3(s * (0.85 + rnd() * 0.3), s, s * (0.85 + rnd() * 0.3)),
        );
        if (!perFile.has(file)) perFile.set(file, []);
        perFile.get(file)!.push(m);
        placed++;
      }

      // раскладываем по участкам 16×16 м: камера и тени фонаря рисуют только ближние участки
      for (const [file, mats] of perFile) {
        const byChunk = new Map<string, THREE.Matrix4[]>();
        for (const m of mats) {
          const key = Math.floor(m.elements[12] / CHUNK) + ':' + Math.floor(m.elements[14] / CHUNK);
          if (!byChunk.has(key)) byChunk.set(key, []);
          byChunk.get(key)!.push(m);
        }
        for (const list of byChunk.values()) {
          for (const part of loaded.get(file)!.parts) {
            const im = new THREE.InstancedMesh(part.geometry, part.material, list.length);
            list.forEach((m, i) => im.setMatrixAt(i, m));
            im.computeBoundingSphere();
            im.castShadow = castShadows && !!kind.shadow;
            im.receiveShadow = true;
            this.group.add(im);
          }
        }
      }
    }
  }
}
