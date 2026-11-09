// Настройки качества: low / medium / high.
// Выбираются автоматически (телефон → medium), можно переопределить: ?q=low | ?q=medium | ?q=high

export type QualityLevel = 'low' | 'medium' | 'high';

export interface QualitySettings {
  level: QualityLevel;
  pixelRatio: number;
  shadows: boolean;
  shadowMapSize: number;
  grassPerSquareMeter: number;
  bloom: boolean;
  fireflies: number;
  dust: number;
}

export const isTouchDevice = (): boolean =>
  window.matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window;

function pickLevel(): QualityLevel {
  const q = new URLSearchParams(location.search).get('q');
  if (q === 'low' || q === 'medium' || q === 'high') return q;
  try {
    const saved = localStorage.getItem('lamplighter.quality');
    if (saved === 'low' || saved === 'medium' || saved === 'high') return saved;
  } catch {
    /* localStorage недоступен — не страшно */
  }
  return isTouchDevice() ? 'medium' : 'high';
}

const PRESETS: Record<QualityLevel, Omit<QualitySettings, 'level'>> = {
  low: { pixelRatio: 1, shadows: false, shadowMapSize: 256, grassPerSquareMeter: 8, bloom: true, fireflies: 40, dust: 60 },
  medium: { pixelRatio: 1.5, shadows: true, shadowMapSize: 512, grassPerSquareMeter: 24, bloom: true, fireflies: 70, dust: 120 },
  high: { pixelRatio: 2, shadows: true, shadowMapSize: 1024, grassPerSquareMeter: 55, bloom: true, fireflies: 110, dust: 200 },
};

const level = pickLevel();
export const quality: QualitySettings = {
  level,
  ...PRESETS[level],
  pixelRatio: Math.min(window.devicePixelRatio, PRESETS[level].pixelRatio),
};
