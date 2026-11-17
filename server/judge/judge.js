/**
 * The judge: assemble -> compile -> run every test -> classify.
 *
 * Shared by the HTTP server and by scripts/validate_questions.js, so the
 * validator exercises exactly the same compile flags and verdict logic as the app.
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { RUNTIME_DIR } from '../paths.js';
import { DOCKER_IMAGE, IS_WIN, getToolchain, runCapture, toolEnv, describeSanitizers } from './toolchain.js';

export const VERDICT = Object.freeze({
  AC: 'Accepted',
  WA: 'Wrong Answer',
  CE: 'Compile Error',
  RE: 'Runtime Error',
  TLE: 'Time Limit Exceeded',
  LEAK: 'Memory Leak',
});

export const USER_CODE_MARKER = '/*USER_CODE*/';
const DEFAULT_TIME_LIMIT_MS = 2000;
const MAX_STDOUT = 1 << 20; // 1 MiB
const MAX_STDERR = 256 << 10;
const RETURN_STDOUT = 64 << 10;
const RETURN_STDERR = 32 << 10;

// ---------------------------------------------------------------- helpers

/** Judge comparison: CRLF->LF, strip trailing spaces on every line, strip trailing blank lines. */
export function normalizeOutput(s) {
  return String(s ?? '')
    .replace(/\r\n?/g, '\n')
    .split('\n')
    .map((l) => l.replace(/[ \t\f\v]+$/, ''))
    .join('\n')
    .replace(/\n+$/, '');
}

/**
 * Insert user code into a harness at USER_CODE_MARKER. `#line` directives make
 * diagnostics and sanitizer stack traces refer to the user's own line numbers
 * as main.c, while harness lines are reported as harness.c.
 */
export function assembleSource(code, harness) {
  const user = String(code ?? '').replace(/\r\n?/g, '\n');
  if (!harness) return user.endsWith('\n') ? user : `${user}\n`;
  const h = harness.replace(/\r\n?/g, '\n');
  const idx = h.indexOf(USER_CODE_MARKER);
  if (idx < 0) throw new Error(`harness_code has no ${USER_CODE_MARKER} marker`);
  const before = h.slice(0, idx);
  const after = h.slice(idx + USER_CODE_MARKER.length);
  const resumeLine = before.split('\n').length; // line of the marker in the harness
  return `#line 1 "harness.c"\n${before}\n#line 1 "main.c"\n${user}\n#line ${resumeLine} "harness.c"\n${after}${
    after.endsWith('\n') ? '' : '\n'
  }`;
}

function quoteArg(a) {
  return /[\s"']/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a;
}

/** Map the UI options onto concrete compiler flags for the active toolchain. */
export function buildCompilePlan(tc, { std = 'c11', sanitizers = true, leakCheck = false } = {}) {
  const s = tc.support || {};
  const stdFlag = std === 'c99' ? 'c99' : 'c11';
  const flags = [`-std=${stdFlag}`, '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-g'];
  let heapcheck = false;
  let sanitizerRuntime = false;
  if (sanitizers) {
    if (s.asan && s.ubsan) {
      flags.push('-fsanitize=address,undefined');
      sanitizerRuntime = true;
    } else {
      const list = [];
      if (s.asan) list.push('address');
      if (s.ubsan) list.push('undefined');
      if (list.length) {
        flags.push(`-fsanitize=${list.join(',')}`);
        sanitizerRuntime = true;
      }
      if (!s.ubsan && s.ubsanTrap) flags.push('-fsanitize=undefined', '-fsanitize-undefined-trap-on-error');
      if (!s.asan) {
        heapcheck = true;
        if (s.stackProtector) flags.push('-fstack-protector-strong');
      }
    }
    // ASan without LeakSanitizer (Windows clang, macOS): add the heap checker for leaks only.
    if (s.asan && !s.lsan) heapcheck = true;
  }
  const lsanActive = sanitizers && s.asan && s.lsan;
  if (leakCheck && !lsanActive && !heapcheck) {
    if (!sanitizers && s.lsanStandalone) {
      flags.push('-fsanitize=leak');
      sanitizerRuntime = true;
    } else heapcheck = true;
  }
  if (tc.isMinGW) flags.push('-mno-ms-bitfields'); // SysV (Linux) struct/bit-field layout
  const sources = ['main.c'];
  const runtimeFiles = [];
  if (heapcheck) {
    flags.push('-include', 'heapcheck.h');
    sources.push('heapcheck.c');
    runtimeFiles.push('heapcheck.h', 'heapcheck.c');
  }
  const args = [...flags, '-fdiagnostics-color=never', '-o', tc.exeName, ...sources, '-lm'];
  const display = [tc.ccName === 'clang' ? 'clang' : 'gcc', ...flags, '-o', 'prog', ...sources].map(quoteArg).join(' ');
  const runEnv = {
    ASAN_OPTIONS: `detect_leaks=${s.lsan ? 1 : 0}:abort_on_error=0:halt_on_error=1:allocator_may_return_null=1:hard_rss_limit_mb=384:quarantine_size_mb=32:print_summary=1:symbolize=1`,
    UBSAN_OPTIONS: 'halt_on_error=1:print_stacktrace=1:print_summary=1',
    LSAN_OPTIONS: 'exitcode=23',
  };
  return { args, display, runEnv, heapcheck, sanitizerRuntime, runtimeFiles, leakDetection: lsanActive || heapcheck || flags.includes('-fsanitize=leak') };
}

const DIAG_RE = /^(?:.*[\\/])?(main\.c|harness\.c|heapcheck\.[ch]):(\d+):(?:(\d+):)? (fatal error|error|warning|note): (.*)$/;
const LINK_RE = /(main\.c|harness\.c):(\d+):(?:\(.*?\))?:? ?(undefined reference to .*)$/;

export function parseDiagnostics(output) {
  const diags = [];
  for (const raw of output.split(/\r?\n/)) {
    let m = DIAG_RE.exec(raw);
    if (m) {
      diags.push({
        file: m[1],
        line: Number(m[2]),
        column: m[3] ? Number(m[3]) : 1,
        severity: m[4] === 'fatal error' ? 'error' : m[4],
        message: m[5],
      });
      continue;
    }
    m = LINK_RE.exec(raw);
    if (m) diags.push({ file: m[1], line: Number(m[2]), column: 1, severity: 'error', message: m[3] });
    else if (/undefined reference to|multiple definition of|ld returned/.test(raw)) {
      diags.push({ file: 'linker', line: 0, column: 0, severity: 'error', message: raw.replace(/^.*?ld(\.exe)?: /, '') });
    }
  }
  return diags;
}

/** Find sanitizer / heap checker reports in stderr. */
export function analyzeStderr(stderr) {
  const out = { kind: null, title: null, line: null, leak: false, leakSummary: null };
  let m;
  if ((m = /ERROR: AddressSanitizer: ([A-Za-z0-9_-]+)/.exec(stderr))) {
    out.kind = 'asan';
    out.title =
      m[1] === 'SEGV'
        ? 'AddressSanitizer: SEGV (segmentation fault - invalid memory access)'
        : `AddressSanitizer: ${m[1]}`;
    // heap checker + ASan (Windows clang): a 2nd free() reads the freed header first. Only the
    // *access* stack (before "freed by thread") decides; the free stack always contains csim_hc_free.
    if (m[1] === 'heap-use-after-free') {
      const accessStack = stderr.split(/freed by thread/)[0];
      if (/#[0-2] 0x[0-9a-f]+ in (csim_hc_free|csim_hc_realloc|hc_validate)\b/.test(accessStack))
        out.title = 'AddressSanitizer: attempting double-free (free/realloc of memory that was already freed)';
    }
    const frame = /#\d+ 0x[0-9a-f]+ in \S+ (?:.*[\\/])?main\.c:(\d+)/.exec(stderr);
    if (frame) out.line = Number(frame[1]);
  } else if ((m = /^(?:.*[\\/])?([\w.]+):(\d+):(\d+): runtime error: (.*)$/m.exec(stderr))) {
    out.kind = 'ubsan';
    out.title = `UndefinedBehaviorSanitizer: ${m[4]}`;
    if (m[1] === 'main.c') out.line = Number(m[2]);
  } else if ((m = /==CSIM-HEAPCHECK== ERROR: (?!memory leak)(.*)/.exec(stderr))) {
    out.kind = 'heapcheck';
    out.title = `Heap checker: ${m[1]}`;
    const at = /at main\.c:(\d+)/.exec(m[1]);
    if (at) out.line = Number(at[1]);
  } else if (/\*\*\* stack smashing detected \*\*\*/.test(stderr)) {
    out.kind = 'ssp';
    out.title = 'Stack buffer overflow (stack smashing detected)';
  } else if (/ERROR: (?:AddressSanitizer|LeakSanitizer): .*rss/.test(stderr)) {
    out.kind = 'memlimit';
    out.title = 'Memory limit exceeded';
  }
  if (/ERROR: LeakSanitizer: detected memory leaks/.test(stderr)) {
    out.leak = true;
    m = /SUMMARY: \w+Sanitizer: (\d+ byte\(s\) leaked in \d+ allocation\(s\))/.exec(stderr);
    out.leakSummary = m ? m[1] : 'memory leaked';
  }
  if ((m = /==CSIM-HEAPCHECK== ERROR: memory leak detected: (.*)/.exec(stderr))) {
    out.leak = true;
    out.leakSummary = m[1];
  }
  return out;
}

const SIGNAL_TEXT = {
  SIGSEGV: 'Segmentation fault (SIGSEGV) - invalid memory access',
  SIGFPE: 'Arithmetic exception (SIGFPE) - e.g. integer division by zero',
  SIGABRT: 'Aborted (SIGABRT) - abort() or a failed assert()',
  SIGILL: 'Illegal instruction (SIGILL) - undefined behavior trapped',
  SIGBUS: 'Bus error (SIGBUS) - misaligned or invalid memory access',
  SIGXFSZ: 'Output file size limit exceeded',
  SIGKILL: 'Killed (SIGKILL) - memory limit exceeded?',
};
const SIGNAL_BY_NUM = { 4: 'SIGILL', 6: 'SIGABRT', 7: 'SIGBUS', 8: 'SIGFPE', 9: 'SIGKILL', 11: 'SIGSEGV', 25: 'SIGXFSZ' };
const WIN_STATUS = {
  0xc0000005: 'Segmentation fault (access violation) - invalid memory access',
  0xc0000094: 'Arithmetic exception - integer division by zero',
  0xc0000095: 'Arithmetic exception - integer overflow',
  0xc00000fd: 'Stack overflow (infinite recursion or huge local array?)',
  0xc000001d:
    'Undefined behavior trapped by UBSan (trap mode): e.g. null-pointer dereference, signed overflow, division by zero, invalid shift or out-of-bounds index',
  0xc0000409: 'Stack buffer overrun detected (fast-fail)',
  0xc0000374: 'Heap corruption detected',
  0xc000008e: 'Floating-point division by zero',
  0xc0000090: 'Floating-point invalid operation',
};

function crashText(run) {
  if (run.signal) return SIGNAL_TEXT[run.signal] || `Killed by signal ${run.signal}`;
  if (IS_WIN && run.code != null) {
    const u = run.code >>> 0;
    if (WIN_STATUS[u]) return WIN_STATUS[u];
    if (u === 3) return 'abort() called (SIGABRT) - e.g. a failed assert()';
  }
  return null;
}

/** Decide the verdict of one test run. */
export function classify(run, expected) {
  const rep = analyzeStderr(run.stderr || '');
  const res = { verdict: VERDICT.AC, message: '', line: rep.line, leak: rep.leak, sanitizer: rep.kind };
  if (run.timedOut) return { ...res, verdict: VERDICT.TLE, message: `Time limit exceeded (${run.timeLimitMs} ms)` };
  if (run.outputLimit) return { ...res, verdict: VERDICT.RE, message: 'Output limit exceeded (more than 1 MiB on stdout)' };
  if (rep.kind) return { ...res, verdict: VERDICT.RE, message: rep.title };
  const crash = crashText(run);
  if (crash) return { ...res, verdict: VERDICT.RE, message: crash };
  if (run.code !== 0 && !(rep.leak && run.code === 23)) {
    // Windows reports exit codes as unsigned 32-bit; show `return -35;` as -35, not 4294967261.
    const shown = IS_WIN && run.code > 0x7fffffff ? run.code | 0 : run.code;
    return { ...res, verdict: VERDICT.RE, message: `Non-zero exit code ${shown} (main must return 0)` };
  }
  if (expected != null && normalizeOutput(run.stdout) !== normalizeOutput(expected)) {
    return {
      ...res,
      verdict: VERDICT.WA,
      message: rep.leak ? `Output does not match. (Also: memory leak detected - ${rep.leakSummary})` : 'Output does not match',
    };
  }
  if (rep.leak) return { ...res, verdict: VERDICT.LEAK, message: `Memory leak detected - ${rep.leakSummary}` };
  return res;
}

// ---------------------------------------------------------------- native execution

function runProgramNative(tc, dir, input, plan, timeLimitMs) {
  return new Promise((resolve) => {
    const exe = path.join(dir, tc.exeName);
    const env = toolEnv(tc.cc, plan.runEnv);
    let cmd = exe;
    let args = [];
    let detached = false;
    if (!IS_WIN) {
      const vlimit = plan.sanitizerRuntime ? '' : 'ulimit -v 262144 2>/dev/null; ';
      cmd = '/bin/sh';
      args = ['-c', `${vlimit}ulimit -f 2048 2>/dev/null; exec ./${tc.exeName}`];
      detached = true; // own process group so a timeout kills everything
    }
    const start = process.hrtime.bigint();
    let stdout = '';
    let stderr = '';
    let stdoutBytes = 0;
    let timedOut = false;
    let outputLimit = false;
    let settled = false;
    const child = spawn(cmd, args, { cwd: dir, env, windowsHide: true, detached });
    const kill = () => {
      try {
        if (detached) process.kill(-child.pid, 'SIGKILL');
        else child.kill('SIGKILL');
      } catch {
        try {
          child.kill('SIGKILL');
        } catch {
          /* already gone */
        }
      }
    };
    const timer = setTimeout(() => {
      timedOut = true;
      kill();
    }, timeLimitMs);
    child.stdout.on('data', (d) => {
      stdoutBytes += d.length;
      if (stdoutBytes > MAX_STDOUT) {
        if (!outputLimit) {
          outputLimit = true;
          kill();
        }
        return;
      }
      stdout += d;
    });
    child.stderr.on('data', (d) => {
      if (stderr.length < MAX_STDERR) stderr += d;
    });
    const finish = (code, signal, error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      const timeMs = Number((process.hrtime.bigint() - start) / 1000000n);
      resolve({ code, signal, stdout, stderr: error ? `${stderr}\n${error}` : stderr, timedOut, outputLimit, timeMs, timeLimitMs });
    };
    child.on('error', (err) => finish(-1, null, String(err)));
    child.on('close', (code, signal) => finish(code, signal));
    child.stdin.on('error', () => {});
    child.stdin.end(input ?? '');
  });
}

// ---------------------------------------------------------------- docker execution

/** On Linux hosts run the container as the current user so files in the temp dir stay deletable. */
function dockerUserArgs() {
  return typeof process.getuid === 'function' ? ['--user', `${process.getuid()}:${process.getgid()}`] : [];
}

function shQuote(s) {
  return `'${String(s).replace(/'/g, `'\\''`)}'`;
}

async function judgeInDocker(tc, dir, plan, inputs, timeLimitMs, compileOnly) {
  inputs.forEach((inp, i) => fs.writeFileSync(path.join(dir, `in_${i}.txt`), inp ?? ''));
  const secs = Math.max(1, Math.ceil(timeLimitMs / 1000));
  const envExports = Object.entries(plan.runEnv)
    .map(([k, v]) => `export ${k}=${shQuote(v)}`)
    .join('\n');
  const script = `#!/bin/sh
cd /work
gcc ${plan.args.map(shQuote).join(' ')} > compile.txt 2>&1
echo $? > compile.rc
[ "$(cat compile.rc)" = "0" ] || exit 0
${compileOnly ? 'exit 0' : ''}
${envExports}
i=0
while [ -f "in_$i.txt" ]; do
  s=$(date +%s%N)
  ( ulimit -f 2048; timeout -s KILL ${secs} ./${tc.exeName} < "in_$i.txt" > "out_$i.txt" 2> "err_$i.txt" )
  echo $? > "rc_$i.txt"
  e=$(date +%s%N)
  echo $(( (e - s) / 1000000 )) > "ms_$i.txt"
  i=$((i + 1))
done
`;
  fs.writeFileSync(path.join(dir, 'run.sh'), script);
  const r = await runCapture(
    'docker',
    [
      'run', '--rm', '--network', 'none', '--memory', '128m', '--memory-swap', '128m', '--pids-limit', '64',
      '--cpus', '1', '--cap-add', 'SYS_PTRACE', ...dockerUserArgs(), '-v', `${dir}:/work`, '-w', '/work', DOCKER_IMAGE, 'sh', 'run.sh',
    ],
    { timeoutMs: 60000 + inputs.length * (timeLimitMs + 1500) },
  );
  const read = (f) => {
    try {
      return fs.readFileSync(path.join(dir, f), 'utf8');
    } catch {
      return null;
    }
  };
  const compileRc = read('compile.rc');
  if (compileRc == null) {
    return { compile: { code: -1, output: `Docker run failed: ${r.stderr || r.stdout}` }, runs: [] };
  }
  const compile = { code: Number(compileRc.trim()), output: read('compile.txt') || '' };
  const runs = [];
  if (compile.code === 0 && !compileOnly) {
    for (let i = 0; i < inputs.length; i++) {
      const rc = Number((read(`rc_${i}.txt`) || '-1').trim());
      const ms = Number((read(`ms_${i}.txt`) || '0').trim());
      let stdout = read(`out_${i}.txt`) || '';
      let outputLimit = false;
      let signal = null;
      let code = rc;
      if (rc > 128 && SIGNAL_BY_NUM[rc - 128]) {
        signal = SIGNAL_BY_NUM[rc - 128];
        code = null;
      }
      const timedOut = signal === 'SIGKILL' && ms >= timeLimitMs - 50;
      if (signal === 'SIGXFSZ' || stdout.length > MAX_STDOUT) outputLimit = true;
      if (stdout.length > MAX_STDOUT) stdout = stdout.slice(0, MAX_STDOUT);
      runs.push({ code, signal, stdout, stderr: (read(`err_${i}.txt`) || '').slice(0, MAX_STDERR), timedOut, outputLimit, timeMs: ms, timeLimitMs });
    }
  }
  return { compile, runs };
}

// ---------------------------------------------------------------- public API

let active = 0;
const waiters = [];
const MAX_PARALLEL = Math.max(1, Number(process.env.JUDGE_PARALLEL) || Math.min(4, Math.ceil(os.cpus().length / 2)));

async function withSlot(fn) {
  if (active >= MAX_PARALLEL) await new Promise((r) => waiters.push(r));
  active++;
  try {
    return await fn();
  } finally {
    active--;
    const next = waiters.shift();
    if (next) next();
  }
}

function scrub(text, dir) {
  if (!text) return text;
  let t = text;
  const real = safeReal(dir);
  const variants = new Set([dir, dir.replace(/\\/g, '/'), real, real.replace(/\\/g, '/')]);
  for (const v of variants) t = t.split(`${v}\\`).join('').split(`${v}/`).join('').split(v).join('.');
  return t;
}
function safeReal(p) {
  try {
    return fs.realpathSync.native(p);
  } catch {
    return p;
  }
}

function clip(s, n) {
  if (s == null) return s;
  return s.length > n ? `${s.slice(0, n)}\n... [truncated ${s.length - n} bytes]` : s;
}

/**
 * Compile `code` (inserted into `harness` if given) and run it against `tests`.
 * tests: [{ input, output }]   (output null => no comparison, e.g. playground)
 */
export async function judge({
  code,
  harness = null,
  tests = [],
  std = 'c11',
  sanitizers = true,
  leakCheck = false,
  timeLimitMs = DEFAULT_TIME_LIMIT_MS,
  stopOnFirstFailure = false,
  compileOnly = false,
  toolchain = null,
}) {
  const tc = toolchain || (await getToolchain());
  if (!tc || tc.mode === 'none') {
    const err = new Error(tc?.error || 'No compiler available');
    err.status = 503;
    throw err;
  }
  const plan = buildCompilePlan(tc, { std, sanitizers, leakCheck });
  const source = assembleSource(code, harness);
  return withSlot(async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'csim-'));
    try {
      fs.writeFileSync(path.join(dir, 'main.c'), source);
      for (const f of plan.runtimeFiles) fs.copyFileSync(path.join(RUNTIME_DIR, f), path.join(dir, f));
      let compile;
      let runs = [];
      if (tc.mode === 'docker') {
        const d = await judgeInDocker(tc, dir, plan, tests.map((t) => t.input), timeLimitMs, compileOnly);
        compile = d.compile;
        runs = d.runs;
      } else {
        const c = await runCapture(tc.cc, plan.args, { cwd: dir, env: toolEnv(tc.cc), timeoutMs: 60000 });
        compile = { code: c.timedOut ? -1 : c.code, output: c.timedOut ? 'Compilation timed out' : c.stdout + c.stderr };
      }
      const compileOutput = scrub(compile.output, dir).replace(/\r\n/g, '\n');
      const diagnostics = parseDiagnostics(compileOutput);
      const result = {
        compile: {
          ok: compile.code === 0,
          output: compileOutput,
          diagnostics,
          warnings: diagnostics.filter((d) => d.severity === 'warning').length,
          errors: diagnostics.filter((d) => d.severity === 'error').length,
          command: plan.display,
        },
        tests: [],
        verdict: null,
        passed: 0,
        total: tests.length,
        toolchain: { mode: tc.mode, version: tc.version, sanitizers: sanitizers ? describeSanitizers(tc) : 'off', leakDetection: plan.leakDetection },
      };
      if (!result.compile.ok) {
        result.verdict = VERDICT.CE;
        return result;
      }
      if (compileOnly) return result;
      for (let i = 0; i < tests.length; i++) {
        const t = tests[i];
        const run = tc.mode === 'docker' ? runs[i] : await runProgramNative(tc, dir, t.input, plan, timeLimitMs);
        const cls = classify(run, t.output);
        const stderr = scrub(run.stderr, dir);
        result.tests.push({
          index: i,
          input: t.input,
          expected: t.output,
          stdout: clip(run.stdout.replace(/\r\n/g, '\n'), RETURN_STDOUT),
          stderr: clip(stderr, RETURN_STDERR),
          exitCode: run.code,
          signal: run.signal,
          timeMs: run.timeMs,
          verdict: cls.verdict,
          message: cls.message,
          line: cls.line,
          leak: cls.leak,
        });
        if (cls.verdict === VERDICT.AC) result.passed++;
        else if (!result.verdict) result.verdict = cls.verdict;
        if (stopOnFirstFailure && cls.verdict !== VERDICT.AC) break;
      }
      if (!result.verdict) result.verdict = VERDICT.AC;
      return result;
    } finally {
      fs.rm(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 }, () => {});
    }
  });
}
