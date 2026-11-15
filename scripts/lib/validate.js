/**
 * Question validation: schema + portability lint + real compilation/judging.
 * Used by scripts/validate_questions.js and scripts/qtool.js.
 */
import { judge, VERDICT, USER_CODE_MARKER, normalizeOutput } from '../../server/judge/judge.js';
import { TOPICS, DIFFICULTIES, TYPES, PREDICT_SPECIAL, topicByName, needsLeakCheck } from '../../server/topics.js';
import { AUTO } from './qformat.js';

const DIFF_LETTER = { Easy: 'E', Medium: 'M', Hard: 'H' };

// ------------------------------------------------------------------ schema

export function schemaErrors(q) {
  const e = [];
  const str = (k, min = 1) => {
    if (typeof q[k] !== 'string') e.push(`${k} must be a string`);
    else if (q[k].trim().length < min) e.push(min > 1 ? `${k} is too short (min ${min} chars)` : `${k} is empty`);
  };
  const topic = topicByName(q.topic);
  if (!topic) e.push(`unknown topic "${q.topic}" (expected one of ${TOPICS.map((t) => t.name).join(', ')})`);
  if (!DIFFICULTIES.includes(q.difficulty)) e.push(`bad difficulty "${q.difficulty}"`);
  if (!TYPES.includes(q.type)) e.push(`bad type "${q.type}"`);
  const idRe = /^([A-Z]{3})-([EMH])-(\d{2})$/;
  const m = idRe.exec(q.id || '');
  if (!m) e.push(`id "${q.id}" must look like ARR-E-01`);
  else {
    if (topic && m[1] !== topic.prefix) e.push(`id prefix ${m[1]} does not match topic ${q.topic} (${topic.prefix})`);
    if (DIFF_LETTER[q.difficulty] && m[2] !== DIFF_LETTER[q.difficulty]) e.push(`id letter ${m[2]} does not match difficulty ${q.difficulty}`);
  }
  str('title', 4);
  if (q.title && q.title.length > 80) e.push('title longer than 80 chars');
  if (!Array.isArray(q.tags) || q.tags.length === 0) e.push('tags must be a non-empty array');
  else for (const t of q.tags) if (!/^[a-z0-9][a-z0-9+-]*$/.test(t)) e.push(`tag "${t}" must be lowercase-kebab-case`);
  str('statement_md', 60);
  str('constraints_md');
  str('starter_code');
  str('solution_code');
  str('explanation_md', 120);
  if (!Array.isArray(q.hints) || q.hints.length !== 2 || q.hints.some((h) => !h || !h.trim())) e.push('exactly 2 non-empty hints are required');
  for (const k of ['sample_tests', 'hidden_tests']) {
    if (!Array.isArray(q[k])) e.push(`${k} must be an array`);
    else
      q[k].forEach((t, i) => {
        if (typeof t?.input !== 'string' || typeof t?.output !== 'string') e.push(`${k}[${i}] needs string input/output`);
        else if (t.output === AUTO) e.push(`${k}[${i}] output is still ${AUTO} (run: npm run q -- fill <file>)`);
      });
  }
  const harness = q.harness_code || '';
  const markerCount = harness.split(USER_CODE_MARKER).length - 1;
  const testable = q.type === 'CODE' || q.type === 'FUNCTION' || q.type === 'FIND_THE_BUG';
  if (q.type === 'FUNCTION' && markerCount !== 1) e.push(`FUNCTION questions need harness_code containing ${USER_CODE_MARKER} exactly once`);
  if (q.type === 'FIND_THE_BUG' && harness && markerCount !== 1) e.push(`harness_code must contain ${USER_CODE_MARKER} exactly once`);
  if ((q.type === 'CODE' || q.type === 'PREDICT_OUTPUT') && harness) e.push(`${q.type} questions must not have harness_code`);
  if (testable) {
    if ((q.sample_tests || []).length < 2) e.push('need at least 2 sample tests');
    if ((q.hidden_tests || []).length < 5) e.push('need at least 5 hidden tests');
    if (q.predict_answer) e.push('predict_answer must be empty for non-PREDICT_OUTPUT questions');
    const inputs = [...(q.sample_tests || []), ...(q.hidden_tests || [])].map((t) => t.input);
    const dup = inputs.find((x, i) => inputs.indexOf(x) !== i);
    if (dup !== undefined) e.push(`duplicate test input: ${JSON.stringify(dup.slice(0, 60))}`);
    if (!/complexity|O\(/i.test(q.explanation_md || '')) e.push('explanation_md must discuss time/space complexity');
    if (q.type !== 'FIND_THE_BUG' && q.solution_code.trim() === q.starter_code.trim()) e.push('starter_code equals solution_code');
  }
  if (q.type === 'FIND_THE_BUG' && q.solution_code.trim() === q.starter_code.trim()) e.push('buggy starter_code equals solution_code');
  if (q.type === 'PREDICT_OUTPUT') {
    if (!q.predict_answer || !q.predict_answer.trim()) e.push('PREDICT_OUTPUT needs predict_answer');
    if ((q.sample_tests || []).length || (q.hidden_tests || []).length) e.push('PREDICT_OUTPUT must not have tests');
    if (!/x86-64/i.test(`${q.statement_md}\n${q.constraints_md}`)) e.push('PREDICT_OUTPUT must state the platform assumptions (x86-64, gcc, ...)');
  }
  if (!/follow-?up/i.test(q.explanation_md || '')) e.push('explanation_md must include interview follow-up questions');
  if (!/mistake|pitfall|trap|gotcha/i.test(q.explanation_md || '')) e.push('explanation_md must mention common mistakes/pitfalls');
  return e;
}

// ------------------------------------------------------------------ portability lint

/** Remove comments; optionally blank out string/char literals. */
export function stripC(code, { keepStrings = false } = {}) {
  let out = '';
  let i = 0;
  const n = code.length;
  while (i < n) {
    const c = code[i];
    const d = code[i + 1];
    if (c === '/' && d === '*') {
      const end = code.indexOf('*/', i + 2);
      const chunk = code.slice(i, end < 0 ? n : end + 2);
      out += chunk.replace(/[^\n]/g, ' ');
      i = end < 0 ? n : end + 2;
    } else if (c === '/' && d === '/') {
      while (i < n && code[i] !== '\n') i++;
    } else if (c === '"' || c === "'") {
      const q = c;
      let j = i + 1;
      while (j < n && code[j] !== q && code[j] !== '\n') j += code[j] === '\\' ? 2 : 1;
      const lit = code.slice(i, j + 1);
      out += keepStrings ? lit : q + ' '.repeat(Math.max(0, lit.length - 2)) + q;
      i = j + 1;
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

const NONPORTABLE_IDENT = {
  strdup: 'POSIX, hidden by glibc under -std=c11',
  strndup: 'POSIX, hidden by glibc under -std=c11',
  strtok_r: 'POSIX, hidden by glibc under -std=c11',
  strcasecmp: 'POSIX', strncasecmp: 'POSIX', strsep: 'BSD', strlcpy: 'BSD', strlcat: 'BSD',
  getline: 'POSIX', getdelim: 'POSIX', fileno: 'POSIX', bzero: 'BSD', bcopy: 'BSD',
  itoa: 'non-standard', ltoa: 'non-standard', stricmp: 'MSVC', strlwr: 'MSVC', strupr: 'MSVC', strrev: 'MSVC',
  gets: 'removed in C11', usleep: 'POSIX', sleep: 'POSIX', alloca: 'non-standard', aligned_alloc: 'not supported by the Windows CRT',
  M_PI: 'not defined by <math.h> under -std=c11', M_E: 'not defined by <math.h> under -std=c11',
  ssize_t: 'POSIX type', typeof: 'GNU keyword, not available with -std=c11 (use __typeof__)', asm: 'GNU keyword (use __asm__)',
  wchar_t: 'size differs between Linux (4) and Windows (2)',
  rand: 'sequence differs between C libraries', srand: 'sequence differs between C libraries', time: 'non-deterministic',
  clock: 'non-deterministic',
};
const TYPE_LIKE_IDENT = new Set(['M_PI', 'M_E', 'ssize_t', 'wchar_t', 'typeof', 'asm']);
const NONPORTABLE_HEADERS = ['unistd.h', 'pthread.h', 'windows.h', 'conio.h', 'malloc.h', 'threads.h', 'sys/', 'io.h', 'alloca.h'];

export function lintCode(code, label) {
  if (!code) return [];
  const errs = [];
  const noStr = stripC(code);
  const withStr = stripC(code, { keepStrings: true });
  const noLongLong = noStr.replace(/\blong\s+long\b/g, 'LL');
  if (/\blong\b/.test(noLongLong))
    errs.push(`${label}: uses \`long\` (8 bytes on Linux, 4 on Windows) - use int/long long/<stdint.h> types`);
  for (const [id, why] of Object.entries(NONPORTABLE_IDENT)) {
    // Function-like names are flagged only when called/declared (`id(`), so variables or
    // struct members named e.g. `time` stay legal; type-like names are flagged anywhere.
    const re = TYPE_LIKE_IDENT.has(id) ? new RegExp(`(?<![\\w.>])${id}\\b`) : new RegExp(`(?<![\\w.>])${id}\\s*\\(`);
    if (re.test(noStr)) errs.push(`${label}: uses \`${id}\` (${why})`);
  }
  for (const h of NONPORTABLE_HEADERS) if (new RegExp(`#\\s*include\\s*<${h.replace('/', '\\/')}`).test(withStr)) errs.push(`${label}: includes non-portable <${h}>`);
  if (/"[^"\n]*%[-+ #0]*\d*p[^"\n]*"/.test(withStr)) errs.push(`${label}: prints a pointer with %p (output differs between platforms)`);
  if (/fflush\s*\(\s*stdin\s*\)/.test(noStr)) errs.push(`${label}: fflush(stdin) is undefined behavior`);
  return errs;
}

// ------------------------------------------------------------------ judging checks

function testsOf(q) {
  return [...(q.sample_tests || []), ...(q.hidden_tests || [])];
}

function describeFailure(t) {
  const lines = [`test #${t.index + 1}: ${t.verdict}${t.message ? ` - ${t.message}` : ''}`];
  if (t.verdict === VERDICT.WA) {
    lines.push(`    input:    ${JSON.stringify(t.input).slice(0, 300)}`);
    lines.push(`    expected: ${JSON.stringify(normalizeOutput(t.expected)).slice(0, 300)}`);
    lines.push(`    actual:   ${JSON.stringify(normalizeOutput(t.stdout)).slice(0, 300)}`);
  }
  if (t.stderr && t.stderr.trim()) lines.push(`    stderr:   ${JSON.stringify(t.stderr.trim()).slice(0, 400)}`);
  return lines.join('\n');
}

/**
 * Fully validate one question. Returns { id, ok, errors[], notes[], ms }.
 * opts.std defaults to c11, sanitizers always ON (exact judge flags).
 */
export async function validateQuestion(q, opts = {}) {
  const t0 = Date.now();
  const errors = schemaErrors(q);
  const notes = [];
  const lintTargets = [
    ['solution_code', q.solution_code],
    ['starter_code', q.starter_code],
    ['harness_code', q.harness_code],
  ];
  for (const [label, code] of lintTargets) errors.push(...lintCode(code, label));
  if (errors.length) return { id: q.id, ok: false, errors, notes, ms: Date.now() - t0 };

  const leakCheck = needsLeakCheck(q);
  const common = { std: opts.std || 'c11', sanitizers: true, leakCheck, toolchain: opts.toolchain };
  const harness = q.harness_code || null;

  if (q.type === 'PREDICT_OUTPUT') {
    const ans = q.predict_answer.trim();
    if (ans === 'Compile Error') {
      const r = await judge({ ...common, code: q.starter_code, compileOnly: true });
      if (r.compile.ok) errors.push('predict_answer is "Compile Error" but the snippet compiles');
      else notes.push(`compile error confirmed: ${r.compile.diagnostics.find((d) => d.severity === 'error')?.message || 'error'}`);
    } else if (ans === 'Undefined Behavior') {
      const r = await judge({ ...common, code: q.starter_code, tests: [{ input: '', output: null }] });
      if (!r.compile.ok) errors.push('UB snippet does not compile:\n' + r.compile.output);
      else {
        const t = r.tests[0];
        notes.push(`UB snippet ran: ${t.verdict}${t.message ? ` (${t.message})` : ''}${r.compile.warnings ? `, ${r.compile.warnings} compiler warning(s)` : ''}`);
      }
    } else {
      if (PREDICT_SPECIAL.some((s) => s.toLowerCase() === ans.toLowerCase()) && !PREDICT_SPECIAL.includes(ans))
        errors.push(`predict_answer must be spelled exactly "Undefined Behavior" or "Compile Error"`);
      const r = await judge({ ...common, code: q.starter_code, tests: [{ input: '', output: q.predict_answer }] });
      if (!r.compile.ok) errors.push(`snippet does not compile:\n${r.compile.output}`);
      else if (r.verdict !== VERDICT.AC) errors.push(`snippet output differs from predict_answer:\n${describeFailure(r.tests[0])}`);
    }
    return { id: q.id, ok: errors.length === 0, errors, notes, ms: Date.now() - t0 };
  }

  // CODE / FUNCTION / FIND_THE_BUG: the reference solution must pass everything, cleanly.
  const sol = await judge({ ...common, code: q.solution_code, harness, tests: testsOf(q) });
  if (!sol.compile.ok) errors.push(`solution does not compile:\n${sol.compile.output}`);
  else {
    if (sol.compile.warnings > 0) {
      if (opts.strictWarnings === false) notes.push(`solution has ${sol.compile.warnings} warning(s) with this compiler`);
      else errors.push(`solution compiles with warnings:\n${sol.compile.output}`);
    }
    for (const t of sol.tests) {
      if (t.verdict !== VERDICT.AC) errors.push(`solution fails ${describeFailure(t)}`);
      else if (t.stderr && t.stderr.trim()) errors.push(`solution writes to stderr on test #${t.index + 1}: ${t.stderr.trim().slice(0, 200)}`);
      if (t.timeMs > 1000) notes.push(`solution is slow on test #${t.index + 1} (${t.timeMs} ms)`);
    }
  }

  if (q.type === 'FIND_THE_BUG') {
    const bug = await judge({ ...common, code: q.starter_code, harness, tests: testsOf(q) });
    if (!bug.compile.ok) errors.push(`buggy starter_code must compile (the bug must be a runtime/logic bug):\n${bug.compile.output}`);
    else if (bug.verdict === VERDICT.AC) errors.push('buggy starter_code passes ALL tests - the bug is not exercised by any test');
    else {
      const failing = bug.tests.filter((t) => t.verdict !== VERDICT.AC);
      notes.push(`buggy code fails ${failing.length}/${bug.tests.length} tests (${[...new Set(failing.map((t) => t.verdict))].join(', ')})`);
    }
  } else {
    const st = await judge({ ...common, code: q.starter_code, harness, compileOnly: true });
    if (!st.compile.ok) errors.push(`starter_code does not compile (users must start from a compiling template):\n${st.compile.output}`);
  }
  return { id: q.id, ok: errors.length === 0, errors, notes, ms: Date.now() - t0 };
}

// ------------------------------------------------------------------ bank-level checks

export function bankErrors(questions, { topics = TOPICS } = {}) {
  const errs = [];
  const ids = new Map();
  for (const q of questions) {
    if (ids.has(q.id)) errs.push(`duplicate id ${q.id}`);
    ids.set(q.id, q);
  }
  for (const topic of topics) {
    const qs = questions.filter((q) => q.topic === topic.name);
    const by = (k, v) => qs.filter((q) => q[k] === v).length;
    const counts = DIFFICULTIES.map((d) => by('difficulty', d));
    if (qs.length !== 30 || counts.some((c) => c !== 10))
      errs.push(`${topic.name}: expected 30 questions (10/10/10), found ${qs.length} (${counts.join('/')})`);
    const code = by('type', 'CODE') + by('type', 'FUNCTION');
    const pred = by('type', 'PREDICT_OUTPUT');
    const bug = by('type', 'FIND_THE_BUG');
    if (qs.length === 30) {
      if (pred < 5 || pred > 7) errs.push(`${topic.name}: PREDICT_OUTPUT count ${pred} (expected ~6, 5..7)`);
      if (bug < 5 || bug > 7) errs.push(`${topic.name}: FIND_THE_BUG count ${bug} (expected ~6, 5..7)`);
      if (code < 16) errs.push(`${topic.name}: CODE+FUNCTION count ${code} (expected ~18)`);
      const emb = qs.filter((q) => q.tags.includes('embedded')).length;
      if (emb < 9) errs.push(`${topic.name}: only ${emb} questions tagged "embedded" (need >= 30% = 9)`);
    }
    const titles = new Map();
    for (const q of qs) {
      const k = q.title.toLowerCase();
      if (titles.has(k)) errs.push(`${topic.name}: duplicate title "${q.title}" (${titles.get(k)}, ${q.id})`);
      titles.set(k, q.id);
    }
  }
  return errs;
}

export function bankStats(questions) {
  const stats = {};
  for (const q of questions) {
    const s = (stats[q.topic] ||= { total: 0, Easy: 0, Medium: 0, Hard: 0, CODE: 0, FUNCTION: 0, PREDICT_OUTPUT: 0, FIND_THE_BUG: 0, embedded: 0 });
    s.total++;
    s[q.difficulty]++;
    s[q.type]++;
    if (q.tags.includes('embedded')) s.embedded++;
  }
  return stats;
}
