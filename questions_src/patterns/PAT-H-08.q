@@@ meta
id: PAT-H-08
topic: C Patterns
difficulty: Hard
type: PREDICT_OUTPUT
title: Number Pyramid with a Hidden Sequencing Trap
tags: undefined-behavior, unsequenced-modification, printf-arguments, number-pyramid
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int n = 4, k = 1;
    for (int i = 1; i <= n; i++) {
        printf("%*s", n - i, "");
        for (int j = 1; j <= i; j++)
            printf("%d", k++ % 10);
        printf(" %d %d\n", k, k++);
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
    int n = 4, k = 1;
    for (int i = 1; i <= n; i++) {
        printf("%*s", n - i, "");
        for (int j = 1; j <= i; j++)
            printf("%d", k++ % 10);
        printf(" %d %d\n", k, k++);
    }
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
The pyramid part (`%*s` indentation, `k++ % 10`) is well-defined. Look at the last `printf` of each row: which argument reads `k`, which one modifies it, and is there anything that orders the two?
@@@ hint
The commas between function arguments are **not** comma operators, and the order in which arguments are evaluated is unspecified. Reading `k` and modifying `k` in two arguments of the same call without a sequence point between them is undefined behavior (C11 6.5p2).
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int n = 4, k = 1;
    for (int i = 1; i <= n; i++) {
        printf("%*s", n - i, "");           /* fine: n - i spaces of indentation */
        for (int j = 1; j <= i; j++)
            printf("%d", k++ % 10);         /* fine: one modification per full expression */
        /* UNDEFINED: argument 2 reads k, argument 3 modifies k (k++).
         * Function arguments are unsequenced relative to each other, and a side effect
         * on a scalar that is unsequenced relative to a value computation using the same
         * scalar is undefined behavior (C11 6.5p2). gcc warns: "operation on 'k' may be
         * undefined" (-Wsequence-point). Typical gcc x86-64 output prints "k+1 k",
         * other compilers print "k k"; neither is guaranteed. */
        printf(" %d %d\n", k, k++);
    }
    return 0;
}
@@@ explanation_md
**Answer: Undefined Behavior**

Everything that draws the pyramid is fine: `%*s` with `n - i` and `""` prints the indentation, and `k++ % 10` modifies `k` once per full expression. The trap is in

```c
printf(" %d %d\n", k, k++);
```

The commas separating function arguments are **not** comma operators, so they are not sequence points. The evaluation order of arguments is unspecified, and between the read of `k` (2nd argument) and the modification `k++` (3rd argument) there is no ordering at all. C11 6.5p2: *"If a side effect on a scalar object is unsequenced relative to ... a value computation using the value of the same scalar object, the behavior is undefined."* The whole program is undefined, not only that line's values.

In practice gcc on x86-64 often evaluates arguments right to left and prints something like `1 2 3 ...` rows followed by `k+1 k`, and clang tends to print `k k`. gcc even warns with `-Wall`: *operation on 'k' may be undefined* (`-Wsequence-point`). Any answer that relies on one of those orders is wrong.

**Fix.** Split the side effect into its own statement: `printf(" %d %d\n", k, k); k++;` or decide explicitly which value you want.

**Complexity.** Not applicable; the program has no defined behavior to analyze.

**Common mistakes**
- Computing a "most likely" output. Undefined behavior means the standard imposes no requirements, and optimizing compilers really do exploit it.
- Confusing **unspecified** (argument order: one of several valid orders, result still defined if the arguments are independent) with **undefined** (same object read and modified without sequencing).
- Thinking the earlier `k++ % 10` is the problem. One `++` per full expression is fine; the semicolon is a sequence point.

**Interview follow-ups**
- Which of these are undefined: `i = i++ + 1;`, `a[i] = i++;`, `f(i++, i++);`, `i++ && i++;`? (The first three are undefined, the last is defined because `&&` is a sequence point.)
- Explain unspecified vs implementation-defined vs undefined behavior, with one example each.
- Why does MISRA C:2012 Rule 13.2 require that "the value of an expression and its persistent side effects shall be the same under all permitted evaluation orders"?
