import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api } from './api';
import { useLocalStorage } from './hooks';
import type { CStd, Health, Progress, QuestionSummary, Status, Topic, Track } from './types';

interface AppState {
  /** every question / topic of every track */
  allQuestions: QuestionSummary[];
  allTopics: Topic[];
  /** questions / topics of the selected track */
  questions: QuestionSummary[];
  topics: Topic[];
  track: Track;
  setTrack: (t: Track) => void;
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
  const [allQuestions, setAllQuestions] = useState<QuestionSummary[]>([]);
  const [allTopics, setAllTopics] = useState<Topic[]>([]);
  const [progress, setProgress] = useState<Progress | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [track, setTrack] = useLocalStorage<Track>('csim:track', 'c');
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
      setAllQuestions(qs);
      setAllTopics(ts);
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

  const questions = useMemo(() => allQuestions.filter((q) => (q.track || 'c') === track), [allQuestions, track]);
  const topics = useMemo(() => allTopics.filter((t) => (t.track || 'c') === track), [allTopics, track]);

  const value = useMemo<AppState>(
    () => ({
      allQuestions,
      allTopics,
      questions,
      topics,
      track,
      setTrack,
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
    [allQuestions, allTopics, questions, topics, track, setTrack, progress, health, loading, error, std, setStd, sanitizers, setSanitizers, statusOf, refreshProgress, reload],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp outside AppProvider');
  return v;
}
