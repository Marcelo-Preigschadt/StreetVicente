/* Black-box QA do export WASM. Sem hooks na simulação e sem dependências em produção. */
const { chromium } = require('playwright');
const { PNG } = require('pngjs');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');

const root = path.resolve(__dirname, '..');
process.chdir(root);
fs.mkdirSync('test-results', { recursive: true });
if (!fs.existsSync('build/StreetVicente')) fs.symlinkSync('web', 'build/StreetVicente');
const server = spawn('python3', ['-m', 'http.server', '8061', '--directory', 'build', '--bind', '127.0.0.1']);
let browser;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const mint = (r,g,b) => g > 155 && b > 115 && r < 145 && g > r * 1.4;
const gold = (r,g,b) => r > 170 && g > 90 && g < 220 && b < 135;
function pixels(buffer, predicate, box) {
  const png = PNG.sync.read(buffer);
  let count = 0, sx = 0, sy = 0;
  for (let y = box.y; y < Math.min(box.y + box.h, png.height); y++) {
    for (let x = box.x; x < Math.min(box.x + box.w, png.width); x++) {
      const i = (y * png.width + x) * 4;
      if (predicate(png.data[i], png.data[i+1], png.data[i+2])) { count++; sx += x; sy += y; }
    }
  }
  return { count, x: sx / Math.max(count, 1), y: sy / Math.max(count, 1) };
}
const fighterBox = {x: 70, y: 200, w: 1140, h: 385};
const healthBox = {x: 704, y: 78, w: 540, h: 14};

(async () => {
  for (let attempt = 0; attempt < 40; attempt++) {
    try { if ((await fetch('http://127.0.0.1:8061/StreetVicente/')).ok) break; } catch {}
    await delay(100);
  }
  browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: {width: 1280, height: 720} });
  const errors = [];
  const responses = {};
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/SCRIPT ERROR|Parse Error|Failed to load script|ERROR:/i.test(message.text())) errors.push(message.text());
  });
  page.on('response', response => {
    if (/index\.(wasm|pck)$/.test(response.url())) responses[response.url().split('/').pop()] = response.status();
  });
  await page.goto('http://127.0.0.1:8061/StreetVicente/', { waitUntil: 'load' });
  await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 60000 });
  await page.locator('canvas').click({ position: {x: 640, y: 450} });
  await page.keyboard.press('r');
  await delay(250);
  let image = await page.screenshot({path: 'test-results/01-ready.png'});
  const initial = pixels(image, mint, fighterBox);
  assert(initial.count > 500, 'P1 deve estar renderizado');
  assert(pixels(image, gold, fighterBox).count > 500, 'P2 deve estar renderizado');
  assert.equal(responses['index.wasm'], 200);
  assert.equal(responses['index.pck'], 200);
  await page.keyboard.down('d');
  await delay(450);
  await page.keyboard.up('d');
  await delay(80);
  image = await page.screenshot();
  const moved = pixels(image, mint, fighterBox);
  assert(moved.x > initial.x + 70, 'P1 deve mover-se por input real no WASM');
  await page.keyboard.press('w');
  await delay(220);
  image = await page.screenshot({path: 'test-results/02-jump.png'});
  const jumping = pixels(image, mint, fighterBox);
  assert(jumping.y < moved.y - 65, 'Pulo deve elevar o lutador');
  await delay(650);
  await page.keyboard.press('r');
  await delay(100);
  // Aproximar até alcance de soco; tolera variações de velocidade de CI.
  await page.keyboard.down('d');
  for (let i = 0; i < 12; i++) {
    await delay(120);
    image = await page.screenshot();
    if (pixels(image, gold, fighterBox).x - pixels(image, mint, fighterBox).x < 120) break;
  }
  await page.keyboard.up('d');
  await delay(80);
  const before = pixels(await page.screenshot(), gold, healthBox).count;
  await page.keyboard.down('f');
  await delay(60);
  await page.keyboard.up('f');
  await delay(150);
  image = await page.screenshot({path: 'test-results/03-hit.png'});
  const after = pixels(image, gold, healthBox).count;
  assert(after < before - 100, 'Soco deve retirar HP de P2 no navegador');
  await page.keyboard.press('Escape');
  await delay(100);
  const pauseA = await page.screenshot({clip: {x:590,y:40,width:100,height:60}});
  await delay(300);
  const pauseB = await page.screenshot({clip: {x:590,y:40,width:100,height:60}});
  assert(pauseA.equals(pauseB), 'Timer deve permanecer parado na pausa');
  await page.setViewportSize({width:960,height:540});
  await delay(150);
  await page.screenshot({path: 'test-results/04-resize.png'});
  assert.deepEqual(errors, [], 'Sem erros GDScript/JavaScript no export Web');
  fs.writeFileSync('test-results/web-smoke.json', JSON.stringify({
    status:'passed', checks:['WASM/PCK no subdiretório', 'dois lutadores renderizados', 'movimento', 'salto', 'ataque com dano', 'pausa', 'resize', 'console sem erros'],
    initialP1:initial, movedP1:moved, jumpingP1:jumping, p2HealthPixels:{before,after}, responses
  }, null, 2));
  console.log('WEB SMOKE PASSED: WASM + movimento + pulo + ataque/dano + pausa + resize');
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => {
  if (browser) await browser.close();
  server.kill();
});
