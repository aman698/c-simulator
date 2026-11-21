#!/usr/bin/env node
/**
 * Regression tests of the FreeRTOS simulator port (judge-runtime/freertos/tests).
 *
 *   node scripts/test_freertos_sim.js [--print]
 *
 * Every <name>.c is compiled and run through the app's own judge (runtime 'freertos', sanitizers on)
 * three times; the three outputs must be identical. Then, depending on the sibling file:
 *   <name>.out      stdout must equal it exactly (Accepted)
 *   <name>.err      verdict must be Runtime Error and stderr must contain its text
 *   <name>.verdict  verdict must be the named one (e.g. TLE)
 * --print shows each program's stdout (handy when writing a new .out file).
 */
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from '../server/paths.js';
import { judge, VERDICT } from '../server/judge/judge.js';
import { getToolchain } from '../server/judge/toolchain.js';

const DIR = path.join(ROOT, 'judge-runtime', 'freertos', 'tests');
const print = process.argv.includes('--print');
const read = (f) => (fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : null);

const toolchain = await getToolchain();
let failed = 0;

for (const file of fs.readdirSync(DIR).filter((f) => f.endsWith('.c')).sort()) {
  const name = file.slice(0, -2);
  const base = path.join(DIR, name);
  const code = fs.readFileSync(path.join(DIR, file), 'utf8');
  const expOut = read(`${base}.out`);
  const expErr = read(`${base}.err`)?.trim();
  const expVerdict = read(`${base}.verdict`)?.trim();
  const problems = [];

  const runs = [];
  for (let i = 0; i < 3; i++) {
    const r = await judge({ code, tests: [{ input: '', output: expOut }], runtime: 'freertos', toolchain });
    if (!r.compile.ok) {
      problems.push(`does not compile:\n${r.compile.output}`);
      break;
    }
    if (r.compile.warnings) problems.push(`compiles with warnings:\n${r.compile.output}`);
    runs.push(r.tests[0]);
  }

  if (runs.length === 3) {
    const [t] = runs;
    if (runs.some((x) => x.stdout !== t.stdout || x.verdict !== t.verdict)) problems.push('non-deterministic across 3 runs');
    if (expOut != null) {
      if (t.verdict !== VERDICT.AC) problems.push(`expected Accepted, got ${t.verdict}\n--- stdout\n${t.stdout}--- stderr\n${t.stderr || ''}`);
    } else if (expErr != null) {
      if (t.verdict !== VERDICT.RE) problems.push(`expected Runtime Error, got ${t.verdict}`);
      if (!(t.stderr || '').includes(expErr)) problems.push(`stderr does not contain "${expErr}":\n${t.stderr}`);
    } else if (expVerdict != null) {
      if (t.verdict !== VERDICT[expVerdict]) problems.push(`expected ${VERDICT[expVerdict]}, got ${t.verdict}`);
    } else {
      problems.push('no .out / .err / .verdict file');
    }
    if (print) console.log(`--- ${name} (${t.verdict})\n${t.stdout}${t.stderr ? `[stderr] ${t.stderr}` : ''}`);
  }

  if (problems.length) failed++;
  console.log(`${problems.length ? 'FAIL' : 'PASS'}  ${name}${problems.length ? `\n  ${problems.join('\n  ')}` : ''}`);
}

console.log(failed ? `\n${failed} simulator test(s) failed` : '\nAll simulator tests passed');
process.exit(failed ? 1 : 0);
