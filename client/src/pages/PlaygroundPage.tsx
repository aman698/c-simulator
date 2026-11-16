import { useCallback, useRef, useState } from 'react';
import { api } from '../api';
import { VerdictBadge } from '../components/Badges';
import { CodeEditor, type CodeEditorHandle } from '../components/CodeEditor';
import { SplitPane } from '../components/SplitPane';
import { useLocalStorage } from '../hooks';
import { useApp } from '../state';
import type { JudgeResult } from '../types';

const DEFAULT_CODE = `#include <stdio.h>
#include <stdint.h>

/* Free experimentation: this program reads integers from stdin. */
int main(void)
{
    int x;
    uint32_t reg = 0;
    while (scanf("%d", &x) == 1) {
        reg |= 1u << (x & 31);
        printf("set bit %2d -> reg = 0x%08X\\n", x & 31, reg);
    }
    return 0;
}
`;

export function PlaygroundPage() {
  const { std, setStd, sanitizers, setSanitizers } = useApp();
  const [code, setCode] = useLocalStorage('csim:playground:code', DEFAULT_CODE);
  const [stdin, setStdin] = useLocalStorage('csim:playground:stdin', '3 7 31\n');
  const [leakCheck, setLeakCheck] = useLocalStorage('csim:playground:leak', true);
  const [result, setResult] = useState<JudgeResult | null>(null);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const editor = useRef<CodeEditorHandle>(null);

  const run = useCallback(async () => {
    if (running) return;
    setRunning(true);
    setError(null);
    try {
      setResult(await api.playground({ code, std, sanitizers, stdin, leakCheck }));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setRunning(false);
    }
  }, [running, code, std, sanitizers, stdin, leakCheck]);

  const t = result?.tests[0];

  return (
    <SplitPane direction="horizontal" initial={0.58} storageKey="playground-h" minPx={320}>
      <div className="flex h-full flex-col">
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-800 bg-[#0f1524] px-3 py-2">
          <span className="text-sm font-semibold text-slate-200">Playground</span>
          <select value={std} onChange={(e) => setStd(e.target.value as 'c99' | 'c11')} className="rounded-md border border-slate-700 bg-slate-900 px-2 py-1 text-xs text-slate-200">
            <option value="c11">C11</option>
            <option value="c99">C99</option>
          </select>
          <label className="flex cursor-pointer items-center gap-1.5 text-xs text-slate-300">
            <input type="checkbox" checked={sanitizers} onChange={(e) => setSanitizers(e.target.checked)} className="accent-sky-500" />
            Sanitizers {sanitizers ? 'ON' : 'OFF'}
          </label>
          <label className="flex cursor-pointer items-center gap-1.5 text-xs text-slate-300">
            <input type="checkbox" checked={leakCheck} onChange={(e) => setLeakCheck(e.target.checked)} className="accent-sky-500" />
            Leak check
          </label>
          <div className="ml-auto flex gap-2">
            <button onClick={() => window.confirm('Reset the playground code?') && setCode(DEFAULT_CODE)} className="rounded-md px-2 py-1 text-xs text-slate-400 hover:bg-slate-800">
              ↺ Reset
            </button>
            <button
              onClick={run}
              disabled={running}
              className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
              title="Ctrl+Enter"
            >
              {running ? 'Running…' : '▶ Run'}
            </button>
          </div>
        </div>
        <div className="min-h-0 flex-1">
          <CodeEditor
            ref={editor}
            value={code}
            onChange={setCode}
            onRun={run}
            onSubmit={run}
            diagnostics={result?.compile.diagnostics}
            errorLine={t?.line ?? null}
            path="playground.c"
          />
        </div>
      </div>
      <div className="flex h-full flex-col bg-[#0d1220]">
        <div className="border-b border-slate-800 p-3">
          <label htmlFor="pg-stdin" className="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-slate-400">
            stdin
          </label>
          <textarea
            id="pg-stdin"
            value={stdin}
            onChange={(e) => setStdin(e.target.value)}
            spellCheck={false}
            rows={6}
            className="w-full resize-y rounded-md border border-slate-700 bg-[#0d1117] p-2 font-mono text-xs text-slate-200 outline-none focus:border-sky-500"
          />
        </div>
        <div className="min-h-0 flex-1 space-y-3 overflow-y-auto p-3">
          {error && <div className="rounded-md border border-rose-500/40 bg-rose-500/10 px-3 py-2 text-sm text-rose-200">{error}</div>}
          {!result && !error && <p className="text-sm text-slate-500">Press Run (Ctrl+Enter) to compile and execute.</p>}
          {result && (
            <>
              <div className="flex flex-wrap items-center gap-3 text-xs text-slate-400">
                {!result.compile.ok ? (
                  <VerdictBadge v="Compile Error" />
                ) : t && t.verdict !== 'Accepted' ? (
                  <VerdictBadge v={t.verdict} />
                ) : (
                  <span className="rounded-md bg-emerald-500/10 px-2 py-0.5 font-semibold text-emerald-300 ring-1 ring-emerald-500/30">Finished</span>
                )}
                {t && <span>exit code {t.exitCode ?? '-'}{t.signal ? ` (${t.signal})` : ''}</span>}
                {t && <span>{t.timeMs} ms</span>}
              </div>
              {t?.message && t.verdict !== 'Accepted' && (
                <div className="rounded-md border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-sm text-rose-200">
                  {t.message}
                  {t.line ? (
                    <button onClick={() => editor.current?.revealLine(t.line!)} className="ml-2 text-sky-300 hover:underline">
                      (line {t.line})
                    </button>
                  ) : null}
                </div>
              )}
              {(result.compile.diagnostics.length > 0 || !result.compile.ok) && (
                <div>
                  <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-slate-400">Compiler output</div>
                  <ul className="mb-2 space-y-0.5">
                    {result.compile.diagnostics
                      .filter((d) => d.file === 'main.c' && d.line > 0)
                      .map((d, i) => (
                        <li key={i} className="font-mono text-xs">
                          <button onClick={() => editor.current?.revealLine(d.line, d.column)} className="text-sky-300 hover:underline">
                            line {d.line}
                          </button>{' '}
                          <span className={d.severity === 'error' ? 'text-rose-300' : 'text-amber-300'}>{d.severity}</span>{' '}
                          <span className="text-slate-200">{d.message}</span>
                        </li>
                      ))}
                  </ul>
                  <pre className="io max-h-64">{result.compile.output}</pre>
                </div>
              )}
              {t && (
                <>
                  <div>
                    <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-slate-400">stdout</div>
                    <pre className="io max-h-[40vh]">{t.stdout || ' '}</pre>
                  </div>
                  {t.stderr && (
                    <div>
                      <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-rose-300">stderr / sanitizer report</div>
                      <pre className="io max-h-[40vh]">{t.stderr}</pre>
                    </div>
                  )}
                </>
              )}
              <p className="font-mono text-[11px] text-slate-500">$ {result.compile.command}</p>
            </>
          )}
        </div>
      </div>
    </SplitPane>
  );
}
