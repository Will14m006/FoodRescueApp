// P8 screenshot harness: jalankan build web lalu ambil screenshot lewat
// Chrome headless (CDP). Bukan bagian aplikasi, hanya alat bantu dokumentasi.
//
// Pakai: node tool/p8_screenshots.mjs
import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import http from 'node:http';
import path from 'node:path';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const ROOT = path.resolve('build/web');
const OUT = path.resolve('../docs/screenshots');
const PORT = 8099;
const CDP_PORT = 9333;

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.css': 'text/css', '.png': 'image/png', '.wasm': 'application/wasm',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml', '.map': 'application/json',
};

const server = http.createServer(async (req, res) => {
  const urlPath = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(ROOT, urlPath === '/' ? 'index.html' : urlPath);
  if (!existsSync(file)) { res.writeHead(404); res.end('404'); return; }
  const { readFile } = await import('node:fs/promises');
  const body = await readFile(file);
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
  res.end(body);
});

await new Promise((r) => server.listen(PORT, r));
await mkdir(OUT, { recursive: true });

const chrome = spawn(CHROME, [
  '--headless=new',
  `--remote-debugging-port=${CDP_PORT}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-gpu',
  '--hide-scrollbars',
  `--user-data-dir=${path.resolve('.chrome-p8')}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getWsUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${CDP_PORT}/json/version`);
      const json = await res.json();
      if (json.webSocketDebuggerUrl) return json.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('Chrome CDP tidak siap');
}

const wsUrl = await getWsUrl();
const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));

let msgId = 0;
const pending = new Map();
const events = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else if (msg.method) {
    events.push(msg);
  }
});

function send(method, params = {}, sessionId) {
  const id = ++msgId;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });
}

const { result: { targetId } } = await send('Target.createTarget', { url: 'about:blank' });
const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });

const call = (method, params) => send(method, params, sessionId);
await call('Page.enable');
await call('Runtime.enable');

async function setViewport(width, height) {
  await call('Emulation.setDeviceMetricsOverride', {
    width, height, deviceScaleFactor: 1, mobile: width < 600,
  });
}

async function shot(name) {
  const res = await call('Page.captureScreenshot', { format: 'png' });
  await writeFile(path.join(OUT, name), Buffer.from(res.result.data, 'base64'));
  console.log('saved', name);
}

async function goto(url) {
  await call('Page.navigate', { url });
  await sleep(6000);
}

async function tapText(text) {
  // Flutter web canvas: klik berdasarkan posisi teks tidak mungkin;
  // pakai koordinat dari accessibility tree.
  const res = await call('Runtime.evaluate', {
    expression: `(() => {
      const nodes = [...document.querySelectorAll('flt-semantics')];
      const hit = nodes.find(n => (n.getAttribute('aria-label')||n.textContent||'').includes(${JSON.stringify(text)}));
      if (!hit) return null;
      const r = hit.getBoundingClientRect();
      return { x: r.x + r.width/2, y: r.y + r.height/2, label: hit.getAttribute('aria-label') };
    })()`,
    returnByValue: true,
  });
  const val = res.result?.result?.value;
  if (!val) throw new Error(`Tidak menemukan elemen: ${text}`);
  for (const type of ['mousePressed', 'mouseReleased']) {
    await call('Input.dispatchMouseEvent', {
      type, x: val.x, y: val.y, button: 'left', clickCount: 1,
    });
  }
  await sleep(1200);
  return val;
}

async function tapXY(x, y) {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await call('Input.dispatchMouseEvent', {
      type, x, y, button: 'left', clickCount: 1,
    });
  }
  await sleep(1200);
}

await goto(`http://localhost:${PORT}/`);
await sleep(3000);

// 1. Login — layar kecil (mobile)
await setViewport(412, 892);
await sleep(1500);
await shot('p8_01_login_mobile.png');

// 2. Keyboard-safe: fokus field password, lalu viewport menyusut
//    (mensimulasikan keyboard naik). Flutter otomatis scroll field ke atas.
await tapXY(206, 465);
await setViewport(412, 500);
await sleep(1800);
await shot('p8_02_keyboard_safe.png');

// 3. Dashboard layar kecil (1 kolom)
await setViewport(412, 892);
await sleep(800);
await tapXY(206, 523); // tombol Masuk
await sleep(5000);
await shot('p8_03_dashboard_mobile.png');

// 4. Dashboard layar besar (adaptif, 2+ kolom)
await setViewport(1440, 900);
await sleep(2500);
await shot('p8_04_dashboard_desktop.png');

// 5. Profil — umpan balik aksi pada menu yang belum ada layarnya
await setViewport(412, 892);
await sleep(1200);
await tapXY(374, 41); // ikon profil di header
await sleep(2500);
await shot('p8_05_profile_mobile.png');

// 6. Snackbar feedback saat menekan menu "Bantuan"
await tapXY(206, 767);
await sleep(700);
await shot('p8_06_feedback_snackbar.png');

chrome.kill();
server.close();
process.exit(0);
