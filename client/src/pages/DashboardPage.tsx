import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { DifficultyBadge, VerdictBadge } from '../components/Badges';
import { formatDuration, timeAgo } from '../hooks';
import { useApp } from '../state';
import type { Difficulty } from '../types';

const DIFFS: Difficulty[] = ['Easy', 'Medium', 'Hard'];

function Tile({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-xl border border-slate-800 bg-[#0f1524] px-4 py-3">
      <div className="text-xs font-medium text-slate-400">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums text-slate-100">{value}</div>
      {sub && <div className="mt-0.5 text-xs text-slate-500">{sub}</div>}
    </div>
  );
}

/** Thin single-hue progress meter; the numbers are always printed as text next to it. */
function Meter({ value, max, label }: { value: number; max: number; label: string }) {
  const pct = max ? Math.round((value / max) * 100) : 0;
  return (
    <div
      className="h-1.5 w-full overflow-hidden rounded-full bg-slate-800"
      role="meter"
      aria-label={label}
      aria-valuenow={value}
      aria-valuemin={0}
      aria-valuemax={max}
      title={`${label}: ${value} of ${max} solved (${pct}%)`}
    >
      <div className="h-full rounded-full bg-sky-500" style={{ width: `${pct}%` }} />
    </div>
  );
}

function dayKey(d: Date) {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** 16-week activity grid, one hue light->dark by number of submissions per day. */
function ActivityGrid({ activity }: { activity: Record<string, number> }) {
  const weeks = 16;
  const today = new Date();
  const start = new Date(today);
  start.setDate(today.getDate() - today.getDay() - (weeks - 1) * 7); // Sunday, 16 weeks ago
  const cols: { key: string; count: number; future: boolean }[][] = [];
  for (let w = 0; w < weeks; w++) {
    const col = [];
    for (let d = 0; d < 7; d++) {
      const day = new Date(start);
      day.setDate(start.getDate() + w * 7 + d);
      const key = dayKey(day);
      col.push({ key, count: activity[key] || 0, future: day > today });
    }
    cols.push(col);
  }
  const shade = (n: number) =>
    n === 0 ? 'bg-slate-800' : n < 2 ? 'bg-sky-900' : n < 4 ? 'bg-sky-700' : n < 8 ? 'bg-sky-500' : 'bg-sky-300';
  return (
    <div>
      <div className="flex gap-[3px]">
        {cols.map((col, i) => (
          <div key={i} className="flex flex-col gap-[3px]">
            {col.map((c) => (
              <div
                key={c.key}
                title={c.future ? '' : `${c.key}: ${c.count} submission${c.count === 1 ? '' : 's'}`}
                className={`h-3 w-3 rounded-[3px] ${c.future ? 'bg-transparent' : shade(c.count)}`}
              />
            ))}
          </div>
        ))}
      </div>
      <div className="mt-2 flex items-center gap-1.5 text-[11px] text-slate-500">
        Less
        {[0, 1, 3, 6, 9].map((n) => (
          <span key={n} className={`h-3 w-3 rounded-[3px] ${shade(n)}`} />
        ))}
        More
      </div>
    </div>
  );
}

export function DashboardPage() {
  const { questions, topics, progress, statusOf } = useApp();

  const stats = useMemo(() => {
    const solved = questions.filter((q) => statusOf(q.id) === 'solved');
    const attempted = questions.filter((q) => statusOf(q.id) === 'attempted');
    const byDiff = Object.fromEntries(
      DIFFS.map((d) => [d, { solved: solved.filter((q) => q.difficulty === d).length, total: questions.filter((q) => q.difficulty === d).length }]),
    ) as Record<Difficulty, { solved: number; total: number }>;
    const byTopic = topics.map((t) => {
      const qs = questions.filter((q) => q.topic === t.name);
      return {
        topic: t,
        total: qs.length,
        solved: qs.filter((q) => statusOf(q.id) === 'solved').length,
        diff: DIFFS.map((d) => ({
          d,
          solved: qs.filter((q) => q.difficulty === d && statusOf(q.id) === 'solved').length,
          total: qs.filter((q) => q.difficulty === d).length,
        })),
      };
    });
    const subs = progress?.submissions || [];
    const accepted = subs.filter((s) => s.verdict === 'Accepted').length;
    return { solved: solved.length, attempted: attempted.length, byDiff, byTopic, subs, accepted };
  }, [questions, topics, progress, statusOf]);

  const interviews = (progress?.interviews || []).filter((s) => s.finishedAt);
  const best = interviews.reduce((m, s) => Math.max(m, s.score || 0), 0);

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-6xl space-y-6 px-6 py-6">
        <h1 className="text-xl font-semibold text-slate-100">Dashboard</h1>

        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Tile label="Solved" value={`${stats.solved} / ${questions.length}`} sub={`${stats.attempted} attempted, not yet solved`} />
          <Tile
            label="Current streak"
            value={`${progress?.streak.current ?? 0} day${progress?.streak.current === 1 ? '' : 's'}`}
            sub={`Longest: ${progress?.streak.longest ?? 0} days`}
          />
          <Tile
            label="Submissions"
            value={String(stats.subs.length)}
            sub={stats.subs.length ? `${Math.round((stats.accepted / stats.subs.length) * 100)}% accepted (last ${stats.subs.length})` : 'No submissions yet'}
          />
          <Tile label="Mock interviews" value={String(interviews.length)} sub={interviews.length ? `Best score ${best} / 100` : 'Try Interview Mode'} />
        </div>

        <div className="grid gap-4 lg:grid-cols-3">
          <section className="rounded-xl border border-slate-800 bg-[#0f1524] p-4">
            <h2 className="mb-3 text-sm font-semibold text-slate-200">By difficulty</h2>
            <div className="space-y-3">
              {DIFFS.map((d) => (
                <div key={d}>
                  <div className="mb-1 flex items-center justify-between text-xs">
                    <DifficultyBadge d={d} small />
                    <span className="tabular-nums text-slate-300">
                      {stats.byDiff[d].solved} / {stats.byDiff[d].total}
                    </span>
                  </div>
                  <Meter value={stats.byDiff[d].solved} max={stats.byDiff[d].total} label={`${d} questions`} />
                </div>
              ))}
            </div>
          </section>
          <section className="rounded-xl border border-slate-800 bg-[#0f1524] p-4 lg:col-span-2">
            <h2 className="mb-3 text-sm font-semibold text-slate-200">Activity (submissions per day, last 16 weeks)</h2>
            <ActivityGrid activity={progress?.activity || {}} />
          </section>
        </div>

        <section className="rounded-xl border border-slate-800 bg-[#0f1524] p-4">
          <h2 className="mb-3 text-sm font-semibold text-slate-200">By topic</h2>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500">
                  <th className="py-1.5 pr-4 font-medium">Topic</th>
                  <th className="w-1/3 py-1.5 pr-4 font-medium">Solved</th>
                  {DIFFS.map((d) => (
                    <th key={d} className="py-1.5 pr-4 text-right font-medium">
                      {d}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/70">
                {stats.byTopic.map((r) => (
                  <tr key={r.topic.slug}>
                    <td className="py-2 pr-4 text-slate-200">{r.topic.name}</td>
                    <td className="py-2 pr-4">
                      <div className="flex items-center gap-3">
                        <Meter value={r.solved} max={r.total} label={r.topic.name} />
                        <span className="w-14 shrink-0 text-right tabular-nums text-xs text-slate-300">
                          {r.solved}/{r.total}
                        </span>
                      </div>
                    </td>
                    {r.diff.map((x) => (
                      <td key={x.d} className="py-2 pr-4 text-right tabular-nums text-xs text-slate-400">
                        {x.solved}/{x.total}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <div className="grid gap-4 lg:grid-cols-3">
          <section className="rounded-xl border border-slate-800 bg-[#0f1524] p-4 lg:col-span-2">
            <h2 className="mb-3 text-sm font-semibold text-slate-200">Last 10 submissions</h2>
            {stats.subs.length === 0 ? (
              <p className="text-sm text-slate-500">Nothing yet. Pick a problem and press Submit.</p>
            ) : (
              <table className="w-full text-sm">
                <tbody className="divide-y divide-slate-800/70">
                  {stats.subs.slice(0, 10).map((s) => (
                    <tr key={s.id}>
                      <td className="py-2 pr-3">
                        <Link to={`/problems/${s.questionId}`} className="text-slate-200 hover:text-sky-300">
                          {s.title}
                        </Link>
                        <div className="text-[11px] text-slate-500">
                          {s.questionId} · {s.topic}
                          {s.kind === 'interview' ? ' · interview' : ''}
                        </div>
                      </td>
                      <td className="py-2 pr-3">
                        <VerdictBadge v={s.verdict} />
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums text-xs text-slate-400">
                        {s.total != null ? `${s.passed}/${s.total}` : ''}
                      </td>
                      <td className="py-2 text-right text-xs text-slate-500">{timeAgo(s.at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
          <section className="rounded-xl border border-slate-800 bg-[#0f1524] p-4">
            <h2 className="mb-3 text-sm font-semibold text-slate-200">Interview history</h2>
            {interviews.length === 0 ? (
              <p className="text-sm text-slate-500">
                No finished interviews.{' '}
                <Link to="/interview" className="text-sky-300 hover:underline">
                  Start one
                </Link>
              </p>
            ) : (
              <ul className="space-y-2">
                {interviews.slice(0, 8).map((s) => (
                  <li key={s.id} className="flex items-center justify-between text-sm">
                    <span className="text-slate-300">
                      {new Date(s.startedAt).toLocaleDateString()}{' '}
                      <span className="text-xs text-slate-500">{s.elapsedMs ? formatDuration(s.elapsedMs) : ''}</span>
                    </span>
                    <span className="font-semibold tabular-nums text-slate-100">{s.score ?? 0} / 100</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
