@@@ meta
id: ARR-M-07
topic: Arrays
difficulty: Medium
type: PREDICT_OUTPUT
title: a vs &a vs &a[0] Pointer Arithmetic
tags: pointer-to-array, array-decay, pointer-arithmetic, sizeof, asked-in-automotive
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

int main(void)
{
    int a[5] = {10, 20, 30, 40, 50};
    int *p = (int *)(&a + 1);
    int (*pa)[5] = &a;

    printf("%zu %zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a, sizeof(a + 0));
    printf("%td %td\n", (char *)(a + 1) - (char *)a, (char *)(&a + 1) - (char *)&a);
    printf("%d %d\n", *(a + 1), *(p - 1));
    printf("%d %d\n", (*pa)[2], *(*pa + 3));
    printf("%d\n", a == &a[0] && (void *)a == (void *)&a);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, `sizeof(int)` = 4, `sizeof(void *)` = 8.
- `%td` prints a `ptrdiff_t`, `%zu` a `size_t`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int a[5] = {10, 20, 30, 40, 50};
    int *p = (int *)(&a + 1);
    int (*pa)[5] = &a;

    printf("%zu %zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a, sizeof(a + 0));
    printf("%td %td\n", (char *)(a + 1) - (char *)a, (char *)(&a + 1) - (char *)&a);
    printf("%d %d\n", *(a + 1), *(p - 1));
    printf("%d %d\n", (*pa)[2], *(*pa + 3));
    printf("%d\n", a == &a[0] && (void *)a == (void *)&a);
    return 0;
}
@@@ predict_answer
20 8 20 8
4 20
20 50
30 40
1
@@@ hint
`a` (after decay) and `&a` hold the **same address** but have **different types**: `int *` versus `int (*)[5]`. Pointer arithmetic steps by the size of the pointed-to type.
@@@ hint
`&a + 1` jumps over the whole 20-byte array to the address just past `a[4]`. Converted to `int *` and stepped back by one `int`, it points at `a[4]`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int a[5] = {10, 20, 30, 40, 50};
    int *p = (int *)(&a + 1);   /* &a: int (*)[5]; +1 skips 20 bytes -> one past a[4] */
    int (*pa)[5] = &a;          /* pointer to the whole array */

    /* sizeof a = 5*4 = 20 (no decay under sizeof); sizeof &a = 8 (a pointer);
     * sizeof *&a = 20 (*&a is the array again); sizeof(a + 0) = 8 (a decays, then +0 -> int *) */
    printf("%zu %zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a, sizeof(a + 0));   /* 20 8 20 8 */

    /* a + 1 advances sizeof(int) = 4 bytes; &a + 1 advances sizeof(int[5]) = 20 bytes */
    printf("%td %td\n", (char *)(a + 1) - (char *)a, (char *)(&a + 1) - (char *)&a); /* 4 20 */

    /* *(a+1) = a[1]; p-1 = last element */
    printf("%d %d\n", *(a + 1), *(p - 1));                                           /* 20 50 */

    /* *pa is the array a, so (*pa)[2] = a[2] and *pa + 3 = &a[3] */
    printf("%d %d\n", (*pa)[2], *(*pa + 3));                                         /* 30 40 */

    /* same address, different types: both comparisons are true */
    printf("%d\n", a == &a[0] && (void *)a == (void *)&a);                           /* 1 */
    return 0;
}
@@@ explanation_md
**Answer:**
```
20 8 20 8
4 20
20 50
30 40
1
```

**Three expressions, one address, two types.**

| expression | type | `+ 1` advances by |
|---|---|---|
| `a` (decayed) | `int *` | 4 bytes |
| `&a[0]` | `int *` | 4 bytes |
| `&a` | `int (*)[5]` | 20 bytes |

- `sizeof` does **not** trigger decay, so `sizeof a == 20`. `sizeof &a` is the size of a pointer. `*&a` is the array itself (20). `a + 0` is an arithmetic expression, so `a` decays first and the result is an `int *` (8).
- `&a + 1` points just past the end of the whole array. That is a valid "one-past-the-end" pointer that may be compared and stepped back, but not dereferenced. Cast to `int *` and decremented once, it points at `a[4] == 50`. This is the well-known `*((int *)(&a + 1) - 1)` idiom for "last element".
- `pa` is a **pointer to an array of 5 ints**. `*pa` is that array, which decays to `&a[0]` in `*pa + 3`.
- `a == &a[0]` is true by the decay rule, and `&a` has the same address value, so the comparison through `void *` is also true.

**Complexity.** N/A. All of these are compile-time type rules; the generated code is the same address arithmetic.

**Common mistakes**
- Assuming `&a + 1 == a + 1`. The values differ by 16 bytes because the pointee types differ.
- Thinking `sizeof(a + 0)` is 20. Once `a` takes part in arithmetic it has already decayed to a pointer.
- Dereferencing `&a + 1` directly. It is one past the end, so `*(&a + 1)` would be undefined behavior; only `p - 1` brings it back inside.

**Interview follow-ups**
- Where do you meet `int (*)[N]` in real code? (Passing 2D arrays: `void f(int (*m)[COLS], int rows)`, or keeping the array size through a function boundary.)
- What is the type of `&a[0] + 1` compared with `&a + 1`, and how many bytes apart are they for `uint8_t buf[64]`? (1 versus 64.)
- Is `(char *)(&a + 1) - (char *)a` the same as `sizeof a`? Why is it still preferable to use `sizeof`?
