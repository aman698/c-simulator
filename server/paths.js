import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const QUESTIONS_DIR = path.join(ROOT, 'questions');
export const QUESTIONS_SRC_DIR = path.join(ROOT, 'questions_src');
export const RUNTIME_DIR = path.join(ROOT, 'judge-runtime');
export const DATA_DIR = process.env.CSIM_DATA_DIR || path.join(ROOT, 'data');
export const DIST_DIR = path.join(ROOT, 'dist');
