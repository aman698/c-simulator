#!/usr/bin/env node
/**
 * UI smoke test + README screenshots, driving a headless Chrome/Edge over the
 * DevTools protocol (no extra dependencies; needs Node >= 22 for global WebSocket).
 *
 *   npm run dev            # in another terminal
 *   node scripts/screenshots.js [--url http://localhost:5173] [--out docs/screenshots]
 *
 * Set BROWSER=/path/to/chrome if it is not found automatically.
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ROOT } from '../server/paths.js';

const argv = process.argv.slice(2);
const opt = (k, d) => (argv.includes(k) ? argv[argv.indexOf(k) + 1] : d);
const BASE = opt('--url', 'http://localhost:5173');
const OUT = path.resolve(ROOT, opt('--out', 'docs/screenshots'));
const PORT = 9333;

function findBrowser() {
  if (process.env.BROWSER) return process.env.BROWSER;
  const candidates =
    process.platform === 'win32'
      ? [
          'C:/Program Files/Google/Chrome/Application/chrome.exe',
          'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
          'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
        ]
      : ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/microsoft-edge'];
  return candidates.find((p) => fs.existsSync(p));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class CDP {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(msg.error.message));
        else resolve(msg.result);
      } else if (msg.method) this.listeners.forEach((l) => l(msg));
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }
  async eval(expr) {
    const r = await this.send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || 'eval failed');
    return r.result.value;
  }
  async waitFor(expr, timeoutMs = 20000) {
    const end = Date.now() + timeoutMs;
    while (Date.now() < end) {
      if (await this.eval(`Boolean(${expr})`).catch(() => false)) return true;
      await sleep(200);
    }
    throw new Error(`timeout waiting for: ${expr}`);
  }
  async goto(url, readyExpr) {
    await this.send('Page.navigate', { url });
    await this.waitFor(readyExpr);
    await sleep(600);
  }
  async shot(name) {
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(OUT, name), Buffer.from(data, 'base64'));
    console.log(`  saved ${path.relative(ROOT, path.join(OUT, name))}`);
  }
  clickButton(text) {
    return this.eval(`(() => { const b = [...document.querySelectorAll('button')].find(x => x.textContent.includes(${JSON.stringify(text)}) && !x.disabled); if (!b) return false; b.click(); return true; })()`);
  }
}

const hasText = (t) => `document.body && document.body.innerText.includes(${JSON.stringify(t)})`;

async function main() {
  const exe = findBrowser();
  if (!exe) throw new Error('No Chrome/Edge found; set BROWSER=/path/to/chrome');
  fs.mkdirSync(OUT, { recursive: true });
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'csim-browser-'));
  const browser = spawn(
    exe,
    ['--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', '--disable-gpu', '--hide-scrollbars', '--window-size=1440,900', 'about:blank'],
    { stdio: 'ignore' },
  );
  try {
    let targets = null;
    for (let i = 0; i < 50 && !targets; i++) {
      try {
        targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      } catch {
        await sleep(200);
      }
    }
    const page = targets?.find((t) => t.type === 'page');
    if (!page) throw new Error('browser did not start');
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((r, j) => {
      ws.addEventListener('open', r);
      ws.addEventListener('error', j);
    });
    const c = new CDP(ws);
    await c.send('Page.enable');
    await c.send('Runtime.enable');
    await c.send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });

    const ids = await (await fetch(`${BASE}/api/questions`)).json();
    const pick = (pred, fallback) => (ids.find(pred) || ids[0] || {}).id || fallback;
    const fnQ = pick((q) => q.type === 'FUNCTION' && q.tags.includes('embedded'), 'PTR-M-01');
    const leakQ = pick((q) => q.topic === 'Dynamic Memory' && q.type === 'FIND_THE_BUG', 'MEM-E-01');
    const predQ = pick((q) => q.type === 'PREDICT_OUTPUT', 'STC-E-01');

    console.log('1. problem page');
    await c.goto(`${BASE}/problems/${fnQ}`, `document.querySelector('.monaco-editor .view-lines')`);
    await c.shot('01-problem.png');

    console.log('2. run buggy code (expect Memory Leak verdict)');
    await c.goto(`${BASE}/problems/${leakQ}`, `document.querySelector('.monaco-editor .view-lines')`);
    await c.clickButton('▶ Run');
    await c.waitFor(`${hasText('test cases passed')} || ${hasText('Compile Error')}`, 60000);
    await sleep(400);
    await c.shot('02-memory-leak-verdict.png');

    console.log('3. predict-output question');
    await c.goto(`${BASE}/problems/${predQ}`, `document.querySelector('#predict-answer')`);
    await c.eval(`(() => { const t = document.querySelector('#predict-answer'); const set = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set; set.call(t, '24 16 24'); t.dispatchEvent(new Event('input', { bubbles: true })); })()`);
    await c.clickButton('Submit answer');
    await c.waitFor(`${hasText('Correct answer')} || ${hasText('CORRECT ANSWER')}`, 30000);
    await sleep(300);
    await c.shot('03-predict-output.png');

    console.log('4. playground run');
    await c.goto(`${BASE}/playground`, `document.querySelector('.monaco-editor .view-lines')`);
    await c.clickButton('▶ Run');
    await c.waitFor(hasText('exit code'), 60000);
    await sleep(300);
    await c.shot('04-playground.png');

    console.log('5. dashboard');
    await c.goto(`${BASE}/dashboard`, hasText('By topic'));
    await c.shot('05-dashboard.png');

    console.log('6. interview mode');
    await c.goto(`${BASE}/interview`, hasText('Interview Mode'));
    await c.shot('06-interview.png');
    ws.close();
  } finally {
    browser.kill();
    await sleep(500);
    fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  }
}

main().catch((err) => {
  console.error(`ERROR: ${err.message}`);
  process.exit(1);
});
