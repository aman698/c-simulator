@@@ meta
id: BIT-E-07
topic: Bit Manipulation
difficulty: Easy
type: PREDICT_OUTPUT
title: Operator Precedence Traps in Bit Tests
tags: operator-precedence, bitwise-and, shifts, flags, misra
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdint.h>

#define FLAG_READY 0x04u

int main(void)
{
    uint32_t status = 0x06;
    int x = 6;

    if (x & 1 == 0)
        printf("even\n");
    else
        printf("odd\n");

    printf("%u\n", 1u << 2 + 1);
    printf("%u\n", status & FLAG_READY != 0);
    printf("%u\n", status & 0x3u << 1);
    printf("%u %d\n", ~status & 0xFu, !status);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, `uint32_t` is `unsigned int`.
- The program compiles (gcc warns with `-Wparentheses`, but warnings are not errors).
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

#define FLAG_READY 0x04u

int main(void)
{
    uint32_t status = 0x06;
    int x = 6;

    if (x & 1 == 0)
        printf("even\n");
    else
        printf("odd\n");

    printf("%u\n", 1u << 2 + 1);
    printf("%u\n", status & FLAG_READY != 0);
    printf("%u\n", status & 0x3u << 1);
    printf("%u %d\n", ~status & 0xFu, !status);
    return 0;
}
@@@ predict_answer
odd
8
0
6
9 0
@@@ hint
Look up where `&`, `<<`, `+` and `==`/`!=` sit in the precedence table. Equality operators bind **tighter** than the bitwise `&`, `^` and `|`.
@@@ hint
Additive operators bind tighter than shifts, and shifts bind tighter than relational and bitwise operators. Rewrite each expression with explicit parentheses before evaluating it.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

#define FLAG_READY 0x04u

int main(void)
{
    uint32_t status = 0x06;
    int x = 6;

    /* x & (1 == 0)  ->  6 & 0  ->  0  -> else branch, although 6 is even */
    if (x & 1 == 0)
        printf("even\n");
    else
        printf("odd\n");                          /* odd */

    /* 1u << (2 + 1)  ->  1u << 3 */
    printf("%u\n", 1u << 2 + 1);                  /* 8 */

    /* status & (FLAG_READY != 0)  ->  6 & 1  ->  0, although the READY bit IS set */
    printf("%u\n", status & FLAG_READY != 0);     /* 0 */

    /* status & (0x3u << 1)  ->  6 & 6, not (6 & 3) << 1 */
    printf("%u\n", status & 0x3u << 1);           /* 6 */

    /* ~ is bitwise: ~6 = 0xFFFFFFF9, & 0xF -> 9.  ! is logical: !6 -> 0 */
    printf("%u %d\n", ~status & 0xFu, !status);   /* 9 0 */
    return 0;
}
@@@ explanation_md
**Answer**
```
odd
8
0
6
9 0
```

The C precedence order that matters here, from tightest to loosest:
`!  ~` (unary) > `* / %` > `+ -` > `<< >>` > `< <= > >=` > `== !=` > `&` > `^` > `|` > `&&` > `||`.

| expression | parsed as | value |
|---|---|---|
| `x & 1 == 0` | `x & (1 == 0)` = `6 & 0` | 0, so the `else` branch prints `odd` |
| `1u << 2 + 1` | `1u << (2 + 1)` | 8 |
| `status & FLAG_READY != 0` | `status & (0x04u != 0)` = `6 & 1` | 0 |
| `status & 0x3u << 1` | `status & (0x3u << 1)` = `6 & 6` | 6 |
| `~status & 0xFu` | `(~status) & 0xF` = `0xFFFFFFF9 & 0xF` | 9 |
| `!status` | logical NOT of a non-zero value | 0 |

The `==`-below-`&` ordering is a historical leftover from early C. Before `&&` existed, `&` doubled as the logical AND, so `if (a == b & c == d)` had to parse "naturally". Every C programmer since then pays for it.

**Complexity.** N/A. Precedence is resolved at compile time.

**Common mistakes**
- Reading `x & 1 == 0` as "x is even". It is always 0 here, so the even branch is dead code. With `-Wall`, gcc warns: *suggest parentheses around comparison in operand of '&'*.
- Writing `if (status & FLAG_READY != 0)` as a "readiness" check. It tests bit 0, not bit 2, so the firmware waits forever even though the flag is set.
- Confusing `~` (bitwise complement) with `!` (logical NOT). `!0x06 == 0`, but `~0x06 == 0xFFFFFFF9`.
- Assuming a shift happens before `+`. `1u << 2 + 1` is 8, not 5.

**Interview follow-ups**
- How would you write the readiness test so that it reads correctly and satisfies MISRA C:2012 Rule 12.1 (explicit precedence)? (`if ((status & FLAG_READY) != 0u)`.)
- Why do most coding standards ban using the result of `&` directly as a boolean in `if (reg & MASK)`, and when is it fine?
- What does `a & b == c` compile to in assembly, and how would a code review tool or `-Wparentheses` catch it?
