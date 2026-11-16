import type { Difficulty, QType, Status, Verdict } from '../types';

const DIFF_CLASS: Record<Difficulty, string> = {
  Easy: 'text-emerald-300 bg-emerald-500/10 ring-emerald-500/30',
  Medium: 'text-amber-300 bg-amber-500/10 ring-amber-500/30',
  Hard: 'text-rose-300 bg-rose-500/10 ring-rose-500/30',
};

export function DifficultyBadge({ d, small }: { d: Difficulty; small?: boolean }) {
  return (
    <span
      className={`inline-flex items-center rounded-full ring-1 ring-inset font-medium ${DIFF_CLASS[d]} ${
        small ? 'px-1.5 py-0 text-[10px]' : 'px-2 py-0.5 text-xs'
      }`}
    >
      {d}
    </span>
  );
}

export const TYPE_LABEL: Record<QType, string> = {
  CODE: 'Program',
  FUNCTION: 'Function',
  PREDICT_OUTPUT: 'Predict Output',
  FIND_THE_BUG: 'Find the Bug',
};

export function TypeBadge({ t }: { t: QType }) {
  return (
    <span className="inline-flex items-center rounded-md bg-slate-800 px-2 py-0.5 text-xs font-medium text-slate-300 ring-1 ring-inset ring-slate-700">
      {TYPE_LABEL[t]}
    </span>
  );
}

export function StatusIcon({ s }: { s: Status }) {
  if (s === 'solved')
    return (
      <span title="Solved" aria-label="Solved" className="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-emerald-500/20 text-[10px] text-emerald-300">
        ✓
      </span>
    );
  if (s === 'attempted')
    return (
      <span title="Attempted" aria-label="Attempted" className="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-amber-500/15 text-[10px] text-amber-300">
        •
      </span>
    );
  return <span title="Unsolved" aria-label="Unsolved" className="inline-block h-4 w-4 shrink-0 rounded-full ring-1 ring-inset ring-slate-600" />;
}

const VERDICT_CLASS: Record<string, string> = {
  Accepted: 'text-emerald-300 bg-emerald-500/10 ring-emerald-500/30',
  'Wrong Answer': 'text-rose-300 bg-rose-500/10 ring-rose-500/30',
  'Compile Error': 'text-amber-300 bg-amber-500/10 ring-amber-500/30',
  'Runtime Error': 'text-orange-300 bg-orange-500/10 ring-orange-500/30',
  'Time Limit Exceeded': 'text-violet-300 bg-violet-500/10 ring-violet-500/30',
  'Memory Leak': 'text-fuchsia-300 bg-fuchsia-500/10 ring-fuchsia-500/30',
};

const VERDICT_ICON: Record<string, string> = {
  Accepted: '✓',
  'Wrong Answer': '✗',
  'Compile Error': '⚠',
  'Runtime Error': '💥',
  'Time Limit Exceeded': '⏱',
  'Memory Leak': '💧',
};

export function VerdictBadge({ v, large }: { v: Verdict | string; large?: boolean }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-md ring-1 ring-inset font-semibold ${VERDICT_CLASS[v] || 'text-slate-300 bg-slate-800 ring-slate-700'} ${
        large ? 'px-2.5 py-1 text-base' : 'px-1.5 py-0.5 text-xs'
      }`}
    >
      <span aria-hidden>{VERDICT_ICON[v] || '•'}</span>
      {v}
    </span>
  );
}

export function Tag({ children }: { children: string }) {
  const embedded = children === 'embedded';
  return (
    <span
      className={`inline-flex items-center rounded px-1.5 py-0.5 text-[11px] font-medium ring-1 ring-inset ${
        embedded ? 'bg-sky-500/10 text-sky-300 ring-sky-500/30' : 'bg-slate-800/80 text-slate-400 ring-slate-700'
      }`}
    >
      {children}
    </span>
  );
}
