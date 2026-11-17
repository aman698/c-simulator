@@@ meta
id: PTR-E-04
topic: Pointers
difficulty: Easy
type: PREDICT_OUTPUT
title: Pointer Walk: *p++ vs (*p)++ vs ++*p vs *++p
tags: operator-precedence, pointer-arithmetic, increment, dereference
@@@ statement_md
A UART receive routine walks a sample buffer with a pointer. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int buf[] = {10, 20, 30, 40};
    int *p = buf;
    int x, y, z, w;

    x = *p++;
    y = (*p)++;
    z = ++*p;
    w = *++p;

    printf("%d %d %d %d\n", x, y, z, w);
    printf("%d %d %d %d %td\n", buf[0], buf[1], buf[2], buf[3], p - buf);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- `%td` prints a `ptrdiff_t` (the type of a pointer difference).
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int buf[] = {10, 20, 30, 40};
    int *p = buf;
    int x, y, z, w;

    x = *p++;
    y = (*p)++;
    z = ++*p;
    w = *++p;

    printf("%d %d %d %d\n", x, y, z, w);
    printf("%d %d %d %d %td\n", buf[0], buf[1], buf[2], buf[3], p - buf);
    return 0;
}
@@@ predict_answer
10 20 22 30
10 22 30 40 2
@@@ hint
Postfix `++` binds tighter than unary `*`, so `*p++` means `*(p++)`. The prefix operators `++` and `*` are applied right to left.
@@@ hint
Ask for each line: is the **pointer** incremented or the **pointed-to value**? And is the old or the new value used?
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int buf[] = {10, 20, 30, 40};
    int *p = buf;               /* p -> buf[0] */
    int x, y, z, w;

    x = *p++;     /* *(p++): read buf[0] = 10, THEN move p -> buf[1]         x = 10 */
    y = (*p)++;   /* read buf[1] = 20, THEN increment buf[1] to 21; p unchanged  y = 20 */
    z = ++*p;     /* ++(*p): increment buf[1] to 22, use the new value           z = 22 */
    w = *++p;     /* *(++p): move p -> buf[2] first, then read 30                w = 30 */

    printf("%d %d %d %d\n", x, y, z, w);                                    /* 10 20 22 30   */
    printf("%d %d %d %d %td\n", buf[0], buf[1], buf[2], buf[3], p - buf);   /* 10 22 30 40 2 */
    return 0;
}
@@@ explanation_md
**Answer**
```
10 20 22 30
10 22 30 40 2
```

| expression | parsed as | modifies | value used |
|---|---|---|---|
| `*p++` | `*(p++)` | pointer `p` | old `*p` (10) |
| `(*p)++` | postfix on the int | `buf[1]`: 20 to 21 | old value (20) |
| `++*p` | `++(*p)` | `buf[1]`: 21 to 22 | new value (22) |
| `*++p` | `*(++p)` | pointer `p` | `*` of the new `p` (30) |

Postfix operators (`p++`, `p[i]`, `f()`) bind tighter than prefix operators (`*`, `++`, `&`). Prefix operators are applied right to left. `p - buf` is a difference in **elements**, not bytes, so `p` (pointing at `buf[2]`) gives `2`.

Every statement modifies only one object, so there is no unsequenced-modification undefined behavior here. That would be different with `*p++ = *p;`.

**Complexity.** O(1). Each line is a single load/store plus an address increment.

**Common mistakes**
- Reading `*p++` as "increment the value". That is `(*p)++`. `*p++` is the idiomatic "read and advance" used in copy loops: `while (n--) *d++ = *s++;`.
- Thinking `++*p` moves the pointer. Prefix operators apply right to left, so `*` first, then `++` on the int.
- Expecting `p - buf` to be 8 (bytes). Pointer subtraction is scaled by `sizeof(int)`.

**Interview follow-ups**
- What does `*p++ = *p;` do? (Undefined behavior: `p` is modified and also read for another purpose without a sequence point, C11 6.5p2.)
- What is the value of `++*p++` and what does it modify?
- In `while (*dst++ = *src++);` (classic strcpy), where do `dst` and `src` point when the loop ends?
- Why is `*p++` on a `volatile uint8_t *` FIFO register pointer usually a bug? (The FIFO is at a single address; you must not advance the pointer.)
