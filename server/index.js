/**
 * C Practice Simulator - judge + API server (Express).
 *   node server/index.js            API on :3001 (Vite dev server proxies /api)
 *   node server/index.js --serve    also serves the production build from dist/
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import express from 'express';
import { DIST_DIR } from './paths.js';
import { TOPICS, needsLeakCheck } from './topics.js';
import { allQuestions, getQuestion, publicView, summary } from './questions.js';
import * as store from './store.js';
import { getToolchain, describeSanitizers } from './judge/toolchain.js';
import { judge, buildCompilePlan, normalizeOutput, VERDICT } from './judge/judge.js';

const PORT = Number(process.env.PORT) || 3001;
const HOST = process.env.HOST || '127.0.0.1';
const MAX_CODE = 100 * 1024;
const MAX_STDIN = 1024 * 1024;
const INTERVIEW_MS = 45 * 60 * 1000;
const INTERVIEW_POINTS = { Easy: 20, Medium: 30, Hard: 50 };

const app = express();
app.use(express.json({ limit: '2mb' }));

const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

function requireQuestion(id) {
  const q = getQuestion(id);
  if (!q) throw httpError(404, `Unknown question ${id}`);
  return q;
}

function judgeOptions(body) {
  const code = String(body.code ?? '');
  if (code.length > MAX_CODE) throw httpError(413, 'Code is too large (max 100 KB)');
  return {
    code,
    std: body.std === 'c99' ? 'c99' : 'c11',
    sanitizers: body.sanitizers !== false,
  };
}

/** Hide hidden-test data except for the first failing hidden test (LeetCode style). */
function shapeTests(result, sampleCount) {
  const firstHiddenFail = result.tests.find((t) => t.index >= sampleCount && t.verdict !== VERDICT.AC);
  result.tests = result.tests.map((t) => {
    const hidden = t.index >= sampleCount;
    if (!hidden || t === firstHiddenFail) return { ...t, hidden };
    return { index: t.index, hidden, verdict: t.verdict, message: t.message, timeMs: t.timeMs, exitCode: t.exitCode, line: t.line };
  });
  return result;
}

// ---------------------------------------------------------------- meta

app.get(
  '/api/health',
  wrap(async (_req, res) => {
    const tc = await getToolchain();
    const qs = allQuestions();
    res.json({
      ok: tc.mode !== 'none',
      questions: qs.length,
      toolchain:
        tc.mode === 'none'
          ? { mode: 'none', error: tc.error }
          : {
              mode: tc.mode,
              version: tc.version,
              machine: tc.machine,
              platform: tc.platform,
              support: tc.support,
              sanitizers: describeSanitizers(tc),
              command: buildCompilePlan(tc, { std: 'c11', sanitizers: true }).display,
            },
    });
  }),
);

app.get('/api/topics', (_req, res) => {
  const qs = allQuestions();
  res.json(TOPICS.map((t) => ({ ...t, count: qs.filter((q) => q.topic === t.name).length })));
});

app.get('/api/questions', (_req, res) => res.json(allQuestions().map(summary)));

app.get('/api/questions/:id', (req, res) => {
  const q = requireQuestion(req.params.id);
  const p = store.questionProgress(q.id);
  res.json({ ...publicView(q), progress: p, saved: store.getSavedCode(q.id) });
});

app.get('/api/questions/:id/solution', (req, res) => {
  const q = requireQuestion(req.params.id);
  const p = store.questionProgress(q.id);
  if (!p || (p.attempts || 0) + (p.runs || 0) < 1) throw httpError(403, 'Make at least one attempt to unlock the solution.');
  res.json({ solution_code: q.solution_code, explanation_md: q.explanation_md, predict_answer: q.predict_answer || null });
});

// ---------------------------------------------------------------- judging

app.post(
  '/api/questions/:id/run',
  wrap(async (req, res) => {
    const q = requireQuestion(req.params.id);
    if (q.type === 'PREDICT_OUTPUT') throw httpError(400, 'Use /predict for PREDICT_OUTPUT questions');
    const opts = judgeOptions(req.body);
    const harness = q.harness_code || null;
    const leakCheck = needsLeakCheck(q);
    let result;
    if (typeof req.body.customInput === 'string') {
      const input = req.body.customInput.slice(0, MAX_STDIN);
      // Expected output for custom input comes from the reference solution.
      const ref = await judge({ ...opts, code: q.solution_code, harness, leakCheck, tests: [{ input, output: null }] });
      const refTest = ref.tests[0];
      const expected = ref.compile.ok && refTest?.verdict === VERDICT.AC ? refTest.stdout : null;
      result = await judge({ ...opts, harness, leakCheck, tests: [{ input, output: expected }] });
      result.custom = true;
      if (expected == null) result.referenceNote = 'The reference solution rejected this input (outside the constraints?), so the output was not compared.';
    } else {
      result = await judge({ ...opts, harness, leakCheck, tests: q.sample_tests });
    }
    store.recordAttempt(q, { kind: 'run', verdict: result.verdict });
    res.json(result);
  }),
);

function updateInterviewResult(interviewId, q, verdict, passed, total) {
  if (!interviewId) return null;
  return store.updateInterview(interviewId, (s) => {
    if (s.finishedAt || !s.questionIds.includes(q.id)) return;
    if (Date.now() > Date.parse(s.startedAt) + s.durationMs + 30000) return; // time is up
    const r = (s.results[q.id] ||= { attempts: 0, bestPassed: 0, total, verdict: null });
    r.attempts++;
    r.total = total;
    if (passed > r.bestPassed || r.verdict == null || verdict === VERDICT.AC) {
      r.bestPassed = Math.max(r.bestPassed, passed);
      if (r.verdict !== VERDICT.AC) r.verdict = verdict;
    }
  });
}

app.post(
  '/api/questions/:id/submit',
  wrap(async (req, res) => {
    const q = requireQuestion(req.params.id);
    if (q.type === 'PREDICT_OUTPUT') throw httpError(400, 'Use /predict for PREDICT_OUTPUT questions');
    const opts = judgeOptions(req.body);
    const tests = [...q.sample_tests, ...q.hidden_tests];
    const result = await judge({ ...opts, harness: q.harness_code || null, leakCheck: needsLeakCheck(q), tests });
    const maxTime = result.tests.reduce((m, t) => Math.max(m, t.timeMs || 0), 0);
    store.recordAttempt(q, {
      kind: req.body.interviewId ? 'interview' : 'submit',
      verdict: result.verdict,
      passed: result.passed,
      total: result.total,
      timeMs: maxTime,
    });
    updateInterviewResult(req.body.interviewId, q, result.verdict, result.passed, result.total);
    res.json(shapeTests(result, q.sample_tests.length));
  }),
);

app.post('/api/questions/:id/predict', (req, res) => {
  const q = requireQuestion(req.params.id);
  if (q.type !== 'PREDICT_OUTPUT') throw httpError(400, 'Not a PREDICT_OUTPUT question');
  const answer = String(req.body.answer ?? '');
  const expected = q.predict_answer;
  const special = ['undefined behavior', 'compile error'];
  const norm = (s) => {
    const n = normalizeOutput(s);
    return special.includes(n.trim().toLowerCase()) ? n.trim().toLowerCase() : n;
  };
  const correct = norm(answer) === norm(expected);
  const verdict = correct ? VERDICT.AC : VERDICT.WA;
  store.recordAttempt(q, { kind: req.body.interviewId ? 'interview' : 'predict', verdict, passed: correct ? 1 : 0, total: 1 });
  updateInterviewResult(req.body.interviewId, q, verdict, correct ? 1 : 0, 1);
  res.json({
    correct,
    verdict,
    // In an interview the answer is revealed only at the end.
    expected: req.body.interviewId ? null : expected,
    explanation_md: req.body.interviewId ? null : q.explanation_md,
    solution_code: req.body.interviewId ? null : q.solution_code,
  });
});

app.post(
  '/api/playground',
  wrap(async (req, res) => {
    const opts = judgeOptions(req.body);
    const stdin = String(req.body.stdin ?? '').slice(0, MAX_STDIN);
    const result = await judge({ ...opts, leakCheck: Boolean(req.body.leakCheck), tests: [{ input: stdin, output: null }] });
    res.json(result);
  }),
);

// ---------------------------------------------------------------- progress / code

app.get('/api/progress', (_req, res) => res.json(store.getProgress()));

app.get('/api/code/:id', (req, res) => res.json(store.getSavedCode(req.params.id)));

app.put('/api/code/:id', (req, res) => {
  requireQuestion(req.params.id);
  const code = String(req.body.code ?? '');
  if (code.length > MAX_CODE) throw httpError(413, 'Code is too large');
  res.json(store.saveCode(req.params.id, code, Number(req.body.updatedAt) || Date.now()));
});

// ---------------------------------------------------------------- interview mode

function pick(arr) {
  return arr[crypto.randomInt(arr.length)];
}

function interviewView(s) {
  const remainingMs = s.finishedAt ? 0 : Math.max(0, Date.parse(s.startedAt) + s.durationMs - Date.now());
  return {
    ...s,
    remainingMs,
    questions: s.questionIds.map((id) => {
      const q = getQuestion(id);
      return q ? summary(q) : { id, title: '(removed)', difficulty: 'Easy', topic: '', type: 'CODE', tags: [] };
    }),
  };
}

app.post('/api/interview/start', (req, res) => {
  const wanted = Array.isArray(req.body.topics) && req.body.topics.length ? req.body.topics : TOPICS.map((t) => t.name);
  const pool = allQuestions().filter((q) => wanted.includes(q.topic));
  const questionIds = [];
  for (const d of ['Easy', 'Medium', 'Hard']) {
    const coding = pool.filter((q) => q.difficulty === d && q.type !== 'PREDICT_OUTPUT');
    const any = pool.filter((q) => q.difficulty === d);
    const from = coding.length ? coding : any;
    if (!from.length) throw httpError(400, `No ${d} questions in the selected topics`);
    questionIds.push(pick(from).id);
  }
  const session = store.createInterview({
    id: crypto.randomUUID(),
    topics: wanted,
    questionIds,
    startedAt: new Date().toISOString(),
    durationMs: INTERVIEW_MS,
    finishedAt: null,
    results: {},
    score: null,
  });
  res.json(interviewView(session));
});

app.get('/api/interview/:id', (req, res) => {
  const s = store.getInterview(req.params.id);
  if (!s) throw httpError(404, 'Unknown interview');
  res.json(interviewView(s));
});

app.post('/api/interview/:id/finish', (req, res) => {
  const s = store.updateInterview(req.params.id, (x) => {
    if (x.finishedAt) return;
    x.finishedAt = new Date().toISOString();
    let score = 0;
    const breakdown = x.questionIds.map((id) => {
      const q = getQuestion(id);
      const r = x.results[id];
      const max = INTERVIEW_POINTS[q?.difficulty] || 0;
      const pts = r && r.total ? (r.verdict === VERDICT.AC ? max : Math.round((max * r.bestPassed) / r.total)) : 0;
      score += pts;
      return { id, points: pts, max, verdict: r?.verdict || 'Not attempted', passed: r?.bestPassed || 0, total: r?.total || 0 };
    });
    x.score = score;
    x.breakdown = breakdown;
    x.elapsedMs = Math.min(x.durationMs, Date.parse(x.finishedAt) - Date.parse(x.startedAt));
  });
  if (!s) throw httpError(404, 'Unknown interview');
  res.json(interviewView(s));
});

// ---------------------------------------------------------------- static (production)

if (process.argv.includes('--serve') && fs.existsSync(DIST_DIR)) {
  app.use(express.static(DIST_DIR));
  app.get(/^\/(?!api\/).*/, (_req, res) => res.sendFile(path.join(DIST_DIR, 'index.html')));
}

app.use('/api', (_req, res) => res.status(404).json({ error: 'Not found' }));

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({ error: err.message || 'Internal error' });
});

const server = app.listen(PORT, HOST, async () => {
  console.log(`[judge] API listening on http://${HOST}:${PORT}`);
  const tc = await getToolchain();
  if (tc.mode === 'none') console.log(`[judge] WARNING: ${tc.error}`);
  else {
    console.log(`[judge] compiler: ${tc.version} (${tc.mode}, ${tc.machine})`);
    console.log(`[judge] sanitizers: ${describeSanitizers(tc)}`);
  }
  console.log(`[judge] ${allQuestions().length} questions loaded`);
  if (process.argv.includes('--serve')) console.log(`[judge] open http://localhost:${PORT}`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    store.flush();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 1000).unref();
  });
}
