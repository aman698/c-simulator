import { useEffect, useState } from 'react';
import type { Diagnostic, JudgeResult, TestResult } from '../types';
import { VerdictBadge } from './Badges';

export type PanelTab = 'result' | 'compile' | 'custom';

interface Props {
  result: JudgeResult | null;
  running: 'run' | 'submit' | 'custom' | null;
  error: string | null;
  tab: PanelTab;
  setTab: (t: PanelTab) => void;
  onJumpToLine: (line: number, column?: number) => void;
  customInput?: string;
  setCustomInput?: (s: string) => void;
  onRunCustom?: () => void;
  allowCustom?: boolean;
}

function IOBlock({ label, text, tone }: { label: string; text: string | null | undefined; tone?: 'bad' | 'good' }) {
  const empty = text == null || text === '';
  return (
    <div className="min-w-0">
      <div className={`mb-1 text-[11px] font-semibold uppercase tracking-wide ${tone === 'bad' ? 'text-rose-300' : tone === 'good' ? 'text-emerald-300' : 'text-slate-400'}`}>
        {label}
      </div>
      <pre className={`io max-h-56 ${empty ? 'italic text-slate-500' : ''}`}>{empty ? '(empty)' : text}</pre>
    </div>
  );
}

function DiagnosticRow({ d, onJump }: { d: Diagnostic; onJump: (line: number, col?: number) => void }) {
  const color = d.severity === 'error' ? 'text-rose-300' : d.severity === 'warning' ? 'text-amber-300' : 'text-slate-400';
  const clickable = d.file === 'main.c' && d.line > 0;
  return (
    <li className="flex gap-2 py-1 font-mono text-xs">
      {clickable ? (
        <button onClick={() => onJump(d.line, d.column)} className="shrink-0 text-sky-300 underline-offset-2 hover:underline" title="Jump to line">
          line {d.line}:{d.column}
        </button>
      ) : (
        <span className="shrink-0 text-slate-500">{d.file === 'harness.c' ? 'hidden harness' : d.file}</span>
      )}
      <span className={`shrink-0 ${color}`}>{d.severity}</span>
      <span className="break-words text-slate-200">{d.message}</span>
    </li>
  );
}

function TestDetail({ t, onJump }: { t: TestResult; onJump: (line: number) => void }) {
  const failed = t.verdict !== 'Accepted';
  const hasData = t.input !== undefined;
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-3 text-xs text-slate-400">
        <VerdictBadge v={t.verdict} />
        <span>{t.timeMs} ms</span>
        {t.exitCode != null && <span>exit code {t.exitCode}</span>}
        {t.signal && <span>signal {t.signal}</span>}
        {t.hidden && <span className="rounded bg-slate-800 px-1.5 py-0.5 text-slate-300">hidden test</span>}
      </div>
      {failed && t.message && (
        <div className="rounded-md border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-sm text-rose-200">
          {t.message}
          {t.line ? (
            <button onClick={() => onJump(t.line!)} className="ml-2 text-sky-300 underline-offset-2 hover:underline">
              (line {t.line})
            </button>
          ) : null}
        </div>
      )}
      {hasData ? (
        <>
          <IOBlock label="Input" text={t.input} />
          <div className="grid gap-3 md:grid-cols-2">
            {t.expected !== null && t.expected !== undefined && <IOBlock label="Expected output" text={t.expected} tone="good" />}
            <IOBlock label={t.expected === null ? 'Output' : 'Your output'} text={t.stdout} tone={t.verdict === 'Wrong Answer' ? 'bad' : undefined} />
          </div>
          {t.stderr ? <IOBlock label="stderr / sanitizer report" text={t.stderr} tone="bad" /> : null}
        </>
      ) : (
        <p className="text-sm text-slate-400">Hidden test case: its input and expected output are not shown.</p>
      )}
    </div>
  );
}

export function ResultsPanel({ result, running, error, tab, setTab, onJumpToLine, customInput, setCustomInput, onRunCustom, allowCustom = true }: Props) {
  const [sel, setSel] = useState(0);

  useEffect(() => {
    if (!result) return;
    const firstFail = result.tests.findIndex((t) => t.verdict !== 'Accepted');
    setSel(firstFail >= 0 ? firstFail : 0);
  }, [result]);

  const tabs: [PanelTab, string][] = [
    ['result', 'Test Result'],
    ['compile', result?.compile.warnings ? `Compiler (${result.compile.warnings} warning${result.compile.warnings > 1 ? 's' : ''})` : 'Compiler'],
  ];
  if (allowCustom) tabs.push(['custom', 'Custom Input']);

  const maxTime = result ? result.tests.reduce((m, t) => Math.max(m, t.timeMs), 0) : 0;

  return (
    <div className="flex h-full flex-col bg-[#0d1220]">
      <div className="flex items-center gap-1 border-b border-slate-800 px-2">
        {tabs.map(([k, label]) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            className={`border-b-2 px-3 py-2 text-xs font-medium ${tab === k ? 'border-sky-400 text-slate-100' : 'border-transparent text-slate-400 hover:text-slate-200'}`}
          >
            {label}
          </button>
        ))}
        <div className="ml-auto pr-2 text-[11px] text-slate-500">
          {running ? (running === 'submit' ? 'Judging all tests…' : 'Running…') : result ? result.toolchain.version : ''}
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-auto p-3">
        {error && <div className="mb-3 rounded-md border border-rose-500/40 bg-rose-500/10 px-3 py-2 text-sm text-rose-200">{error}</div>}

        {tab === 'custom' && allowCustom && (
          <div className="space-y-2">
            <p className="text-xs text-slate-400">Your program runs on this stdin. The expected output is computed by the reference solution.</p>
            <textarea
              value={customInput}
              onChange={(e) => setCustomInput?.(e.target.value)}
              spellCheck={false}
              rows={6}
              className="w-full resize-y rounded-md border border-slate-700 bg-[#0d1117] p-2 font-mono text-xs text-slate-200 outline-none focus:border-sky-500"
              placeholder="stdin for your program"
            />
            <button
              onClick={onRunCustom}
              disabled={!!running}
              className="rounded-md bg-slate-700 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-600 disabled:opacity-50"
            >
              Run with custom input
            </button>
            {result?.custom && result.tests[0] && (
              <div className="pt-2">
                {result.referenceNote && <p className="mb-2 text-xs text-amber-300">{result.referenceNote}</p>}
                <TestDetail t={result.tests[0]} onJump={onJumpToLine} />
              </div>
            )}
          </div>
        )}

        {tab === 'compile' && (
          <div className="space-y-3">
            {!result && <p className="text-sm text-slate-500">Run your code to see compiler output.</p>}
            {result && (
              <>
                <div className="rounded-md bg-slate-900 px-3 py-2 font-mono text-[11px] text-slate-400">$ {result.compile.command}</div>
                {result.compile.diagnostics.length > 0 ? (
                  <ul className="divide-y divide-slate-800">
                    {result.compile.diagnostics.map((d, i) => (
                      <DiagnosticRow key={i} d={d} onJump={onJumpToLine} />
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-emerald-300">Compiled cleanly: no errors, no warnings.</p>
                )}
                {result.compile.output && <pre className="io max-h-72">{result.compile.output}</pre>}
                <p className="text-[11px] text-slate-500">Sanitizers: {result.toolchain.sanitizers}{result.toolchain.leakDetection ? ' · leak detection on' : ''}</p>
              </>
            )}
          </div>
        )}

        {tab === 'result' && (
          <div className="space-y-3">
            {!result && !running && (
              <p className="text-sm text-slate-500">
                Press <kbd className="rounded bg-slate-800 px-1">Ctrl</kbd>+<kbd className="rounded bg-slate-800 px-1">Enter</kbd> to run the sample tests,{' '}
                <kbd className="rounded bg-slate-800 px-1">Ctrl</kbd>+<kbd className="rounded bg-slate-800 px-1">Shift</kbd>+<kbd className="rounded bg-slate-800 px-1">Enter</kbd> to submit.
              </p>
            )}
            {running && !result && <p className="animate-pulse text-sm text-slate-400">Compiling and running…</p>}
            {result && (
              <>
                <div className="flex flex-wrap items-center gap-3">
                  {result.verdict && <VerdictBadge v={result.verdict} large />}
                  {result.compile.ok && (
                    <span className="text-sm text-slate-300">
                      {result.passed} / {result.total} test cases passed
                      <span className="ml-2 text-slate-500">max {maxTime} ms</span>
                    </span>
                  )}
                  {result.custom && <span className="text-xs text-slate-400">(custom input)</span>}
                </div>
                {!result.compile.ok && (
                  <div className="space-y-2">
                    <ul className="divide-y divide-slate-800">
                      {result.compile.diagnostics
                        .filter((d) => d.severity === 'error')
                        .map((d, i) => (
                          <DiagnosticRow key={i} d={d} onJump={onJumpToLine} />
                        ))}
                    </ul>
                    {result.compile.diagnostics.filter((d) => d.severity === 'error').length === 0 && <pre className="io">{result.compile.output}</pre>}
                  </div>
                )}
                {result.compile.ok && result.tests.length > 0 && (
                  <>
                    <div className="flex flex-wrap gap-1.5">
                      {result.tests.map((t, i) => (
                        <button
                          key={i}
                          onClick={() => setSel(i)}
                          className={`rounded-md px-2.5 py-1 text-xs font-medium ring-1 ring-inset ${
                            t.verdict === 'Accepted' ? 'text-emerald-300 ring-emerald-500/30' : 'text-rose-300 ring-rose-500/40'
                          } ${sel === i ? 'bg-slate-700' : 'bg-slate-900 hover:bg-slate-800'}`}
                        >
                          {t.verdict === 'Accepted' ? '✓' : '✗'} {t.hidden ? `Hidden ${i + 1}` : `Case ${i + 1}`}
                        </button>
                      ))}
                    </div>
                    {result.tests[sel] && <TestDetail t={result.tests[sel]} onJump={onJumpToLine} />}
                  </>
                )}
                {result.compile.ok && result.compile.warnings > 0 && (
                  <button onClick={() => setTab('compile')} className="text-xs text-amber-300 hover:underline">
                    {result.compile.warnings} compiler warning(s): view
                  </button>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
