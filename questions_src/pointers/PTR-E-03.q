@@@ meta
id: PTR-E-03
topic: Pointers
difficulty: Easy
type: PREDICT_OUTPUT
title: const int * vs int * const vs int const *
tags: const-correctness, const-pointer, pointer-to-const, misra
@@@ statement_md
A calibration module uses pointers with different `const` placements. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>

int main(void)
{
    int speed = 50;
    int limit = 120;

    const int *p = &speed;        /* (A) */
    int *const q = &limit;        /* (B) */
    const int *const r = &speed;  /* (C) */

    p = q;            /* 1 */
    *q += 5;          /* 2 */
    speed = 70;       /* 3 */

    int const *s = q; /* 4 */
    *s = 130;         /* 5 */

    printf("%d %d %d %d\n", *p, *q, *r, *s);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc (also true for clang), C11.
- Read every declaration right-to-left: what is `const`, the pointer or the pointed-to `int`?
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int speed = 50;
    int limit = 120;

    const int *p = &speed;        /* (A) */
    int *const q = &limit;        /* (B) */
    const int *const r = &speed;  /* (C) */

    p = q;            /* 1 */
    *q += 5;          /* 2 */
    speed = 70;       /* 3 */

    int const *s = q; /* 4 */
    *s = 130;         /* 5 */

    printf("%d %d %d %d\n", *p, *q, *r, *s);
    return 0;
}
@@@ predict_answer
Compile Error
@@@ hint
Read declarations from right to left: `int *const q` is "q is a const pointer to int". `const int *p` is "p is a pointer to an int that is const (through p)".
@@@ hint
`int const *` and `const int *` are the **same type**. `const` before the `*` protects the pointed-to `int`. `const` after the `*` protects the pointer itself.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int speed = 50;
    int limit = 120;

    const int *p = &speed;        /* (A) pointer to const int: *p is read-only, p can move   */
    int *const q = &limit;        /* (B) const pointer to int: q cannot move, *q is writable */
    const int *const r = &speed;  /* (C) neither r nor *r may be modified                    */

    p = q;            /* 1 OK: p itself is not const; int* -> const int* is an implicit, safe conversion */
    *q += 5;          /* 2 OK: limit becomes 125; the pointee of q is not const                         */
    speed = 70;       /* 3 OK: speed itself was never declared const; only access THROUGH p/r is read-only */

    int const *s = q; /* 4 OK: `int const *` is exactly the same type as `const int *`              */
    *s = 130;         /* 5 ERROR: assignment of read-only location '*s'  (gcc)
                       *          read-only variable is not assignable   (clang)               */

    printf("%d %d %d %d\n", *p, *q, *r, *s);
    return 0;
}
@@@ explanation_md
**Answer: `Compile Error`.** Line 5 assigns through a pointer to `const int`.

Read each declaration from the identifier outwards (right to left):

| declaration | reads as | `ptr = ...` | `*ptr = ...` |
|---|---|---|---|
| `const int *p` | p is a pointer to const int | allowed | **error** |
| `int const *s` | s is a pointer to const int (same type!) | allowed | **error** |
| `int *const q` | q is a const pointer to int | **error** | allowed |
| `const int *const r` | r is a const pointer to const int | **error** | **error** |

Lines 1 to 4 are all legal:
1. `p = q` changes where `p` points, which is allowed. Converting `int *` to `const int *` *adds* a qualifier, so it is implicit and safe.
2. `*q += 5` modifies `limit` through a const *pointer*. The pointee is not const.
3. `speed = 70` is fine. `const int *` means "read-only *through this pointer*". It does not make the object itself constant.
4. `int const *s = q` has the same type as line (A).

Line 5 violates a constraint (C11 6.5.16p2: the left operand of an assignment must be a modifiable lvalue). Both gcc ("assignment of read-only location `*s`") and clang ("read-only variable is not assignable") reject it with a hard error. Without line 5, the program would print `125 125 70 125`.

**Complexity.** N/A. `const` is a compile-time check with zero runtime cost. On microcontrollers, a `const` *object* at file scope is usually placed in flash instead of RAM.

**Common mistakes**
- Reading `int const *` as "const pointer". The position of `const` relative to `*` is what matters, not relative to `int`.
- Thinking line 3 is an error. `const int *p = &speed` does not make `speed` const.
- Thinking line 1 needs a cast. Adding `const` is implicit. Removing it (`const int *` to `int *`) is what needs a cast, and writing through such a pointer to a genuinely const object is undefined behavior.

**Interview follow-ups**
- Why should a function that only reads a buffer take `const uint8_t *buf`? (Documents intent, lets callers pass flash-resident tables, MISRA C Rule 8.13.)
- Why does `char **` not convert implicitly to `const char **`, even though `char *` converts to `const char *`?
- What is the difference between `const volatile uint32_t *` and `volatile uint32_t *const`, and where would you use each for a read-only status register?
- Can you modify a `const int` object through a cast `*(int *)&x = 5;`? (Undefined behavior. The object may even live in flash.)
