@@@ meta
id: PTR-M-06
topic: Pointers
difficulty: Medium
type: PREDICT_OUTPUT
title: The &a + 1 Trick, Pointer Difference Units and a char View of int
tags: pointer-arithmetic, pointer-difference, sizeof, endianness, address-of-array
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `char` is signed.**

```c
#include <stdio.h>

int main(void)
{
    int a[5] = {300, 0x2233, 9, 7, 8};
    int *end = (int *)(&a + 1);
    char *c = (char *)a;

    printf("%zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a);
    printf("%d %td %td\n", *(end - 1), end - a, (char *)end - c);
    printf("%d %d %d %d\n", c[0], c[1], c[4], c[5]);
    printf("%td %d\n", &a[4] - &a[1], *(int *)(c + 8));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11, little-endian.
- `%td` prints a `ptrdiff_t`.
- `300` is `0x0000012C`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int a[5] = {300, 0x2233, 9, 7, 8};
    int *end = (int *)(&a + 1);
    char *c = (char *)a;

    printf("%zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a);
    printf("%d %td %td\n", *(end - 1), end - a, (char *)end - c);
    printf("%d %d %d %d\n", c[0], c[1], c[4], c[5]);
    printf("%td %d\n", &a[4] - &a[1], *(int *)(c + 8));
    return 0;
}
@@@ predict_answer
20 8 20
8 5 20
44 1 51 34
3 9
@@@ hint
`a` decays to `&a[0]` (type `int *`), but `&a` has type `int (*)[5]`, a pointer to the **whole array**. So `&a + 1` jumps `sizeof a` = 20 bytes, to just past the last element.
@@@ hint
Pointer differences count **elements of the pointed-to type**: `int *` differences are in ints, `char *` differences are in bytes. On a little-endian machine, `c[4]` is the **least** significant byte of `a[1]`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int a[5] = {300, 0x2233, 9, 7, 8};
    int *end = (int *)(&a + 1);   /* &a: int (*)[5]; +1 skips 20 bytes -> one past a[4] */
    char *c = (char *)a;          /* byte view of the array (char may alias anything)   */

    /* sizeof a = 20 (5 ints), sizeof &a = 8 (a pointer), sizeof *&a = 20 (the array again) */
    printf("%zu %zu %zu\n", sizeof a, sizeof &a, sizeof *&a);

    /* *(end - 1) = a[4] = 8;  end - a = 5 ints;  (char *)end - c = 20 bytes */
    printf("%d %td %td\n", *(end - 1), end - a, (char *)end - c);

    /* little-endian bytes: a[0] = 0x0000012C -> 2C 01 00 00, a[1] = 0x00002233 -> 33 22 00 00
     * c[0] = 0x2C = 44, c[1] = 0x01 = 1, c[4] = 0x33 = 51, c[5] = 0x22 = 34 */
    printf("%d %d %d %d\n", c[0], c[1], c[4], c[5]);

    /* &a[4] - &a[1] = 3 (elements); c + 8 is the address of a[2] -> 9 */
    printf("%td %d\n", &a[4] - &a[1], *(int *)(c + 8));
    return 0;
}
@@@ explanation_md
**Answer**
```
20 8 20
8 5 20
44 1 51 34
3 9
```

**Why `&a + 1` works.** `a` and `&a` have the same *address* but different *types*:

| expression | type | `+ 1` moves |
|---|---|---|
| `a` (decays) | `int *` | 4 bytes |
| `&a` | `int (*)[5]` | 20 bytes |

`(int *)(&a + 1)` is therefore the classic way to get a one-past-the-end pointer without knowing the length. It is legal to *form* and compare this pointer, and to compute `end - 1`, but not to dereference `end` itself. (Writing `*(&a + 1)` instead of the cast is technically a dereference of a one-past-the-end pointer, which the standard forbids.)

**Units.** `end - a` is 5 because `int *` differences count ints. The same two addresses as `char *` differ by 20 bytes.

**Byte view.** On little-endian x86, `300 = 0x0000012C` is stored as `2C 01 00 00`, and `0x2233` as `33 22 00 00`. All four printed bytes are below 0x80, so the sign of `char` does not matter here. `c + 8` is the address of `a[2]`, and reading it back as `int` is fine: it really is an `int` object, correctly aligned.

**Complexity.** N/A. Every expression here is a constant-time address computation, and the sizes are compile-time constants.

**Common mistakes**
- Thinking `&a + 1` is `&a[1]`. It skips the **whole** array.
- Expecting `end - a` to be 20, or `(char *)end - c` to be 5. The difference is scaled by the pointed-to type.
- Reading bytes in big-endian order and answering `0 0 0 0` (the high bytes) on line 3.
- Using `sizeof a` inside a function that received `a` as a parameter. There it is only `sizeof(int *)` = 8.

**Interview follow-ups**
- Why is `*(int *)(c + 1)` undefined even though it "works on x86"? (Misaligned access, and it reads parts of two different ints.)
- With `char` holding `0xFF`, what do `printf("%d", c[k])` and `printf("%d", (unsigned char)c[k])` print?
- Implement `ARRAY_LEN(a)` using `(&a)[1] - a`. Why is the `sizeof(a)/sizeof(a[0])` version still preferred?
- What is the type of `&a[0]` versus `&a`, and which one would you pass to `memset`?
