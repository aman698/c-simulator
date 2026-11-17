@@@ meta
id: PTR-E-05
topic: Pointers
difficulty: Easy
type: FIND_THE_BUG
title: ADC Moving-Average Filter Averages Half the Window
tags: embedded, array-decay, sizeof, adc, filter
@@@ statement_md
An ECU smooths raw 12-bit ADC samples with an 8-tap moving-average filter. The last `FILTER_LEN = 8` samples are kept in a ring buffer `history[]`, which starts with all zeros. After every new sample the program prints the mean of **all 8 slots**, rounded down (integer division by 8). A negative input value is a "reset" command: the whole history is cleared to zeros and the write position goes back to slot 0.

On the bench the filter output is about **twice too large** while the window fills up, and after a reset the old samples are still partly visible.

Find and fix the bug. Do not change the input/output format.

**Input**
- Line 1: `n`, the number of values.
- Line 2: `n` integers. A value `>= 0` is a sample; a value `< 0` is a reset command.

**Output**
- For each sample: the filter mean on its own line.
- For each reset: the line `reset`.

**Example**
```
Input:
3
800 800 800

Output:
100
200
300
```
After the first sample the history is `800 0 0 0 0 0 0 0`, so the mean is `800 / 8 = 100`.
@@@ constraints_md
- `0 <= n <= 1000`
- Samples are in `0..4095` (12-bit ADC).
- `FILTER_LEN` is 8.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define FILTER_LEN 8u
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static uint16_t history[FILTER_LEN];
static size_t pos;

/* Clear the whole filter history. */
static void filter_reset(uint16_t hist[FILTER_LEN])
{
    memset(hist, 0, sizeof(hist));
}

/* Mean of all FILTER_LEN slots, rounded down. */
static uint16_t filter_mean(const uint16_t hist[FILTER_LEN])
{
    const size_t len = ARRAY_SIZE(hist);
    uint32_t sum = 0;
    for (size_t i = 0; i < len; i++)
        sum += hist[i];
    return (uint16_t)(sum / len);
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int k = 0; k < n; k++) {
        int v;
        if (scanf("%d", &v) != 1) return 0;
        if (v < 0) {
            filter_reset(history);
            pos = 0;
            printf("reset\n");
            continue;
        }
        history[pos] = (uint16_t)v;
        pos = (pos + 1) % FILTER_LEN;
        printf("%u\n", (unsigned)filter_mean(history));
    }
    return 0;
}
@@@ sample_input
3
800 800 800
@@@ sample_output
100
200
300

@@@ sample_input
10
8 16 24 32 40 48 56 64 72 80
@@@ sample_output
1
3
6
10
15
21
28
36
44
52

@@@ hidden_input
1
0
@@@ hidden_output
0

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
9
4095 4095 4095 4095 4095 4095 4095 4095 4095
@@@ hidden_output
511
1023
1535
2047
2559
3071
3583
4095
4095

@@@ hidden_input
10
100 100 100 100 100 100 100 100 -1 8
@@@ hidden_output
12
25
37
50
62
75
87
100
reset
1

@@@ hidden_input
12
1 2 3 4 5 6 7 8 9 10 11 12
@@@ hidden_output
0
0
0
1
1
2
3
4
5
6
7
8

@@@ hidden_input
5
4095 -1 -1 4095 1
@@@ hidden_output
511
reset
reset
511
512

@@@ hint
Print `sizeof(hist)` inside `filter_mean` and compare it with `sizeof(history)` in `main`. Are they the same?
@@@ hint
A parameter declared as `uint16_t hist[FILTER_LEN]` is really `uint16_t *hist`. The array **decays** to a pointer, and the `[8]` is ignored. So `sizeof(hist)` is the size of a pointer (8 bytes), not 16.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define FILTER_LEN 8u
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static uint16_t history[FILTER_LEN];
static size_t pos;

/* Clear the whole filter history. */
static void filter_reset(uint16_t hist[FILTER_LEN])
{
    memset(hist, 0, FILTER_LEN * sizeof hist[0]);   /* FIX: sizeof(hist) is sizeof(uint16_t *) == 8 */
}

/* Mean of all FILTER_LEN slots, rounded down. */
static uint16_t filter_mean(const uint16_t hist[FILTER_LEN])
{
    const size_t len = FILTER_LEN;                   /* FIX: ARRAY_SIZE(hist) == 8 / 2 == 4 on a pointer */
    uint32_t sum = 0;
    for (size_t i = 0; i < len; i++)
        sum += hist[i];
    return (uint16_t)(sum / len);
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int k = 0; k < n; k++) {
        int v;
        if (scanf("%d", &v) != 1) return 0;
        if (v < 0) {
            filter_reset(history);
            pos = 0;
            printf("reset\n");
            continue;
        }
        history[pos] = (uint16_t)v;
        pos = (pos + 1) % FILTER_LEN;
        printf("%u\n", (unsigned)filter_mean(history));
    }
    return 0;
}
@@@ explanation_md
**Bug.** In a parameter list, `uint16_t hist[FILTER_LEN]` is adjusted to `uint16_t *hist` (C11 6.7.6.3p7). Inside the functions, `hist` is a pointer, so:

- `sizeof(hist)` is `sizeof(uint16_t *)` = **8** on x86-64, not 16. `memset` clears only the first 4 samples, and after a reset slots 4..7 keep their old values.
- `ARRAY_SIZE(hist)` is `8 / 2` = **4**. The mean sums 4 slots and divides by 4, so while the window fills (with zeros in the other slots) the output is roughly twice too large.

On a 32-bit MCU (4-byte pointers) the same code gives `4 / 2 = 2`. The bug depends on the target, which makes it hard to catch when unit tests run on a PC.

**Fix.** Use the known length `FILTER_LEN` (or pass the length as a parameter) instead of `sizeof` on the parameter. gcc even warns about this: `-Wsizeof-array-argument` and `-Wsizeof-pointer-div`.

**Complexity.** O(FILTER_LEN) per sample for the mean (a running sum would make it O(1)), O(1) extra space.

**Common mistakes**
- Trusting the `[8]` in the parameter declaration. It is documentation only; the compiler does not check it and `sizeof` ignores it.
- Using an `ARRAY_SIZE` macro on anything but a real array. A safer macro rejects pointers at compile time, e.g. with `_Static_assert` and `__builtin_types_compatible_p` (as the Linux kernel does).
- Fixing only `filter_mean` and leaving the partial `memset` in `filter_reset`.

**Interview follow-ups**
- How can you make a function receive a real array, so that `sizeof` works? (Pass a pointer to the array: `const uint16_t (*hist)[FILTER_LEN]`, then `sizeof *hist == 16`.)
- Rewrite the filter with a running sum so each update is O(1). What overflow concern appears for long windows?
- Why is integer division by a power of two cheap on a Cortex-M0 without a divide instruction, and what changes if `FILTER_LEN` becomes 10?
- What does `uint16_t hist[static 8]` mean in a C99/C11 parameter list?
