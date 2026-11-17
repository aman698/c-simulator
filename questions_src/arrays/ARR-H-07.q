@@@ meta
id: ARR-H-07
topic: Arrays
difficulty: Hard
type: PREDICT_OUTPUT
title: Walking a 2D Sensor Grid Through Row 0
tags: embedded, undefined-behavior, 2d-array, array-bounds, aggressive-loop-optimization
@@@ statement_md
A colleague sums a 3x4 grid of tyre-temperature sensors with one flat loop. He argues that "a 2D array is contiguous in memory anyway". What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**. A 2D array is laid out row by row with no padding between rows.

```c
#include <stdio.h>

int main(void)
{
    int grid[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12},
    };
    int sum = 0;

    /* walk the whole grid as one flat row */
    for (int k = 0; k < 12; k++)
        sum += grid[0][k];

    printf("%d\n", sum);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- The memory layout claim in the statement is true. The question is what the C standard says about the access.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int grid[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12},
    };
    int sum = 0;

    /* walk the whole grid as one flat row */
    for (int k = 0; k < 12; k++)
        sum += grid[0][k];

    printf("%d\n", sum);
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
`grid[0]` is not "the grid". It is an object of type `int[4]`. What does the standard say about a subscript beyond the bounds of the array you are indexing, even if other valid memory happens to be there?
@@@ hint
C11 Annex J.2 lists this exact case as undefined: *"An array subscript is out of range, even if an object is apparently accessible with the given subscript (as in the lvalue expression `a[1][7]` given the declaration `int a[4][5]`)"*. `grid[0][4]` through `grid[0][11]` are out of range.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int grid[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12},
    };
    int sum = 0;

    /* grid[0] has type int[4]. grid[0][k] is *(grid[0] + k), and pointer arithmetic
     * is only defined inside that 4-element array (plus one past the end, which
     * must not be dereferenced). k = 4..11 -> undefined behavior (C11 6.5.6p8, J.2).
     * UBSan (-fsanitize=bounds) reports "index 4 out of bounds for type 'int [4]'";
     * gcc -O2 may assume k < 4 and turn the loop into something else entirely. */
    for (int k = 0; k < 12; k++)
        sum += grid[0][k];

    /* Defined alternatives:
     *   for (r..3) for (c..4) sum += grid[r][c];
     *   or store the grid as int flat[3 * 4] and index flat[r * 4 + c]. */
    printf("%d\n", sum);
    return 0;
}
@@@ explanation_md
**Answer: `Undefined Behavior`.**

`grid[0][k]` means `*(grid[0] + k)`. `grid[0]` is an array of **4** `int`s. It decays to a pointer to its first element, and pointer arithmetic is defined only within that array (and one past its end, which may not be dereferenced), per C11 6.5.6p8. For `k >= 4` the access is outside the `int[4]` object, even though the memory belongs to `grid[1]`. Annex J.2 names this case explicitly (`a[1][7]` for `int a[4][5]`).

**What really happens.**
- At `-O0` without sanitizers, gcc usually prints `78`, the "expected" sum. That is why the bug survives code review and bench tests.
- With the judge's UBSan, `-fsanitize=bounds` stops the program at `k = 4`: *index 4 out of bounds for type 'int [4]'*.
- At `-O2`, gcc can assume the loop body never runs with `k >= 4` (`-Waggressive-loop-optimizations`). It may cut the loop short or produce an infinite loop. This broke the SPEC CPU2006 benchmark `h264ref` when gcc 4.8 introduced this optimisation.

**Correct ways to flatten.**
- Nested loops over `r` and `c` (the compiler generates the same linear walk anyway).
- Declare the storage as one flat array `int flat[ROWS * COLS]` and index it with `r * COLS + c`.
- `(int *)grid` walked to 12 elements is widely used and works with every mainstream compiler, but its strict conformance is debated. MISRA C forbids it (Rule 18.1), so do not rely on it in safety code.

**Complexity.** N/A (a correctness question); the defined versions are O(R * C) like the original.

**Common mistakes**
- Answering `78`. That is one possible behavior of UB, not the defined result.
- Believing "contiguous memory" makes the access legal. The rules are about the **object** being indexed, not about the addresses.
- Thinking sanitizers or `-O0` behavior prove the code correct.

**Interview follow-ups**
- Is `&grid[0][4]` (without dereferencing) allowed? (Yes: one past the end of `grid[0]`. But `&grid[0][5]` is already UB.)
- How do you pass this grid to a function so that the callee can index `[r][c]` correctly? (`int (*g)[4]`, or a VLA parameter `int g[][cols]`.)
- Why might a static analyser (Polyspace, Coverity, MISRA checker) flag `memcpy(dst, grid[0], sizeof grid)` but not `memcpy(dst, grid, sizeof grid)`?
