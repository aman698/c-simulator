import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../api';
import { readLS, useDebouncedEffect, writeLS } from '../hooks';
import { useApp } from '../state';
import type { JudgeResult, PredictResult, QuestionDetail, SavedCode, Solution } from '../types';
import { DifficultyBadge, Tag, TypeBadge, VerdictBadge } from './Badges';
import { CodeEditor, type CodeEditorHandle } from './CodeEditor';
import { Markdown } from './Markdown';
import { ResultsPanel, type PanelTab } from './ResultsPanel';
import { SplitPane } from './SplitPane';

interface Props {
  id: string;
  /** Interview mode: no hints, no solution, no custom input, separate code storage. */
  interviewId?: string;
  interviewLocked?: boolean;
  onJudged?: () => void;
}

export function QuestionWorkspace({ id, interviewId, interviewLocked, onJudged }: Props) {
  const { std, setStd, sanitizers, setSanitizers, refreshProgress } = useApp();
  const [q, setQ] = useState<QuestionDetail | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [result, setResult] = useState<JudgeResult | null>(null);
  const [running, setRunning] = useState<'run' | 'submit' | 'custom' | null>(null);
  const [judgeError, setJudgeError] = useState<string | null>(null);
  const [tab, setTab] = useState<PanelTab>('result');
  const [hintsShown, setHintsShown] = useState(0);
  const [attempted, setAttempted] = useState(false);
  const [solution, setSolution] = useState<Solution | null>(null);
  const [solutionError, setSolutionError] = useState<string | null>(null);
  const [customInput, setCustomInput] = useState('');
  const [predictAnswer, setPredictAnswer] = useState('');
  const [predict, setPredict] = useState<PredictResult | null>(null);
  const editor = useRef<CodeEditorHandle>(null);
  const dirty = useRef(false);
  const interview = Boolean(interviewId);
  const codeKey = interview ? `csim:icode:${interviewId}:${id}` : `csim:code:${id}`;

  // ---- load question + restore code
  useEffect(() => {
    let cancelled = false;
    setQ(null);
    setLoadError(null);
    setResult(null);
    setJudgeError(null);
    setTab('result');
    setHintsShown(0);
    setSolution(null);
    setSolutionError(null);
    setPredict(null);
    setPredictAnswer('');
    dirty.current = false;
    api.question(id).then(
      (detail) => {
        if (cancelled) return;
        setQ(detail);
        const local = readLS<SavedCode | null>(codeKey, null);
        const server = interview ? null : detail.saved;
        const best = [local, server].filter((x): x is SavedCode => !!x).sort((a, b) => b.updatedAt - a.updatedAt)[0];
        setCode(best?.code ?? detail.starter_code);
        setAttempted(Boolean(detail.progress && (detail.progress.attempts || 0) + (detail.progress.runs || 0) > 0));
        setCustomInput(detail.sample_tests[0]?.input ?? '');
      },
      (e: Error) => !cancelled && setLoadError(e.message),
    );
    return () => {
      cancelled = true;
    };
  }, [id, codeKey, interview]);

  // ---- auto-save (localStorage + backend)
  useDebouncedEffect(
    () => {
      if (!q || !dirty.current) return;
      const updatedAt = Date.now();
      writeLS(codeKey, { code, updatedAt });
      if (!interview) api.saveCode(id, code, updatedAt).catch(() => {});
    },
    [code],
    700,
  );

  const onCodeChange = (v: string) => {
    dirty.current = true;
    setCode(v);
  };

  const afterJudge = useCallback(
    (r: JudgeResult) => {
      setResult(r);
      setAttempted(true);
      setTab('result');
      void refreshProgress();
      onJudged?.();
    },
    [refreshProgress, onJudged],
  );

  const run = useCallback(async () => {
    if (!q || running || interviewLocked) return;
    setRunning('run');
    setJudgeError(null);
    try {
      afterJudge(await api.run(id, { code, std, sanitizers }));
    } catch (e) {
      setJudgeError((e as Error).message);
    } finally {
      setRunning(null);
    }
  }, [q, running, interviewLocked, id, code, std, sanitizers, afterJudge]);

  const submit = useCallback(async () => {
    if (!q || running || interviewLocked) return;
    setRunning('submit');
    setJudgeError(null);
    try {
      afterJudge(await api.submit(id, { code, std, sanitizers, interviewId }));
    } catch (e) {
      setJudgeError((e as Error).message);
    } finally {
      setRunning(null);
    }
  }, [q, running, interviewLocked, id, code, std, sanitizers, interviewId, afterJudge]);

  const runCustom = useCallback(async () => {
    if (!q || running) return;
    setRunning('custom');
    setJudgeError(null);
    try {
      const r = await api.run(id, { code, std, sanitizers, customInput });
      afterJudge(r);
      setTab('custom');
    } catch (e) {
      setJudgeError((e as Error).message);
    } finally {
      setRunning(null);
    }
  }, [q, running, id, code, std, sanitizers, customInput, afterJudge]);

  const submitPredict = useCallback(
    async (answer: string) => {
      if (!q || running || interviewLocked) return;
      setRunning('submit');
      setJudgeError(null);
      try {
        const r = await api.predict(id, answer, interviewId);
        setPredict(r);
        setAttempted(true);
        void refreshProgress();
        onJudged?.();
      } catch (e) {
        setJudgeError((e as Error).message);
      } finally {
        setRunning(null);
      }
    },
    [q, running, interviewLocked, id, interviewId, refreshProgress, onJudged],
  );

  // global shortcuts when focus is outside Monaco (Monaco handles its own)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!(e.ctrlKey || e.metaKey) || e.key !== 'Enter') return;
      if ((e.target as HTMLElement | null)?.closest?.('.monaco-editor')) return;
      if (q?.type === 'PREDICT_OUTPUT') {
        if ((e.target as HTMLElement | null)?.tagName === 'TEXTAREA') {
          e.preventDefault();
          void submitPredict(predictAnswer);
        }
        return;
      }
      e.preventDefault();
      if (e.shiftKey) void submit();
      else void run();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [q, run, submit, submitPredict, predictAnswer]);

  const loadSolution = async () => {
    setSolutionError(null);
    try {
      setSolution(await api.solution(id));
    } catch (e) {
      setSolutionError((e as Error).message);
    }
  };

  const resetCode = () => {
    if (!q) return;
    if (!window.confirm('Reset the editor to the starter code? Your current code will be lost.')) return;
    dirty.current = true;
    setCode(q.starter_code);
  };

  if (loadError) return <div className="p-6 text-rose-300">{loadError}</div>;
  if (!q) return <div className="p-6 text-slate-500">Loading question…</div>;

  const isPredict = q.type === 'PREDICT_OUTPUT';
  const errorLine = result?.tests.find((t) => t.verdict !== 'Accepted' && t.line)?.line ?? null;

  // ------------------------------------------------------------ left pane
  const left = (
    <div className="h-full overflow-y-auto px-5 py-4">
      <div className="mb-1 font-mono text-xs text-slate-500">{q.id} · {q.topic}</div>
      <h1 className="text-lg font-semibold text-slate-100">{q.title}</h1>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <DifficultyBadge d={q.difficulty} />
        <TypeBadge t={q.type} />
        {q.progress?.status === 'solved' && <span className="text-xs font-medium text-emerald-300">✓ Solved</span>}
      </div>

      {q.track === 'freertos' && (
        <details className="mt-4 rounded-md border border-sky-500/20 bg-sky-500/5 px-3 py-2 text-xs text-slate-300">
          <summary className="cursor-pointer font-semibold text-sky-300">FreeRTOS simulator: how time works</summary>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Real FreeRTOS-Kernel V11.3.3 on a deterministic virtual-time port. 1 tick = 1 ms.</li>
            <li>
              Your code runs in <b>zero simulated time</b>. Ticks advance only while every task is blocked, or inside{' '}
              <code>vSimBusyWork(n)</code> (CPU work of n ticks that can be preempted and time-sliced).
            </li>
            <li>Priorities 0-7: use 1-6 for your tasks (0 = idle, 7 = timer service task). Preemption and time slicing are on.</li>
            <li>A task that never blocks starves the idle task, so time stops and you get Time Limit Exceeded.</li>
            <li>Blocking APIs inside an ISR, failed <code>configASSERT</code>s and tasks that return are reported as Runtime Errors.</li>
          </ul>
        </details>
      )}

      <Markdown className="mt-4">{q.statement_md}</Markdown>

      {q.constraints_md && (
        <section className="mt-5">
          <h2 className="mb-1 text-sm font-semibold text-slate-200">Constraints</h2>
          <Markdown>{q.constraints_md}</Markdown>
        </section>
      )}

      {!isPredict && q.sample_tests.length > 0 && (
        <section className="mt-5 space-y-3">
          <h2 className="text-sm font-semibold text-slate-200">Sample tests</h2>
          {q.type === 'FUNCTION' && (
            <p className="text-xs text-slate-400">A hidden <code className="text-slate-300">main()</code> reads this input, calls your function and prints the result.</p>
          )}
          {q.sample_tests.map((t, i) => (
            <div key={i} className="grid gap-2 sm:grid-cols-2">
              <div>
                <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-slate-400">Input {i + 1}</div>
                <pre className="io">{t.input || ' '}</pre>
              </div>
              <div>
                <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-slate-400">Output {i + 1}</div>
                <pre className="io">{t.output || ' '}</pre>
              </div>
            </div>
          ))}
          <p className="text-xs text-slate-500">+ {q.hidden_test_count} hidden tests on Submit.</p>
        </section>
      )}

      {q.tags.length > 0 && (
        <div className="mt-5 flex flex-wrap gap-1.5">
          {q.tags.map((t) => (
            <Tag key={t}>{t}</Tag>
          ))}
        </div>
      )}

      {!interview && (
        <section className="mt-6 space-y-3 border-t border-slate-800 pt-4">
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setHintsShown((n) => Math.min(q.hints.length, n + 1))}
              disabled={hintsShown >= q.hints.length}
              className="rounded-md bg-slate-800 px-3 py-1.5 text-xs font-medium text-slate-200 ring-1 ring-slate-700 hover:bg-slate-700 disabled:opacity-40"
            >
              💡 {hintsShown >= q.hints.length ? 'No more hints' : `Hint ${hintsShown + 1} of ${q.hints.length}`}
            </button>
            <button
              onClick={loadSolution}
              disabled={!attempted || !!solution}
              title={attempted ? 'Show the reference solution and explanation' : 'Make at least one attempt (Run or Submit) to unlock'}
              className="rounded-md bg-slate-800 px-3 py-1.5 text-xs font-medium text-slate-200 ring-1 ring-slate-700 hover:bg-slate-700 disabled:opacity-40"
            >
              {attempted ? '📖 Show solution' : '🔒 Solution (attempt first)'}
            </button>
          </div>
          {q.hints.slice(0, hintsShown).map((h, i) => (
            <div key={i} className="rounded-md border border-amber-500/20 bg-amber-500/5 px-3 py-2">
              <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-amber-300">Hint {i + 1}</div>
              <Markdown>{h}</Markdown>
            </div>
          ))}
          {solutionError && <p className="text-xs text-rose-300">{solutionError}</p>}
          {solution && (
            <div className="space-y-3 rounded-md border border-sky-500/20 bg-sky-500/5 px-3 py-3">
              <div className="text-[11px] font-semibold uppercase tracking-wide text-sky-300">Explanation</div>
              <Markdown>{solution.explanation_md}</Markdown>
              <div className="text-[11px] font-semibold uppercase tracking-wide text-sky-300">{isPredict ? 'Annotated snippet' : 'Reference solution'}</div>
              <Markdown>{'```c\n' + solution.solution_code + '```'}</Markdown>
              {!isPredict && (
                <button
                  onClick={() => {
                    if (window.confirm('Replace your code with the reference solution?')) {
                      dirty.current = true;
                      setCode(solution.solution_code);
                    }
                  }}
                  className="text-xs text-sky-300 hover:underline"
                >
                  Load into editor
                </button>
              )}
            </div>
          )}
        </section>
      )}
    </div>
  );

  // ------------------------------------------------------------ right pane
  const toolbar = (
    <div className="flex flex-wrap items-center gap-2 border-b border-slate-800 bg-[#0f1524] px-3 py-2">
      <select
        value={std}
        onChange={(e) => setStd(e.target.value as 'c99' | 'c11')}
        className="rounded-md border border-slate-700 bg-slate-900 px-2 py-1 text-xs text-slate-200"
        title="C language standard"
      >
        <option value="c11">C11</option>
        <option value="c99">C99</option>
      </select>
      <label className="flex cursor-pointer items-center gap-1.5 text-xs text-slate-300" title="AddressSanitizer + UndefinedBehaviorSanitizer + LeakSanitizer">
        <input type="checkbox" checked={sanitizers} onChange={(e) => setSanitizers(e.target.checked)} className="accent-sky-500" />
        Sanitizers {sanitizers ? 'ON' : 'OFF'}
      </label>
      {q.topic === 'Dynamic Memory' && <span className="text-[11px] text-fuchsia-300" title="This topic always checks for leaks">leak check always on</span>}
      <div className="ml-auto flex items-center gap-2">
        <button onClick={resetCode} className="rounded-md px-2 py-1 text-xs text-slate-400 hover:bg-slate-800 hover:text-slate-200" title="Reset to starter code">
          ↺ Reset
        </button>
        <button
          onClick={run}
          disabled={!!running || interviewLocked}
          className="rounded-md bg-slate-700 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-600 disabled:opacity-50"
          title="Run sample tests (Ctrl+Enter)"
        >
          {running === 'run' ? 'Running…' : '▶ Run'}
        </button>
        <button
          onClick={submit}
          disabled={!!running || interviewLocked}
          className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
          title="Submit: all tests including hidden (Ctrl+Shift+Enter)"
        >
          {running === 'submit' ? 'Judging…' : 'Submit'}
        </button>
      </div>
    </div>
  );

  const right = isPredict ? (
    <SplitPane direction="vertical" initial={0.55} storageKey="predict-v" minPx={120}>
      <div className="flex h-full flex-col">
        <div className="border-b border-slate-800 bg-[#0f1524] px-3 py-2 text-xs text-slate-400">Snippet (read-only)</div>
        <div className="min-h-0 flex-1">
          <CodeEditor value={q.starter_code} readOnly path={`${q.id}-snippet.c`} />
        </div>
      </div>
      <div className="h-full overflow-y-auto bg-[#0d1220] p-4">
        <label className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-400" htmlFor="predict-answer">
          Exact program output
        </label>
        <textarea
          id="predict-answer"
          value={predictAnswer}
          onChange={(e) => setPredictAnswer(e.target.value)}
          spellCheck={false}
          rows={5}
          className="w-full resize-y rounded-md border border-slate-700 bg-[#0d1117] p-2 font-mono text-sm text-slate-100 outline-none focus:border-sky-500"
          placeholder="Type exactly what the program prints"
        />
        <div className="mt-2 flex flex-wrap gap-2">
          <button
            onClick={() => submitPredict(predictAnswer)}
            disabled={!!running || interviewLocked || !predictAnswer.trim()}
            className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
          >
            Submit answer
          </button>
          <button
            onClick={() => submitPredict('Undefined Behavior')}
            disabled={!!running || interviewLocked}
            className="rounded-md bg-slate-800 px-3 py-1.5 text-xs font-semibold text-amber-200 ring-1 ring-amber-500/30 hover:bg-slate-700 disabled:opacity-50"
          >
            Undefined Behavior
          </button>
          <button
            onClick={() => submitPredict('Compile Error')}
            disabled={!!running || interviewLocked}
            className="rounded-md bg-slate-800 px-3 py-1.5 text-xs font-semibold text-rose-200 ring-1 ring-rose-500/30 hover:bg-slate-700 disabled:opacity-50"
          >
            Compile Error
          </button>
        </div>
        {judgeError && <p className="mt-3 text-sm text-rose-300">{judgeError}</p>}
        {predict && (
          <div className="mt-4 space-y-3">
            <VerdictBadge v={predict.correct ? 'Accepted' : 'Wrong Answer'} large />
            {predict.expected != null && (
              <div>
                <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-emerald-300">Correct answer</div>
                <pre className="io">{predict.expected}</pre>
              </div>
            )}
            {predict.explanation_md && <Markdown>{predict.explanation_md}</Markdown>}
            {interview && <p className="text-xs text-slate-400">The answer and explanation are revealed after the interview.</p>}
          </div>
        )}
      </div>
    </SplitPane>
  ) : (
    <SplitPane direction="vertical" initial={0.62} storageKey="editor-v" minPx={120}>
      <div className="flex h-full flex-col">
        {toolbar}
        <div className="min-h-0 flex-1">
          <CodeEditor
            ref={editor}
            value={code}
            onChange={onCodeChange}
            diagnostics={result?.compile.diagnostics}
            errorLine={errorLine}
            onRun={run}
            onSubmit={submit}
            path={`${interviewId ? `${interviewId}-` : ''}${q.id}.c`}
          />
        </div>
      </div>
      <ResultsPanel
        result={result}
        running={running}
        error={judgeError}
        tab={tab}
        setTab={setTab}
        onJumpToLine={(line, col) => editor.current?.revealLine(line, col)}
        customInput={customInput}
        setCustomInput={setCustomInput}
        onRunCustom={runCustom}
        allowCustom={!interview}
      />
    </SplitPane>
  );

  return (
    <SplitPane direction="horizontal" initial={0.42} storageKey="question-h" minPx={300}>
      {left}
      {right}
    </SplitPane>
  );
}
