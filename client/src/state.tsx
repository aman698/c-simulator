import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api } from './api';
import { useLocalStorage } from './hooks';
import type { CStd, Health, Progress, QuestionSummary, Status, Topic } from './types';

interface AppState {
  questions: QuestionSummary[];
  topics: Topic[];
  progress: Progress | null;
  health: Health | null;
  loading: boolean;
  error: string | null;
  std: CStd;
  setStd: (s: CStd) => void;
  sanitizers: boolean;
  setSanitizers: (b: boolean) => void;
  statusOf: (id: string) => Status;
  refreshProgress: () => Promise<void>;
  reload: () => Promise<void>;
}

const Ctx = createContext<AppState | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [questions, setQuestions] = useState<QuestionSummary[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [progress, setProgress] = useState<Progress | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [std, setStd] = useLocalStorage<CStd>('csim:std', 'c11');
  const [sanitizers, setSanitizers] = useLocalStorage<boolean>('csim:sanitizers', true);

  const refreshProgress = useCallback(async () => {
    try {
      setProgress(await api.progress());
    } catch {
      /* keep the old view */
    }
  }, []);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [qs, ts, pr] = await Promise.all([api.questions(), api.topics(), api.progress()]);
      setQuestions(qs);
      setTopics(ts);
      setProgress(pr);
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
    api.health().then(setHealth, () => setHealth(null));
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  const statusOf = useCallback(
    (id: string): Status => {
      const p = progress?.questions[id];
      return p ? p.status : 'unsolved';
    },
    [progress],
  );

  const value = useMemo<AppState>(
    () => ({
      questions,
      topics,
      progress,
      health,
      loading,
      error,
      std,
      setStd,
      sanitizers,
      setSanitizers,
      statusOf,
      refreshProgress,
      reload,
    }),
    [questions, topics, progress, health, loading, error, std, setStd, sanitizers, setSanitizers, statusOf, refreshProgress, reload],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp outside AppProvider');
  return v;
}
