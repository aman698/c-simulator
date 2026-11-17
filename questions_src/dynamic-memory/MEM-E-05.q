@@@ meta
id: MEM-E-05
topic: Dynamic Memory
difficulty: Easy
type: CODE
title: Readings Above the Average (Runtime-Sized Array)
tags: embedded, malloc, dynamic-array, two-pass, integer-average
@@@ statement_md
An end-of-line tester downloads a burst of `n` ADC readings from an ECU. `n` is known only at run time, so the readings must be stored in a buffer allocated with `malloc` after `n` is read. Then print every reading that is **strictly greater than the average** of all readings, in input order.

The average is the exact rational value `sum / n`. Integer division does not count (see the examples with negative values).

**Input**
- Line 1: `n`.
- Line 2: `n` integers.

**Output**
- If `n = 0`: print `NO DATA`.
- Otherwise line 1: `count=<k>`, where `k` is the number of readings strictly above the average.
- Line 2 (only if `k > 0`): those readings in input order, separated by single spaces.

**Example**
```
Input:
5
10 20 30 40 50

Output:
count=2
40 50
```
(Average 30. Only 40 and 50 are strictly greater.)

```
Input:
2
-1 -2

Output:
count=1
-1
```
(Average -1.5. Truncating integer division would give -1 and wrongly drop `-1`.)
@@@ constraints_md
- `0 <= n <= 200000`
- `-10^9 <= reading <= 10^9`
- Allocate exactly `n` elements with `malloc` (do not call `malloc(0)`), and free the buffer before returning.
- No floating point is needed. Floating point also works but is not required.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1)
        return 0;

    /* TODO: handle n == 0, allocate n ints, read them,
       print the readings strictly above the average, free the buffer */

    return 0;
}
@@@ sample_input
5
10 20 30 40 50
@@@ sample_output
count=2
40 50

@@@ sample_input
2
-1 -2
@@@ sample_output
count=1
-1

@@@ hidden_input
0
@@@ hidden_output
NO DATA

@@@ hidden_input
1
42
@@@ hidden_output
count=0

@@@ hidden_input
4
7 7 7 7
@@@ hidden_output
count=0

@@@ hidden_input
3
-3 -2 -2
@@@ hidden_output
count=2
-2 -2

@@@ hidden_input
4
1000000000 1000000000 1000000000 -1000000000
@@@ hidden_output
count=3
1000000000 1000000000 1000000000

@@@ hidden_input
6
5 -5 4 -4 3 -2
@@@ hidden_output
count=3
5 4 3

@@@ hidden_input
7
-1000000000 -999999999 -1000000000 -1000000000 -1000000000 -1000000000 -1000000000
@@@ hidden_output
count=1
-999999999

@@@ hint
You need two passes over the data (one to compute the sum, one to compare), so the readings must be stored. Allocate `n * sizeof *buf` bytes **after** reading `n`, and use a 64-bit sum: `200000 * 10^9` does not fit in an `int`.
@@@ hint
Avoid fractions. `x > sum / n` (exact) is equivalent to `x * n > sum` for `n > 0`. Compute it in `long long`. Free the buffer on every path after it was allocated.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1)
        return 0;
    if (n <= 0) {
        printf("NO DATA\n");          /* never call malloc(0): result is implementation-defined */
        return 0;
    }

    int *buf = malloc((size_t)n * sizeof *buf);
    if (buf == NULL)
        return 1;

    long long sum = 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%d", &buf[i]) != 1) {
            free(buf);                /* error path frees too */
            return 0;
        }
        sum += buf[i];
    }

    /* x > sum / n  <=>  x * n > sum   (n > 0), exact in 64-bit integers */
    int k = 0;
    for (int i = 0; i < n; i++)
        if ((long long)buf[i] * n > sum)
            k++;

    printf("count=%d\n", k);
    if (k > 0) {
        int printed = 0;
        for (int i = 0; i < n; i++) {
            if ((long long)buf[i] * n > sum) {
                printf("%s%d", printed ? " " : "", buf[i]);
                printed++;
            }
        }
        printf("\n");
    }

    free(buf);
    return 0;
}
@@@ explanation_md
**Approach.**
1. Read `n`. For `n = 0`, print `NO DATA` and do not allocate. `malloc(0)` may return `NULL` or a unique pointer; the behavior is implementation-defined, so avoid depending on it.
2. `buf = malloc((size_t)n * sizeof *buf)`. Writing `sizeof *buf` instead of `sizeof(int)` keeps the expression correct if the element type ever changes. Check for `NULL`.
3. First pass: read the values and accumulate a `long long` sum. Second pass: count, then print the values with `x * n > sum`.
4. `free(buf)` on every path after the allocation, including the input-error path.

The comparison `x * n > sum` is exact. `sum / n` in integer arithmetic truncates toward zero. For `-1 -2` it gives `-1`, and `-1 > -1` is false, but the true average is -1.5. `x * n` is at most `10^9 * 2*10^5 = 2*10^14`, which fits easily in 64 bits.

**Complexity.** Time O(n), space O(n) for the heap buffer.

**Common mistakes**
- `int sum`. It overflows at about 2 * 10^9 (signed overflow is UB).
- `sum / n` in integer arithmetic, which is wrong for negative or fractional averages.
- `malloc(n)` instead of `malloc(n * sizeof *buf)`. That allocates bytes, not ints, and causes a heap overflow.
- `int n` used directly in `n * sizeof(int)` without a cast. That works because `n` is converted to `size_t`, but a negative `n` becomes a huge size. Validate `n` first.
- A variable-length array `int buf[n]` on the stack. With `n = 200000` (800 KB) it can overflow a 1 MB stack, and RTOS task stacks are often only 1-4 KB.

**Interview follow-ups**
- Can you solve it in one pass with O(1) memory? (No. The average is unknown until the last value is read, so every value must be kept, or the input must be read twice.)
- When would you prefer a VLA, a static buffer, or `malloc` on an ECU? What does MISRA C:2012 say about VLAs (Rule 18.8) and `malloc` (Rule 21.3)?
- How would you compute a running mean of a sensor stream without overflow and without storing the samples?
