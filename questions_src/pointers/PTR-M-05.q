@@@ meta
id: PTR-M-05
topic: Pointers
difficulty: Medium
type: PREDICT_OUTPUT
title: Array of Pointers vs Pointer to Array
tags: pointer-to-array, array-of-pointers, sizeof, 2d-array, operator-precedence
@@@ statement_md
`int *ap[3]` and `int (*pa)[4]` differ only by a pair of parentheses, but they are completely different types. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int m[3][4] = {
        {3, 1, 4, 1},
        {5, 9, 2, 6},
        {7, 8, 0, 4},
    };
    int (*pa)[4] = m;                  /* pointer to array of 4 int */
    int *ap[3] = {m[2], m[0], m[1]};   /* array of 3 pointers to int */

    printf("%zu %zu %zu %zu %zu\n", sizeof pa, sizeof *pa, sizeof ap, sizeof *ap, sizeof m);
    printf("%d %d\n", *pa[1], (*pa)[1]);
    printf("%d %d %d\n", pa[2][1], ap[2][1], *(*(ap + 1) + 2));
    printf("%td %td\n", (char *)(pa + 1) - (char *)pa, (char *)(ap + 1) - (char *)ap);
    pa++;
    printf("%d %td\n", (*pa)[3], pa - m);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11. `%zu` prints `size_t`, `%td` prints `ptrdiff_t`.
- `[]` binds tighter than unary `*`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int m[3][4] = {
        {3, 1, 4, 1},
        {5, 9, 2, 6},
        {7, 8, 0, 4},
    };
    int (*pa)[4] = m;                  /* pointer to array of 4 int */
    int *ap[3] = {m[2], m[0], m[1]};   /* array of 3 pointers to int */

    printf("%zu %zu %zu %zu %zu\n", sizeof pa, sizeof *pa, sizeof ap, sizeof *ap, sizeof m);
    printf("%d %d\n", *pa[1], (*pa)[1]);
    printf("%d %d %d\n", pa[2][1], ap[2][1], *(*(ap + 1) + 2));
    printf("%td %td\n", (char *)(pa + 1) - (char *)pa, (char *)(ap + 1) - (char *)ap);
    pa++;
    printf("%d %td\n", (*pa)[3], pa - m);
    return 0;
}
@@@ predict_answer
8 16 24 8 48
5 1
8 9 4
16 8
6 1
@@@ hint
Use the "clockwise/spiral" reading: `int (*pa)[4]` means "pa is a **pointer** to an array of 4 int", so `pa + 1` skips a whole row (16 bytes). `int *ap[3]` means "ap is an **array** of 3 pointers to int", so `sizeof ap` is 3 pointers.
@@@ hint
`*pa[1]` parses as `*(pa[1])` (row 1, element 0) because `[]` binds tighter than `*`. `(*pa)[1]` is row 0, element 1. Remember that `ap` was initialised in the order `m[2], m[0], m[1]`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int m[3][4] = {
        {3, 1, 4, 1},
        {5, 9, 2, 6},
        {7, 8, 0, 4},
    };
    int (*pa)[4] = m;                  /* m decays to &m[0], type int (*)[4]              */
    int *ap[3] = {m[2], m[0], m[1]};   /* each m[i] decays to &m[i][0], type int *          */

    /* sizeof pa = 8 (one pointer), sizeof *pa = 16 (int[4]),
     * sizeof ap = 24 (3 pointers), sizeof *ap = 8 (int *), sizeof m = 48 (12 ints) */
    printf("%zu %zu %zu %zu %zu\n", sizeof pa, sizeof *pa, sizeof ap, sizeof *ap, sizeof m);

    /* *pa[1] = *(pa[1]) = m[1][0] = 5      (*pa)[1] = m[0][1] = 1 */
    printf("%d %d\n", *pa[1], (*pa)[1]);

    /* pa[2][1] = m[2][1] = 8
     * ap[2][1]: ap[2] == m[1]  -> m[1][1] = 9
     * *(*(ap + 1) + 2) = ap[1][2]: ap[1] == m[0] -> m[0][2] = 4 */
    printf("%d %d %d\n", pa[2][1], ap[2][1], *(*(ap + 1) + 2));

    /* pa + 1 moves by sizeof(int[4]) = 16 bytes; ap + 1 moves by sizeof(int *) = 8 bytes */
    printf("%td %td\n", (char *)(pa + 1) - (char *)pa, (char *)(ap + 1) - (char *)ap);

    pa++;                                /* pa -> m[1] */
    printf("%d %td\n", (*pa)[3], pa - m);   /* m[1][3] = 6, difference counted in ROWS: 1 */
    return 0;
}
@@@ explanation_md
**Answer**
```
8 16 24 8 48
5 1
8 9 4
16 8
6 1
```

| | `int (*pa)[4]` | `int *ap[3]` |
|---|---|---|
| what it is | **one pointer** to a row of 4 ints | **an array** of 3 pointers |
| `sizeof` | 8 | 24 |
| `sizeof *x` | 16 (`int[4]`) | 8 (`int *`) |
| `x + 1` advances | 16 bytes (one row) | 8 bytes (one pointer) |
| typical use | walking a real 2-D array `int m[R][4]` | jagged tables, `argv`, string tables |

Line by line:
1. `pa` is a pointer (8), `*pa` is a whole row (16), `ap` is three pointers (24), `*ap` is one pointer (8), and `m` is 12 ints (48).
2. Precedence: `*pa[1]` = `*(pa[1])` = first element of row 1 = **5**. `(*pa)[1]` = row 0, index 1 = **1**.
3. `pa[2][1]` = `m[2][1]` = 8. `ap[2]` points to row 1, so `ap[2][1]` = 9. `*(*(ap+1)+2)` is `ap[1][2]`, and `ap[1]` points to row 0, so it is 4.
4. Byte distances: pointer arithmetic is scaled by the size of the **pointed-to type**: 16 for `int[4]`, 8 for `int *`.
5. After `pa++`, `pa` points to row 1: `(*pa)[3]` = 6. `pa - m` counts rows, so it is **1**.

**Complexity.** N/A. All of these are compile-time sizes and constant-time address computations.

**Common mistakes**
- Treating `int (*pa)[4]` and `int *pa[4]` as the same type. The parentheses make the pointer part bind first.
- Forgetting that `[]` binds tighter than `*`, which swaps the two answers on line 2.
- Assuming `sizeof *ap` is the size of a row. `ap[i]` is just a pointer, and the compiler does not know how long the row behind it is.
- Thinking `int **` can point to `int m[3][4]`. A 2-D array is **not** an array of pointers; `int **pp = m;` is a constraint violation.

**Interview follow-ups**
- Declare a function that takes `m` without losing the row length. (`void f(int (*rows)[4], size_t nrows)`, or `int rows[][4]`.)
- What are `sizeof &m` and `sizeof *&m`, and what is `(char *)(&m + 1) - (char *)m`?
- When is an array of row pointers (`int *rows[R]`) better than a true 2-D array in embedded code? (Jagged rows, rows in different memory sections, row swapping without copying.)
- Read this declaration aloud: `int (*(*fp)(void))[4];`
