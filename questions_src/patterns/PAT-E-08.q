@@@ meta
id: PAT-E-08
topic: C Patterns
difficulty: Easy
type: PREDICT_OUTPUT
title: putchar with Character Arithmetic
tags: putchar, char-arithmetic, ascii, ternary-operator
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**, ASCII character set.

```c
#include <stdio.h>

int main(void)
{
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j <= i; j++)
            putchar(j % 2 ? 'a' + i + j : 'A' + i + j);
        putchar(' ');
        putchar('0' + i * 4);
        putchar('\n');
    }
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11, ASCII (`'A'` = 65, `'a'` = 97, `'0'` = 48).
@@@ starter_code
#include <stdio.h>

int main(void)
{
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j <= i; j++)
            putchar(j % 2 ? 'a' + i + j : 'A' + i + j);
        putchar(' ');
        putchar('0' + i * 4);
        putchar('\n');
    }
    return 0;
}
@@@ predict_answer
A 0
Bc 4
CdE 8
DeFg <
@@@ hint
Every row starts with the letter `'A' + i`; the column index `j` moves you further along the alphabet, and odd columns are lowercase.
@@@ hint
`putchar('0' + x)` prints a digit only while `x <= 9`. What is the character with code `48 + 12`?
@@@ solution_code
#include <stdio.h>

int main(void)
{
    for (int i = 0; i < 4; i++) {
        /* letter number (i + j) of the alphabet; odd columns lowercase */
        for (int j = 0; j <= i; j++)
            putchar(j % 2 ? 'a' + i + j : 'A' + i + j);
        putchar(' ');
        /* '0' + 0, 4, 8, 12 -> '0', '4', '8', and 48 + 12 = 60 = '<' */
        putchar('0' + i * 4);
        putchar('\n');
    }
    /* i=0: A          0
     * i=1: B c        4
     * i=2: C d E      8
     * i=3: D e F g    <
     */
    return 0;
}
@@@ explanation_md
**Answer**
```
A 0
Bc 4
CdE 8
DeFg <
```

**Step by step.** In row `i`, column `j` prints letter number `i + j` (0 = A), uppercase for even `j` and lowercase for odd `j`. Row 3 is `D e F g`. The last column prints `'0' + 4i`: `'0'`, `'4'`, `'8'`, and for `i = 3` it prints character 48 + 12 = 60, which is `'<'`, not `"12"`. `putchar` writes **one** character; it never formats a number.

**Complexity.** 10 letters in 4 rows: O(n^2) for n rows, O(1) memory.

**Common mistakes**
- Expecting `12` in the last row. `'0' + x` is a digit character only for `0 <= x <= 9`. For a number, use `printf("%d", x)`.
- Thinking `putchar` "knows" it received a letter. It receives an `int`, converts it to `unsigned char` and writes that byte.
- Precedence of `?:`: here `j % 2` is the whole condition because `?:` has very low precedence. The two branches are evaluated only when chosen.
- Mixing up `'a' - 'A'` (32) with other offsets when converting case.

**Interview follow-ups**
- Convert a lowercase letter to uppercase without `toupper`: `c - 'a' + 'A'`, or `c & ~0x20` in ASCII. Why is the bit trick not portable?
- Print a two-digit number with only `putchar`: `putchar('0' + x / 10); putchar('0' + x % 10);`. How would you print a whole `uint16_t` this way on a UART without `printf`?
- What does `putchar(321)` print, and why? (It converts to `unsigned char`: 321 - 256 = 65 = `'A'`.)
