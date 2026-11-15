/** The 8 topics of the bank. `slug` = file name in questions/ and folder in questions_src/. */
export const TOPICS = [
  { slug: 'arrays', name: 'Arrays', prefix: 'ARR', leakCheck: false },
  { slug: 'strings', name: 'Strings', prefix: 'STR', leakCheck: false },
  { slug: 'patterns', name: 'C Patterns', prefix: 'PAT', leakCheck: false },
  { slug: 'bit-manipulation', name: 'Bit Manipulation', prefix: 'BIT', leakCheck: false },
  { slug: 'pointers', name: 'Pointers', prefix: 'PTR', leakCheck: false },
  { slug: 'structures', name: 'Structures', prefix: 'STC', leakCheck: false },
  { slug: 'enums', name: 'Enums', prefix: 'ENM', leakCheck: false },
  { slug: 'dynamic-memory', name: 'Dynamic Memory', prefix: 'MEM', leakCheck: true },
];

export const DIFFICULTIES = ['Easy', 'Medium', 'Hard'];
export const TYPES = ['CODE', 'FUNCTION', 'PREDICT_OUTPUT', 'FIND_THE_BUG'];
export const PREDICT_SPECIAL = ['Undefined Behavior', 'Compile Error'];

export const topicByName = (name) => TOPICS.find((t) => t.name === name);
export const topicBySlug = (slug) => TOPICS.find((t) => t.slug === slug);

/** Leak checking is forced on for the Dynamic Memory topic even when sanitizers are toggled off. */
export const needsLeakCheck = (q) => Boolean(topicByName(q.topic)?.leakCheck);
