@@@ meta
id: PAT-M-07
topic: C Patterns
difficulty: Medium
type: PREDICT_OUTPUT
title: printf Return Values and Star Widths
tags: printf, field-width, return-value, formatting
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int total = 0;
    for (int i = 1; i <= 3; i++) {
        int n = printf("%*d|%-*d|", i + 1, i * 7, i, i * 50);
        total += n;
        printf("%d\n", n);
    }
    printf("%d\n", printf("%*s", -4, "ab") + total);
    return 0;
}
```

Type the exact output (leading spaces matter), or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, glibc, C11.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int total = 0;
    for (int i = 1; i <= 3; i++) {
        int n = printf("%*d|%-*d|", i + 1, i * 7, i, i * 50);
        total += n;
        printf("%d\n", n);
    }
    printf("%d\n", printf("%*s", -4, "ab") + total);
    return 0;
}
@@@ predict_answer
 7|50|6
 14|100|8
  21|150|9
ab  27
@@@ hint
`printf` returns the number of characters it wrote, padding included. A field width is a **minimum**: a value that is wider than the field is printed in full.
@@@ hint
A `*` width taken from a **negative** argument means "the `-` flag plus the positive width", so `printf("%*s", -4, "ab")` prints `ab` followed by two spaces. The inner `printf` runs before the outer one can print anything.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int total = 0;
    for (int i = 1; i <= 3; i++) {
        /* i=1: "%2d" of 7  -> " 7",   "%-1d" of 50  -> "50"  : " 7|50|"     = 6 chars
         * i=2: "%3d" of 14 -> " 14",  "%-2d" of 100 -> "100" : " 14|100|"   = 8 chars
         * i=3: "%4d" of 21 -> "  21", "%-3d" of 150 -> "150" : "  21|150|"  = 9 chars
         * a width smaller than the number never truncates it */
        int n = printf("%*d|%-*d|", i + 1, i * 7, i, i * 50);
        total += n;                 /* 6 + 8 + 9 = 23 */
        printf("%d\n", n);          /* the count goes right after the bars */
    }
    /* inner call first: width -4 = left-justify in 4 -> "ab  ", returns 4
     * outer call prints 4 + 23 = 27 on the same line */
    printf("%d\n", printf("%*s", -4, "ab") + total);
    return 0;
}
@@@ explanation_md
**Answer**
```
 7|50|6
 14|100|8
  21|150|9
ab  27
```

**Step by step.**
1. `%*d` takes the width from the argument list (`i + 1`), and `%-*d` does the same with left alignment (width `i`). Widths are minimums: `%-1d` of 50 prints `50`, and `%-2d` of 100 prints `100`. The bars show that no padding was added on the right.
2. `printf` returns the number of characters written: 6, 8 and 9. Each count is printed on the same line, right after the second bar.
3. In the last statement, the argument `printf("%*s", -4, "ab")` must be evaluated **before** the outer call runs. A negative `*` width is treated as the `-` flag with width 4 (C11 7.21.6.1p5), so it prints `ab` plus two spaces and returns 4. The outer `printf` then prints `4 + 23 = 27` right after those spaces.

**Complexity.** Constant work. `printf` return values are a cheap way to measure output for alignment.

**Common mistakes**
- Thinking a field width truncates (`%-1d` of 50 printing `5`). Only a **precision** truncates strings (`%.1s`); numbers are never truncated.
- Forgetting that the padding spaces are part of the return value.
- Expecting `27` on its own line. The inner `printf` has already written `ab  ` without a newline.
- Assuming a negative width is an error or is ignored.

**Interview follow-ups**
- Use the return value of `printf` (or `snprintf(NULL, 0, ...)`) to right-align a table column whose width is unknown until all values have been formatted.
- What does `printf` return on an output error, and why do embedded logging wrappers check it?
- What is the difference between `%5.2s`, `%-5s` and `%.*s`, and which one is useful for printing a non-terminated buffer (a CAN payload)?
