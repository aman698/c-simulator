#!/usr/bin/env node
/**
 * Validate the whole question bank with the real compiler and the app's own judge.
 *
 *   node scripts/validate_questions.js [--topic <slug>] [--id <ID>] [--jobs N] [--verbose]
 *
 * For every question:
 *  - JSON schema, unique IDs, 10/10/10 per topic, type mix, >=30% `embedded`
 *  - portability lint (no `long`, no POSIX-only functions under -std=c11, no %p, ...)
 *  - solution_code (inside the harness for FUNCTION) compiles with the exact judge flags,
 *    with ZERO warnings, and passes ALL sample + hidden tests with no ASan/UBSan/leak reports
 *  - FIND_THE_BUG: the buggy starter compiles and FAILS at least one test
 *  - PREDICT_OUTPUT: the snippet's real output == predict_answer (or it really fails to compile)
 *  - CODE/FUNCTION: the starter template compiles
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { QUESTIONS_DIR } from '../server/paths.js';
import { applyCcOption } from './lib/cc.js';
import { TOPICS, topicBySlug } from '../server/topics.js';
import { getToolchain, describeSanitizers } from '../server/judge/toolchain.js';
import { buildCompilePlan } from '../server/judge/judge.js';
import { validateQuestion, bankErrors, bankStats } from './lib/validate.js';

const argv = process.argv.slice(2);
const opt = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};
const verbose = argv.includes('--verbose');
const topicFilter = opt('--topic');
const idFilter = opt('--id');
const jobs = Number(opt('--jobs')) || Math.max(1, os.cpus().length);
process.env.JUDGE_PARALLEL ||= String(jobs);
// --cc <path|gcc|clang>: validate with a specific compiler. `clang` = the bundled MSYS2 CLANG64
// clang (Windows ASan+UBSan pass). With clang, warnings are reported but do not fail
// (gcc is the reference compiler for the zero-warning rule).
applyCcOption(argv);

function loadBank() {
  const all = [];
  for (const t of TOPICS) {
    const file = path.join(QUESTIONS_DIR, `${t.slug}.json`);
    if (!fs.existsSync(file)) continue;
    all.push(...JSON.parse(fs.readFileSync(file, 'utf8')));
  }
  return all;
}

async function pool(items, n, fn) {
  const results = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        results[i] = await fn(items[i], i);
      }
    }),
  );
  return results;
}

async function main() {
  const tc = await getToolchain();
  if (tc.mode === 'none') {
    console.error(`ERROR: ${tc.error}`);
    process.exit(2);
  }
  const plan = buildCompilePlan(tc, { std: 'c11', sanitizers: true, leakCheck: true });
  console.log('C Practice Simulator - question bank validator');
  console.log(`  toolchain : ${tc.version} [${tc.mode}, ${tc.machine}]`);
  console.log(`  sanitizers: ${describeSanitizers(tc)}`);
  console.log(`  command   : ${plan.display}`);
  console.log('');

  let bank = loadBank();
  if (bank.length === 0) {
    console.error('No questions found. Run `npm run build:questions` first.');
    process.exit(2);
  }
  let topics = TOPICS;
  if (topicFilter) {
    const t = topicBySlug(topicFilter);
    if (!t) {
      console.error(`Unknown topic slug ${topicFilter}`);
      process.exit(2);
    }
    topics = [t];
    bank = bank.filter((q) => q.topic === t.name);
  }
  if (idFilter) bank = bank.filter((q) => q.id === idFilter);

  const started = Date.now();
  let done = 0;
  const results = await pool(bank, jobs, async (q) => {
    let r;
    try {
      r = await validateQuestion(q, { toolchain: tc, strictWarnings: !/clang/i.test(tc.version) });
    } catch (err) {
      r = { id: q.id, ok: false, errors: [`validator crashed: ${err.stack || err}`], notes: [], ms: 0 };
    }
    done++;
    if (process.stdout.isTTY) process.stdout.write(`\r  validating ${done}/${bank.length} ...`);
    return { q, r };
  });
  if (process.stdout.isTTY) process.stdout.write('\r' + ' '.repeat(40) + '\r');

  let currentTopic = null;
  for (const { q, r } of results) {
    if (q.topic !== currentTopic) {
      currentTopic = q.topic;
      console.log(`\n[${q.topic}]`);
    }
    const mark = r.ok ? 'PASS' : 'FAIL';
    console.log(`  ${mark}  ${q.id.padEnd(9)} ${q.type.padEnd(14)} ${q.title}${verbose ? `  (${r.ms} ms)` : ''}`);
    if (!r.ok) for (const e of r.errors) console.log(e.split('\n').map((l) => `          ${l}`).join('\n'));
    if (verbose) for (const n of r.notes) console.log(`          note: ${n}`);
  }

  const bErrs = idFilter ? [] : bankErrors(bank, { topics });
  if (!idFilter) {
    console.log('\nBank summary:');
    const stats = bankStats(bank);
    for (const t of topics) {
      const s = stats[t.name];
      if (!s) {
        console.log(`  ${t.name.padEnd(17)} (no questions)`);
        continue;
      }
      console.log(
        `  ${t.name.padEnd(17)} ${String(s.total).padStart(3)}  E/M/H ${s.Easy}/${s.Medium}/${s.Hard}  ` +
          `CODE ${s.CODE} FUNCTION ${s.FUNCTION} PREDICT ${s.PREDICT_OUTPUT} BUG ${s.FIND_THE_BUG}  embedded ${s.embedded}`,
      );
    }
  }
  if (bErrs.length) {
    console.log('\nBank-level problems:');
    for (const e of bErrs) console.log(`  - ${e}`);
  }
  const valid = results.filter((x) => x.r.ok).length;
  console.log(`\nTime: ${((Date.now() - started) / 1000).toFixed(1)} s`);
  console.log(`${valid}/${bank.length} questions valid`);
  if (valid !== bank.length || bErrs.length) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
