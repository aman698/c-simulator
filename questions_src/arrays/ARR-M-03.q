@@@ meta
id: ARR-M-03
topic: Arrays
difficulty: Medium
type: FUNCTION
title: Partition DTC Records by Severity (Dutch National Flag)
tags: embedded, dutch-national-flag, three-way-partition, in-place, diagnostics, size-t
@@@ statement_md
A diagnostic manager stores Diagnostic Trouble Codes (DTCs) as records:

```c
typedef struct {
    uint16_t code;      /* DTC number                               */
    uint8_t  severity;  /* 0 = info, 1 = warning, 2 = critical      */
} dtc_t;
```

Before the DTC list is sent to the tester, it must be grouped as **all critical records first, then all warnings, then all info records**. Implement

```c
void sort_by_severity(dtc_t *a, size_t n);
```

- Rearrange `a[0..n-1]` **in place** with **one pass** and O(1) extra memory (Dutch national flag partition).
- The order **within** one severity class does not matter.
- Every record must survive intact. A "counting" approach that counts severities and then overwrites the array with `2,2,1,0,...` destroys the `code` fields.
- `a` may be `NULL` only when `n == 0`. `qsort` is disabled.

**How it is tested.** A hidden `main()` calls your function and then checks that the severities are non-increasing and that the multiset of `(code, severity)` records is unchanged. Guard records before and after the array detect out-of-bounds writes. It prints the class sizes, the verdicts and, for small inputs, the severity sequence. Large tests are generated from a seed.

**Input (read by the hidden harness)**
- Either: line 1 `n`, then `n` lines `code severity` (code in hex),
- or: one line `GEN n seed`.

**Output**
- `critical: c2 warning: c1 info: c0`, then `order OK` / `order WRONG at i`, then `records OK` / `records CHANGED`, then (only for explicit input with `n > 0`) `severities: ...`.

**Example**
```
Input:
6
0301 2
0420 1
0171 0
0300 2
0102 0
0128 1

Output:
critical: 2 warning: 2 info: 2
order OK
records OK
severities: 2 2 1 1 0 0
```
@@@ constraints_md
- `0 <= n <= 200000`
- `0 <= code <= 0xFFFF`, `severity` is `0`, `1` or `2`
- One pass, O(n) time, O(1) extra memory. Records must be moved, not regenerated.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

/* dtc_t is already defined by the system:
 *   typedef struct { uint16_t code; uint8_t severity; } dtc_t;
 */

void sort_by_severity(dtc_t *a, size_t n)
{
    /* TODO: critical (2) first, then warning (1), then info (0) */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint16_t code;      /* DTC number                               */
    uint8_t  severity;  /* 0 = info, 1 = warning, 2 = critical      */
} dtc_t;

#define qsort(...) qsort_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef qsort

#define MAXN 200000
#define GUARD 4

static dtc_t arena[GUARD + MAXN + GUARD];
static int balance[3][65536];

static int is_guard(const dtc_t *d)
{
    return d->code == 0xDEADu && d->severity == 0xEEu;
}

int main(void)
{
    char tok[16];
    int n;
    int gen = 0;
    if (scanf("%15s", tok) != 1) return 0;
    if (strcmp(tok, "GEN") == 0) {
        unsigned int seed;
        if (scanf("%d %u", &n, &seed) != 2) return 0;
        if (n < 0 || n > MAXN) return 0;
        gen = 1;
        uint32_t x = seed;
        for (int i = 0; i < n; i++) {
            x = x * 1103515245u + 12345u;
            arena[GUARD + i].code = (uint16_t)(x >> 16);
            arena[GUARD + i].severity = (uint8_t)((x >> 8) % 3u);
        }
    } else {
        if (sscanf(tok, "%d", &n) != 1 || n < 0 || n > MAXN) return 0;
        for (int i = 0; i < n; i++) {
            unsigned code, sev;
            if (scanf("%x %u", &code, &sev) != 2 || code > 0xFFFFu || sev > 2u) return 0;
            arena[GUARD + i].code = (uint16_t)code;
            arena[GUARD + i].severity = (uint8_t)sev;
        }
    }
    for (int i = 0; i < GUARD; i++) {
        arena[i].code = 0xDEADu; arena[i].severity = 0xEEu;
        arena[GUARD + n + i].code = 0xDEADu; arena[GUARD + n + i].severity = 0xEEu;
    }
    dtc_t *a = arena + GUARD;
    int cnt[3] = {0, 0, 0};
    for (int i = 0; i < n; i++) {
        balance[a[i].severity][a[i].code]++;
        cnt[a[i].severity]++;
    }

    sort_by_severity(n == 0 ? NULL : a, (size_t)n);

    for (int i = 0; i < GUARD; i++) {
        if (!is_guard(&arena[i]) || !is_guard(&arena[GUARD + n + i])) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    printf("critical: %d warning: %d info: %d\n", cnt[2], cnt[1], cnt[0]);

    int bad = -1;
    for (int i = 0; i < n; i++) {
        if (a[i].severity > 2u || (i > 0 && a[i].severity > a[i - 1].severity)) { bad = i; break; }
    }
    if (bad >= 0) printf("order WRONG at %d\n", bad);
    else printf("order OK\n");

    int changed = 0;
    for (int i = 0; i < n; i++) {
        if (a[i].severity > 2u) { changed = 1; break; }
        balance[a[i].severity][a[i].code]--;
    }
    for (int i = 0; !changed && i < n; i++) {
        /* n is fixed, so a lost record implies a duplicated one: its balance is negative */
        if (balance[a[i].severity][a[i].code] != 0) changed = 1;
    }
    printf("records %s\n", changed ? "CHANGED" : "OK");

    if (!gen && n > 0) {
        printf("severities:");
        for (int i = 0; i < n; i++) printf(" %u", (unsigned)a[i].severity);
        printf("\n");
    }
    return 0;
}
@@@ sample_input
6
0301 2
0420 1
0171 0
0300 2
0102 0
0128 1
@@@ sample_output
critical: 2 warning: 2 info: 2
order OK
records OK
severities: 2 2 1 1 0 0

@@@ sample_input
5
1001 0
1002 0
1003 1
1004 2
1005 2
@@@ sample_output
critical: 2 warning: 1 info: 2
order OK
records OK
severities: 2 2 1 0 0

@@@ hidden_input
0
@@@ hidden_output
critical: 0 warning: 0 info: 0
order OK
records OK

@@@ hidden_input
1
C0DE 1
@@@ hidden_output
critical: 0 warning: 1 info: 0
order OK
records OK
severities: 1

@@@ hidden_input
4
0001 0
0002 0
0003 0
0004 0
@@@ hidden_output
critical: 0 warning: 0 info: 4
order OK
records OK
severities: 0 0 0 0

@@@ hidden_input
5
FFFF 2
0000 2
FFFF 2
0000 2
1234 2
@@@ hidden_output
critical: 5 warning: 0 info: 0
order OK
records OK
severities: 2 2 2 2 2

@@@ hidden_input
7
0A01 0
0A02 0
0A03 1
0A04 1
0A05 1
0A06 2
0A07 2
@@@ hidden_output
critical: 2 warning: 3 info: 2
order OK
records OK
severities: 2 2 1 1 1 0 0

@@@ hidden_input
8
0B01 1
0B02 0
0B03 2
0B04 1
0B05 0
0B06 2
0B07 1
0B08 0
@@@ hidden_output
critical: 2 warning: 3 info: 3
order OK
records OK
severities: 2 2 1 1 1 0 0 0

@@@ hidden_input
GEN 200000 1
@@@ hidden_output
critical: 66395 warning: 66898 info: 66707
order OK
records OK

@@@ hidden_input
GEN 99999 31337
@@@ hidden_output
critical: 33342 warning: 33290 info: 33367
order OK
records OK

@@@ hint
Keep three regions while you scan: `[0, lo)` is all critical, `[lo, mid)` all warnings, `[hi, n)` all info, and `[mid, hi)` is still unknown. Look only at `a[mid]`.
@@@ hint
Critical: swap `a[lo]` and `a[mid]`, then `lo++` and `mid++`. Warning: `mid++`. Info: `hi--`, swap `a[mid]` and `a[hi]`, and do **not** advance `mid`, because the element swapped in has not been examined. Use an exclusive `hi` (starting at `n`) so that a `size_t` never has to go below zero.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

static void swap_dtc(dtc_t *x, dtc_t *y)
{
    dtc_t t = *x;
    *x = *y;
    *y = t;
}

void sort_by_severity(dtc_t *a, size_t n)
{
    if (a == NULL || n < 2)
        return;

    /* [0,lo) = critical, [lo,mid) = warning, [mid,hi) = unknown, [hi,n) = info */
    size_t lo = 0, mid = 0, hi = n;

    while (mid < hi) {
        if (a[mid].severity == 2u) {
            swap_dtc(&a[lo], &a[mid]);
            lo++;
            mid++;
        } else if (a[mid].severity == 1u) {
            mid++;
        } else {
            hi--;                         /* exclusive bound: never wraps below 0 */
            swap_dtc(&a[mid], &a[hi]);    /* new a[mid] is unexamined: keep mid */
        }
    }
}
@@@ explanation_md
**Approach: Dijkstra's Dutch national flag partition.** Maintain four regions and shrink the unknown one by one element per step:

```
[ critical | warning | unknown ... | info ]
0          lo        mid           hi     n
```

- `a[mid]` is critical: swap it to `lo`. The element that comes back from `lo` is a warning (or `lo == mid`), so both `lo` and `mid` advance.
- `a[mid]` is a warning: it is already in place, so `mid++`.
- `a[mid]` is info: swap it with the last unknown element `a[hi-1]` and shrink `hi`. The element that arrives at `mid` has **not** been classified yet, so `mid` stays.

Whole records are swapped, so every `code` stays attached to its severity.

**Complexity.** Time O(n): every step either advances `mid` or decrements `hi`, at most `n` steps and at most `n` swaps. Space O(1).

**Common mistakes**
- **Counting sort on the keys** (count 0/1/2, then rewrite). It sorts the severities but destroys the payload. That is acceptable for LeetCode's "sort colors" but wrong for records.
- Advancing `mid` after the swap with `hi`. The swapped-in element is skipped and may be an info record in the middle.
- `size_t hi = n - 1;` followed by `hi--` when it is `0`. Unsigned wrap-around makes `hi` huge, the loop runs off the array, and `n == 0` already underflows. An exclusive `hi` avoids both.
- Two-pass partitioning (2s to the front, then 1s): correct and O(n), but not the single pass asked for.

**Interview follow-ups**
- Is this partition stable? (No. How would you get a stable 3-way partition with O(1) memory, and at what cost?)
- Generalise to `k` classes (e.g. 8 DTC priority levels). (Counting sort into a *separate* output buffer, or `k - 1` partition passes.)
- This partition is the core of 3-way quicksort. Why does it make quicksort fast on inputs with many equal keys?
- The DTC table lives in NVM (non-volatile memory) mirrored in RAM. How do you minimise writes back to EEPROM after sorting?
