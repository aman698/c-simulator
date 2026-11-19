/** Loads questions/<topic>.json (re-reads a file when its mtime changes). */
import fs from 'node:fs';
import path from 'node:path';
import { QUESTIONS_DIR } from './paths.js';
import { TOPICS, topicByName } from './topics.js';

const cache = new Map(); // slug -> { mtimeMs, questions }

function loadTopic(topic) {
  const file = path.join(QUESTIONS_DIR, `${topic.slug}.json`);
  let stat;
  try {
    stat = fs.statSync(file);
  } catch {
    cache.delete(topic.slug);
    return [];
  }
  const hit = cache.get(topic.slug);
  if (hit && hit.mtimeMs === stat.mtimeMs) return hit.questions;
  try {
    const questions = JSON.parse(fs.readFileSync(file, 'utf8'));
    cache.set(topic.slug, { mtimeMs: stat.mtimeMs, questions });
    return questions;
  } catch (err) {
    console.error(`[questions] cannot parse ${file}: ${err.message}`);
    return hit ? hit.questions : [];
  }
}

export function allQuestions() {
  return TOPICS.flatMap(loadTopic);
}

export function getQuestion(id) {
  return allQuestions().find((q) => q.id === id) || null;
}

/** Sidebar/list view. */
export function summary(q) {
  return {
    id: q.id,
    topic: q.topic,
    difficulty: q.difficulty,
    type: q.type,
    title: q.title,
    tags: q.tags,
    track: topicByName(q.topic)?.track || 'c',
  };
}

/** Everything the question page needs, minus the secrets (harness, hidden tests, answers). */
export function publicView(q) {
  return {
    ...summary(q),
    statement_md: q.statement_md,
    constraints_md: q.constraints_md,
    starter_code: q.starter_code,
    sample_tests: q.sample_tests,
    hidden_test_count: q.hidden_tests.length,
    hints: q.hints,
    has_harness: Boolean(q.harness_code),
  };
}
