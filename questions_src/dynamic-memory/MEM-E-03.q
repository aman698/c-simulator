@@@ meta
id: MEM-E-03
topic: Dynamic Memory
difficulty: Easy
type: PREDICT_OUTPUT
title: ARRAY_SIZE on a calloc'd Buffer
tags: sizeof, calloc, array-size-macro, pointer-vs-array, embedded
@@@ statement_md
A firmware engineer uses the classic `COUNT()` macro to loop over buffers. One buffer is a static array; the other comes from `calloc`. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdlib.h>

#define COUNT(a) (sizeof(a) / sizeof((a)[0]))

int main(void)
{
    int fixed[8] = {0};
    int *dyn = calloc(8, sizeof *dyn);
    if (dyn == NULL)
        return 1;

    dyn[2] = 5;
    int sum = 0;
    for (size_t i = 0; i < COUNT(fixed); i++)
        sum += dyn[i];

    printf("%zu %zu\n", COUNT(fixed), COUNT(dyn));
    printf("%zu %zu %zu\n", sizeof fixed, sizeof dyn, sizeof *dyn);
    printf("%d\n", sum);

    free(dyn);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, LP64 (`int` 4 bytes, pointers 8 bytes).
- The snippet compiles (gcc may warn about `sizeof` on a pointer).
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

#define COUNT(a) (sizeof(a) / sizeof((a)[0]))

int main(void)
{
    int fixed[8] = {0};
    int *dyn = calloc(8, sizeof *dyn);
    if (dyn == NULL)
        return 1;

    dyn[2] = 5;
    int sum = 0;
    for (size_t i = 0; i < COUNT(fixed); i++)
        sum += dyn[i];

    printf("%zu %zu\n", COUNT(fixed), COUNT(dyn));
    printf("%zu %zu %zu\n", sizeof fixed, sizeof dyn, sizeof *dyn);
    printf("%d\n", sum);

    free(dyn);
    return 0;
}
@@@ predict_answer
8 2
32 8 4
5
@@@ hint
`sizeof` is evaluated at compile time from the **type** of its operand. What is the type of `dyn`? Does that type remember how many bytes `calloc` returned?
@@@ hint
`dyn` is an `int *`, so `sizeof dyn` is the pointer size (8) and `COUNT(dyn)` is `8 / 4 = 2`. `calloc` zero-fills the block, so the only non-zero element is `dyn[2] = 5`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

#define COUNT(a) (sizeof(a) / sizeof((a)[0]))

int main(void)
{
    int fixed[8] = {0};                     /* type int[8]: sizeof = 32         */
    int *dyn = calloc(8, sizeof *dyn);      /* type int *: sizeof = 8 (pointer)  */
    if (dyn == NULL)                        /* calloc zero-fills all 32 bytes    */
        return 1;

    dyn[2] = 5;
    int sum = 0;
    for (size_t i = 0; i < COUNT(fixed); i++)   /* COUNT(fixed) = 32 / 4 = 8 */
        sum += dyn[i];                          /* 0+0+5+0+0+0+0+0 = 5       */

    printf("%zu %zu\n", COUNT(fixed), COUNT(dyn));                /* 8 2      */
    printf("%zu %zu %zu\n", sizeof fixed, sizeof dyn, sizeof *dyn); /* 32 8 4 */
    printf("%d\n", sum);                                          /* 5        */

    free(dyn);
    return 0;
}
@@@ explanation_md
**Answer**
```
8 2
32 8 4
5
```

- `fixed` has type `int[8]`, so `sizeof fixed` is 32 and `COUNT(fixed)` is 8.
- `dyn` has type `int *`. `sizeof dyn` is the **size of the pointer** (8 on LP64), not the size of the block it points to. `COUNT(dyn)` is `8 / sizeof(int)` = **2**. The macro compiles but gives a wrong answer.
- `calloc` zero-initializes the block, so only `dyn[2]` is non-zero and the sum is 5. With `malloc` the other seven elements would be indeterminate, and the sum would be garbage.

The size of a heap block is **not** recorded anywhere you can query in standard C. The allocator knows it, but the language gives you no access. Every API that takes a heap buffer therefore also needs its length (`buf, len`).

**Complexity.** `sizeof` costs nothing at run time; it is a compile-time constant. `calloc` costs O(n) to zero the block.

**Common mistakes**
- Using `sizeof(ptr)` or `COUNT(ptr)` as the element count of a heap or parameter buffer. Array parameters decay too: inside `void f(int a[8])`, `sizeof a` is 8.
- Assuming `malloc` returns zeroed memory. Only `calloc` (or an explicit `memset`) does.
- Thinking `calloc(8, 4)` and `malloc(32)` are always the same. `calloc` also checks the `count * size` multiplication for overflow.

**Interview follow-ups**
- Make `COUNT(p)` fail to compile when `p` is a pointer. (GCC trick: `_Static_assert(!__builtin_types_compatible_p(__typeof__(a), __typeof__(&(a)[0])), ...)`.)
- Why can `calloc` be faster than `malloc` + `memset` for large blocks? (Fresh pages from the OS are already zero.)
- How do non-standard calls like glibc's `malloc_usable_size` or MSVC's `_msize` work, and why should portable code not use them?
