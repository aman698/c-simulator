#!/usr/bin/env node
/**
 * Build questions/<topic>.json (strict schema) from questions_src/<topic>/*.q sources.
 * Usage: node scripts/build_questions.js [--quiet]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { QUESTIONS_DIR, QUESTIONS_SRC_DIR } from '../server/paths.js';
import { TOPICS } from '../server/topics.js';
import { readQuestionFile } from './lib/qformat.js';

const quiet = process.argv.includes('--quiet');
const ORDER = { Easy: 0, Medium: 1, Hard: 2 };

export function loadTopicSources(topic) {
  const dir = path.join(QUESTIONS_SRC_DIR, topic.slug);
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.q')).sort();
  const qs = files.map((f) => {
    const q = readQuestionFile(path.join(dir, f));
    q.__file = path.join(dir, f);
    return q;
  });
  qs.sort((a, b) => ORDER[a.difficulty] - ORDER[b.difficulty] || a.id.localeCompare(b.id));
  return qs;
}

/** Write via temp file + rename so concurrent readers never see a half-written JSON file. */
function writeAtomic(file, text) {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, text);
  for (let attempt = 0; ; attempt++) {
    try {
      fs.renameSync(tmp, file);
      return;
    } catch (err) {
      if (attempt >= 20 || !['EPERM', 'EBUSY', 'EACCES'].includes(err.code)) throw err;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50); // Windows: reader holds the file
    }
  }
}

function main() {
  fs.mkdirSync(QUESTIONS_DIR, { recursive: true });
  const ti = process.argv.indexOf('--topic');
  const only = ti >= 0 ? process.argv[ti + 1] : null;
  let total = 0;
  let failed = false;
  for (const topic of TOPICS.filter((t) => !only || t.slug === only)) {
    let qs;
    try {
      qs = loadTopicSources(topic);
    } catch (err) {
      console.error(`ERROR (${topic.slug}): ${err.message}`);
      failed = true;
      continue;
    }
    if (!qs) continue;
    for (const q of qs) {
      if (q.topic !== topic.name) {
        console.error(`ERROR: ${q.__file}: topic "${q.topic}" does not match folder "${topic.slug}" (${topic.name})`);
        failed = true;
      }
      const expectedName = `${q.id}.q`;
      if (path.basename(q.__file) !== expectedName) {
        console.error(`ERROR: ${q.__file}: file name should be ${expectedName}`);
        failed = true;
      }
    }
    const clean = qs.map(({ __file, ...q }) => q);
    writeAtomic(path.join(QUESTIONS_DIR, `${topic.slug}.json`), `${JSON.stringify(clean, null, 2)}\n`);
    total += clean.length;
    if (!quiet) console.log(`  ${topic.slug.padEnd(18)} ${String(clean.length).padStart(3)} questions`);
  }
  if (!quiet) console.log(`Built ${total} questions into ${path.relative(process.cwd(), QUESTIONS_DIR) || QUESTIONS_DIR}/`);
  if (failed) process.exit(1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
