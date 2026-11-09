// Заставка с названием. Нужна ещё и потому, что браузер разрешает
// звук только после нажатия/тапа.

export function showTitle(onStart: () => void): { setReady: () => void } {
  const style = document.createElement('style');
  style.textContent = `
    @import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;1,400&display=swap');
    .title { position: fixed; inset: 0; z-index: 30; display: flex; flex-direction: column;
      align-items: center; justify-content: center; gap: 18px; color: #f3d7a6; cursor: pointer;
      background: radial-gradient(ellipse at 50% 55%, rgba(40,28,20,0.35), rgba(5,6,16,0.97) 70%);
      font-family: 'Cormorant Garamond', Georgia, serif; transition: opacity 2.2s ease; user-select: none;
      -webkit-tap-highlight-color: transparent; padding: 0 16px; text-align: center; }
    .title h1 { margin: 0; font-weight: 500; font-size: clamp(34px, 7vw, 72px); letter-spacing: 0.04em;
      text-shadow: 0 0 24px rgba(255,160,70,0.35); }
    .title p { margin: 0; font-style: italic; font-size: clamp(16px, 2.4vw, 22px); opacity: 0.7; }
    .title .hint { margin-top: 28px; font-size: clamp(14px, 2vw, 18px); opacity: 0;
      animation: breathe 3.5s ease-in-out infinite; }
    .title.ready .hint { opacity: 1; }
    .title .controls { position: absolute; bottom: 24px; font-size: 14px; opacity: 0.45; font-style: normal; }
    @keyframes breathe { 0%,100% { opacity: 0.35 } 50% { opacity: 0.9 } }
  `;
  document.head.appendChild(style);

  const touch = window.matchMedia('(pointer: coarse)').matches;
  const el = document.createElement('div');
  el.className = 'title';
  el.innerHTML = `
    <h1>Последний фонарщик</h1>
    <p>Небо закрыла Пелена. Остался один фонарь.</p>
    <div class="hint">${touch ? 'Коснитесь, чтобы начать' : 'Нажмите, чтобы начать'}</div>
    <div class="controls">${touch ? 'Тап по земле — идти' : 'WASD — идти · клик по земле — идти туда · F — fps'}</div>
  `;
  document.body.appendChild(el);

  let ready = false;
  let started = false;
  const start = () => {
    if (!ready || started) return;
    started = true;
    el.style.opacity = '0';
    el.style.pointerEvents = 'none';
    setTimeout(() => el.remove(), 2500);
    onStart();
  };
  el.addEventListener('pointerup', start);
  window.addEventListener('keydown', start);

  return {
    setReady: () => {
      ready = true;
      el.classList.add('ready');
    },
  };
}
