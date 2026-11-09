// Проверка игры: открывает её в Chrome, стартует, ходит, сохраняет скриншоты, выводит ошибки консоли.
// Запуск: node scripts/shot.mjs [url] [outDir] [width] [height]
import puppeteer from 'puppeteer-core';

const url = process.argv[2] ?? 'http://localhost:5173/?fps';
const out = process.argv[3] ?? '.';
const w = +(process.argv[4] ?? 1280);
const h = +(process.argv[5] ?? 800);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: 'new',
  args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage();
await page.setViewport({ width: w, height: h, isMobile: w < 600, hasTouch: w < 600 });
const errors = [];
page.on('console', (m) => { if (['error', 'warning'].includes(m.type())) errors.push(`[${m.type()}] ${m.text()}`); });
page.on('response', (r) => { if (r.status() >= 400) errors.push('[http ' + r.status() + '] ' + r.url()); });
page.on('pageerror', (e) => errors.push('[pageerror] ' + e.message));
await page.goto(url, { waitUntil: 'networkidle0', timeout: 60000 });
await page.waitForSelector('.title.ready', { timeout: 60000 });
await page.screenshot({ path: `${out}/0-title.png` });
await page.mouse.click(w / 2, h / 2);
await sleep(3500);
await page.screenshot({ path: `${out}/1-start.png` });
await page.keyboard.down('KeyW'); await page.keyboard.down('KeyD');
await sleep(2500);
await page.keyboard.up('KeyD');
await sleep(1500);
await page.keyboard.up('KeyW');
await page.screenshot({ path: `${out}/2-walk.png` });
await sleep(1200);
await page.keyboard.press('KeyF');
await sleep(1200);
await page.screenshot({ path: `${out}/3-fps.png` });
console.log(errors.length ? errors.join('\n') : 'no console errors');
await browser.close();
