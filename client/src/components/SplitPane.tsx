import { useRef, type PointerEvent, type ReactNode } from 'react';
import { useLocalStorage } from '../hooks';

interface Props {
  direction: 'horizontal' | 'vertical';
  initial: number; // ratio of the first pane, 0..1
  minPx?: number;
  storageKey: string;
  children: [ReactNode, ReactNode];
}

/** Two panes with a draggable divider; the ratio is remembered per storageKey. */
export function SplitPane({ direction, initial, minPx = 180, storageKey, children }: Props) {
  const [ratio, setRatio] = useLocalStorage<number>(`csim:split:${storageKey}`, initial);
  const box = useRef<HTMLDivElement>(null);
  const horizontal = direction === 'horizontal';

  const onPointerDown = (e: PointerEvent<HTMLDivElement>) => {
    e.preventDefault();
    const el = box.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const total = horizontal ? rect.width : rect.height;
    const min = Math.min(0.45, minPx / Math.max(total, 1));
    const move = (ev: globalThis.PointerEvent) => {
      const pos = horizontal ? (ev.clientX - rect.left) / rect.width : (ev.clientY - rect.top) / rect.height;
      setRatio(Math.min(1 - min, Math.max(min, pos)));
    };
    const up = () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
      document.body.style.userSelect = '';
      document.body.style.cursor = '';
    };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    document.body.style.userSelect = 'none';
    document.body.style.cursor = horizontal ? 'col-resize' : 'row-resize';
  };

  return (
    <div ref={box} className={`flex h-full w-full min-h-0 min-w-0 ${horizontal ? 'flex-row' : 'flex-col'}`}>
      <div className="min-h-0 min-w-0 shrink-0 overflow-hidden" style={{ flexBasis: `${ratio * 100}%` }}>
        {children[0]}
      </div>
      <div
        role="separator"
        aria-orientation={horizontal ? 'vertical' : 'horizontal'}
        onPointerDown={onPointerDown}
        onDoubleClick={() => setRatio(initial)}
        title="Drag to resize (double-click to reset)"
        className={`shrink-0 bg-slate-800 transition-colors hover:bg-sky-600/70 ${horizontal ? 'gutter-h w-1.5' : 'gutter-v h-1.5'}`}
      />
      <div className="min-h-0 min-w-0 flex-1 overflow-hidden">{children[1]}</div>
    </div>
  );
}
