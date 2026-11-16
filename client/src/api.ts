import type {
  CStd,
  Health,
  InterviewSession,
  JudgeResult,
  PredictResult,
  Progress,
  QuestionDetail,
  QuestionSummary,
  SavedCode,
  Solution,
  Topic,
} from './types';

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(url, {
      ...init,
      headers: { 'content-type': 'application/json', ...(init?.headers || {}) },
    });
  } catch {
    throw new Error('Cannot reach the judge server. Is `npm run dev` running?');
  }
  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    /* non-JSON */
  }
  if (!res.ok) {
    const msg = (data as { error?: string } | null)?.error || `${res.status} ${res.statusText}`;
    throw new Error(msg);
  }
  return data as T;
}

const post = <T>(url: string, body: unknown) => request<T>(url, { method: 'POST', body: JSON.stringify(body) });

export interface JudgeOptions {
  code: string;
  std: CStd;
  sanitizers: boolean;
}

export const api = {
  health: () => request<Health>('/api/health'),
  topics: () => request<Topic[]>('/api/topics'),
  questions: () => request<QuestionSummary[]>('/api/questions'),
  question: (id: string) => request<QuestionDetail>(`/api/questions/${encodeURIComponent(id)}`),
  solution: (id: string) => request<Solution>(`/api/questions/${encodeURIComponent(id)}/solution`),
  run: (id: string, opts: JudgeOptions & { customInput?: string }) =>
    post<JudgeResult>(`/api/questions/${encodeURIComponent(id)}/run`, opts),
  submit: (id: string, opts: JudgeOptions & { interviewId?: string }) =>
    post<JudgeResult>(`/api/questions/${encodeURIComponent(id)}/submit`, opts),
  predict: (id: string, answer: string, interviewId?: string) =>
    post<PredictResult>(`/api/questions/${encodeURIComponent(id)}/predict`, { answer, interviewId }),
  playground: (opts: JudgeOptions & { stdin: string; leakCheck: boolean }) => post<JudgeResult>('/api/playground', opts),
  progress: () => request<Progress>('/api/progress'),
  saveCode: (id: string, code: string, updatedAt: number) =>
    request<SavedCode>(`/api/code/${encodeURIComponent(id)}`, { method: 'PUT', body: JSON.stringify({ code, updatedAt }) }),
  startInterview: (topics: string[]) => post<InterviewSession>('/api/interview/start', { topics }),
  interview: (id: string) => request<InterviewSession>(`/api/interview/${encodeURIComponent(id)}`),
  finishInterview: (id: string) => post<InterviewSession>(`/api/interview/${encodeURIComponent(id)}/finish`, {}),
};
