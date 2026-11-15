/**
 * Toolchain discovery + capability probing.
 *
 * Execution modes (env JUDGE_MODE = auto | docker | native, default auto):
 *   docker : every submission runs in `gcc:latest` with --network none --memory=128m
 *   native : the host gcc (Linux / WSL recommended; MinGW gcc on Windows supported)
 * auto picks docker when the daemon is reachable and the image is present
 * (it starts a background `docker pull` otherwise and uses native meanwhile).
 */
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { ROOT } from '../paths.js';

export const IS_WIN = process.platform === 'win32';
export const DOCKER_IMAGE = process.env.JUDGE_DOCKER_IMAGE || 'gcc:latest';

function which(cmd) {
  const r = spawnSync(IS_WIN ? 'where' : 'which', [cmd], { encoding: 'utf8' });
  if (r.status !== 0) return null;
  const first = r.stdout.split(/\r?\n/).map((s) => s.trim()).find(Boolean);
  return first || null;
}

function resolveCompiler() {
  if (process.env.CC) return process.env.CC;
  const onPath = which('gcc');
  if (onPath) return onPath;
  if (IS_WIN) {
    const local = path.join(ROOT, '.toolchain', 'msys64', 'ucrt64', 'bin', 'gcc.exe');
    if (fs.existsSync(local)) return local;
  }
  return null;
}

/** Environment for spawning the compiler / compiled programs (DLL search path on Windows). */
export function toolEnv(cc, extra = {}) {
  const env = { ...process.env, ...extra };
  if (cc && path.isAbsolute(cc)) {
    const key = Object.keys(env).find((k) => k.toLowerCase() === 'path') || 'PATH';
    env[key] = path.dirname(cc) + path.delimiter + (env[key] || '');
  }
  return env;
}

export function runCapture(cmd, args, { cwd, env, input, timeoutMs = 20000 } = {}) {
  return new Promise((resolve) => {
    let stdout = '';
    let stderr = '';
    let timedOut = false;
    let child;
    try {
      child = spawn(cmd, args, { cwd, env, windowsHide: true });
    } catch (err) {
      resolve({ code: -1, signal: null, stdout: '', stderr: String(err), timedOut: false, error: err });
      return;
    }
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGKILL');
    }, timeoutMs);
    child.stdout.on('data', (d) => (stdout += d));
    child.stderr.on('data', (d) => (stderr += d));
    child.on('error', (err) => {
      clearTimeout(timer);
      resolve({ code: -1, signal: null, stdout, stderr: stderr + String(err), timedOut, error: err });
    });
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      resolve({ code, signal, stdout, stderr, timedOut });
    });
    child.stdin.on('error', () => {});
    child.stdin.end(input ?? '');
  });
}

const PROBE_OK = '#include <stdio.h>\nint main(void){ puts("ok"); return 0; }\n';
const PROBE_LEAK =
  '#include <stdlib.h>\n#include <stdio.h>\nint main(void){ char *volatile p = malloc(37); p[0]=1; p = 0; puts("ok"); return 0; }\n';

async function probeFlags(runner, flags, source, check) {
  const res = await runner(flags, source);
  if (!res.compiled) return false;
  return check ? check(res) : res.run.code === 0 && res.run.stdout.includes('ok');
}

/** Run probes with a given "compile+run" runner and return a support map. */
export async function probeSupport(runner) {
  const support = {};
  support.asan = await probeFlags(runner, ['-fsanitize=address'], PROBE_OK);
  support.ubsan = await probeFlags(runner, ['-fsanitize=undefined'], PROBE_OK);
  support.lsan = support.asan
    ? await probeFlags(runner, ['-fsanitize=address'], PROBE_LEAK, (r) => /LeakSanitizer/.test(r.run.stderr))
    : false;
  support.lsanStandalone = await probeFlags(runner, ['-fsanitize=leak'], PROBE_LEAK, (r) =>
    /LeakSanitizer/.test(r.run.stderr),
  );
  support.ubsanTrap = support.ubsan
    ? false
    : await probeFlags(runner, ['-fsanitize=undefined', '-fsanitize-undefined-trap-on-error'], PROBE_OK);
  support.stackProtector = await probeFlags(runner, ['-fstack-protector-strong'], PROBE_OK);
  return support;
}

function nativeRunner(cc, exeName, isMinGW) {
  return async (flags, source) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'csim-probe-'));
    try {
      fs.writeFileSync(path.join(dir, 'main.c'), source);
      const extra = isMinGW ? ['-mno-ms-bitfields'] : [];
      const c = await runCapture(cc, ['-std=c11', '-g', ...extra, ...flags, '-o', exeName, 'main.c'], {
        cwd: dir,
        env: toolEnv(cc),
      });
      if (c.code !== 0) return { compiled: false, compile: c };
      const run = await runCapture(path.join(dir, exeName), [], {
        cwd: dir,
        // Windows ASan aborts with "detect_leaks is not supported on this platform"
        env: toolEnv(cc, { ASAN_OPTIONS: IS_WIN ? '' : 'detect_leaks=1', LSAN_OPTIONS: 'exitcode=23' }),
        timeoutMs: 15000,
      });
      return { compiled: true, run };
    } finally {
      fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    }
  };
}

function dockerRunner() {
  return async (flags, source) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'csim-probe-'));
    try {
      fs.writeFileSync(path.join(dir, 'main.c'), source);
      const script = `gcc -std=c11 -g ${flags.join(' ')} -o prog main.c > compile.txt 2>&1 || { echo COMPILE_FAIL; exit 0; }
ASAN_OPTIONS=detect_leaks=1 LSAN_OPTIONS=exitcode=23 ./prog; echo "RC=$?"`;
      fs.writeFileSync(path.join(dir, 'probe.sh'), script);
      const r = await runCapture(
        'docker',
        ['run', '--rm', '--network', 'none', '--cap-add', 'SYS_PTRACE', '-v', `${dir}:/work`, '-w', '/work', DOCKER_IMAGE, 'sh', 'probe.sh'],
        { timeoutMs: 120000 },
      );
      if (r.stdout.includes('COMPILE_FAIL') || r.code !== 0) return { compiled: false, compile: r };
      const m = /RC=(\d+)/.exec(r.stdout);
      return {
        compiled: true,
        run: { code: m ? Number(m[1]) : -1, stdout: r.stdout.replace(/RC=\d+\s*$/, ''), stderr: r.stderr },
      };
    } finally {
      fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
    }
  };
}

async function dockerAvailable() {
  const info = await runCapture('docker', ['info', '--format', '{{.ServerVersion}}'], { timeoutMs: 8000 });
  if (info.code !== 0) return { daemon: false, image: false };
  const img = await runCapture('docker', ['image', 'inspect', DOCKER_IMAGE], { timeoutMs: 8000 });
  return { daemon: true, image: img.code === 0 };
}

let cached = null;
let pulling = null;

async function detectNative() {
  const cc = resolveCompiler();
  if (!cc) return null;
  const ver = await runCapture(cc, ['--version'], { env: toolEnv(cc) });
  if (ver.code !== 0) return null;
  const machine = (await runCapture(cc, ['-dumpmachine'], { env: toolEnv(cc) })).stdout.trim();
  const isMinGW = /mingw|windows/i.test(machine);
  const exeName = IS_WIN ? 'prog.exe' : 'prog';
  const support = await probeSupport(nativeRunner(cc, exeName, isMinGW));
  return {
    mode: 'native',
    cc,
    ccName: path.basename(cc).replace(/\.exe$/i, ''),
    version: ver.stdout.split(/\r?\n/)[0],
    machine,
    isMinGW,
    exeName,
    platform: process.platform,
    support,
  };
}

async function detectDocker() {
  const support = await probeSupport(dockerRunner());
  const ver = await runCapture('docker', ['run', '--rm', DOCKER_IMAGE, 'gcc', '--version'], { timeoutMs: 60000 });
  return {
    mode: 'docker',
    cc: 'gcc',
    ccName: 'gcc',
    version: `${ver.stdout.split(/\r?\n/)[0]} (docker ${DOCKER_IMAGE})`,
    machine: 'x86_64-linux-gnu',
    isMinGW: false,
    exeName: 'prog',
    platform: 'linux',
    support,
  };
}

function startBackgroundPull(onDone) {
  if (pulling) return;
  console.log(`[judge] Docker is available but ${DOCKER_IMAGE} is missing; pulling it in the background...`);
  pulling = runCapture('docker', ['pull', DOCKER_IMAGE], { timeoutMs: 30 * 60 * 1000 }).then((r) => {
    pulling = null;
    if (r.code === 0) {
      console.log(`[judge] ${DOCKER_IMAGE} pulled; switching to docker mode.`);
      onDone();
    } else console.log(`[judge] docker pull failed: ${r.stderr.trim()}`);
  });
}

/**
 * Detect (once) and return the active toolchain. Returns { mode, cc, support, ... }
 * or { mode: 'none', error } when nothing usable exists.
 */
export async function getToolchain({ refresh = false } = {}) {
  if (cached && !refresh) return cached;
  const want = (process.env.JUDGE_MODE || 'auto').toLowerCase();
  let tc = null;
  if (want === 'docker' || want === 'auto') {
    const d = await dockerAvailable();
    if (d.daemon && d.image) tc = await detectDocker();
    else if (d.daemon && want === 'auto')
      startBackgroundPull(() => {
        cached = null;
      });
    else if (want === 'docker') {
      cached = { mode: 'none', error: `JUDGE_MODE=docker but docker/${DOCKER_IMAGE} is not available` };
      return cached;
    }
  }
  if (!tc) tc = await detectNative();
  cached = tc || {
    mode: 'none',
    error:
      'No C compiler found. Install gcc (Linux/WSL: sudo apt install build-essential; Windows-native: node scripts/setup_windows_toolchain.js) or set CC.',
  };
  return cached;
}

/** Human-readable description of what the sanitizer toggle maps to on this toolchain. */
export function describeSanitizers(tc) {
  if (!tc || !tc.support) return 'unavailable';
  const s = tc.support;
  if (s.asan && s.ubsan && s.lsan) return 'AddressSanitizer + UndefinedBehaviorSanitizer + LeakSanitizer';
  const parts = [];
  if (s.asan) parts.push('AddressSanitizer');
  if (s.ubsan) parts.push('UBSan');
  else if (s.ubsanTrap) parts.push('UBSan (trap mode)');
  if (!s.asan || !s.lsan) parts.push('portable heap checker (leaks, double/invalid free, heap overflow, write-after-free)');
  if (!s.asan && s.stackProtector) parts.push('stack protector');
  return parts.join(' + ');
}
