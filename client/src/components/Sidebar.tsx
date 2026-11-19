import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useLocalStorage } from '../hooks';
import { useApp } from '../state';
import type { Difficulty, QType, Status } from '../types';
import { DifficultyBadge, StatusIcon, TYPE_LABEL } from './Badges';

interface Filters {
  topic: string; // topic name or 'all'
  difficulty: Difficulty | 'all';
  type: QType | 'all';
  status: Status | 'all';
  embedded: boolean;
  search: string;
}

const DEFAULT_FILTERS: Filters = { topic: 'all', difficulty: 'all', type: 'all', status: 'all', embedded: false, search: '' };
const DIFFS: Difficulty[] = ['Easy', 'Medium', 'Hard'];

export function Sidebar({ activeId }: { activeId?: string }) {
  const { questions, topics, statusOf } = useApp();
  const [f, setF] = useLocalStorage<Filters>('csim:filters', DEFAULT_FILTERS);
  // the remembered topic may belong to the other track
  const topicSel = topics.some((t) => t.name === f.topic) ? f.topic : 'all';
  const set = <K extends keyof Filters>(k: K, v: Filters[K]) => setF((prev) => ({ ...prev, [k]: v }));

  const solvedByTopic = useMemo(() => {
    const m: Record<string, number> = {};
    for (const q of questions) if (statusOf(q.id) === 'solved') m[q.topic] = (m[q.topic] || 0) + 1;
    return m;
  }, [questions, statusOf]);

  const list = useMemo(() => {
    const s = f.search.trim().toLowerCase();
    return questions.filter(
      (q) =>
        (topicSel === 'all' || q.topic === topicSel) &&
        (f.difficulty === 'all' || q.difficulty === f.difficulty) &&
        (f.type === 'all' || q.type === f.type) &&
        (f.status === 'all' || statusOf(q.id) === f.status) &&
        (!f.embedded || q.tags.includes('embedded')) &&
        (!s || q.title.toLowerCase().includes(s) || q.id.toLowerCase().includes(s) || q.tags.some((t) => t.includes(s))),
    );
  }, [questions, f, topicSel, statusOf]);

  const totalSolved = Object.values(solvedByTopic).reduce((a, b) => a + b, 0);
  const filtered = JSON.stringify({ ...f, topic: 'all' }) !== JSON.stringify({ ...DEFAULT_FILTERS });

  return (
    <aside className="flex h-full flex-col border-r border-slate-800 bg-[#0c111c]">
      <nav className="border-b border-slate-800 p-2" aria-label="Topics">
        <TopicButton active={topicSel === 'all'} onClick={() => set('topic', 'all')} label="All topics" solved={totalSolved} total={questions.length} />
        {topics.map((t) => (
          <TopicButton
            key={t.slug}
            active={topicSel === t.name}
            onClick={() => set('topic', t.name)}
            label={t.name}
            solved={solvedByTopic[t.name] || 0}
            total={t.count}
          />
        ))}
      </nav>

      <div className="space-y-2 border-b border-slate-800 p-3">
        <input
          value={f.search}
          onChange={(e) => set('search', e.target.value)}
          placeholder="Search title, ID or tag…"
          className="w-full rounded-md border border-slate-700 bg-slate-900 px-2.5 py-1.5 text-xs text-slate-200 outline-none placeholder:text-slate-500 focus:border-sky-500"
        />
        <div className="flex gap-1" role="group" aria-label="Difficulty">
          {(['all', ...DIFFS] as const).map((d) => (
            <button
              key={d}
              onClick={() => set('difficulty', d)}
              className={`flex-1 rounded-md px-1.5 py-1 text-[11px] font-medium ring-1 ring-inset ${
                f.difficulty === d ? 'bg-slate-700 text-white ring-slate-500' : 'text-slate-400 ring-slate-700 hover:bg-slate-800'
              }`}
            >
              {d === 'all' ? 'All' : d}
            </button>
          ))}
        </div>
        <div className="flex gap-2">
          <select
            value={f.type}
            onChange={(e) => set('type', e.target.value as Filters['type'])}
            className="min-w-0 flex-1 rounded-md border border-slate-700 bg-slate-900 px-1.5 py-1 text-[11px] text-slate-300"
            aria-label="Question type"
          >
            <option value="all">All types</option>
            {(Object.keys(TYPE_LABEL) as QType[]).map((t) => (
              <option key={t} value={t}>
                {TYPE_LABEL[t]}
              </option>
            ))}
          </select>
          <select
            value={f.status}
            onChange={(e) => set('status', e.target.value as Filters['status'])}
            className="min-w-0 flex-1 rounded-md border border-slate-700 bg-slate-900 px-1.5 py-1 text-[11px] text-slate-300"
            aria-label="Status"
          >
            <option value="all">Any status</option>
            <option value="unsolved">Unsolved</option>
            <option value="attempted">Attempted</option>
            <option value="solved">Solved</option>
          </select>
        </div>
        <div className="flex items-center justify-between">
          <label className="flex cursor-pointer items-center gap-1.5 text-[11px] text-slate-300">
            <input type="checkbox" checked={f.embedded} onChange={(e) => set('embedded', e.target.checked)} className="accent-sky-500" />
            Embedded-specific only
          </label>
          {filtered && (
            <button onClick={() => setF({ ...DEFAULT_FILTERS, topic: f.topic })} className="text-[11px] text-sky-300 hover:underline">
              Clear
            </button>
          )}
        </div>
      </div>

      <div className="px-3 pt-2 text-[11px] text-slate-500">{list.length} question{list.length === 1 ? '' : 's'}</div>
      <ul className="min-h-0 flex-1 overflow-y-auto p-2">
        {list.map((q) => (
          <li key={q.id}>
            <Link
              to={`/problems/${q.id}`}
              className={`flex items-start gap-2 rounded-md px-2 py-1.5 ${activeId === q.id ? 'bg-slate-800' : 'hover:bg-slate-800/60'}`}
            >
              <span className="mt-0.5">
                <StatusIcon s={statusOf(q.id)} />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] text-slate-200">{q.title}</span>
                <span className="flex items-center gap-1.5 text-[10px] text-slate-500">
                  <span className="font-mono">{q.id}</span>·<span>{TYPE_LABEL[q.type]}</span>
                  {q.tags.includes('embedded') && <span className="text-sky-400">· embedded</span>}
                </span>
              </span>
              <DifficultyBadge d={q.difficulty} small />
            </Link>
          </li>
        ))}
        {list.length === 0 && <li className="p-3 text-xs text-slate-500">No questions match these filters.</li>}
      </ul>
    </aside>
  );
}

function TopicButton({ active, onClick, label, solved, total }: { active: boolean; onClick: () => void; label: string; solved: number; total: number }) {
  return (
    <button
      onClick={onClick}
      className={`flex w-full items-center justify-between rounded-md px-2 py-1 text-left text-[13px] ${
        active ? 'bg-sky-500/15 text-sky-200' : 'text-slate-300 hover:bg-slate-800/60'
      }`}
    >
      <span>{label}</span>
      <span className="font-mono text-[11px] text-slate-500">
        {solved}/{total}
      </span>
    </button>
  );
}
