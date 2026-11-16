export type Difficulty = 'Easy' | 'Medium' | 'Hard';
export type QType = 'CODE' | 'FUNCTION' | 'PREDICT_OUTPUT' | 'FIND_THE_BUG';
export type Verdict =
  | 'Accepted'
  | 'Wrong Answer'
  | 'Compile Error'
  | 'Runtime Error'
  | 'Time Limit Exceeded'
  | 'Memory Leak';
export type Status = 'unsolved' | 'attempted' | 'solved';

export interface Topic {
  slug: string;
  name: string;
  prefix: string;
  leakCheck: boolean;
  count: number;
}

export interface QuestionSummary {
  id: string;
  topic: string;
  difficulty: Difficulty;
  type: QType;
  title: string;
  tags: string[];
}

export interface TestCase {
  input: string;
  output: string;
}

export interface QuestionProgress {
  status: 'attempted' | 'solved';
  attempts: number;
  runs?: number;
  lastVerdict?: string;
  solvedAt?: string;
  firstAttemptAt?: string;
}

export interface SavedCode {
  code: string;
  updatedAt: number;
}

export interface QuestionDetail extends QuestionSummary {
  statement_md: string;
  constraints_md: string;
  starter_code: string;
  sample_tests: TestCase[];
  hidden_test_count: number;
  hints: string[];
  has_harness: boolean;
  progress: QuestionProgress | null;
  saved: SavedCode | null;
}

export interface Solution {
  solution_code: string;
  explanation_md: string;
  predict_answer: string | null;
}

export interface Diagnostic {
  file: string;
  line: number;
  column: number;
  severity: 'error' | 'warning' | 'note';
  message: string;
}

export interface TestResult {
  index: number;
  hidden?: boolean;
  input?: string;
  expected?: string | null;
  stdout?: string;
  stderr?: string;
  exitCode: number | null;
  signal?: string | null;
  timeMs: number;
  verdict: Verdict;
  message: string;
  line?: number | null;
  leak?: boolean;
}

export interface JudgeResult {
  compile: {
    ok: boolean;
    output: string;
    diagnostics: Diagnostic[];
    warnings: number;
    errors: number;
    command: string;
  };
  tests: TestResult[];
  verdict: Verdict | null;
  passed: number;
  total: number;
  toolchain: { mode: string; version: string; sanitizers: string; leakDetection: boolean };
  custom?: boolean;
  referenceNote?: string;
}

export interface PredictResult {
  correct: boolean;
  verdict: Verdict;
  expected: string | null;
  explanation_md: string | null;
  solution_code: string | null;
}

export interface Submission {
  id: string;
  questionId: string;
  title: string;
  topic: string;
  difficulty: Difficulty;
  kind: 'submit' | 'predict' | 'interview';
  verdict: Verdict;
  passed: number | null;
  total: number | null;
  timeMs: number | null;
  at: string;
}

export interface InterviewResult {
  attempts: number;
  bestPassed: number;
  total: number;
  verdict: Verdict | null;
}

export interface InterviewSession {
  id: string;
  topics: string[];
  questionIds: string[];
  questions: QuestionSummary[];
  startedAt: string;
  durationMs: number;
  finishedAt: string | null;
  results: Record<string, InterviewResult>;
  score: number | null;
  breakdown?: { id: string; points: number; max: number; verdict: string; passed: number; total: number }[];
  remainingMs: number;
  elapsedMs?: number;
}

export interface Progress {
  questions: Record<string, QuestionProgress>;
  submissions: Submission[];
  activity: Record<string, number>;
  streak: { current: number; longest: number };
  interviews: InterviewSession[];
}

export interface Health {
  ok: boolean;
  questions: number;
  toolchain: {
    mode: string;
    version?: string;
    machine?: string;
    platform?: string;
    sanitizers?: string;
    command?: string;
    error?: string;
    support?: Record<string, boolean>;
  };
}

export type CStd = 'c99' | 'c11';
