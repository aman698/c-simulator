# Authoring questions

Questions are written as plain-text **`.q` source files** in `questions_src/<topic-slug>/<ID>.q`.
`npm run build:questions` compiles them into the strict-schema JSON files `questions/<topic-slug>.json`
that the app serves. The source format exists only so that C code and Markdown never have to be
JSON-escaped; the JSON is the deliverable and is regenerated on every `npm run dev` / `npm run validate`.

| Topic | slug (folder / JSON file) | ID prefix |
|---|---|---|
| Arrays | `arrays` | `ARR` |
| Strings | `strings` | `STR` |
| C Patterns | `patterns` | `PAT` |
| Bit Manipulation | `bit-manipulation` | `BIT` |
| Pointers | `pointers` | `PTR` |
| Structures | `structures` | `STC` |
| Enums | `enums` | `ENM` |
| Dynamic Memory | `dynamic-memory` | `MEM` |

IDs are `PREFIX-<E|M|H>-NN`, e.g. `PTR-M-04` (E/M/H must match the difficulty, NN = 01..10).
The file name must be `<ID>.q`.

## 1. The `.q` format

A file is a sequence of sections. Each section starts with a line `@@@ <name>` and its body is
everything up to the next `@@@` line, taken **verbatim** (no escaping).

```
@@@ meta
id: PTR-M-04
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Short Title In Title Case
tags: embedded, double-pointer, asked-in-automotive
@@@ statement_md
Markdown...
@@@ constraints_md
- bullet list
@@@ starter_code
C code the user starts from
@@@ harness_code
hidden main() with /*USER_CODE*/ (FUNCTION; optional for FIND_THE_BUG)
@@@ sample_input
...
@@@ sample_output
...
@@@ hidden_input
...
@@@ hidden_output
...
@@@ predict_answer
(PREDICT_OUTPUT only)
@@@ hint
first hint
@@@ hint
second hint
@@@ solution_code
reference solution
@@@ explanation_md
Markdown...
```

Rules:
- `sample_input`/`sample_output` (and `hidden_*`) come in **pairs**, in order. Repeat the pair once per test.
- Code and Markdown sections: leading/trailing blank lines are trimmed.
- Inputs: trailing blank lines are trimmed and a single `\n` is appended (an empty section = empty stdin).
  A line that is exactly `<<BLANK>>` stands for an intentionally empty input line.
- Outputs: trailing blank lines are trimmed; **leading spaces are significant** (patterns!).
- An output section containing just `<<AUTO>>` is filled in from the reference solution by
  `npm run q -- fill <file>`. Use it for long outputs (patterns, big tests) and **review what it wrote**.
  Hand-write expected outputs for small tests: a mismatch between your hand-written answer and the
  solution is exactly the kind of bug the validator is there to catch.
- Exactly **2 hints** (progressive: nudge first, then the key idea).

## 2. Question types

### CODE
Full program, stdin -> stdout. `starter_code` must compile (warnings are fine) and should contain
the I/O skeleton so the user focuses on the logic.

### FUNCTION
The user implements one function; `starter_code` is only the signature + a stub body (no `main`).
`harness_code` is a complete C file containing the marker `/*USER_CODE*/` exactly once; the judge
pastes the user's code there (with `#line` directives so errors point at the user's own lines).
The harness `main()` reads a test description from stdin, calls the function and prints results.

Harness guidelines:
- `#include` every header the harness and the function signature need **before** the marker.
- Print clear, deterministic results; for "in-place" APIs also verify pointer identity, return values.
- Ban library shortcuts with macros placed before the marker and `#undef`-ed after it, e.g.
  `#define strlen(s) strlen_is_not_allowed_here` (the user then gets a compile error if they cheat).
- Guard buffers with canaries to report `OUT OF BOUNDS WRITE` instead of silently passing.
- The harness itself must be warning-free, leak-free and UB-free.
- To test large sizes without huge test files, let the harness **generate data** from a seed in the
  input with a tiny deterministic LCG (`x = x * 1103515245u + 12345u`), never `rand()`.
- To test `volatile`-correctness (cannot be observed at `-O0`), check the type in the harness:
  `_Generic(&g_rx_flag, volatile int *: 1, default: 0)` and print `FAIL: not volatile`.
- To test realloc/malloc failure handling, make the exercise call an allocator hook supplied by the
  harness (e.g. `void *xrealloc(void *, size_t)` declared in the statement) that fails on demand.

### PREDICT_OUTPUT
`starter_code` is the full compilable snippet, and the same snippet is shown in `statement_md` in a
```` ```c ```` block. `predict_answer` is the exact stdout, or exactly `Undefined Behavior`, or
exactly `Compile Error`. No tests. `solution_code` = the snippet annotated with comments explaining
each step. State the platform in the statement:
**"Assume x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes."**

The validator compiles the snippet with the judge flags (warnings allowed, sanitizers ON) and requires
the real output to equal `predict_answer`; for `Compile Error` it requires compilation to fail.
So a "defined" snippet must contain no UB (implementation-defined behavior such as right-shifting a
negative number, `char` signedness, or out-of-range conversion to a signed type is fine - say so in
the explanation). For `Undefined Behavior`, cite the rule (e.g. C11 6.5p2, unsequenced side effects)
and still make the snippet compile.

### FIND_THE_BUG
`starter_code` is realistic buggy code that **compiles**; `solution_code` is the minimal fix
(comment the fixed line with `/* FIX: ... */`). The buggy code must fail at least one test
(Wrong Answer, Runtime Error, Memory Leak or TLE) and the fix must pass all. Describe intended
behavior and symptoms in the statement, never the bug's location. Optional `harness_code` works as
for FUNCTION. Bugs that only show up under sanitizers (leaks, use-after-free, overflow by one) are
great, but make sure at least one test also exercises them on the heap checker (see section 4).

## 3. Tests

- CODE / FUNCTION / FIND_THE_BUG: at least **2 sample + 5 hidden** tests, all inputs distinct.
- Cover: empty input / n = 0 (when allowed), n = 1, max size, negative numbers, `INT_MIN`/`INT_MAX`,
  all-same elements, NULL (FUNCTION harness can pass NULL explicitly), duplicates, boundaries.
- Keep each test under ~50 KB; prefer harness-generated data for big sizes.
- Output must be deterministic: no `%p`, no uninitialized reads, no reliance on the order of equal
  keys in `qsort` (glibc and Windows sort differently) - make comparators total.
- The judge compares after normalizing: CRLF -> LF, trailing spaces/tabs removed on every line,
  trailing blank lines removed. Leading spaces matter.
- Time limit 2 s per test with sanitizers (roughly 2-3x slower than plain `-O0`).

## 4. The judge environment and portability rules

Compile command (exact judge flags, sanitizers ON, C11):

```
gcc -std=c11 -Wall -Wextra -Werror=implicit-function-declaration -g -fsanitize=address,undefined -o prog main.c -lm
```

- Linux/WSL/Docker: real ASan + UBSan + LeakSanitizer. **Leaks fail every topic** when sanitizers
  are ON (and Dynamic Memory forces leak checking even with sanitizers OFF).
- Windows-native MinGW gcc has no ASan/LSan: the judge substitutes UBSan trap mode, the stack
  protector and `judge-runtime/heapcheck.[ch]` (leaks, double/invalid free, heap overflow via
  redzones, write-after-free via quarantine). `npm run validate -- --cc clang` runs a second pass
  with clang + real AddressSanitizer + UBSan on Windows.

The reference solution must compile with **zero warnings** under gcc, pass every test, write nothing
to stderr and leak nothing. The validator also rejects non-portable code (the bank must behave
identically on Linux and Windows):

- **Never use `long` / `unsigned long` / `long double`** (8 bytes on Linux, 4 on Windows). Use `int`,
  `long long`, `size_t`, `<stdint.h>` types. Print `int64_t`/`uint64_t` via a cast:
  `printf("%lld", (long long)x)`, `uint32_t` with `%u` (or `PRIu32`), `size_t` with `%zu`.
- No POSIX/BSD/MSVC extras hidden by `-std=c11`: `strdup`, `strndup`, `strtok_r`, `getline`,
  `strcasecmp`, `itoa`, `M_PI`, `ssize_t`, `typeof` (use `__typeof__`), `unistd.h`, `sys/*`, ...
- No `rand`/`srand`/`time`/`clock`, no `%p`, no `wchar_t`, no `aligned_alloc`, no `fflush(stdin)`.
- Big arrays: make them `static` (Windows default stack is 1 MB); keep locals under ~64 KB.
- Never name a struct member, function pointer or local function `malloc`, `calloc`, `realloc` or
  `free` (e.g. an allocator "vtable" with a `.free` member): the Windows heap checker defines these
  as function-like macros. Use `alloc_fn` / `free_fn` etc.
- `Compile Error` predict snippets must be hard errors in **both** gcc and clang (check both passes);
  e.g. assigning to a `const` object, a missing declaration, a `break` outside a loop/switch.
- Bit-field layout is forced to the Linux (SysV) layout on MinGW (`-mno-ms-bitfields`).
- `char` is signed on x86-64; right shift of a negative `int` is arithmetic in gcc (impl.-defined).

## 5. Statement, explanation, tags

- Statements are fully specified: exact input format, exact output format, constraints, at least one
  worked example. Interview tone, embedded/automotive context where natural.
- `explanation_md` must cover: **Approach**, **Complexity** (time + space; "O(...)"),
  **Common mistakes**, **Interview follow-ups** (2-4 real follow-up questions). The validator checks
  for the words "complexity", "mistake"/"pitfall"/"trap" and "follow-up".
- Tags: lowercase-kebab-case. Tag embedded/automotive-flavored questions with `embedded`
  (>= 30% of each topic). Optional company-style tags: `asked-in-automotive`, `bsp`, `misra`, ...
- Difficulty: Easy = clear concept check (5-10 min); Medium = needs a technique or trap awareness
  (15-20 min); Hard = multi-concept, edge-case heavy or embedded design in C (25-40 min).
- Per topic: 30 questions, 10 Easy / 10 Medium / 10 Hard, ~18 CODE+FUNCTION, ~6 PREDICT_OUTPUT,
  ~6 FIND_THE_BUG, every question testing a distinct concept.

## 6. Workflow

```bash
npm run q -- new pointers PTR-H-03 FUNCTION "Title"   # scaffold a file
# ...write it...
npm run q -- fill questions_src/pointers/PTR-H-03.q   # fill <<AUTO>> outputs (optional)
npm run q -- check questions_src/pointers/PTR-H-03.q  # validate one file, verbose
npm run q -- run PTR-H-03 --input "3\n1 2 3"           # run the solution on ad-hoc input
npm run validate -- --topic pointers                   # whole topic + bank rules (gcc)
npm run validate -- --topic pointers --cc clang        # Windows only: ASan/UBSan pass
node scripts/validate_questions.js --src --topic pointers   # validate straight from .q sources
npm run validate                                       # everything -> "240/240 questions valid"
```
