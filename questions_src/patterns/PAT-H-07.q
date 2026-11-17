@@@ meta
id: PAT-H-07
topic: C Patterns
difficulty: Hard
type: PREDICT_OUTPUT
title: Comma Operator and Post-Increment in Loop Conditions
tags: comma-operator, post-increment, short-circuit, loop-conditions, sequence-points
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int i, j, k = 0;
    for (i = 0, j = 5; j--, i < 4; i += 2, j -= 2) {
        int n = 0;
        while (n++ < i)
            putchar('*');
        printf("|%d %d %d\n", i, j, n);
    }
    while (k++ < 3 && k++ < 3)
        printf("k=%d\n", k);
    printf("end i=%d j=%d k=%d\n", i, j, k);
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
    int i, j, k = 0;
    for (i = 0, j = 5; j--, i < 4; i += 2, j -= 2) {
        int n = 0;
        while (n++ < i)
            putchar('*');
        printf("|%d %d %d\n", i, j, n);
    }
    while (k++ < 3 && k++ < 3)
        printf("k=%d\n", k);
    printf("end i=%d j=%d k=%d\n", i, j, k);
    return 0;
}
@@@ predict_answer
|0 4 1
**|2 1 3
k=2
end i=4 j=-2 k=4
@@@ hint
The value of a comma expression is its **right** operand; the left operand is evaluated first and its value thrown away. So the loop condition is just `i < 4`, but `j--` still runs **every time** the condition is checked, including the final, failing check.
@@@ hint
`n++ < i` compares the **old** value of `n` and increments it anyway, also on the comparison that ends the loop. `&&` is a sequence point and short-circuits: the second `k++` only runs if the first comparison was true.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int i, j, k = 0;
    /* condition "j--, i < 4": j-- runs on EVERY check, the result is i < 4 */
    for (i = 0, j = 5; j--, i < 4; i += 2, j -= 2) {
        int n = 0;
        /* n++ < i: compares old n, increments always -> after the loop n = i + 1 */
        while (n++ < i)
            putchar('*');
        printf("|%d %d %d\n", i, j, n);
    }
    /* check 1: j 5->4, 0<4 -> "|0 4 1"          then i=2, j=2
     * check 2: j 2->1, 2<4 -> "**|2 1 3"        then i=4, j=-1
     * check 3: j -1->-2, 4<4 false -> exit with i=4, j=-2 */

    /* && is a sequence point and short-circuits:
     * iteration 1: 0<3 (k=1), 1<3 (k=2) -> true, prints k=2
     * iteration 2: 2<3 (k=3), 3<3 (k=4) -> false, loop ends with k=4 */
    while (k++ < 3 && k++ < 3)
        printf("k=%d\n", k);
    printf("end i=%d j=%d k=%d\n", i, j, k);
    return 0;
}
@@@ explanation_md
**Answer**
```
|0 4 1
**|2 1 3
k=2
end i=4 j=-2 k=4
```

**Step by step.**
1. **Comma operator in the condition.** `j--, i < 4` evaluates `j--`, discards its value, then evaluates `i < 4`, which is the value of the whole expression. The condition is checked three times (`i = 0, 2, 4`), so `j` is decremented three times by the condition and twice by the increment expression `j -= 2`: `5 -> 4`, `-> 2 -> 1`, `-> -1 -> -2`.
2. **Post-increment in the `while`.** `n++ < i` compares the old `n` and increments it every time, including the failing comparison. The body therefore prints `i` stars and leaves `n = i + 1`.
3. **`&&` with side effects.** `&&` evaluates the left side completely (including the increment) before the right side, so there is no undefined behavior. In the second iteration the left side is true (`2 < 3`), the right side `3 < 3` is false, and `k` ends at 4.

**Complexity.** Constant. The question is about evaluation order, not cost.

**Common mistakes**
- Thinking the comma makes the loop test **both** conditions (`j-- && i < 4`). Only the last operand decides.
- Forgetting the final, failing condition check, which still executes `j--` (answer `j=-1` instead of `-2`).
- Expecting `n = i` after the `while`. The failing comparison also increments.
- Assuming the second `k++` always runs, or calling the `&&` line undefined behavior. `&&`, `||`, `?:` and the comma operator are sequence points.

**Interview follow-ups**
- Is the comma in `printf("%d %d", a, b)` a comma operator? (No, it separates function arguments. Their evaluation order is unspecified, and modifying the same variable in two arguments is undefined.)
- Rewrite the `for` loop so that a MISRA reviewer accepts it. MISRA C:2012 Rule 12.3 says the comma operator should not be used, and Rule 13.3 restricts `++`/`--` in larger expressions.
- What does `x = (1, 2, 3);` assign, and why does `x = 1, 2, 3;` behave differently? (Assignment binds tighter than the comma.)
