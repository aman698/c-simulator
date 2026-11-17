@@@ meta
id: STR-E-09
topic: Strings
difficulty: Easy
type: FIND_THE_BUG
title: DTC Tag Builder with a Heap Overflow
tags: embedded, malloc, off-by-one, null-terminator, heap-overflow, diagnostics
@@@ statement_md
A diagnostic tool builds a tag `"<ECU>:<DTC>"` (for example `"BCM:U0100"`) on the heap for every fault it reads. It prints each tag with its length and then frees it.

On the developer's PC the output is always correct. The judge, however, reports a **Runtime Error (heap-buffer-overflow)** on every test that contains at least one fault. On the target ECU, the same code corrupts the heap allocator's bookkeeping and crashes minutes later, far from the real cause.

Find and fix the bug. Do not change the output format.

**Input**
- Line 1: `n`, the number of faults.
- Next `n` lines: an ECU name and a DTC code, separated by a space (no spaces inside either).

**Output**
- For each fault, one line `<ECU>:<DTC> (<length>)`, where `<length>` is `strlen` of the tag.

**Example**
```
Input:
2
BCM U0100
ECM P0301

Output:
BCM:U0100 (9)
ECM:P0301 (9)
```
@@@ constraints_md
- `0 <= n <= 1000`
- ECU name: 1..31 characters; DTC: 1..15 characters.
- Every `malloc`ed block must be large enough for everything written into it.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Build "<ecu>:<dtc>" on the heap, e.g. "BCM:U0100". The caller frees it. */
static char *make_tag(const char *ecu, const char *dtc)
{
    size_t len = strlen(ecu) + strlen(dtc) + 1;     /* +1 for the ':' separator */
    char *tag = malloc(len);
    if (tag == NULL)
        return NULL;

    strcpy(tag, ecu);
    strcat(tag, ":");
    strcat(tag, dtc);
    return tag;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        char ecu[32], dtc[16];
        if (scanf("%31s %15s", ecu, dtc) != 2) break;

        char *tag = make_tag(ecu, dtc);
        if (tag == NULL) return 1;
        printf("%s (%zu)\n", tag, strlen(tag));
        free(tag);
    }
    return 0;
}
@@@ sample_input
2
BCM U0100
ECM P0301
@@@ sample_output
BCM:U0100 (9)
ECM:P0301 (9)

@@@ sample_input
0
@@@ sample_output

@@@ hidden_input
1
A B
@@@ hidden_output
A:B (3)

@@@ hidden_input
3
INSTRUMENT_CLUSTER_ECU_FRONT_01 C1234
TCU P0700
GW U0001
@@@ hidden_output
INSTRUMENT_CLUSTER_ECU_FRONT_01:C1234 (37)
TCU:P0700 (9)
GW:U0001 (8)

@@@ hidden_input
2
ABS C0035
ABS C0040
@@@ hidden_output
ABS:C0035 (9)
ABS:C0040 (9)

@@@ hidden_input
1
ADAS_RADAR_FRONT_LEFT_CORNER_01 U0123456789ABCD
@@@ hidden_output
ADAS_RADAR_FRONT_LEFT_CORNER_01:U0123456789ABCD (47)

@@@ hidden_input
4
EPS C1A00
BMS P0A80
OBC P0D00
VCU U0293
@@@ hidden_output
EPS:C1A00 (9)
BMS:P0A80 (9)
OBC:P0D00 (9)
VCU:U0293 (9)

@@@ hint
Count the bytes that `strcpy` + `strcat` + `strcat` write for `"A"` and `"B"`. Compare that with the number of bytes passed to `malloc`.
@@@ hint
`strlen` does not count the terminating `'\0'`, but `strcpy`/`strcat` always write one. The tag needs `strlen(ecu) + 1 (':') + strlen(dtc) + 1 ('\0')` bytes.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Build "<ecu>:<dtc>" on the heap, e.g. "BCM:U0100". The caller frees it. */
static char *make_tag(const char *ecu, const char *dtc)
{
    size_t len = strlen(ecu) + strlen(dtc) + 2;     /* FIX: +1 for ':' and +1 for the '\0' */
    char *tag = malloc(len);
    if (tag == NULL)
        return NULL;

    strcpy(tag, ecu);
    strcat(tag, ":");
    strcat(tag, dtc);
    return tag;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        char ecu[32], dtc[16];
        if (scanf("%31s %15s", ecu, dtc) != 2) break;

        char *tag = make_tag(ecu, dtc);
        if (tag == NULL) return 1;
        printf("%s (%zu)\n", tag, strlen(tag));
        free(tag);
    }
    return 0;
}
@@@ explanation_md
**Bug.** The size calculation counts the separator but not the **terminating `'\0'`**. For `"BCM"` + `"U0100"` the code allocates 3 + 5 + 1 = 9 bytes, but `strcat(tag, dtc)` writes 10 bytes (`B C M : U 0 1 0 0 \0`). The terminator lands one byte past the block: a **heap buffer overflow by one**.

It "works" on a PC because glibc rounds every allocation up (a 9-byte request gets a 24-byte chunk), so the extra byte lands in slack space. AddressSanitizer poisons the bytes right after the requested size and reports the write immediately. Small embedded allocators often pack blocks tightly, so the `'\0'` overwrites the next block's header and the crash shows up much later.

**Fix.** Allocate `strlen(ecu) + strlen(dtc) + 2`. Even clearer, name the parts: `strlen(ecu) + 1 /* ':' */ + strlen(dtc) + 1 /* '\0' */`.

**Complexity.** O(len(ecu) + len(dtc)) time and space per tag.

**Common mistakes**
- `malloc(strlen(s))` to copy a string: the most common off-by-one in C. A copy of `s` always needs `strlen(s) + 1` bytes.
- Fixing the symptom by allocating "a few more bytes" (`+ 16`). That hides the bug instead of fixing the size calculation.
- Trusting "it prints the right thing". Writing one byte past a block is undefined behavior even when the output looks correct.

**Interview follow-ups**
- Rewrite `make_tag` with a single `snprintf`: call it once with `NULL, 0` to get the length, `malloc(len + 1)`, then format. Why is this safer than a `strcpy`/`strcat` chain?
- How does AddressSanitizer detect a 1-byte overflow (shadow memory, redzones), and why can't valgrind always see overflows **inside** glibc's rounding slack?
- In a MISRA project without `malloc`, how would you provide these tags? (A fixed `char tag[48]` with a compile-time size check, or a static pool of fixed-size blocks.)
