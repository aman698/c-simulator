#!/usr/bin/env node
/**
 * Question authoring helper.
 *
 *   npm run q -- new <topic-slug> <ID> <TYPE> ["Title"]   scaffold questions_src/<topic>/<ID>.q
 *   npm run q -- check <file.q | topic-slug | ID> ...    parse + fully validate (verbose)
 *   npm run q -- fill <file.q> ...                       replace <<AUTO>> outputs with the solution's output
 *   npm run q -- run <file.q> [--starter] [--input "text" | --input-file f]   run code on custom input
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { QUESTIONS_SRC_DIR } from '../server/paths.js';
import { TOPICS, TYPES, topicBySlug, needsLeakCheck, runtimeOf } from '../server/topics.js';
import { judge, normalizeOutput } from '../server/judge/judge.js';
import { getToolchain } from '../server/judge/toolchain.js';
import { readQuestionFile, fillAutoOutputs, AUTO } from './lib/qformat.js';
import { validateQuestion } from './lib/validate.js';
import { applyCcOption } from './lib/cc.js';

const [cmd, ...rawRest] = process.argv.slice(2);
applyCcOption(rawRest); // --cc gcc|clang|<path>
const rest = rawRest.filter((a, i) => a !== '--cc' && rawRest[i - 1] !== '--cc');

function resolveTargets(args) {
  const files = [];
  for (const a of args) {
    if (a.startsWith('--')) continue;
    if (fs.existsSync(a) && fs.statSync(a).isFile()) files.push(path.resolve(a));
    else if (topicBySlug(a)) {
      const dir = path.join(QUESTIONS_SRC_DIR, a);
      if (fs.existsSync(dir)) for (const f of fs.readdirSync(dir).sort()) if (f.endsWith('.q')) files.push(path.join(dir, f));
    } else if (fs.existsSync(a) && fs.statSync(a).isDirectory()) {
      for (const f of fs.readdirSync(a).sort()) if (f.endsWith('.q')) files.push(path.resolve(a, f));
    } else {
      const hit = TOPICS.map((t) => path.join(QUESTIONS_SRC_DIR, t.slug, `${a}.q`)).find((p) => fs.existsSync(p));
      if (hit) files.push(hit);
      else console.error(`Not found: ${a}`);
    }
  }
  return files;
}

const TEMPLATE = (topic, id, type, title) => {
  const diff = { E: 'Easy', M: 'Medium', H: 'Hard' }[id.split('-')[1]] || 'Easy';
  const fn = type === 'FUNCTION';
  return `@@@ meta
id: ${id}
topic: ${topic.name}
difficulty: ${diff}
type: ${type}
title: ${title || 'TODO title'}
tags: TODO
@@@ statement_md
TODO: problem statement (Markdown). State the exact input and output format.
@@@ constraints_md
- TODO
@@@ starter_code
${fn ? '/* Implement the function below. Do not write main(). */\nint solve(int n)\n{\n    /* TODO */\n    return 0;\n}' : '#include <stdio.h>\n\nint main(void)\n{\n    /* TODO */\n    return 0;\n}'}
${fn ? '@@@ harness_code\n#include <stdio.h>\n\n/*USER_CODE*/\n\nint main(void)\n{\n    int n;\n    while (scanf("%d", &n) == 1) printf("%d\\n", solve(n));\n    return 0;\n}\n' : ''}${type === 'PREDICT_OUTPUT' ? '@@@ predict_answer\nTODO\n' : `@@@ sample_input
TODO
@@@ sample_output
${AUTO}
@@@ sample_input
TODO
@@@ sample_output
${AUTO}
@@@ hidden_input
TODO
@@@ hidden_output
${AUTO}
`}@@@ hint
TODO hint 1
@@@ hint
TODO hint 2
@@@ solution_code
TODO
@@@ explanation_md
**Approach.** TODO

**Complexity.** Time O(?), space O(?).

**Common mistakes.** TODO

**Interview follow-ups.** TODO
`;
};

async function cmdNew([slug, id, type, title]) {
  const topic = topicBySlug(slug);
  if (!topic || !id || !TYPES.includes(type)) {
    console.error(`usage: new <topic-slug> <ID> <${TYPES.join('|')}> ["Title"]`);
    process.exit(2);
  }
  const file = path.join(QUESTIONS_SRC_DIR, slug, `${id}.q`);
  if (fs.existsSync(file)) {
    console.error(`${file} already exists`);
    process.exit(1);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, TEMPLATE(topic, id, type, title));
  console.log(`created ${file}`);
}

async function cmdCheck(args) {
  const files = resolveTargets(args);
  const tc = await getToolchain();
  const strictWarnings = !/clang/i.test(tc.version);
  const checkOne = async (f) => {
    let q;
    try {
      q = readQuestionFile(f);
    } catch (err) {
      return { f, r: { ok: false, errors: [`parse error: ${err.message}`], notes: [] } };
    }
    try {
      return { f, q, r: await validateQuestion(q, { toolchain: tc, strictWarnings }) };
    } catch (err) {
      return { f, q, r: { ok: false, errors: [`crash: ${err.stack}`], notes: [] } };
    }
  };
  let ok = 0;
  for (const f of files) {
    const { q, r } = await checkOne(f); // sequential: keeps memory use low
    console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${path.basename(f)}${q ? `  ${q.type}  ${q.title}` : ''}`);
    for (const e of r.errors) console.log(e.split('\n').map((l) => `      ${l}`).join('\n'));
    for (const n of r.notes) console.log(`      note: ${n}`);
    if (r.ok) ok++;
  }
  console.log(`\n${ok}/${files.length} valid`);
  if (ok !== files.length) process.exit(1);
}

async function cmdFill(args) {
  const files = resolveTargets(args);
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    const q = readQuestionFile(f);
    const outputs = {};
    for (const kind of ['sample', 'hidden']) {
      const tests = q[`${kind}_tests`];
      if (!tests.some((t) => t.output === AUTO)) continue;
      const r = await judge({
        code: q.solution_code,
        harness: q.harness_code || null,
        tests: tests.map((t) => ({ input: t.input, output: null })),
        leakCheck: needsLeakCheck(q),
        runtime: runtimeOf(q),
      });
      if (!r.compile.ok) {
        console.error(`${path.basename(f)}: solution does not compile:\n${r.compile.output}`);
        process.exitCode = 1;
        break;
      }
      outputs[kind] = r.tests.map((t, i) => {
        if (tests[i].output !== AUTO) return null;
        if (t.verdict !== 'Accepted') {
          console.error(`${path.basename(f)}: ${kind} test #${i + 1}: ${t.verdict} ${t.message} ${t.stderr || ''}`);
          process.exitCode = 1;
          return null;
        }
        return normalizeOutput(t.stdout);
      });
    }
    const res = fillAutoOutputs(text, outputs);
    if (res.filled) fs.writeFileSync(f, res.text);
    console.log(`${path.basename(f)}: filled ${res.filled} output(s)`);
  }
}

async function cmdRun(args) {
  const [file] = resolveTargets(args.slice(0, 1));
  if (!file) process.exit(2);
  const q = readQuestionFile(file);
  const i = args.indexOf('--input');
  const fi = args.indexOf('--input-file');
  const input = fi >= 0 ? fs.readFileSync(args[fi + 1], 'utf8') : i >= 0 ? args[i + 1].replace(/\\n/g, '\n') : '';
  const code = args.includes('--starter') ? q.starter_code : q.solution_code;
  const r = await judge({
    code: q.type === 'PREDICT_OUTPUT' ? q.starter_code : code,
    harness: q.harness_code || null,
    tests: [{ input, output: null }],
    leakCheck: needsLeakCheck(q),
    runtime: runtimeOf(q),
  });
  if (!r.compile.ok || r.compile.warnings) console.log(r.compile.output);
  if (r.compile.ok) {
    const t = r.tests[0];
    process.stdout.write(t.stdout);
    if (t.stderr) process.stderr.write(t.stderr);
    console.error(`[${t.verdict}${t.message ? `: ${t.message}` : ''}, exit ${t.exitCode}, ${t.timeMs} ms]`);
  }
}

const COMMANDS = { new: cmdNew, check: cmdCheck, fill: cmdFill, run: cmdRun };
if (!COMMANDS[cmd]) {
  console.log(fs.readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(2, 8).join('\n'));
  process.exit(cmd ? 2 : 0);
}
COMMANDS[cmd](rest).catch((err) => {
  console.error(err);
  process.exit(2);
});
