# C Practice Simulator

A LeetCode-style, fully local practice app for **embedded / automotive C interviews**. It has a real `gcc` judge with
AddressSanitizer, UndefinedBehaviorSanitizer and LeakSanitizer, and a bank of **240 verified questions**
(8 topics × 30, each topic 10 Easy / 10 Medium / 10 Hard).

![Problem page](docs/screenshots/01-problem.png)

| Memory-leak detection | Predict the output |
|---|---|
| ![Memory leak verdict](docs/screenshots/02-memory-leak-verdict.png) | ![Predict output](docs/screenshots/03-predict-output.png) |
| **Dashboard** | **Playground** |
| ![Dashboard](docs/screenshots/05-dashboard.png) | ![Playground](docs/screenshots/04-playground.png) |

## Features

- **Real compiler judge.** Code is compiled with
  `gcc -std=c11 -Wall -Wextra -Werror=implicit-function-declaration -g -fsanitize=address,undefined -o prog main.c`
  and run against every test with a **2 s** time limit and a memory limit. Verdicts are
  `Accepted | Wrong Answer | Compile Error | Runtime Error | Time Limit Exceeded | Memory Leak`.
- **Toggles.** Sanitizers ON/OFF and a C99/C11 dropdown.
- **Leak detection.** A leak fails the test with *"Memory leak detected"* even when the output is correct. The
  **Dynamic Memory** topic always checks for leaks, even with sanitizers OFF.
- **Four question types.**
  - **CODE:** a full program, stdin to stdout.
  - **FUNCTION:** you write one function and a hidden `main()` harness calls it.
  - **PREDICT_OUTPUT:** type the exact output, or pick *Undefined Behavior* / *Compile Error*.
  - **FIND_THE_BUG:** buggy code is preloaded and you fix it.
- **Results panel.** Compile errors and warnings appear as squiggles in the editor and as clickable line links.
  Each failing test shows the sanitizer report (ASan, UBSan, LSan), stdout, stderr, exit code and time.
- **Run vs Submit.** **Run** uses the sample tests. **Submit** also runs the hidden tests, and the first failing
  hidden test is shown in full. **Custom input** runs your code on any stdin and compares it against the
  reference solution's output for that input.
- **Hints and solutions.** Up to 2 hints, revealed one at a time. *Show solution* unlocks after one attempt and
  includes an explanation (approach, time/space complexity, common mistakes, interview follow-ups).
- **Autosave.** Your code is saved per question, in localStorage and on the backend.
- **Sidebar.** Lists the 8 topics; filters by difficulty, type and status, plus an *Embedded-specific only*
  filter and search.
- **Dashboard.** Solved count per topic and per difficulty, current and longest streak, activity heatmap, the last
  10 submissions, and interview history.
- **Interview Mode.** Three random questions (1 Easy, 1 Medium, 1 Hard) from the topics you choose, a 45-minute
  timer, no hints, and a score out of 100 at the end (20/30/50 points, with partial credit for tests passed).
- **Playground.** A blank editor with stdin for free experimentation.
- **Shortcuts.** <kbd>Ctrl</kbd>+<kbd>Enter</kbd> = Run, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Enter</kbd> = Submit.

## Quick start

You need **Node.js ≥ 20.19** and **gcc**. The recommended setup is **Linux or WSL2**, which gives you the real ASan,
UBSan and LeakSanitizer.

### Linux / WSL2 (recommended)

```bash
# Windows only: install WSL2 + Ubuntu once, from an *administrator* PowerShell, then reboot:
#   wsl --install -d Ubuntu
# Then inside Ubuntu:
sudo apt update && sudo apt install -y build-essential          # gcc with libasan/libubsan/liblsan
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs

cd ~ && cp -r "/mnt/c/Users/<you>/Documents/c simulator" c-simulator && cd c-simulator   # or git clone
npm install
npm run dev            # judge API on :3001 + web UI on http://localhost:5173
```

Open **http://localhost:5173** in your Windows browser (WSL2 forwards localhost).

Keep the project inside the Linux filesystem (`~/...`), not under `/mnt/c`. Builds and process spawning are
much faster there.

### Docker (optional, strongest sandbox)

If `docker info` works, the judge picks Docker automatically. On first start it pulls `gcc:latest` in the
background, and uses native gcc until the pull finishes. Every submission then runs in a throw-away container
with `--network none --memory=128m --pids-limit 64 --cpus 1`.

To force a mode, set `JUDGE_MODE=docker` or `JUDGE_MODE=native` (`npm run dev` uses `auto`).

### Windows without WSL (fallback)

```powershell
node scripts/setup_windows_toolchain.js           # portable MSYS2 gcc into .toolchain/ (no admin needed)
node scripts/setup_windows_toolchain.js --clang   # optional: clang + AddressSanitizer for Windows
npm install
npm run dev
```

MinGW gcc has **no ASan/LSan runtime**. On Windows the judge substitutes:

- UBSan in trap mode,
- `-fstack-protector-strong`,
- `-mno-ms-bitfields` (Linux struct layout),
- its own portable heap checker, [`judge-runtime/heapcheck.c`](judge-runtime/heapcheck.c). It detects leaks,
  double/invalid `free`, heap overflow (redzones) and write-after-free (quarantine poisoning).

The toolbar pill shows which mode is active.

### Production build

```bash
npm start          # builds the UI into dist/ and serves UI + API on http://localhost:3001
```

## How the judge works

| Step | What happens |
|---|---|
| Assemble | FUNCTION/FIND_THE_BUG questions with a hidden harness get your code inserted at `/*USER_CODE*/`. `#line` directives keep compiler errors and sanitizer stack traces pointing at **your** line numbers. |
| Compile | Exact judge flags (above) plus `-lm`, in a fresh temp directory (deleted afterwards) or a Docker container. |
| Run | Each test gets its stdin, a 2 s wall-clock limit (process-group kill), a 1 MiB stdout cap, and a memory limit: `ulimit -v 256 MB` natively without sanitizers, ASan `hard_rss_limit_mb` with sanitizers, or Docker `--memory=128m`. |
| Compare | CRLF→LF, trailing spaces on every line and trailing blank lines are ignored. **Leading spaces matter** (patterns!). |
| Verdict | TLE → Runtime Error (signal, ASan/UBSan report, non-zero exit) → Wrong Answer → Memory Leak → Accepted, decided per test. |

Sanitizer mode by platform:

| Platform | Sanitizers ON | Sanitizers OFF |
|---|---|---|
| Linux / WSL2 / Docker | `-fsanitize=address,undefined` (LSan included) | plain; Dynamic Memory adds `-fsanitize=leak` |
| Windows + MinGW gcc | UBSan trap + stack protector + heap checker | plain; Dynamic Memory adds the heap checker |
| Windows + clang (`CC=clang`) | ASan + UBSan + heap checker (leaks) | plain |

Environment variables: `PORT` (API, default 3001), `CC` (compiler), `JUDGE_MODE` (`auto|docker|native`),
`JUDGE_DOCKER_IMAGE` (default `gcc:latest`), `JUDGE_PARALLEL` (concurrent judge jobs), `CSIM_DATA_DIR`
(progress storage, default `data/`).

## The question bank

| Topic | Questions | Easy / Medium / Hard | Embedded-tagged |
|---|---|---|---|
<!-- BANK_TABLE -->

Every topic has about 18 CODE/FUNCTION, 6 PREDICT_OUTPUT and 6 FIND_THE_BUG questions. At least 30% are
embedded/automotive-flavoured, for example:

- UART ring buffers, ADC filters, sensor calibration lookup tables;
- CAN signal packing (Intel/Motorola), J1939 decoding, CRC-8 SAE J1850 and CRC-16-CCITT;
- memory-mapped registers through `volatile` pointers, ISR dispatch tables;
- UDS request parsing and session state machines, DTC status bytes;
- fixed-block memory pools and a `my_malloc` with coalescing.

Each question follows the strict JSON schema in `questions/<topic>.json`. Every CODE, FUNCTION and FIND_THE_BUG
question has at least 2 sample and 5 hidden tests covering edge cases (n = 0/1, max size, negatives,
`INT_MIN`/`INT_MAX`, all-equal values, NULL, ...).

### Adding a question

Questions are authored as plain-text `.q` files in `questions_src/<topic>/` (no JSON escaping of C code), and
`npm run build:questions` generates `questions/*.json`. The full format and rules are in
**[docs/AUTHORING.md](docs/AUTHORING.md)**.

```bash
npm run q -- new pointers PTR-H-11 FUNCTION "My new question"   # scaffold
npm run q -- fill questions_src/pointers/PTR-H-11.q             # fill <<AUTO>> outputs from the solution
npm run q -- check questions_src/pointers/PTR-H-11.q            # validate one file
npm run validate                                                 # validate the whole bank
```

## Validation

`scripts/validate_questions.js` uses the **same judge code as the app**. For every question it:

1. checks the JSON schema and unique IDs, 30 questions (10/10/10) per topic, the type mix, and ≥ 30% `embedded`;
2. lints for portability (no `long`, no POSIX-only calls hidden by `-std=c11`, no `%p`, no `rand`, ...);
3. compiles `solution_code` (inside the harness for FUNCTION) with the exact judge flags and **requires zero
   warnings**;
4. runs **all** sample + hidden tests and requires 100% Accepted, with no sanitizer, UB or leak reports and nothing
   on stderr;
5. for **FIND_THE_BUG**, requires that the buggy starter code compiles and **fails at least one test**;
6. for **PREDICT_OUTPUT**, compiles the snippet and requires its real output to equal `predict_answer`. For
   *Compile Error* answers it requires that compilation fails;
7. checks that CODE/FUNCTION starter templates compile.

Final validator output:

```
<!-- VALIDATOR_OUTPUT -->
```

<!-- VALIDATION_NOTES -->

## Project layout

```
client/                 React + Vite + TypeScript + Tailwind + Monaco UI
server/                 Express API (index.js), progress store, question loader
server/judge/           toolchain detection + compile/run/verdict engine (shared with the validator)
judge-runtime/          portable heap checker used when LeakSanitizer is unavailable
questions/              the bank: one strict-schema JSON file per topic (generated, committed)
questions_src/          .q sources of every question
scripts/                validate_questions.js, build_questions.js, qtool.js, setup_windows_toolchain.js, screenshots.js
docs/                   AUTHORING.md, screenshots
data/                   your progress (progress.json, git-ignored)
```

## Decisions and assumptions

The brief asked for sensible decisions to be made and recorded instead of asked. These are those decisions.

**Stack and storage**
- **Backend: Node.js + Express.** It keeps one language across the repo, and lets the validator import the exact
  judge module the app uses (`server/judge/judge.js`). That guarantees the validator and the app agree.
- **Progress: a local JSON file** (`data/progress.json`, atomic writes) instead of SQLite. This is a single-user
  local app, and it avoids a native module build (node-gyp) on Windows.
- **Question sources: `.q` text files.** `questions_src/*.q` are compiled into the strict-schema
  `questions/<topic>.json`, and the JSON is committed. C code and Markdown inside JSON strings are unreadable
  and error-prone to escape by hand.
- **Schema extension.** `harness_code` is also allowed on FIND_THE_BUG questions. Some bugs (missing
  `volatile`, a bug inside one driver function) are best tested through a hidden harness. For all other
  types it stays empty, as the schema says.

**Judge behaviour**
- **Extra compiler flags:**
  - `-lm` is always appended (needed for `<math.h>` on glibc).
  - `-mno-ms-bitfields` is added on MinGW, so struct and bit-field layout matches Linux.
- **Output comparison** ignores trailing spaces on each line and trailing blank lines. **Leading spaces count**,
  so pattern alignment is still judged.
- **Verdict order per test:** TLE → Runtime Error (signal, sanitizer report, or non-zero exit; `main` must return
  0) → Wrong Answer → Memory Leak → Accepted. If the output is wrong *and* memory leaked, the verdict is Wrong
  Answer and the leak is mentioned in the message.
- **Leak checking:**
  - With sanitizers ON, leaks fail tests in **every** topic. ASan on Linux enables LeakSanitizer by default,
    and the Windows fallback is kept consistent with that.
  - Dynamic Memory keeps leak checking on even with sanitizers OFF (via `-fsanitize=leak`, or the heap checker
    where that is unavailable).
- **Memory limit:**
  - Without a sanitizer runtime: `ulimit -v` 256 MB.
  - With ASan: `hard_rss_limit_mb=384` instead. ASan reserves terabytes of virtual address space, so `ulimit -v`
    would break it.
  - In Docker: `--memory=128m`.
  - Native Windows: no memory limit.
- **Time limit:** 2 s wall clock per test. The program's whole process group is killed on timeout.
- **Hidden tests:** only the **first failing** hidden test shows its input and expected output (LeetCode style);
  the others show only their verdict.
- **Custom input:** the expected output is computed by running the reference solution on the same input.

**Practice features**
- **Solution unlock:** any judged attempt counts (Run or Submit). Only Submit and predict answers count towards
  "solved", the streak and the submission history.
- **Streak:** consecutive days with at least one submission. Today counts as soon as you submit, and the streak
  survives until the day ends.
- **Interview Mode:**
  - It picks coding questions (CODE / FUNCTION / FIND_THE_BUG) when the chosen topics have them.
  - Scoring is 20 / 30 / 50 points for Easy / Medium / Hard, with partial credit in proportion to the best
    passed-test ratio.
  - Hints, solutions and custom input are disabled during the interview. Predict-output answers are revealed
    only after it ends.

**Question bank**
- **Portability rules:** the bank must behave identically on Linux and Windows, so `long`, POSIX-only
  functions, `%p`, `rand` and `wchar_t` are not used. The validator lints for them.
- **PREDICT_OUTPUT platform:** questions assume x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8
  bytes, and say so in the statement.
- **Expected outputs:**
  - Short outputs were written by hand, and the validator cross-checks them against the reference solutions.
  - Long outputs (patterns, big tests) were generated from the reference solution and then reviewed.
  - Several string and protocol questions (NMEA, VIN, Base64, wildcard, AT parsing) were cross-checked
    against independent JavaScript implementations.
- **Large inputs:** big test sizes are produced inside the hidden harness from a seed (a deterministic LCG), so
  the JSON stays small while O(n²) solutions still hit the time limit.

**This build machine (Windows 10)**
- **Toolchain:** the machine had no WSL distro, Docker, Node.js or gcc, and no admin rights for installing
  WSL. So portable Node.js 24, MSYS2 gcc 16.2 and MSYS2 clang 23 (with the Windows ASan runtime) were installed
  into the git-ignored `.toolchain/` folder. The judge finds that gcc automatically when none is on `PATH`.

## Troubleshooting

- **"no compiler found"** in the toolbar: install gcc (`sudo apt install build-essential`), or set `CC=/path/to/gcc`.
- **The pill says "partial sanitizers"**: you are on a toolchain without ASan/LSan (MinGW, or WSL1). Use WSL2/Linux
  for the real thing; the portable heap checker still catches leaks and double frees.
- **Port already in use**: `PORT=3002 npm run dev` changes the API port (Vite proxies to it automatically). The
  UI port 5173 is fixed in `vite.config.ts`.
- **Reset progress**: stop the server and delete `data/progress.json`.
