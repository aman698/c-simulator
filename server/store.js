/**
 * User progress persisted in data/progress.json (single local user).
 * Writes are debounced and atomic (temp file + rename).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { DATA_DIR } from './paths.js';

const FILE = path.join(DATA_DIR, 'progress.json');
const MAX_SUBMISSIONS = 500;

function empty() {
  return { version: 1, questions: {}, submissions: [], code: {}, activity: {}, interviews: [] };
}

let state = empty();
try {
  state = { ...empty(), ...JSON.parse(fs.readFileSync(FILE, 'utf8')) };
} catch {
  /* first run */
}

let timer = null;
function persist() {
  if (timer) return;
  timer = setTimeout(() => {
    timer = null;
    fs.mkdirSync(DATA_DIR, { recursive: true });
    const tmp = `${FILE}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(state, null, 1));
    try {
      fs.renameSync(tmp, FILE);
    } catch {
      fs.writeFileSync(FILE, JSON.stringify(state, null, 1));
    }
  }, 250);
}

export function flush() {
  if (timer) {
    clearTimeout(timer);
    timer = null;
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(FILE, JSON.stringify(state, null, 1));
  }
}

/** Local calendar day, YYYY-MM-DD. */
export function dayKey(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function streaks(activity) {
  const days = new Set(Object.keys(activity).filter((k) => activity[k] > 0));
  const step = (d, delta) => {
    const x = new Date(d);
    x.setDate(x.getDate() + delta);
    return x;
  };
  let current = 0;
  let cursor = new Date();
  if (!days.has(dayKey(cursor))) cursor = step(cursor, -1); // a streak survives until the day ends
  while (days.has(dayKey(cursor))) {
    current++;
    cursor = step(cursor, -1);
  }
  let longest = 0;
  const sorted = [...days].sort();
  let run = 0;
  let prev = null;
  for (const k of sorted) {
    const d = new Date(`${k}T12:00:00`);
    run = prev && Math.round((d - prev) / 86400000) === 1 ? run + 1 : 1;
    longest = Math.max(longest, run);
    prev = d;
  }
  return { current, longest };
}

export function getProgress() {
  return {
    questions: state.questions,
    submissions: state.submissions.slice(0, 50),
    activity: state.activity,
    streak: streaks(state.activity),
    interviews: state.interviews.slice(0, 20),
  };
}

export function questionProgress(id) {
  return state.questions[id] || null;
}

/**
 * Record a judged attempt. kind: 'run' | 'submit' | 'predict' | 'interview'.
 * Only submit/predict/interview count towards solved status, streak and the history list;
 * a run marks the question as attempted (which also unlocks the solution).
 */
export function recordAttempt(q, { kind, verdict, passed = null, total = null, timeMs = null }) {
  const now = new Date().toISOString();
  const p = (state.questions[q.id] ||= { status: 'attempted', attempts: 0, runs: 0, firstAttemptAt: now });
  if (kind === 'run') p.runs = (p.runs || 0) + 1;
  else {
    p.attempts++;
    p.lastVerdict = verdict;
    p.lastSubmittedAt = now;
    if (verdict === 'Accepted' || verdict === 'Correct') {
      if (p.status !== 'solved') p.solvedAt = now;
      p.status = 'solved';
    }
    const sub = {
      id: crypto.randomUUID(),
      questionId: q.id,
      title: q.title,
      topic: q.topic,
      difficulty: q.difficulty,
      kind,
      verdict,
      passed,
      total,
      timeMs,
      at: now,
    };
    state.submissions.unshift(sub);
    if (state.submissions.length > MAX_SUBMISSIONS) state.submissions.length = MAX_SUBMISSIONS;
    const day = dayKey();
    state.activity[day] = (state.activity[day] || 0) + 1;
  }
  persist();
  return p;
}

export function getSavedCode(id) {
  return state.code[id] || null;
}

export function saveCode(id, code, updatedAt = Date.now()) {
  state.code[id] = { code: String(code).slice(0, 200000), updatedAt };
  persist();
  return state.code[id];
}

// ---------------------------------------------------------------- interviews

export function createInterview(session) {
  state.interviews.unshift(session);
  if (state.interviews.length > 100) state.interviews.length = 100;
  persist();
  return session;
}

export function getInterview(id) {
  return state.interviews.find((s) => s.id === id) || null;
}

export function updateInterview(id, fn) {
  const s = getInterview(id);
  if (!s) return null;
  fn(s);
  persist();
  return s;
}

export function resetProgress() {
  state = empty();
  persist();
}
