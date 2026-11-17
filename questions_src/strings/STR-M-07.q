@@@ meta
id: STR-M-07
topic: Strings
difficulty: Medium
type: PREDICT_OUTPUT
title: Walking a String with *p++, (*p)++ and *++p
tags: operator-precedence, pointer-increment, post-increment, char-array
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

int main(void)
{
    char s[] = "ABCD";
    char *p = s;

    char a = *p++;
    char b = (*p)++;
    char c = *++p;
    char d = ++*p;

    printf("%c%c%c%c %s %d\n", a, b, c, d, s, (int)(p - s));

    while (*p++)
        ;
    printf("%d\n", (int)(p - s));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc. `s` is a modifiable array, not a string literal.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    char s[] = "ABCD";
    char *p = s;

    char a = *p++;
    char b = (*p)++;
    char c = *++p;
    char d = ++*p;

    printf("%c%c%c%c %s %d\n", a, b, c, d, s, (int)(p - s));

    while (*p++)
        ;
    printf("%d\n", (int)(p - s));
    return 0;
}
@@@ predict_answer
ABCD ACDD 2
5
@@@ hint
Postfix `++` binds tighter than unary `*`, so `*p++` means `*(p++)`: read the char, then advance the **pointer**. `(*p)++` increments the **char** instead. Prefix operators apply right to left: `*++p` moves first, `++*p` increments the char first.
@@@ hint
`while (*p++);` tests `*p` and then increments `p` **even when** the test fails. When the loop stops, `p` points one past the `'\0'`, not at it.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    char s[] = "ABCD";      /* s = A B C D \0  (indices 0..4)                 */
    char *p = s;            /* p -> s[0]                                     */

    char a = *p++;          /* *(p++): a = 'A', then p -> s[1]               */
    char b = (*p)++;        /* b = 'B', then s[1] becomes 'C'   s = "ACCD"   */
    char c = *++p;          /* p -> s[2] first, c = 'C'                      */
    char d = ++*p;          /* s[2] becomes 'D' first, d = 'D'  s = "ACDD"   */

    printf("%c%c%c%c %s %d\n", a, b, c, d, s, (int)(p - s));   /* ABCD ACDD 2 */

    while (*p++)            /* reads s[2]='D', s[3]='D', s[4]='\0' ...        */
        ;                   /* ... and still increments after reading '\0'    */
    printf("%d\n", (int)(p - s));                               /* 5: one past */
    return 0;
}
@@@ explanation_md
**Answer**
```
ABCD ACDD 2
5
```

| statement | what changes | value | `s` afterwards | `p` |
|---|---|---|---|---|
| `a = *p++` | pointer moves after the read | `'A'` | `ABCD` | `s+1` |
| `b = (*p)++` | the **char** `s[1]` is incremented after the read | `'B'` | `ACCD` | `s+1` |
| `c = *++p` | pointer moves before the read | `'C'` | `ACCD` | `s+2` |
| `d = ++*p` | the char `s[2]` is incremented before the read | `'D'` | `ACDD` | `s+2` |

The letters `a b c d` happen to spell `ABCD`, while the array itself became `ACDD`.

The loop `while (*p++);` performs the test and the increment on every iteration, **including** the one that reads the `'\0'`. Starting at `s+2`, it reads `s[2]`, `s[3]`, `s[4]` (`'\0'`) and leaves `p == s + 5`, one past the terminator. Pointing one past the end of an array is allowed; dereferencing it would not be.

**Complexity.** The walk is O(n), one step per character.

**Common mistakes**
- Reading `*p++` as `(*p)++`. That is the most frequent precedence trap in C string code. Postfix operators bind tighter than prefix and unary ones.
- Assuming `while (*p++);` leaves `p` **at** the terminator. It leaves `p` one past it, which is why the classic `my_strlen` written this way must return `p - s - 1`.
- Assuming the expressions are undefined behavior. Each statement modifies `p` or `*p` only once and is followed by a sequence point, so everything is well defined. It would be UB to write `*p++ = *p;` (C11 6.5p2: unsequenced read and write of `p`).

**Interview follow-ups**
- Explain why `while ((*d++ = *s++) != '\0');` copies a string including its terminator.
- Is `i = i++ + 1;` defined? What about `a[i] = i++;`? (Both are UB in C: the side effect on `i` is unsequenced relative to another use of `i`.)
- `*p++` on a `volatile uint8_t *p` that points to a UART data register: how many bus reads happen, and why does it matter?
