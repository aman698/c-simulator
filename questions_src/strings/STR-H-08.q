@@@ meta
id: STR-H-08
topic: Strings
difficulty: Hard
type: PREDICT_OUTPUT
title: Unsigned strlen Arithmetic and strcmp Truthiness
tags: size-t, unsigned-arithmetic, strlen, strcmp, usual-arithmetic-conversions
@@@ statement_md
A code reviewer flagged this function as "obviously fine". What does the program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `size_t` = 8 bytes (unsigned)**.

```c
#include <stdio.h>
#include <string.h>

int main(void)
{
    const char *a = "CAN";
    const char *b = "FlexRay";
    int i = -1;

    if (strlen(a) - strlen(b) > 0)
        puts("a is longer");
    else
        puts("b is longer");

    if (i < strlen(a))
        puts("i < len");
    else
        puts("i >= len");

    if (strcmp(a, "CAN"))
        puts("match");
    else
        puts("no match");

    printf("%zu\n", strlen(a) - strlen(b));
    printf("%d\n", (int)strlen(a) - (int)strlen(b));

    for (size_t k = strlen(a) - 1; k < strlen(a); k--)
        putchar(a[k]);
    putchar('\n');
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, LP64: `size_t` is a 64-bit unsigned type, `int` is 32-bit. Compiler warnings (e.g. `-Wsign-compare`) do not stop compilation.
@@@ starter_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    const char *a = "CAN";
    const char *b = "FlexRay";
    int i = -1;

    if (strlen(a) - strlen(b) > 0)
        puts("a is longer");
    else
        puts("b is longer");

    if (i < strlen(a))
        puts("i < len");
    else
        puts("i >= len");

    if (strcmp(a, "CAN"))
        puts("match");
    else
        puts("no match");

    printf("%zu\n", strlen(a) - strlen(b));
    printf("%d\n", (int)strlen(a) - (int)strlen(b));

    for (size_t k = strlen(a) - 1; k < strlen(a); k--)
        putchar(a[k]);
    putchar('\n');
    return 0;
}
@@@ predict_answer
a is longer
i >= len
no match
18446744073709551612
-4
NAC
@@@ hint
`strlen` returns `size_t`, an **unsigned** type. Unsigned arithmetic never goes negative: `3 - 7` wraps around to 2^64 - 4. When an `int` meets a `size_t` in a comparison, the `int` is converted to `size_t` first.
@@@ hint
`strcmp` returns **0** when the strings are equal, and 0 is "false" in an `if`. The final loop counts an unsigned index down: after `k == 0`, `k--` wraps to `SIZE_MAX`, which is not `< 3`, so the loop ends cleanly.
@@@ solution_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    const char *a = "CAN";          /* strlen = 3 */
    const char *b = "FlexRay";      /* strlen = 7 */
    int i = -1;

    if (strlen(a) - strlen(b) > 0)  /* size_t: 3 - 7 = 2^64 - 4, which is > 0 */
        puts("a is longer");        /* <- printed (wrong conclusion!)          */
    else
        puts("b is longer");

    if (i < strlen(a))              /* -1 converted to size_t = 2^64 - 1       */
        puts("i < len");
    else
        puts("i >= len");           /* <- printed                              */

    if (strcmp(a, "CAN"))           /* equal -> 0 -> false                     */
        puts("match");
    else
        puts("no match");           /* <- printed                              */

    printf("%zu\n", strlen(a) - strlen(b));          /* 18446744073709551612 */
    printf("%d\n", (int)strlen(a) - (int)strlen(b)); /* -4: signed arithmetic */

    for (size_t k = strlen(a) - 1; k < strlen(a); k--)  /* k = 2, 1, 0, then SIZE_MAX */
        putchar(a[k]);                                   /* N A C                      */
    putchar('\n');
    return 0;
}
@@@ explanation_md
**Answer**
```
a is longer
i >= len
no match
18446744073709551612
-4
NAC
```

1. `strlen(a) - strlen(b)` is computed in `size_t`. Unsigned arithmetic is modulo 2^64, so `3 - 7` is `18446744073709551612`, which is `> 0`. The program concludes that `"CAN"` is longer than `"FlexRay"`. Correct comparison: `strlen(a) > strlen(b)`.
2. `i < strlen(a)`: the usual arithmetic conversions turn the `int` `-1` into `size_t` (C11 6.3.1.8), giving `SIZE_MAX`. `SIZE_MAX < 3` is false. gcc warns about this with `-Wsign-compare` (enabled by `-Wextra`).
3. `strcmp` returns `0` for equal strings, so `if (strcmp(a, "CAN"))` takes the **else** branch. Always write `strcmp(...) == 0`.
4. Casting **before** subtracting makes it signed: `3 - 7 = -4`.
5. Counting down with an unsigned index: `k` runs 2, 1, 0. Then `k--` wraps to `SIZE_MAX`, and `SIZE_MAX < 3` ends the loop. This is a correct (if surprising) idiom, the usual alternative being `for (size_t k = n; k-- > 0; )`. The naive `k >= 0` condition would never become false.

None of this is undefined behavior: unsigned wrap-around is fully defined. That is exactly why the compiler cannot stop you.

**Complexity.** N/A for the output. Note that each `strlen` call is O(n), and the loop condition calls it on every iteration, which turns an O(n) loop into O(n^2) for long strings.

**Common mistakes**
- Treating `size_t` results as if they could be negative (`len1 - len2 < 0`, `strlen(s) - 1` on an empty string).
- Comparing signed and unsigned values and ignoring `-Wsign-compare`.
- Reading `if (strcmp(x, y))` as "if equal".
- Writing `for (size_t k = n - 1; k >= 0; k--)`: an infinite loop that reads out of bounds once `k` wraps.

**Interview follow-ups**
- How do MISRA C:2012 Rule 10.4 (operands of the same essential type category) and `-Wconversion` help catch these bugs in ECU code?
- What does `if (len - 1 < 0)` compile to when `len` is `uint32_t` (always false), and how did a bug like this become a CVE?
- Is `(int)strlen(s)` safe? (Only if the length is known to be `<= INT_MAX`; otherwise the conversion result is implementation-defined.)
