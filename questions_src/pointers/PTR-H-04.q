@@@ meta
id: PTR-H-04
topic: Pointers
difficulty: Hard
type: PREDICT_OUTPUT
title: Triple-Pointer Puzzle over a Table of ECU Names
tags: pointer-to-pointer, triple-pointer, operator-precedence, array-of-pointers, puzzle
@@@ statement_md
A classic screening puzzle (a variant of "POINTER STEW" from *The C Puzzle Book*). Track every pointer carefully, including the ones that get **modified**. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    const char *w[] = {"BRAKE", "CAN", "ENGINE", "LIGHT"};
    const char **wp[] = {w + 3, w + 2, w + 1, w};
    const char ***p = wp;

    printf("%s ", **++p);
    printf("%s ", *--*++p + 3);
    printf("%s ", *p[-2] + 3);
    printf("%s\n", p[-1][-1] + 1);
    printf("%s %td\n", **p, *p - w);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- Postfix `[]` binds tighter than the prefix operators `* ++ --`, and prefix operators apply right to left.
- `%td` prints a `ptrdiff_t`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    const char *w[] = {"BRAKE", "CAN", "ENGINE", "LIGHT"};
    const char **wp[] = {w + 3, w + 2, w + 1, w};
    const char ***p = wp;

    printf("%s ", **++p);
    printf("%s ", *--*++p + 3);
    printf("%s ", *p[-2] + 3);
    printf("%s\n", p[-1][-1] + 1);
    printf("%s %td\n", **p, *p - w);
    return 0;
}
@@@ predict_answer
ENGINE KE HT AN
BRAKE 0
@@@ hint
Draw three rows of boxes: `w[0..3]` (pointers to strings), `wp[0..3]` (pointers into `w`), and `p` (a pointer into `wp`). Note that `++p` moves `p`, but `--*p` changes an element of **`wp`**, and that change is permanent.
@@@ hint
`*--*++p + 3` is `(*(--(*(++p)))) + 3`: move `p`, decrement the `wp` element it points to, dereference to get a string, then skip 3 characters. `p[-2]` means `*(p - 2)` and is relative to the **current** `p`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    const char *w[] = {"BRAKE", "CAN", "ENGINE", "LIGHT"};   /* w[0]..w[3]          */
    const char **wp[] = {w + 3, w + 2, w + 1, w};            /* wp[i] -> w[3 - i]   */
    const char ***p = wp;                                    /* p -> wp[0]          */

    /* ++p -> wp[1];  *p = wp[1] = w + 2;  **p = w[2] = "ENGINE" */
    printf("%s ", **++p);

    /* ++p -> wp[2];  --*p makes wp[2] = w + 0 (PERMANENT);  * -> "BRAKE";  + 3 -> "KE" */
    printf("%s ", *--*++p + 3);

    /* p == wp + 2;  p[-2] = wp[0] = w + 3;  * -> "LIGHT";  + 3 -> "HT" */
    printf("%s ", *p[-2] + 3);

    /* p[-1] = wp[1] = w + 2;  [-1] -> w[1] = "CAN";  + 1 -> "AN" */
    printf("%s\n", p[-1][-1] + 1);

    /* *p = wp[2], which was decremented to w + 0:  **p = "BRAKE",  *p - w = 0 */
    printf("%s %td\n", **p, *p - w);
    return 0;
}
@@@ explanation_md
**Answer**
```
ENGINE KE HT AN
BRAKE 0
```

State before the first `printf`:

```
w : [ "BRAKE" | "CAN" | "ENGINE" | "LIGHT" ]
       w+0      w+1      w+2        w+3
wp: [ w+3 | w+2 | w+1 | w+0 ]
p ->  wp[0]
```

| statement | effect | printed |
|---|---|---|
| `**++p` | `p` moves to `wp[1]` (= `w+2`) | `ENGINE` |
| `*--*++p + 3` | `p` moves to `wp[2]`; **`wp[2]` is decremented from `w+1` to `w+0`**; `*` gives `"BRAKE"`; `+3` | `KE` |
| `*p[-2] + 3` | `p[-2]` = `wp[0]` = `w+3`; `"LIGHT"` + 3 | `HT` |
| `p[-1][-1] + 1` | `p[-1]` = `wp[1]` = `w+2`; `[-1]` gives `w[1]` = `"CAN"`; `+1` | `AN` |
| `**p`, `*p - w` | `wp[2]` is now `w+0` | `BRAKE 0` |

Every access stays inside its array (negative subscripts are fine when the result stays in bounds), and each statement modifies at most one object. So the program is fully defined.

**Complexity.** N/A. Each expression is a constant number of loads and pointer additions.

**Common mistakes**
- Treating `--*++p` as moving `p` back. The `--` applies to `*p`, an element of `wp`, not to `p`.
- Forgetting that this modification persists. The last line then gives `CAN 1` instead of `BRAKE 0`.
- Computing `p[-2]` relative to the original `p` (`wp`) instead of the current one (`wp + 2`).
- Adding 3 to the pointer *before* dereferencing (`*(... + 3)`). `+` binds weaker than the unary operators, so it is applied to the final `char *`.

**Interview follow-ups**
- Where do you meet `char ***` in real code? (A function that allocates and returns an `argv`-style array through an out-parameter: `int split(const char *s, char ***out)`.)
- Why is `wp[i]` of type `const char **` and not `char **`? What would `-Wcast-qual` say if you dropped the `const`?
- Rewrite line 2 without side effects inside the `printf` argument. Why do coding standards (MISRA C Rule 13.2/13.3) discourage combining `++`/`--` with other operators?
- What is the difference between `p[-1][-1]` and `*(*p - 1) - 1` here?
