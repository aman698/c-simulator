/**
 * Tracks and topics of the bank. `slug` = file name in questions/ and folder in questions_src/.
 * `runtime: 'freertos'` compiles submissions against the FreeRTOS kernel + simulator port.
 */
export const TRACKS = {
  c: {
    id: 'c',
    name: 'C',
    perTopic: 30,
    difficulty: { Easy: 10, Medium: 10, Hard: 10 },
    types: ['CODE', 'FUNCTION', 'PREDICT_OUTPUT', 'FIND_THE_BUG'],
    checkTypeMix: true,
    embeddedMin: 9,
  },
  freertos: {
    id: 'freertos',
    name: 'FreeRTOS',
    perTopic: 10,
    difficulty: { Easy: 3, Medium: 4, Hard: 3 },
    types: ['CODE', 'FUNCTION'],
    checkTypeMix: false,
    embeddedMin: 0,
  },
};

export const TOPICS = [
  { slug: 'arrays', name: 'Arrays', prefix: 'ARR', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'strings', name: 'Strings', prefix: 'STR', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'patterns', name: 'C Patterns', prefix: 'PAT', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'bit-manipulation', name: 'Bit Manipulation', prefix: 'BIT', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'pointers', name: 'Pointers', prefix: 'PTR', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'structures', name: 'Structures', prefix: 'STC', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'enums', name: 'Enums', prefix: 'ENM', track: 'c', runtime: 'c', leakCheck: false },
  { slug: 'dynamic-memory', name: 'Dynamic Memory', prefix: 'MEM', track: 'c', runtime: 'c', leakCheck: true },

  { slug: 'rtos-tasks', name: 'Tasks & Scheduling', prefix: 'RTK', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-queues', name: 'Queues', prefix: 'RQU', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-sync', name: 'Semaphores & Mutexes', prefix: 'RSM', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-events', name: 'Event Groups & Notifications', prefix: 'REV', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-timers', name: 'Software Timers', prefix: 'RTM', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-isr', name: 'Interrupts & ISRs', prefix: 'RIS', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-memory', name: 'RTOS Memory Management', prefix: 'RMM', track: 'freertos', runtime: 'freertos', leakCheck: false },
  { slug: 'rtos-design', name: 'RTOS Design Patterns', prefix: 'RDS', track: 'freertos', runtime: 'freertos', leakCheck: false },
];

export const DIFFICULTIES = ['Easy', 'Medium', 'Hard'];
export const TYPES = ['CODE', 'FUNCTION', 'PREDICT_OUTPUT', 'FIND_THE_BUG'];
export const PREDICT_SPECIAL = ['Undefined Behavior', 'Compile Error'];

export const topicByName = (name) => TOPICS.find((t) => t.name === name);
export const topicBySlug = (slug) => TOPICS.find((t) => t.slug === slug);
export const trackOf = (q) => TRACKS[topicByName(q.topic)?.track || 'c'];
export const runtimeOf = (q) => topicByName(q.topic)?.runtime || 'c';

/** Leak checking is forced on for the Dynamic Memory topic even when sanitizers are toggled off. */
export const needsLeakCheck = (q) => Boolean(topicByName(q.topic)?.leakCheck);
