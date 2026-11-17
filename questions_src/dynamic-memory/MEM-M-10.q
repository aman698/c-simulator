@@@ meta
id: MEM-M-10
topic: Dynamic Memory
difficulty: Medium
type: PREDICT_OUTPUT
title: sizeof *p on a NULL Pointer and Other malloc Idioms
tags: sizeof, unevaluated-operand, malloc-idiom, vla, pointer-to-pointer
@@@ statement_md
Code reviews often recommend the idiom `p = malloc(n * sizeof *p)`. A colleague objects: "`*p` dereferences `p` before it points anywhere, and that will crash!" What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `float` = 4 bytes, `double` = 8 bytes**.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct sample {
    double  t;
    uint8_t ch;
};

int main(void)
{
    struct sample *s = NULL;
    int i = 0, n = 2;

    size_t a = sizeof *s;            /* s is NULL here */
    size_t b = sizeof(i++);
    size_t c = sizeof(int[n++]);

    float **grid = malloc(3 * sizeof *grid);
    if (grid == NULL)
        return 1;
    s = malloc(sizeof *s);
    if (s == NULL) {
        free(grid);
        return 1;
    }
    s->ch = 7;

    printf("%zu %zu %d\n", a, b, i);
    printf("%zu %d\n", c, n);
    printf("%zu %zu %zu\n", sizeof grid, sizeof *grid, sizeof **grid);
    printf("%d\n", s->ch);

    free(s);
    free(grid);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11, System V ABI (`double` is 8-byte aligned).
- Both `malloc` calls succeed.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct sample {
    double  t;
    uint8_t ch;
};

int main(void)
{
    struct sample *s = NULL;
    int i = 0, n = 2;

    size_t a = sizeof *s;            /* s is NULL here */
    size_t b = sizeof(i++);
    size_t c = sizeof(int[n++]);

    float **grid = malloc(3 * sizeof *grid);
    if (grid == NULL)
        return 1;
    s = malloc(sizeof *s);
    if (s == NULL) {
        free(grid);
        return 1;
    }
    s->ch = 7;

    printf("%zu %zu %d\n", a, b, i);
    printf("%zu %d\n", c, n);
    printf("%zu %zu %zu\n", sizeof grid, sizeof *grid, sizeof **grid);
    printf("%d\n", s->ch);

    free(s);
    free(grid);
    return 0;
}
@@@ predict_answer
16 4 0
8 3
8 8 4
7
@@@ hint
`sizeof expr` needs only the **type** of `expr`. For ordinary types the expression is not evaluated at all (C11 6.5.3.4p2), so nothing is dereferenced and nothing is incremented. There is one exception in that same paragraph: variable length array types.
@@@ hint
`struct sample` is 8 (double) + 1 + 7 padding = 16. `int[n++]` is a VLA type, so its size expression **is** evaluated at run time: the size is 2 * 4 = 8, and `n` becomes 3. `grid` is `float **` (8 bytes), `*grid` is `float *` (8), `**grid` is `float` (4).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct sample {
    double  t;    /* offset 0, 8 bytes                        */
    uint8_t ch;   /* offset 8, 1 byte + 7 tail padding -> 16  */
};

int main(void)
{
    struct sample *s = NULL;
    int i = 0, n = 2;

    size_t a = sizeof *s;            /* NOT evaluated: only the type matters -> 16   */
    size_t b = sizeof(i++);          /* NOT evaluated: i stays 0, sizeof(int) = 4    */
    size_t c = sizeof(int[n++]);     /* VLA type: size expression IS evaluated:
                                        2 * 4 = 8, and n becomes 3                   */

    float **grid = malloc(3 * sizeof *grid);   /* 3 * sizeof(float *) = 24 bytes     */
    if (grid == NULL)
        return 1;
    s = malloc(sizeof *s);                     /* 16 bytes, right type automatically */
    if (s == NULL) {
        free(grid);
        return 1;
    }
    s->ch = 7;

    printf("%zu %zu %d\n", a, b, i);                                   /* 16 4 0 */
    printf("%zu %d\n", c, n);                                          /* 8 3    */
    printf("%zu %zu %zu\n", sizeof grid, sizeof *grid, sizeof **grid); /* 8 8 4  */
    printf("%d\n", s->ch);                                             /* 7      */

    free(s);
    free(grid);
    return 0;
}
@@@ explanation_md
**Answer**
```
16 4 0
8 3
8 8 4
7
```

- **`sizeof *s` with `s == NULL` is fine.** `sizeof` only needs the operand's type (`struct sample`). The operand is not evaluated, so there is no dereference. That is why `p = malloc(n * sizeof *p)` is safe and is the preferred idiom: change the type of `p`, and the allocation size follows automatically.
- **`sizeof(i++)`** gives `sizeof(int)` = 4 and **does not increment** `i`. Side effects inside `sizeof` are a classic code-review trap.
- **VLA exception.** For a variable length array type, the operand **is** evaluated (C11 6.5.3.4p2). `int[n++]` has `n == 2` elements, so the size is 8, and the side effect runs: `n` becomes 3.
- **Levels of indirection.** `grid` is `float **` (8), `*grid` is `float *` (8), `**grid` is `float` (4). `malloc(3 * sizeof *grid)` correctly allocates 3 **pointers**. Writing `3 * sizeof **grid` (3 floats, 12 bytes) would be a heap overflow as soon as `grid[2]` is written on a 64-bit target.
- `struct sample` = 8 (`double`) + 1 (`uint8_t`) + 7 tail padding = 16.

**Complexity.** All `sizeof` results except the VLA one are compile-time constants (zero run-time cost).

**Common mistakes**
- Believing `sizeof *p` crashes when `p` is `NULL` or uninitialized.
- Writing `malloc(sizeof(struct sample *))`: the size of the **pointer** (8), not the struct (16). That is a heap overflow when the second half of the struct is written.
- Expecting `sizeof(i++)` to increment `i`.
- Mixing up `sizeof *grid` and `sizeof **grid` for pointer-to-pointer allocations.

**Interview follow-ups**
- Why do many style guides prefer `sizeof *p` over `sizeof(type)` in `malloc` calls? Give a refactoring that silently breaks the `sizeof(type)` form.
- `sizeof` is an operator, not a function. When are the parentheses required? (With a type name: `sizeof(int)`; not with an expression: `sizeof x`.)
- MISRA C:2012 Rule 13.6 says the operand of `sizeof` shall not contain side effects. Which line here violates it?
