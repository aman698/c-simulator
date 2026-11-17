@@@ meta
id: MEM-E-06
topic: Dynamic Memory
difficulty: Easy
type: CODE
title: CAN Identifier Histogram With calloc
tags: embedded, calloc, zero-initialization, histogram, can-bus, asked-in-automotive
@@@ statement_md
A bus-load analyzer counts how many frames were seen for each CAN identifier. The largest valid identifier `M` comes from the configuration at run time, so the counter table must be **allocated at run time**: one counter per identifier `0..M`, all starting at zero. Use `calloc`, because it returns zero-initialized memory.

Frames whose identifier is greater than `M` are corrupt. Do **not** use them as an index; count them as `invalid`.

**Input**
- Line 1: `M` (hexadecimal, no `0x` prefix) and `n` (decimal, the number of frames).
- Line 2: `n` identifiers in hexadecimal (no prefix).

**Output**
- For every identifier that occurred at least once, in ascending order: `0x%03X <count>`.
- Last line: `distinct=<d> invalid=<k> busiest=<id>`, where `busiest` is the valid identifier with the highest count (smallest identifier on ties) printed as `0x%03X`, or `none` if no valid frame was seen.

**Example**
```
Input:
7FF 6
100 7DF 100 800 0A0 100

Output:
0x0A0 1
0x100 3
0x7DF 1
distinct=3 invalid=1 busiest=0x100
```
@@@ constraints_md
- `0 <= M <= 0xFFFFF` (so up to 1,048,576 counters)
- `0 <= n <= 100000`, identifiers `0 <= id <= 0xFFFFFFF`
- The counter table must come from `calloc` and be freed before `main` returns.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    unsigned int max_id;
    int n;
    if (scanf("%x %d", &max_id, &n) != 2)
        return 0;

    /* TODO: allocate max_id + 1 zeroed counters with calloc,
       count the frames, print the histogram and the summary line, free */

    return 0;
}
@@@ sample_input
7FF 6
100 7DF 100 800 0A0 100
@@@ sample_output
0x0A0 1
0x100 3
0x7DF 1
distinct=3 invalid=1 busiest=0x100

@@@ sample_input
7FF 0
@@@ sample_output
distinct=0 invalid=0 busiest=none

@@@ hidden_input
0 3
0 0 1
@@@ hidden_output
0x000 2
distinct=1 invalid=1 busiest=0x000

@@@ hidden_input
FF 4
100 1FF FFFFFFF 200
@@@ hidden_output
distinct=0 invalid=4 busiest=none

@@@ hidden_input
7FF 6
7FF 001 7FF 001 3A0 3A0
@@@ hidden_output
0x001 2
0x3A0 2
0x7FF 2
distinct=3 invalid=0 busiest=0x001

@@@ hidden_input
FFFFF 5
FFFFF 18DAF110 FFFFF 00000 18DAF110
@@@ hidden_output
0x000 1
0xFFFFF 2
distinct=2 invalid=2 busiest=0xFFFFF

@@@ hidden_input
7FF 1
7E8
@@@ hidden_output
0x7E8 1
distinct=1 invalid=0 busiest=0x7E8

@@@ hidden_input
1F 10
1F 1E 1F 1E 1F 0 20 1 2 1E
@@@ hidden_output
0x000 1
0x001 1
0x002 1
0x01E 3
0x01F 3
distinct=5 invalid=1 busiest=0x01E

@@@ hint
`calloc(count, size)` allocates `count * size` bytes **and zeroes them**. With `malloc` you would need a `memset`, and forgetting it means counting on top of garbage. You need `M + 1` counters (identifiers `0..M` inclusive).
@@@ hint
Check `id > M` **before** indexing. An out-of-range identifier used as an index is a heap overflow. One final pass over `0..M` prints the non-zero counters and tracks the busiest one (use a strict `>` so the smallest identifier wins ties).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    unsigned int max_id;
    int n;
    if (scanf("%x %d", &max_id, &n) != 2)
        return 0;

    /* one zeroed counter per identifier 0..max_id */
    size_t slots = (size_t)max_id + 1;
    unsigned int *count = calloc(slots, sizeof *count);
    if (count == NULL)
        return 1;

    int invalid = 0;
    for (int i = 0; i < n; i++) {
        unsigned int id;
        if (scanf("%x", &id) != 1)
            break;
        if (id > max_id)
            invalid++;                /* never index with untrusted data */
        else
            count[id]++;
    }

    int distinct = 0;
    size_t busiest = 0;
    unsigned int best = 0;
    for (size_t id = 0; id < slots; id++) {
        if (count[id] == 0)
            continue;
        printf("0x%03X %u\n", (unsigned int)id, count[id]);
        distinct++;
        if (count[id] > best) {       /* strict: smallest id wins ties */
            best = count[id];
            busiest = id;
        }
    }

    if (distinct == 0)
        printf("distinct=0 invalid=%d busiest=none\n", invalid);
    else
        printf("distinct=%d invalid=%d busiest=0x%03X\n", distinct, invalid, (unsigned int)busiest);

    free(count);
    return 0;
}
@@@ explanation_md
**Approach.** The table size depends on run-time configuration, so allocate it with `calloc(M + 1, sizeof *count)`. Every counter starts at 0, with no `memset` needed. Validate each identifier before using it as an index, then scan the table once to print the non-zero entries and find the maximum.

**Why `calloc` and not `malloc`?**
- `malloc` returns **indeterminate** contents. `count[id]++` on garbage gives garbage, and in a debug build it may happen to work because fresh pages are zero.
- `calloc` checks `count * size` for overflow. `malloc(count * size)` silently wraps around on overflow.
- For large blocks `calloc` can be cheaper than `malloc` + `memset`, because the allocator knows that fresh pages from the OS are already zero.

**Complexity.** Time O(n + M), space O(M) for the table.

**Common mistakes**
- Allocating `M` counters instead of `M + 1`. Then `count[M]` is one past the end, a classic off-by-one heap overflow.
- Incrementing `count[id]` before checking `id <= M`. Corrupt bus data becomes memory corruption.
- `malloc` without zeroing. It can pass locally and fail elsewhere.
- Ties: updating `busiest` with `>=` picks the **largest** identifier.

**Interview follow-ups**
- Extended CAN identifiers are 29 bits (`0x1FFFFFFF`). A full table would need 2 GB. What would you use instead? (A hash map, a sorted array of seen IDs, or the acceptance-filter configuration as the table index.)
- On a small MCU with no heap, how would you size this table, and where would you place it? (A static array sized from the DBC at build time.)
- Is `calloc(0, 4)` safe? What may it return, and how should code handle it?
