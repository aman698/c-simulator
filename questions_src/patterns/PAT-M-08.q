@@@ meta
id: PAT-M-08
topic: C Patterns
difficulty: Medium
type: PREDICT_OUTPUT
title: Unsigned Countdown and a Loop That Never Runs
tags: unsigned-wraparound, signed-unsigned-comparison, sizeof, loop-bounds
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, `unsigned int` = 4 bytes, pointer = 8 bytes, `size_t` = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int stars[] = {3, 1, 2};
    unsigned i;
    int rows = 0;

    for (i = 2; i < 10; i--) {
        for (int k = -1; k < stars[i]; k++)
            putchar('*');
        printf(" %u\n", i);
        rows++;
    }
    for (int j = -1; j < sizeof stars / sizeof stars[0]; j++)
        printf("row %d\n", j);
    printf("rows=%d i=%u\n", rows, i);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11. `UINT_MAX` = 4294967295.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int stars[] = {3, 1, 2};
    unsigned i;
    int rows = 0;

    for (i = 2; i < 10; i--) {
        for (int k = -1; k < stars[i]; k++)
            putchar('*');
        printf(" %u\n", i);
        rows++;
    }
    for (int j = -1; j < sizeof stars / sizeof stars[0]; j++)
        printf("row %d\n", j);
    printf("rows=%d i=%u\n", rows, i);
    return 0;
}
@@@ predict_answer
*** 2
** 1
**** 0
rows=3 i=4294967295
@@@ hint
Unsigned arithmetic is modulo 2^32: decrementing `0u` gives `4294967295`, which is **not** `< 10`. That is the only reason the first loop ends.
@@@ hint
`sizeof` yields a `size_t` (unsigned). In `j < sizeof ...` the `int j = -1` is converted to `size_t` first, and becomes the largest `size_t` value.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int stars[] = {3, 1, 2};
    unsigned i;
    int rows = 0;

    /* i = 2, 1, 0, then 0 - 1 wraps to 4294967295 (well-defined for unsigned),
     * which fails "i < 10" and ends the loop. */
    for (i = 2; i < 10; i--) {
        /* k runs from -1 to stars[i]-1: stars[i] + 1 stars */
        for (int k = -1; k < stars[i]; k++)
            putchar('*');
        printf(" %u\n", i);         /* i=2: "***", i=1: "**", i=0: "****" */
        rows++;
    }
    /* -1 < (size_t)3 ?  -1 is converted to size_t -> 18446744073709551615,
     * so the condition is false immediately: the body never runs.
     * gcc -Wextra warns: comparison of integer expressions of different signedness */
    for (int j = -1; j < sizeof stars / sizeof stars[0]; j++)
        printf("row %d\n", j);
    printf("rows=%d i=%u\n", rows, i);
    return 0;
}
@@@ explanation_md
**Answer**
```
*** 2
** 1
**** 0
rows=3 i=4294967295
```

**Step by step.**
1. The outer loop counts `i = 2, 1, 0`. Decrementing `0u` is **well-defined** for unsigned types: it wraps to `UINT_MAX = 4294967295`. That value fails `i < 10`, so the loop stops after three rows. Writing `i >= 0` instead would loop forever, and gcc warns that the comparison is always true.
2. The inner loop starts at `k = -1`, so row `i` gets `stars[i] + 1` stars: `stars[2] = 2` gives 3, `stars[1] = 1` gives 2, `stars[0] = 3` gives 4.
3. In `j < sizeof stars / sizeof stars[0]` the right side is `size_t` (3). By the usual arithmetic conversions `j` is converted to `size_t`, and `-1` becomes `18446744073709551615`. `18446744073709551615 < 3` is false, so `row ...` is never printed.
4. After the loop `i` holds the wrapped value `4294967295`.

No undefined behavior: unsigned wrap-around and signed-to-unsigned conversion are both fully defined.

**Complexity.** Constant (3 rows). The lesson is about types, not speed.

**Common mistakes**
- Thinking the first loop runs forever, or until `i` becomes negative. An unsigned value is never negative.
- Expecting `row -1 ... row 2` from the second loop. A comparison between `int` and `size_t` is done in `size_t`.
- Printing `i=-1`. `%u` prints the unsigned value; `printf("%d", i)` would technically be a type mismatch.
- Assuming `stars[i]` was read with `i = 4294967295`. The condition is checked before the body, so it never is.

**Interview follow-ups**
- Write a correct countdown over an array with `size_t` (`for (size_t i = n; i-- > 0; )`) and explain why it works for `n = 0`.
- How does `-Wsign-compare` (part of `-Wextra`) help, and what is the MISRA C view on mixing signed and unsigned operands (essential type model, Rule 10.4)?
- What is wrong with `for (size_t k = strlen(s) - 1; k >= 0; k--)` to print a string backwards, and what happens for an empty string?
