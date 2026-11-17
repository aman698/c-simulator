@@@ meta
id: MEM-M-08
topic: Dynamic Memory
difficulty: Medium
type: FIND_THE_BUG
title: Sample Logger That Loses Its Data When realloc Fails
tags: embedded, realloc, realloc-failure, memory-leak, error-handling, asked-in-automotive
@@@ statement_md
An ADC sample logger on an infotainment head unit appends 16-bit samples to a growable array. It uses `xrealloc()`, a project wrapper that behaves exactly like `realloc` but lets the test harness simulate out-of-memory on chosen calls.

Required behavior of `log_append`: if the array cannot grow, return `-1` (the harness reports the sample as dropped), and **every sample logged so far must stay intact**. A later append may try to grow again.

The logger works in all normal tests. Under the out-of-memory tests, the judge reports **Wrong Answer** (earlier samples turn into garbage), **Runtime Error**, or **Memory Leak**. Find and fix the bug. The harness (hidden `main()`) is correct.

**How it is tested.** The harness makes the listed `xrealloc` calls fail, appends all samples, prints the drops, the final `len`/`cap` and the logged samples, and then calls `log_free`.

**Input (read by the hidden harness)**
- Line 1: `fail <k>` followed by `k` call numbers (counting `xrealloc` calls from 1) that must return `NULL`.
- Line 2: `n` followed by `n` samples, or `G <n> <seed>` for `n` generated samples.

**Output**
- `drop #<i> (<value>)` for every rejected sample (1-based index).
- `len=<len> cap=<cap>`, then the samples `[...]` (at most 20) or `sum=<sum> first=<first> last=<last>`.

**Example**
```
Input:
fail 1 2
10 1 2 3 4 5 6 7 8 9 10

Output:
drop #9 (9)
len=9 cap=16
[1 2 3 4 5 6 7 8 10]
```
(Call 1 grows the array to 8 slots. Call 2, at the 9th sample, fails. Call 3, at the 10th sample, succeeds.)
@@@ constraints_md
- `0 <= n <= 200000`, samples are in `-32768..32767`.
- At most 16 failing calls per test.
- No leaks, even after failed calls.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

void *xrealloc(void *p, size_t n); /* like realloc; the harness can make it fail */

struct sample_log {
    int16_t *samples;
    size_t len;
    size_t cap;
};

/* Append v. On allocation failure return -1 and keep the log unchanged. */
int log_append(struct sample_log *log, int16_t v)
{
    if (log->len == log->cap) {
        size_t newcap = log->cap ? log->cap * 2 : 8;
        log->samples = xrealloc(log->samples, newcap * sizeof *log->samples);
        if (log->samples == NULL)
            return -1;
        log->cap = newcap;
    }
    log->samples[log->len++] = v;
    return 0;
}

void log_free(struct sample_log *log)
{
    free(log->samples);
    log->samples = NULL;
    log->len = 0;
    log->cap = 0;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int g_calls;
static int g_fail[16];
static int g_nfail;

void *xrealloc(void *p, size_t n)
{
    g_calls++;
    for (int i = 0; i < g_nfail; i++)
        if (g_fail[i] == g_calls)
            return NULL;                 /* simulated out-of-memory: p is untouched */
    return realloc(p, n);
}

/*USER_CODE*/

int main(void)
{
    char word[8];
    if (scanf("%7s %d", word, &g_nfail) != 2 || g_nfail < 0 || g_nfail > 16)
        return 0;
    for (int i = 0; i < g_nfail; i++)
        if (scanf("%d", &g_fail[i]) != 1)
            return 0;

    int n;
    unsigned int seed = 0;
    int generated = 0;
    if (scanf(" G %d %u", &n, &seed) == 2)
        generated = 1;
    else if (scanf("%d", &n) != 1)
        return 0;

    struct sample_log log = { NULL, 0, 0 };
    for (int i = 1; i <= n; i++) {
        int v;
        if (generated) {
            seed = seed * 1103515245u + 12345u;
            v = (int)((seed >> 8) % 65536u) - 32768;
        } else if (scanf("%d", &v) != 1) {
            break;
        }
        if (log_append(&log, (int16_t)v) != 0)
            printf("drop #%d (%d)\n", i, v);
    }

    printf("len=%zu cap=%zu\n", log.len, log.cap);
    if (log.len <= 20) {
        printf("[");
        for (size_t i = 0; i < log.len; i++)
            printf("%s%d", i ? " " : "", log.samples[i]);
        printf("]\n");
    } else {
        long long sum = 0;
        for (size_t i = 0; i < log.len; i++)
            sum += log.samples[i];
        printf("sum=%lld first=%d last=%d\n", sum, log.samples[0], log.samples[log.len - 1]);
    }
    log_free(&log);
    return 0;
}
@@@ sample_input
fail 1 2
10 1 2 3 4 5 6 7 8 9 10
@@@ sample_output
drop #9 (9)
len=9 cap=16
[1 2 3 4 5 6 7 8 10]

@@@ sample_input
fail 0
5 -32768 32767 0 -1 1
@@@ sample_output
len=5 cap=8
[-32768 32767 0 -1 1]

@@@ hidden_input
fail 0
0
@@@ hidden_output
len=0 cap=0
[]

@@@ hidden_input
fail 1 1
3 7 8 9
@@@ hidden_output
drop #1 (7)
len=2 cap=8
[8 9]

@@@ hidden_input
fail 1 2
9 10 20 30 40 50 60 70 80 90
@@@ hidden_output
drop #9 (90)
len=8 cap=8
[10 20 30 40 50 60 70 80]

@@@ hidden_input
fail 3 3 4 5
20 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
@@@ hidden_output
drop #17 (17)
drop #18 (18)
drop #19 (19)
len=17 cap=32
[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 20]

@@@ hidden_input
fail 0
G 200000 3
@@@ hidden_output
len=200000 cap=262144
sum=-5297002 first=-11493 last=-16774

@@@ hidden_input
fail 4 10 11 12 13
G 100000 11
@@@ hidden_output
drop #2049 (-19418)
drop #2050 (-143)
drop #2051 (-2149)
drop #2052 (15881)
len=99996 cap=131072
sum=3012854 first=1422 last=-27335

@@@ hint
Trace what `log->samples` holds right after a failing `xrealloc`. Where is the pointer to the block with the first 8 samples stored at that moment?
@@@ hint
`p = realloc(p, n)` is the classic leak. On failure `realloc` returns `NULL` but does **not** free the old block, and the assignment overwrites the only pointer to it. Store the result in a temporary, and commit it to `log->samples` only if it is not `NULL`.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

void *xrealloc(void *p, size_t n); /* like realloc; the harness can make it fail */

struct sample_log {
    int16_t *samples;
    size_t len;
    size_t cap;
};

/* Append v. On allocation failure return -1 and keep the log unchanged. */
int log_append(struct sample_log *log, int16_t v)
{
    if (log->len == log->cap) {
        size_t newcap = log->cap ? log->cap * 2 : 8;
        int16_t *tmp = xrealloc(log->samples, newcap * sizeof *log->samples); /* FIX: keep the old pointer until success */
        if (tmp == NULL)
            return -1;                       /* old block (and data) still owned by log */
        log->samples = tmp;
        log->cap = newcap;
    }
    log->samples[log->len++] = v;
    return 0;
}

void log_free(struct sample_log *log)
{
    free(log->samples);
    log->samples = NULL;
    log->len = 0;
    log->cap = 0;
}
@@@ explanation_md
**Bug.** `log->samples = xrealloc(log->samples, ...)`. When `realloc` fails it returns `NULL` and **leaves the old block allocated** (C11 7.22.3.5p4). The assignment overwrites the only pointer to that block:
- the logged samples are lost, and the block is **leaked**;
- `len` still says 8, but `samples` is `NULL`. If the run ends now, printing the log dereferences `NULL` (Runtime Error);
- if another append follows, `realloc(NULL, 32)` behaves like `malloc` and returns a fresh block of **garbage**. The log now claims 8 valid samples that are uninitialized (Wrong Answer).

**Fix.** Use a temporary:
```c
int16_t *tmp = xrealloc(log->samples, newcap * sizeof *tmp);
if (tmp == NULL) return -1;     /* log untouched */
log->samples = tmp;
log->cap = newcap;
```
Update `cap` only after success as well.

**Complexity.** Amortized O(1) per append (doubling), O(n) space. The fix costs nothing.

**Common mistakes**
- Using `p = realloc(p, n)` because "malloc never fails on Linux". With overcommit, `malloc` rarely fails on desktops, but it **does** fail on RTOS heaps, under `ulimit`/cgroup limits, for huge sizes, and in 32-bit processes. Static analyzers (cppcheck, PC-lint, Coverity) flag this pattern.
- Freeing the old block on failure "to be safe". The spec says the log must survive, so on failure you keep it.
- Not testing the failure path at all. Fault injection through an allocator hook (as this harness does) is the standard way to cover it.

**Interview follow-ups**
- What does `realloc(p, 0)` do? (Implementation-defined before C23, undefined behavior in C23. Never use it to free.)
- Why might `realloc` be cheaper than `malloc` + `memcpy` + `free`? When does it grow in place?
- For a safety-critical logger (ISO 26262), what replaces this design? A fixed ring buffer sized for the worst case, with an overflow counter, and no dynamic allocation after init (MISRA C:2012 Rule 21.3, Directive 4.12).
