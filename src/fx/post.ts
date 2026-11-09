import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';

// Пост-обработка: свечение огня (bloom) → тон-маппинг →
// цветокоррекция в сине-янтарную гамму, виньетка, лёгкое зерно.

const GradeShader = {
  uniforms: {
    tDiffuse: { value: null as THREE.Texture | null },
    uTime: { value: 0 },
    uFade: { value: 0 }, // 0 — чёрный экран, 1 — видно
    uRes: { value: new THREE.Vector2(1, 1) },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
  `,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse;
    uniform float uTime, uFade;
    uniform vec2 uRes;
    varying vec2 vUv;
    float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    void main() {
      // тон-маппинг и перевод в sRGB прямо здесь — на один полноэкранный проход меньше
      vec3 c = texture2D(tDiffuse, vUv).rgb;
      c = ACESFilmicToneMapping(c);
      c = sRGBTransferOETF(vec4(c, 1.0)).rgb;
      float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
      // тени уходят в глубокий синий/фиолетовый, светлое — в тёплый янтарь
      vec3 shadowTint = vec3(0.045, 0.05, 0.13);
      vec3 warm = c * vec3(1.08, 0.97, 0.82);
      c = mix(c + shadowTint * (1.0 - smoothstep(0.0, 0.25, l)), warm, smoothstep(0.08, 0.6, l));
      // чуть больше контраста и меньше насыщенности в темноте
      c = mix(vec3(l), c, mix(0.75, 1.1, smoothstep(0.02, 0.4, l)));
      c = pow(max(c, 0.0), vec3(1.05));
      // виньетка
      vec2 q = vUv - 0.5;
      q.x *= uRes.x / uRes.y;
      float vig = 1.0 - smoothstep(0.25, 1.05, length(q));
      c *= mix(0.25, 1.0, vig);
      // плёночное зерно
      float g = hash(vUv * uRes + fract(uTime * 7.13) * 100.0) - 0.5;
      c += g * 0.035 * (1.0 - l * 0.6);
      gl_FragColor = vec4(c * uFade, 1.0);
    }
  `,
};

export class Post {
  readonly composer: EffectComposer;
  private grade: ShaderPass;
  private bloom?: UnrealBloomPass;

  constructor(renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.Camera, useBloom: boolean) {
    this.composer = new EffectComposer(renderer);
    this.composer.addPass(new RenderPass(scene, camera));
    if (useBloom) {
      this.bloom = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.85, 0.65, 0.9);
      this.composer.addPass(this.bloom);
    }
    this.grade = new ShaderPass(GradeShader);
    this.composer.addPass(this.grade);
    this.resize(renderer);
  }

  resize(renderer: THREE.WebGLRenderer): void {
    const pr = renderer.getPixelRatio();
    this.composer.setPixelRatio(pr);
    this.composer.setSize(window.innerWidth, window.innerHeight);
    this.grade.uniforms.uRes.value.set(window.innerWidth * pr, window.innerHeight * pr);
  }

  set fade(v: number) {
    this.grade.uniforms.uFade.value = v;
  }

  render(t: number): void {
    this.grade.uniforms.uTime.value = t;
    this.composer.render();
  }
}
