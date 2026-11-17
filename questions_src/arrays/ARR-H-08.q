@@@ meta
id: ARR-H-08
topic: Arrays
difficulty: Hard
type: PREDICT_OUTPUT
title: Pointer-to-Row Arithmetic and sizeof on a VLA Type
tags: pointer-to-array, 2d-array, vla, sizeof-evaluation, operator-precedence
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `size_t` = 8 bytes**. C11 with VLA support (gcc's default).

```c
#include <stdio.h>

int main(void)
{
    int m[3][4] = { {1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12} };
    int (*p)[4] = m + 1;
    int *q = m[2] + 1;
    int n = 2;

    printf("%zu %zu %zu\n", sizeof m / sizeof m[0], sizeof *p, sizeof(p + 0));
    printf("%d %d %d\n", **p, -1[q], (*p)[3]);
    printf("%d %d\n", p[1][2], *(*(m + 2) + 3));

    size_t s = sizeof(int[n++][4]);
    size_t t = sizeof(n++);
    printf("%zu %zu %d\n", s, t, n);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11 (variable length arrays supported).
- Every access stays inside the row it indexes; the snippet has no undefined behavior.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int m[3][4] = { {1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12} };
    int (*p)[4] = m + 1;
    int *q = m[2] + 1;
    int n = 2;

    printf("%zu %zu %zu\n", sizeof m / sizeof m[0], sizeof *p, sizeof(p + 0));
    printf("%d %d %d\n", **p, -1[q], (*p)[3]);
    printf("%d %d\n", p[1][2], *(*(m + 2) + 3));

    size_t s = sizeof(int[n++][4]);
    size_t t = sizeof(n++);
    printf("%zu %zu %d\n", s, t, n);
    return 0;
}
@@@ predict_answer
3 16 8
5 -11 8
11 12
32 4 3
@@@ hint
`m + 1` has type `int (*)[4]`: it points at the whole row `m[1]`. Postfix operators bind tighter than unary ones, so `-1[q]` is `-(1[q])`, which is `-(q[1])`.
@@@ hint
`sizeof` normally does **not** evaluate its operand. The exception (C11 6.5.3.4p2) is an operand of **variable length array** type: then the size expression is evaluated at run time, with its side effects.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int m[3][4] = { {1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12} };
    int (*p)[4] = m + 1;      /* points at row 1 (type: pointer to int[4]) */
    int *q = m[2] + 1;        /* points at m[2][1] == 10 */
    int n = 2;

    /* 48 / 16 = 3 rows; *p is a whole row = 16 bytes; p + 0 is still a pointer = 8 */
    printf("%zu %zu %zu\n", sizeof m / sizeof m[0], sizeof *p, sizeof(p + 0));   /* 3 16 8 */

    /* **p = m[1][0] = 5;  -1[q] = -(q[1]) = -m[2][2] = -11;  (*p)[3] = m[1][3] = 8 */
    printf("%d %d %d\n", **p, -1[q], (*p)[3]);                                   /* 5 -11 8 */

    /* p[1] is row m[2]; *(m + 2) is row m[2], + 3 -> &m[2][3] */
    printf("%d %d\n", p[1][2], *(*(m + 2) + 3));                                 /* 11 12 */

    /* int[n++][4] is a VLA type: the size expression IS evaluated -> 2*4*4 = 32, n becomes 3.
     * n++ in sizeof(n++) has type int (not a VLA): NOT evaluated -> 4, n stays 3. */
    size_t s = sizeof(int[n++][4]);
    size_t t = sizeof(n++);
    printf("%zu %zu %d\n", s, t, n);                                             /* 32 4 3 */
    return 0;
}
@@@ explanation_md
**Answer:**
```
3 16 8
5 -11 8
11 12
32 4 3
```

**Line 1.** `sizeof m = 3*4*4 = 48` and `sizeof m[0] = 16`, so there are 3 rows. `p` is a pointer to a 4-int row, so `*p` is a whole row (16 bytes). `p + 0` is a pointer (8).

**Line 2.** `p = m + 1` points at row 1, so `**p = m[1][0] = 5` and `(*p)[3] = m[1][3] = 8`. `q` points at `m[2][1]`. Subscripting is a **postfix** operator, which binds tighter than unary minus, so `-1[q]` parses as `-(1[q]) = -(q[1]) = -m[2][2] = -11`. It is not `(-1)[q]`, which would be `q[-1] = m[2][0]`.

**Line 3.** `p[1]` is `*(p + 1)`, which is row `m[2]`, so `p[1][2] = 11`. `*(m + 2)` is also row `m[2]`; it decays to `&m[2][0]`, `+ 3` gives `&m[2][3]`, so the value is 12. Every access stays inside the row being indexed, so all of this is well defined.

**Line 4.** `sizeof` is usually a compile-time constant and its operand is **not evaluated**: `sizeof(n++)` is `sizeof(int) = 4`, and `n` does not change. The one exception is a **variable length array type** (C11 6.5.3.4p2): `int[n++][4]` has a run-time size, so `n++` *is* evaluated. The size uses the old value `2` (2 * 4 * 4 = 32), and `n` becomes 3.

**Complexity.** N/A. Only the VLA `sizeof` costs anything at run time (a multiply).

**Common mistakes**
- Treating `p + 1` like `int *` arithmetic (4 bytes) instead of a whole row (16 bytes).
- Reading `-1[q]` as `q[-1]`. Precedence: postfix `[]` before unary `-`.
- Assuming every `sizeof` is side-effect-free. With VLAs it is not, which is one reason MISRA C:2012 (Rule 18.8) bans VLAs, and Rule 13.6 forbids side effects in `sizeof` operands.
- Putting `n` and `sizeof(int[n++][4])` in the **same** `printf` call. The read of `n` and the side effect would be unsequenced, which is UB (C11 6.5p2). That is why the snippet uses separate statements.

**Interview follow-ups**
- Why are VLAs dangerous on a microcontroller even when they are used correctly? (Unbounded stack use, no failure reporting, and C11 made them optional, `__STDC_NO_VLA__`.)
- Declare a function parameter that receives `m` and allows `g[r][c]` indexing: `void f(int rows, int g[][4])` versus `void f(int rows, int cols, int g[rows][cols])`.
- What are the types of `m`, `m[0]`, `&m`, `&m[0]` and `*m`, and how many bytes does each advance on `+ 1` (after decay)? (`m`: 16, `m[0]`: 4, `&m`: 48, `&m[0]`: 16, `*m`: 4.)
