import Editor, { type OnMount } from '@monaco-editor/react';
import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef } from 'react';
import '../monaco';
import type { Diagnostic } from '../types';

type EditorInstance = Parameters<OnMount>[0];
type MonacoInstance = Parameters<OnMount>[1];

export interface CodeEditorHandle {
  revealLine: (line: number, column?: number) => void;
  focus: () => void;
}

interface Props {
  value: string;
  onChange?: (value: string) => void;
  readOnly?: boolean;
  diagnostics?: Diagnostic[];
  /** extra highlighted line (e.g. a sanitizer report location) */
  errorLine?: number | null;
  onRun?: () => void;
  onSubmit?: () => void;
  path?: string;
  fontSize?: number;
}

export const CodeEditor = forwardRef<CodeEditorHandle, Props>(function CodeEditor(
  { value, onChange, readOnly, diagnostics, errorLine, onRun, onSubmit, path, fontSize = 14 },
  ref,
) {
  const editorRef = useRef<EditorInstance | null>(null);
  const monacoRef = useRef<MonacoInstance | null>(null);
  const decorations = useRef<string[]>([]);
  const runRef = useRef(onRun);
  const submitRef = useRef(onSubmit);
  runRef.current = onRun;
  submitRef.current = onSubmit;

  useImperativeHandle(ref, () => ({
    revealLine(line, column = 1) {
      const ed = editorRef.current;
      if (!ed) return;
      ed.revealLineInCenter(line);
      ed.setPosition({ lineNumber: line, column: Math.max(1, column) });
      ed.focus();
    },
    focus() {
      editorRef.current?.focus();
    },
  }));

  const applyMarkers = useCallback(() => {
    const ed = editorRef.current;
    const m = monacoRef.current;
    const model = ed?.getModel();
    if (!ed || !m || !model) return;
    const lineCount = model.getLineCount();
    const markers = (diagnostics || [])
      .filter((d) => d.file === 'main.c' && d.line > 0 && d.severity !== 'note')
      .map((d) => {
        const line = Math.min(d.line, lineCount);
        return {
          startLineNumber: line,
          startColumn: Math.max(1, d.column),
          endLineNumber: line,
          endColumn: model.getLineMaxColumn(line),
          message: d.message,
          severity: d.severity === 'error' ? m.MarkerSeverity.Error : m.MarkerSeverity.Warning,
          source: 'gcc',
        };
      });
    m.editor.setModelMarkers(model, 'judge', markers);
    const decos =
      errorLine && errorLine > 0 && errorLine <= lineCount
        ? [
            {
              range: new m.Range(errorLine, 1, errorLine, 1),
              options: { isWholeLine: true, className: 'bg-rose-500/15', linesDecorationsClassName: 'border-l-4 border-rose-500' },
            },
          ]
        : [];
    decorations.current = ed.deltaDecorations(decorations.current, decos);
  }, [diagnostics, errorLine]);

  useEffect(applyMarkers, [applyMarkers]);

  const onMount: OnMount = (editor, m) => {
    editorRef.current = editor;
    monacoRef.current = m;
    editor.addCommand(m.KeyMod.CtrlCmd | m.KeyCode.Enter, () => runRef.current?.());
    editor.addCommand(m.KeyMod.CtrlCmd | m.KeyMod.Shift | m.KeyCode.Enter, () => submitRef.current?.());
    applyMarkers();
  };

  return (
    <Editor
      height="100%"
      language="c"
      theme="vs-dark"
      path={path}
      value={value}
      onChange={(v) => onChange?.(v ?? '')}
      onMount={onMount}
      loading={<div className="p-4 text-sm text-slate-500">Loading editor…</div>}
      options={{
        readOnly,
        fontSize,
        fontFamily: "'JetBrains Mono', 'Cascadia Code', Consolas, monospace",
        minimap: { enabled: false },
        scrollBeyondLastLine: false,
        automaticLayout: true,
        tabSize: 4,
        insertSpaces: true,
        lineNumbersMinChars: 3,
        padding: { top: 10 },
        fixedOverflowWidgets: true,
        renderLineHighlight: readOnly ? 'none' : 'line',
        domReadOnly: readOnly,
      }}
    />
  );
});
