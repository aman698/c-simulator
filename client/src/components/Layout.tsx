import { NavLink, Outlet } from 'react-router-dom';
import { useApp } from '../state';

const LINKS = [
  ['/problems', 'Problems'],
  ['/dashboard', 'Dashboard'],
  ['/interview', 'Interview Mode'],
  ['/playground', 'Playground'],
] as const;

function ToolchainPill() {
  const { health } = useApp();
  if (!health) return <span className="text-[11px] text-slate-500">judge: connecting…</span>;
  const tc = health.toolchain;
  if (tc.mode === 'none')
    return (
      <span title={tc.error} className="rounded-full bg-rose-500/15 px-2.5 py-1 text-[11px] font-medium text-rose-300 ring-1 ring-rose-500/30">
        ● no compiler found
      </span>
    );
  const s = tc.support || {};
  const full = s.asan && s.ubsan && s.lsan;
  const short = (tc.version || '').replace(/\(.*?\)/g, '').replace(/\s+/g, ' ').trim();
  return (
    <span
      title={`${tc.version}\n${tc.machine} (${tc.mode})\nSanitizers: ${tc.sanitizers}\n$ ${tc.command}`}
      className={`max-w-[22rem] truncate rounded-full px-2.5 py-1 text-[11px] font-medium ring-1 ${
        full ? 'bg-emerald-500/10 text-emerald-300 ring-emerald-500/30' : 'bg-amber-500/10 text-amber-300 ring-amber-500/30'
      }`}
    >
      ● {tc.mode} · {short}
      {!full && ' · partial sanitizers'}
    </span>
  );
}

export function Layout() {
  return (
    <div className="flex h-full flex-col">
      <header className="flex h-12 shrink-0 items-center gap-6 border-b border-slate-800 bg-[#0a0e16] px-4">
        <NavLink to="/problems" className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-sky-500 font-mono text-sm font-bold text-white">C</span>
          <span className="text-sm font-semibold text-slate-100">C Practice Simulator</span>
        </NavLink>
        <nav className="flex gap-1">
          {LINKS.map(([to, label]) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `rounded-md px-3 py-1.5 text-[13px] font-medium ${isActive ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-slate-200'}`
              }
            >
              {label}
            </NavLink>
          ))}
        </nav>
        <div className="ml-auto">
          <ToolchainPill />
        </div>
      </header>
      <main className="min-h-0 flex-1">
        <Outlet />
      </main>
    </div>
  );
}
