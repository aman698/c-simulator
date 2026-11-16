import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { DifficultyBadge, TypeBadge, VerdictBadge } from '../components/Badges';
import { QuestionWorkspace } from '../components/QuestionWorkspace';
import { formatDuration, readLS, removeLS, useNow, writeLS } from '../hooks';
import { useApp } from '../state';
import type { InterviewSession } from '../types';

const ACTIVE_KEY = 'csim:interview:active';

export function InterviewPage() {
  const { topics, refreshProgress } = useApp();
  const [activeId, setActiveId] = useState<string | null>(() => readLS<string | null>(ACTIVE_KEY, null));
  const [session, setSession] = useState<InterviewSession | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [current, setCurrent] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const now = useNow(1000, Boolean(session && !session.finishedAt));

  useEffect(() => {
    if (topics.length && selected.length === 0) setSelected(topics.map((t) => t.name));
  }, [topics, selected.length]);

  const reloadSession = useCallback(async () => {
    if (!activeId) return;
    try {
      setSession(await api.interview(activeId));
    } catch {
      removeLS(ACTIVE_KEY);
      setActiveId(null);
      setSession(null);
    }
  }, [activeId]);

  useEffect(() => {
    void reloadSession();
  }, [reloadSession]);

  const remaining = session ? Math.max(0, Date.parse(session.startedAt) + session.durationMs - now) : 0;

  const finish = useCallback(async () => {
    if (!session || session.finishedAt) return;
    setBusy(true);
    try {
      setSession(await api.finishInterview(session.id));
      void refreshProgress();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }, [session, refreshProgress]);

  // auto-finish when the clock runs out
  useEffect(() => {
    if (session && !session.finishedAt && remaining <= 0) void finish();
  }, [session, remaining, finish]);

  const start = async () => {
    setError(null);
    setBusy(true);
    try {
      const s = await api.startInterview(selected);
      writeLS(ACTIVE_KEY, s.id);
      setActiveId(s.id);
      setSession(s);
      setCurrent(0);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const reset = () => {
    removeLS(ACTIVE_KEY);
    setActiveId(null);
    setSession(null);
  };

  // ---------------------------------------------------------------- setup
  if (!session) {
    return (
      <div className="h-full overflow-y-auto">
        <div className="mx-auto max-w-2xl space-y-5 px-6 py-8">
          <div>
            <h1 className="text-xl font-semibold text-slate-100">Interview Mode</h1>
            <p className="mt-1 text-sm text-slate-400">
              Three random questions (1 Easy, 1 Medium, 1 Hard) from the topics you choose, a 45-minute timer, no hints and no solutions. Points:
              Easy 20, Medium 30, Hard 50, with partial credit for passed tests.
            </p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-[#0f1524] p-4">
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-slate-200">Topics</h2>
              <div className="space-x-3 text-xs">
                <button onClick={() => setSelected(topics.map((t) => t.name))} className="text-sky-300 hover:underline">
                  All
                </button>
                <button onClick={() => setSelected([])} className="text-sky-300 hover:underline">
                  None
                </button>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {topics.map((t) => (
                <label key={t.slug} className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm text-slate-300 hover:bg-slate-800/60">
                  <input
                    type="checkbox"
                    className="accent-sky-500"
                    checked={selected.includes(t.name)}
                    onChange={(e) => setSelected((s) => (e.target.checked ? [...s, t.name] : s.filter((x) => x !== t.name)))}
                  />
                  {t.name}
                  <span className="ml-auto text-xs text-slate-500">{t.count}</span>
                </label>
              ))}
            </div>
          </div>
          {error && <p className="text-sm text-rose-300">{error}</p>}
          <button
            onClick={start}
            disabled={busy || selected.length === 0}
            className="rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
          >
            Start 45-minute interview
          </button>
        </div>
      </div>
    );
  }

  // ---------------------------------------------------------------- summary
  if (session.finishedAt) {
    return (
      <div className="h-full overflow-y-auto">
        <div className="mx-auto max-w-3xl space-y-5 px-6 py-8">
          <h1 className="text-xl font-semibold text-slate-100">Interview finished</h1>
          <div className="flex items-end gap-6 rounded-xl border border-slate-800 bg-[#0f1524] p-5">
            <div>
              <div className="text-xs font-medium text-slate-400">Score</div>
              <div className="text-4xl font-semibold tabular-nums text-slate-100">
                {session.score ?? 0}
                <span className="text-lg text-slate-500"> / 100</span>
              </div>
            </div>
            <div className="text-sm text-slate-400">Time used: {formatDuration(session.elapsedMs ?? session.durationMs)} of 45:00</div>
          </div>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs text-slate-500">
                <th className="py-1.5 font-medium">Question</th>
                <th className="py-1.5 font-medium">Verdict</th>
                <th className="py-1.5 text-right font-medium">Tests</th>
                <th className="py-1.5 text-right font-medium">Points</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70">
              {session.questions.map((q) => {
                const b = session.breakdown?.find((x) => x.id === q.id);
                return (
                  <tr key={q.id}>
                    <td className="py-2.5 pr-3">
                      <div className="flex items-center gap-2">
                        <DifficultyBadge d={q.difficulty} small />
                        <Link to={`/problems/${q.id}`} className="text-slate-200 hover:text-sky-300">
                          {q.title}
                        </Link>
                      </div>
                      <div className="text-[11px] text-slate-500">
                        {q.id} · {q.topic}
                      </div>
                    </td>
                    <td className="py-2.5 pr-3">{b && b.verdict !== 'Not attempted' ? <VerdictBadge v={b.verdict} /> : <span className="text-xs text-slate-500">Not attempted</span>}</td>
                    <td className="py-2.5 pr-3 text-right tabular-nums text-xs text-slate-400">{b && b.total ? `${b.passed}/${b.total}` : '-'}</td>
                    <td className="py-2.5 text-right font-semibold tabular-nums text-slate-200">
                      {b?.points ?? 0}
                      <span className="font-normal text-slate-500">/{b?.max ?? 0}</span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <p className="text-xs text-slate-500">Open a question to review it; hints and the solution are available again outside interview mode.</p>
          <button onClick={reset} className="rounded-lg bg-slate-700 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-600">
            New interview
          </button>
        </div>
      </div>
    );
  }

  // ---------------------------------------------------------------- in progress
  const q = session.questions[current];
  const low = remaining < 5 * 60 * 1000;
  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-slate-800 bg-[#0c111c] px-3 py-2">
        {session.questions.map((x, i) => {
          const r = session.results[x.id];
          return (
            <button
              key={x.id}
              onClick={() => setCurrent(i)}
              className={`flex items-center gap-2 rounded-md px-3 py-1.5 text-xs ${i === current ? 'bg-slate-800 text-white' : 'text-slate-400 hover:bg-slate-800/60'}`}
            >
              <DifficultyBadge d={x.difficulty} small />
              <span className="max-w-[14rem] truncate">{x.title}</span>
              {r?.verdict === 'Accepted' ? (
                <span className="text-emerald-300">✓</span>
              ) : r ? (
                <span className="tabular-nums text-amber-300">
                  {r.bestPassed}/{r.total}
                </span>
              ) : null}
            </button>
          );
        })}
        <div className="ml-auto flex items-center gap-3">
          <TypeBadge t={q.type} />
          <span className={`rounded-md px-2.5 py-1 font-mono text-sm font-semibold tabular-nums ${low ? 'bg-rose-500/15 text-rose-300' : 'bg-slate-800 text-slate-100'}`} aria-live="polite">
            ⏱ {formatDuration(remaining)}
          </span>
          <button
            onClick={() => window.confirm('Finish the interview now and see your score?') && void finish()}
            disabled={busy}
            className="rounded-md bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-rose-500 disabled:opacity-50"
          >
            Finish
          </button>
        </div>
      </div>
      <div className="min-h-0 flex-1">
        <QuestionWorkspace key={`${session.id}-${q.id}`} id={q.id} interviewId={session.id} interviewLocked={remaining <= 0} onJudged={reloadSession} />
      </div>
    </div>
  );
}
