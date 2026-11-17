@@@ meta
id: PAT-E-07
topic: C Patterns
difficulty: Easy
type: PREDICT_OUTPUT
title: break and continue in a Nested Star Loop
tags: nested-loops, break, continue, control-flow
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    for (int i = 1; i <= 5; i++) {
        if (i == 4)
            continue;
        for (int j = 1; j <= 5; j++) {
            if (j > i)
                break;
            if (j % 2 == 0)
                continue;
            putchar('*');
        }
        printf("%d\n", i);
    }
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    for (int i = 1; i <= 5; i++) {
        if (i == 4)
            continue;
        for (int j = 1; j <= 5; j++) {
            if (j > i)
                break;
            if (j % 2 == 0)
                continue;
            putchar('*');
        }
        printf("%d\n", i);
    }
    return 0;
}
@@@ predict_answer
*1
*2
**3
***5
@@@ hint
`break` and `continue` only affect the **innermost** loop that encloses them.
@@@ hint
The outer `continue` for `i == 4` skips the rest of that iteration, including the `printf` with the newline. In the inner loop, `continue` skips one column and `break` ends the row.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    for (int i = 1; i <= 5; i++) {
        if (i == 4)
            continue;           /* skips the inner loop AND the printf: no line for 4 */
        for (int j = 1; j <= 5; j++) {
            if (j > i)
                break;          /* leaves only the inner loop: row has columns 1..i */
            if (j % 2 == 0)
                continue;       /* even columns print nothing */
            putchar('*');       /* odd columns 1, 3, 5 that are <= i */
        }
        printf("%d\n", i);
    }
    /* i=1: j=1 *            -> "*1"
     * i=2: j=1 *, j=2 skip  -> "*2"
     * i=3: j=1 *, j=3 *     -> "**3"
     * i=4: skipped entirely
     * i=5: j=1,3,5 *        -> "***5"
     */
    return 0;
}
@@@ explanation_md
**Answer**
```
*1
*2
**3
***5
```

**Step by step.** The inner loop visits `j = 1..i` (the `break` fires at `j = i + 1`, or the loop ends at 5) and prints a star only for odd `j`. So row `i` has as many stars as there are odd numbers in `1..i`: 1, 1, 2, -, 3. For `i == 4` the **outer** `continue` jumps straight to `i++`. Neither the stars nor the `printf("%d\n", i)` run, so there is no line for 4 at all, not even an empty one.

**Complexity.** O(rows x columns) = at most 25 inner iterations. No extra memory.

**Common mistakes**
- Assuming `break` leaves **both** loops. C has no labelled break; it ends only the innermost `for`/`while`/`do`/`switch`. To leave both, use a flag, `goto`, or put the loops in a function and `return`.
- Expecting a line `4` or an empty line for `i == 4`. `continue` skips the rest of the body, including the newline.
- Counting stars as `i` instead of "odd `j` in `1..i`".
- Forgetting that `break` inside a `switch` nested in a loop only leaves the `switch`, which is a classic trap in state machines.

**Interview follow-ups**
- Rewrite the inner loop without `break`/`continue` (`for (j = 1; j <= i; j += 2)`). Which version would MISRA C prefer? (Rule 15.4 allows at most one `break` per loop; older MISRA versions banned `continue`.)
- How do you exit two nested loops cleanly in C? Compare a flag, `goto cleanup`, and a helper function.
- What changes if the outer `continue` is replaced by `break`?
