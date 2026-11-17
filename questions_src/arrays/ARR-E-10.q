@@@ meta
id: ARR-E-10
topic: Arrays
difficulty: Easy
type: FIND_THE_BUG
title: CAN DLC Histogram With a Mis-Sized Counter Array
tags: embedded, can, off-by-one, array-bounds, histogram
@@@ statement_md
A CAN bus logger computes statistics over captured **classical CAN** frames. A frame's DLC (data length code) is `0..8` for classical CAN. The values `9..15` can appear on the wire but are invalid here and must only be counted as invalid.

The tool prints how many frames had each DLC from 0 to 8, the total number of payload bytes, and the number of invalid frames.

On the target, the "invalid DLC" counter sometimes jumps by more than one per frame and the counts for 8-byte frames look like garbage. Under the judge, the program is stopped with an out-of-bounds report. Find and fix the bug. Do not change the output format.

**Input**
- Line 1: `n`, the number of frames.
- Next `n` lines: `ID DLC`, with the ID in hexadecimal.

**Output**
- 9 lines `DLC d: count` for `d = 0..8`, then `payload bytes: X`, then `invalid DLC: Y`.

**Example**
```
Input:
5
123 8
1A0 2
7DF 8
100 0
3FF 15

Output:
DLC 0: 1
DLC 1: 0
DLC 2: 1
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 2
payload bytes: 18
invalid DLC: 1
```
@@@ constraints_md
- `0 <= n <= 10000`
- `0 <= ID <= 0x7FF`, `0 <= DLC <= 15`
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

#define MAX_DLC 8u                     /* classical CAN: 0..8 data bytes */

static uint32_t dlc_count[MAX_DLC];    /* frames seen per DLC value */

int main(void)
{
    int n;
    uint32_t payload_bytes = 0;
    uint32_t invalid = 0;

    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        unsigned id, dlc;
        if (scanf("%x %u", &id, &dlc) != 2) return 0;
        (void)id;
        if (dlc > MAX_DLC) {           /* 9..15 are not valid for classical CAN */
            invalid++;
            continue;
        }
        dlc_count[dlc]++;
        payload_bytes += dlc;
    }

    for (unsigned d = 0; d <= MAX_DLC; d++)
        printf("DLC %u: %u\n", d, (unsigned)dlc_count[d]);
    printf("payload bytes: %u\n", (unsigned)payload_bytes);
    printf("invalid DLC: %u\n", (unsigned)invalid);
    return 0;
}
@@@ sample_input
5
123 8
1A0 2
7DF 8
100 0
3FF 15
@@@ sample_output
DLC 0: 1
DLC 1: 0
DLC 2: 1
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 2
payload bytes: 18
invalid DLC: 1

@@@ sample_input
3
10 1
11 1
12 3
@@@ sample_output
DLC 0: 0
DLC 1: 2
DLC 2: 0
DLC 3: 1
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 0
payload bytes: 5
invalid DLC: 0

@@@ hidden_input
0
@@@ hidden_output
DLC 0: 0
DLC 1: 0
DLC 2: 0
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 0
payload bytes: 0
invalid DLC: 0

@@@ hidden_input
1
7FF 8
@@@ hidden_output
DLC 0: 0
DLC 1: 0
DLC 2: 0
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 1
payload bytes: 8
invalid DLC: 0

@@@ hidden_input
9
0 0
1 1
2 2
3 3
4 4
5 5
6 6
7 7
8 8
@@@ hidden_output
DLC 0: 1
DLC 1: 1
DLC 2: 1
DLC 3: 1
DLC 4: 1
DLC 5: 1
DLC 6: 1
DLC 7: 1
DLC 8: 1
payload bytes: 36
invalid DLC: 0

@@@ hidden_input
4
1 9
2 10
3 15
4 9
@@@ hidden_output
DLC 0: 0
DLC 1: 0
DLC 2: 0
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 0
payload bytes: 0
invalid DLC: 4

@@@ hidden_input
20
100 8
107 8
10E 8
115 8
11C 8
123 8
12A 8
131 8
138 8
13F 8
146 8
14D 8
154 8
15B 8
162 8
169 8
170 8
177 8
17E 8
185 8
@@@ hidden_output
DLC 0: 0
DLC 1: 0
DLC 2: 0
DLC 3: 0
DLC 4: 0
DLC 5: 0
DLC 6: 0
DLC 7: 0
DLC 8: 20
payload bytes: 160
invalid DLC: 0

@@@ hidden_input
60
1F0 8
240 8
140 5
40 0
740 0
640 3
542 7
440 5
340 0
240 6
140 8
42 8
2A0 7
A0 4
6A0 0
4A0 2
2A0 3
A0 6
6A2 0
49A 1
750 0
4D0 1
650 1
3D0 10
550 1
2D0 8
450 8
1D0 6
350 8
D0 2
250 4
4A8 8
5E0 4
5E2 8
78C 4
720 8
120 2
320 11
520 3
722 6
118 8
7D8 2
0 2
500 4
200 11
702 2
400 7
100 8
600 12
300 12
0 4
500 8
202 11
260 2
660 6
260 12
7A0 2
5A0 8
3A0 8
1A0 7
@@@ hidden_output
DLC 0: 6
DLC 1: 4
DLC 2: 8
DLC 3: 3
DLC 4: 6
DLC 5: 2
DLC 6: 5
DLC 7: 4
DLC 8: 15
payload bytes: 241
invalid DLC: 7

@@@ hint
How many different values can a valid DLC take? Count them, including the zero.
@@@ hint
`0..8` is **nine** values, but `dlc_count[MAX_DLC]` has eight slots (`0..7`). Every 8-byte frame writes `dlc_count[8]`, one element past the end, and the print loop reads it too. On the target that is whatever variable the linker placed next.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

#define MAX_DLC 8u                     /* classical CAN: 0..8 data bytes */

static uint32_t dlc_count[MAX_DLC + 1u];   /* FIX: values 0..MAX_DLC need MAX_DLC + 1 slots */

int main(void)
{
    int n;
    uint32_t payload_bytes = 0;
    uint32_t invalid = 0;

    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        unsigned id, dlc;
        if (scanf("%x %u", &id, &dlc) != 2) return 0;
        (void)id;
        if (dlc > MAX_DLC) {           /* 9..15 are not valid for classical CAN */
            invalid++;
            continue;
        }
        dlc_count[dlc]++;
        payload_bytes += dlc;
    }

    for (unsigned d = 0; d <= MAX_DLC; d++)
        printf("DLC %u: %u\n", d, (unsigned)dlc_count[d]);
    printf("payload bytes: %u\n", (unsigned)payload_bytes);
    printf("invalid DLC: %u\n", (unsigned)invalid);
    return 0;
}
@@@ explanation_md
**Bug.** A table indexed by values `0..MAX` needs `MAX + 1` elements. `dlc_count[MAX_DLC]` has 8 slots, indices `0..7`. The code correctly rejects `dlc > 8`, so DLC 8 passes the check and `dlc_count[8]++` writes **one element past the end**. The print loop `d <= MAX_DLC` reads that element too. Both are undefined behavior (C11 6.5.6p8). On the ECU, `dlc_count[8]` aliases whatever the linker placed next in `.bss`, possibly the `invalid` counter of another module. That explains the "jumping" counter. UBSan's bounds check (`-fsanitize=bounds`, part of `undefined`) and ASan report it immediately.

**Fix.** Size the array from the range of values: `dlc_count[MAX_DLC + 1u]`. Changing the loop to `d < MAX_DLC` is the **wrong** fix: the print is then in bounds, but every 8-byte frame still writes out of bounds, and DLC 8 is never reported.

**Complexity.** Time O(n), space O(MAX_DLC).

**Common mistakes**
- Confusing "the maximum value is 8" with "the array has 8 elements". This is the most common off-by-one in histogram, lookup-table and state-table code.
- Fixing the symptom (the print loop) instead of the cause (the array size).
- Using a magic number `9` in one place and `MAX_DLC` in another. Derive every size from one constant.

**Interview follow-ups**
- How would you guard the table at compile time? (`_Static_assert(sizeof dlc_count / sizeof dlc_count[0] == MAX_DLC + 1u, "...")`.)
- In **CAN FD**, DLC 9..15 encode 12, 16, 20, 24, 32, 48 and 64 bytes. Write a `static const uint8_t dlc_to_len[16]` table and count payload bytes correctly.
- Why might this bug never show up on the bench but appear in the vehicle? (The bench CAN tools sent only short frames; the layout of `.bss` changes between builds.)
