// Замер реальной скорости (без ограничения 60 fps): node scripts/bench.mjs <url> [ширина] [высота] [dpr]
import puppeteer from 'puppeteer-core';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const [url, w = 1440, h = 900, dpr = 2] = process.argv.slice(2);
const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: 'new',
  args: ['--use-angle=metal', '--disable-gpu-vsync', '--disable-frame-rate-limit', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage();
await page.setViewport({ width: +w, height: +h, deviceScaleFactor: +dpr });
page.on('pageerror', (e) => console.log('ERR', e.message));
await page.goto(url, { waitUntil: 'load', timeout: 120000 });
await page.waitForSelector('.title.ready', { timeout: 120000 });
await page.mouse.click(+w / 2, +h / 2);
await sleep(8000);
const fps = await page.evaluate(() => new Promise((res) => {
  let n = 0; const t0 = performance.now();
  const f = () => { n++; if (performance.now() - t0 < 4000) requestAnimationFrame(f); else res(n / ((performance.now() - t0) / 1000)); };
  requestAnimationFrame(f);
}));
const pr = await page.evaluate(() => document.querySelector('canvas').width / window.innerWidth);
console.log(fps.toFixed(1).padStart(6), 'fps ', `${w}x${h}@${dpr}`, 'render scale', pr.toFixed(2), url.split('?')[1] ?? '');
await browser.close();
