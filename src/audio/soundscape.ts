import type { Surface } from '../world/terrain';

// Звуки мира, синтезированные на лету (Web Audio): никаких записей и никакой музыки.
// Во тьме мир почти беззвучен: ветер, треск фитиля, шаги.

export class Soundscape {
  private ctx: AudioContext | null = null;
  private master!: GainNode;
  private noise!: AudioBuffer; // белый шум
  private brown!: AudioBuffer; // «коричневый» шум — низкий гул ветра
  private windGain!: GainNode;
  private windFilter!: BiquadFilterNode;
  private whistleGain!: GainNode;
  private whistleFilter!: BiquadFilterNode;
  private windPan!: StereoPannerNode;
  private hissGain!: GainNode;
  private nextCrackle = 0;
  private t = 0;

  /** Запуск — только после жеста пользователя (требование браузеров). */
  start(): void {
    if (this.ctx) return;
    const ctx = new AudioContext();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.master.gain.value = 0;
    this.master.gain.linearRampToValueAtTime(0.9, ctx.currentTime + 4);
    const comp = ctx.createDynamicsCompressor();
    this.master.connect(comp).connect(ctx.destination);

    this.noise = this.makeNoise(2, false);
    this.brown = this.makeNoise(4, true);

    // ── ветер: низкий гул + тихий посвист ──
    this.windPan = ctx.createStereoPanner();
    this.windPan.connect(this.master);
    this.windGain = ctx.createGain();
    this.windGain.gain.value = 0.25;
    this.windFilter = ctx.createBiquadFilter();
    this.windFilter.type = 'bandpass';
    this.windFilter.frequency.value = 400;
    this.windFilter.Q.value = 0.6;
    this.loop(this.brown).connect(this.windFilter).connect(this.windGain).connect(this.windPan);

    this.whistleGain = ctx.createGain();
    this.whistleGain.gain.value = 0;
    this.whistleFilter = ctx.createBiquadFilter();
    this.whistleFilter.type = 'bandpass';
    this.whistleFilter.frequency.value = 1100;
    this.whistleFilter.Q.value = 9;
    this.loop(this.noise).connect(this.whistleFilter).connect(this.whistleGain).connect(this.windPan);

    // ── фитиль: еле слышное шипение ──
    this.hissGain = ctx.createGain();
    this.hissGain.gain.value = 0.004;
    const hp = ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 3500;
    this.loop(this.noise).connect(hp).connect(this.hissGain).connect(this.master);

    document.addEventListener('visibilitychange', () => {
      if (document.hidden) ctx.suspend();
      else ctx.resume();
    });
  }

  private makeNoise(seconds: number, brown: boolean): AudioBuffer {
    const ctx = this.ctx!;
    const len = Math.floor(ctx.sampleRate * seconds);
    const buf = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      let last = 0;
      for (let i = 0; i < len; i++) {
        const w = Math.random() * 2 - 1;
        if (brown) {
          last = (last + 0.02 * w) / 1.02;
          d[i] = last * 3.5;
        } else d[i] = w;
      }
      // плавно сводим конец с началом, чтобы петля не щёлкала
      const fade = Math.floor(ctx.sampleRate * 0.05);
      for (let i = 0; i < fade; i++) {
        const k = i / fade;
        d[len - fade + i] = d[len - fade + i] * (1 - k) + d[i] * k;
      }
    }
    return buf;
  }

  private loop(buf: AudioBuffer): AudioBufferSourceNode {
    const s = this.ctx!.createBufferSource();
    s.buffer = buf;
    s.loop = true;
    s.loopStart = Math.random() * buf.duration * 0.5;
    s.start(0, Math.random() * buf.duration);
    return s;
  }

  /** Каждый кадр: порывы ветра и случайный треск фитиля. */
  update(dt: number): void {
    const ctx = this.ctx;
    if (!ctx) return;
    this.t += dt;
    const t = this.t;
    const now = ctx.currentTime;
    const gust = 0.5 + 0.5 * Math.sin(t * 0.11) * Math.sin(t * 0.047 + 1.3);
    const g2 = Math.max(0, Math.sin(t * 0.07 + 2) * Math.sin(t * 0.19));
    this.windGain.gain.setTargetAtTime(0.12 + gust * 0.32, now, 0.5);
    this.windFilter.frequency.setTargetAtTime(260 + gust * 520, now, 0.6);
    this.whistleGain.gain.setTargetAtTime(g2 * g2 * 0.012, now, 0.8);
    this.whistleFilter.frequency.setTargetAtTime(900 + g2 * 700 + Math.sin(t * 0.5) * 80, now, 0.4);
    this.windPan.pan.setTargetAtTime(Math.sin(t * 0.05) * 0.6, now, 1);

    if (t > this.nextCrackle) {
      this.crackle();
      // иногда — серия щелчков подряд
      this.nextCrackle = t + (Math.random() < 0.25 ? 0.05 + Math.random() * 0.12 : 0.4 + Math.random() * 2.2);
    }
  }

  private burst(opts: {
    when?: number; dur: number; type: BiquadFilterType; freq: number; q?: number;
    gain: number; attack?: number; pan?: number; sweepTo?: number;
  }): void {
    const ctx = this.ctx!;
    const t0 = opts.when ?? ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const f = ctx.createBiquadFilter();
    f.type = opts.type;
    f.frequency.setValueAtTime(opts.freq, t0);
    if (opts.sweepTo) f.frequency.exponentialRampToValueAtTime(opts.sweepTo, t0 + opts.dur);
    f.Q.value = opts.q ?? 1;
    const g = ctx.createGain();
    const a = opts.attack ?? 0.002;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(opts.gain, t0 + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + a + opts.dur);
    const p = ctx.createStereoPanner();
    p.pan.value = opts.pan ?? 0;
    src.connect(f).connect(g).connect(p).connect(this.master);
    src.start(t0, Math.random() * (this.noise.duration - 0.5));
    src.stop(t0 + a + opts.dur + 0.05);
  }

  private crackle(): void {
    this.burst({ dur: 0.008 + Math.random() * 0.02, type: 'bandpass', freq: 1800 + Math.random() * 3000, q: 1.5, gain: 0.025 + Math.random() * 0.04, pan: 0.15 });
  }

  /** Шаг по поверхности. */
  step(surface: Surface): void {
    if (!this.ctx) return;
    const v = 0.85 + Math.random() * 0.3;
    const pan = (Math.random() - 0.5) * 0.15;
    switch (surface) {
      case 'grass': // шорох травы
        this.burst({ dur: 0.14 * v, type: 'bandpass', freq: 3200 * v, q: 0.7, gain: 0.05, attack: 0.025, pan });
        this.burst({ dur: 0.05, type: 'lowpass', freq: 500, gain: 0.05, attack: 0.005, pan });
        break;
      case 'dirt': // мягкий глухой шаг + хруст
        this.burst({ dur: 0.08 * v, type: 'lowpass', freq: 380 * v, q: 0.8, gain: 0.16, attack: 0.004, pan });
        this.burst({ dur: 0.06, type: 'bandpass', freq: 1700 * v, q: 1.2, gain: 0.03, attack: 0.01, pan });
        break;
      case 'rock': // твёрдый короткий щелчок
        this.burst({ dur: 0.03 * v, type: 'bandpass', freq: 2400 * v, q: 2.5, gain: 0.07, pan });
        this.burst({ dur: 0.05, type: 'lowpass', freq: 260, gain: 0.12, pan });
        break;
      case 'water': // плеск на мелководье
        this.burst({ dur: 0.22 * v, type: 'bandpass', freq: 600, sweepTo: 2200, q: 1.5, gain: 0.08, attack: 0.02, pan });
        this.burst({ dur: 0.12, type: 'lowpass', freq: 300, gain: 0.08, attack: 0.01, pan });
        break;
    }
  }
}
