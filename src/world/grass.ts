import * as THREE from 'three';
import { mulberry32 } from '../core/noise';
import { heightAt, surfaceWeights, WATER_LEVEL, ISLAND_RADIUS } from './terrain';

// Тысячи травинок (InstancedMesh), разбитых на квадраты-чанки,
// чтобы рисовалось только то, что видит камера. Ветер и
// «расступание» вокруг героя — в вершинном шейдере.

const CHUNK = 10;

function bladeGeometry(): THREE.BufferGeometry {
  // сужающаяся травинка из 3 сегментов, слегка изогнутая
  const segs = 3;
  const pos: number[] = [];
  const col: number[] = [];
  const idx: number[] = [];
  for (let i = 0; i <= segs; i++) {
    const t = i / segs;
    const w = 0.042 * (1 - t * 0.9);
    const bend = t * t * 0.12;
    if (i < segs) {
      pos.push(-w, t, bend, w, t, bend);
    } else {
      pos.push(0, t, bend);
    }
    const c = 0.5 + t * 0.5; // темнее у корня — имитация затенения
    for (let k = 0; k < (i < segs ? 2 : 1); k++) col.push(c, c, c);
  }
  for (let i = 0; i < segs - 1; i++) {
    const a = i * 2;
    idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
  }
  const last = (segs - 1) * 2;
  idx.push(last, last + 1, last + 2);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  // все нормали вверх — трава освещается мягко, как «газон», без чёрных боков
  const nrm = new Float32Array(pos.length);
  for (let i = 0; i < nrm.length; i += 3) nrm[i + 1] = 1;
  g.setAttribute('normal', new THREE.BufferAttribute(nrm, 3));
  g.setIndex(idx);
  return g;
}

export class Grass {
  readonly group = new THREE.Group();
  readonly uniforms = {
    uTime: { value: 0 },
    uPlayer: { value: new THREE.Vector3() },
  };

  constructor(perSquareMeter: number) {
    const geo = bladeGeometry();
    const mat = new THREE.MeshStandardMaterial({
      vertexColors: true,
      side: THREE.DoubleSide,
      roughness: 0.9,
    });
    mat.onBeforeCompile = (shader) => {
      shader.uniforms.uTime = this.uniforms.uTime;
      shader.uniforms.uPlayer = this.uniforms.uPlayer;
      // обе стороны травинки освещаются одинаково (не переворачиваем нормаль у «изнанки»)
      shader.fragmentShader = shader.fragmentShader.replace(
        '#include <normal_fragment_begin>',
        '#include <normal_fragment_begin>\nnormal = normalize( vNormal );\nnonPerturbedNormal = normal;',
      );
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nuniform float uTime;\nuniform vec3 uPlayer;')
        .replace(
          '#include <project_vertex>',
          /* glsl */ `
          vec4 mvPosition = vec4( transformed, 1.0 );
          #ifdef USE_INSTANCING
            mvPosition = instanceMatrix * mvPosition;
          #endif
          float k = position.y * position.y;                // гнётся верхушка, корень на месте
          vec2 wp = mvPosition.xz;
          float gust = sin(uTime * 0.35 + wp.x * 0.05 + wp.y * 0.03) * 0.5 + 0.5; // медленные порывы
          float w = sin(uTime * 1.6 + wp.x * 0.45 + wp.y * 0.25) * 0.6
                  + sin(uTime * 2.7 + wp.x * 0.9 - wp.y * 0.7) * 0.25;
          vec2 windDir = normalize(vec2(1.0, 0.35));
          mvPosition.xz += windDir * (w * (0.06 + gust * 0.14) + gust * 0.12) * k;
          // трава расступается вокруг героя
          vec2 d = wp - uPlayer.xz;
          float dist = length(d);
          float push = (1.0 - smoothstep(0.15, 0.85, dist)) * k;
          mvPosition.xz += (d / max(dist, 0.001)) * push * 0.35;
          mvPosition.y -= push * 0.25;
          mvPosition = modelViewMatrix * mvPosition;
          gl_Position = projectionMatrix * mvPosition;
          `,
        );
    };

    const rnd = mulberry32(99);
    const dummy = new THREE.Object3D();
    const color = new THREE.Color();
    const half = ISLAND_RADIUS + 6;
    for (let cx = -half; cx < half; cx += CHUNK) {
      for (let cz = -half; cz < half; cz += CHUNK) {
        const want = Math.floor(CHUNK * CHUNK * perSquareMeter);
        const mats: THREE.Matrix4[] = [];
        const cols: THREE.Color[] = [];
        for (let i = 0; i < want; i++) {
          const x = cx + rnd() * CHUNK;
          const z = cz + rnd() * CHUNK;
          const h = heightAt(x, z);
          if (h < WATER_LEVEL + 0.25) continue;
          const g = surfaceWeights(x, z)[0];
          if (rnd() > g * g * 1.1) continue; // трава только там, где «травяная» текстура
          dummy.position.set(x, h - 0.02, z);
          dummy.rotation.set((rnd() - 0.5) * 0.25, rnd() * Math.PI * 2, (rnd() - 0.5) * 0.25);
          const s = 0.18 + rnd() * 0.28 * (0.6 + g * 0.6);
          dummy.scale.set(0.8 + rnd() * 0.6, s, 1);
          dummy.updateMatrix();
          mats.push(dummy.matrix.clone());
          // оттенки: от сухой оливковой до сочной зелени
          color.setHSL(0.19 + rnd() * 0.09, 0.3 + rnd() * 0.25, 0.2 + rnd() * 0.14);
          cols.push(color.clone());
        }
        if (!mats.length) continue;
        const mesh = new THREE.InstancedMesh(geo, mat, mats.length);
        mats.forEach((m, i) => {
          mesh.setMatrixAt(i, m);
          mesh.setColorAt(i, cols[i]);
        });
        mesh.computeBoundingSphere();
        mesh.receiveShadow = true;
        mesh.castShadow = false;
        this.group.add(mesh);
      }
    }
  }

  update(t: number, player: THREE.Vector3): void {
    this.uniforms.uTime.value = t;
    this.uniforms.uPlayer.value.copy(player);
  }
}
