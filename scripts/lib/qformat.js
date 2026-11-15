/**
 * Parser/serializer for the `.q` question source format (see docs/AUTHORING.md).
 *
 * A .q file is a sequence of sections, each introduced by a line `@@@ <name>`.
 * Section bodies are raw text, so C code and Markdown need no JSON escaping.
 */
import fs from 'node:fs';

export const SECTION_RE = /^@@@ ([a-z_]+)\s*$/;
export const AUTO = '<<AUTO>>';
const KNOWN = new Set([
  'meta', 'statement_md', 'constraints_md', 'starter_code', 'harness_code', 'sample_input', 'sample_output',
  'hidden_input', 'hidden_output', 'predict_answer', 'hint', 'solution_code', 'explanation_md',
]);

/** Split into raw sections: [{ name, lines, startLine, endLine }] (line numbers 0-based, body lines only). */
export function splitSections(text) {
  const lines = text.replace(/\r\n?/g, '\n').split('\n');
  const sections = [];
  let cur = null;
  lines.forEach((line, i) => {
    const m = SECTION_RE.exec(line);
    if (m) {
      if (cur) cur.endLine = i;
      cur = { name: m[1], lines: [], startLine: i + 1, endLine: lines.length };
      sections.push(cur);
    } else if (cur) cur.lines.push(line);
    else if (line.trim() !== '') throw new Error(`line ${i + 1}: text before the first @@@ section`);
  });
  return { sections, lines };
}

const trimBlankEdges = (lines) => {
  let a = 0;
  let b = lines.length;
  while (a < b && lines[a].trim() === '') a++;
  while (b > a && lines[b - 1].trim() === '') b--;
  return lines.slice(a, b);
};
const trimTrailingEmpty = (lines) => {
  let b = lines.length;
  while (b > 0 && lines[b - 1].trim() === '') b--;
  return lines.slice(0, b);
};

const asText = (lines) => trimBlankEdges(lines).join('\n');
const asCode = (lines) => {
  const t = trimBlankEdges(lines).join('\n');
  return t ? `${t}\n` : '';
};
const asInput = (lines) => {
  const body = trimTrailingEmpty(lines).map((l) => (l === '<<BLANK>>' ? '' : l));
  return body.length ? `${body.join('\n')}\n` : '';
};
const asOutput = (lines) => {
  const body = trimTrailingEmpty(lines);
  return body.length ? `${body.join('\n')}\n` : '';
};

function parseMeta(lines, file) {
  const meta = {};
  for (const raw of lines) {
    if (!raw.trim() || raw.trim().startsWith('#')) continue;
    const idx = raw.indexOf(':');
    if (idx < 0) throw new Error(`${file}: bad meta line "${raw}"`);
    meta[raw.slice(0, idx).trim()] = raw.slice(idx + 1).trim();
  }
  return meta;
}

/** Parse .q text into a question object following the strict JSON schema. */
export function parseQuestion(text, file = '<input>') {
  const { sections } = splitSections(text);
  const q = {
    id: '', topic: '', difficulty: '', type: '', title: '', tags: [],
    statement_md: '', constraints_md: '', starter_code: '', harness_code: '',
    sample_tests: [], hidden_tests: [], predict_answer: '', hints: [], solution_code: '', explanation_md: '',
  };
  let pendingInput = null;
  const seen = new Set();
  for (const s of sections) {
    if (!KNOWN.has(s.name)) throw new Error(`${file}: unknown section "@@@ ${s.name}"`);
    const single = !['hint', 'sample_input', 'sample_output', 'hidden_input', 'hidden_output'].includes(s.name);
    if (single && seen.has(s.name)) throw new Error(`${file}: duplicate section "@@@ ${s.name}"`);
    seen.add(s.name);
    switch (s.name) {
      case 'meta': {
        const m = parseMeta(s.lines, file);
        q.id = m.id || '';
        q.topic = m.topic || '';
        q.difficulty = m.difficulty || '';
        q.type = m.type || '';
        q.title = m.title || '';
        q.tags = (m.tags || '').split(',').map((t) => t.trim()).filter(Boolean);
        break;
      }
      case 'statement_md':
      case 'constraints_md':
      case 'explanation_md':
        q[s.name] = asText(s.lines);
        break;
      case 'starter_code':
      case 'harness_code':
      case 'solution_code':
        q[s.name] = asCode(s.lines);
        break;
      case 'predict_answer':
        q.predict_answer = trimTrailingEmpty(s.lines).join('\n');
        break;
      case 'hint':
        q.hints.push(asText(s.lines));
        break;
      case 'sample_input':
      case 'hidden_input':
        if (pendingInput) throw new Error(`${file}: ${pendingInput.kind}_input at line ${pendingInput.line} has no matching _output`);
        pendingInput = { kind: s.name.split('_')[0], value: asInput(s.lines), line: s.startLine };
        break;
      case 'sample_output':
      case 'hidden_output': {
        const kind = s.name.split('_')[0];
        if (!pendingInput || pendingInput.kind !== kind) throw new Error(`${file}: ${s.name} at line ${s.startLine} without a preceding ${kind}_input`);
        const out = trimBlankEdges(s.lines).join('\n') === AUTO ? AUTO : asOutput(s.lines);
        q[`${kind}_tests`].push({ input: pendingInput.value, output: out });
        pendingInput = null;
        break;
      }
      default:
        break;
    }
  }
  if (pendingInput) throw new Error(`${file}: ${pendingInput.kind}_input at line ${pendingInput.line} has no matching _output`);
  return q;
}

export function readQuestionFile(file) {
  return parseQuestion(fs.readFileSync(file, 'utf8'), file);
}

/**
 * Replace every `<<AUTO>>` output section of a .q file, in order, with the given outputs.
 * `outputsByKind` = { sample: [..per sample test..], hidden: [...] } (null entries are left untouched).
 */
export function fillAutoOutputs(text, outputsByKind) {
  const { sections, lines } = splitSections(text);
  const counters = { sample: 0, hidden: 0 };
  const replacements = [];
  for (const s of sections) {
    if (s.name !== 'sample_output' && s.name !== 'hidden_output') continue;
    const kind = s.name.split('_')[0];
    const idx = counters[kind]++;
    if (trimBlankEdges(s.lines).join('\n') !== AUTO) continue;
    const value = outputsByKind[kind]?.[idx];
    if (value == null) continue;
    const body = value.replace(/\r\n?/g, '\n').replace(/\n+$/, '');
    replacements.push({ start: s.startLine, end: s.endLine, body: body.split('\n') });
  }
  const out = [...lines];
  for (const r of replacements.reverse()) {
    // keep one blank line before the next section marker for readability
    out.splice(r.start, r.end - r.start, ...r.body, ...(r.end < lines.length ? [''] : []));
  }
  return { text: out.join('\n'), filled: replacements.length };
}

/** Serialize a question object to .q text (used by `qtool new` / converters). */
export function serializeQuestion(q) {
  const parts = [];
  const sec = (name, body) => parts.push(`@@@ ${name}`, body ?? '', '');
  sec('meta', [`id: ${q.id}`, `topic: ${q.topic}`, `difficulty: ${q.difficulty}`, `type: ${q.type}`, `title: ${q.title}`, `tags: ${q.tags.join(', ')}`].join('\n'));
  sec('statement_md', q.statement_md);
  sec('constraints_md', q.constraints_md);
  sec('starter_code', q.starter_code.replace(/\n$/, ''));
  if (q.harness_code) sec('harness_code', q.harness_code.replace(/\n$/, ''));
  for (const t of q.sample_tests) {
    sec('sample_input', t.input.replace(/\n$/, ''));
    sec('sample_output', t.output.replace(/\n$/, ''));
  }
  for (const t of q.hidden_tests) {
    sec('hidden_input', t.input.replace(/\n$/, ''));
    sec('hidden_output', t.output.replace(/\n$/, ''));
  }
  if (q.predict_answer) sec('predict_answer', q.predict_answer);
  for (const h of q.hints) sec('hint', h);
  sec('solution_code', q.solution_code.replace(/\n$/, ''));
  sec('explanation_md', q.explanation_md);
  return parts.join('\n');
}
