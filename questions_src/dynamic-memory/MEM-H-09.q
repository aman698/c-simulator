@@@ meta
id: MEM-H-09
topic: Dynamic Memory
difficulty: Hard
type: PREDICT_OUTPUT
title: SAFE_FREE Inside a Helper Function
tags: double-free, macro, pass-by-value, dangling-pointer, undefined-behavior
@@@ statement_md
A coding guideline says: "Always free through `SAFE_FREE`, which nulls the pointer, so a second free is harmless." A developer wraps it in a small helper. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SAFE_FREE(p) do { free(p); (p) = NULL; } while (0)

static void release(char *buf)
{
    SAFE_FREE(buf);                 /* "now nobody can double-free it" */
}

int main(void)
{
    char *frame = malloc(8);
    if (frame == NULL)
        return 1;
    strcpy(frame, "CAN");

    release(frame);
    printf("released\n");

    SAFE_FREE(frame);               /* cleanup at the end of main */
    printf("done\n");
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc (glibc), compiled with the judge flags.
- `malloc(8)` succeeds.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SAFE_FREE(p) do { free(p); (p) = NULL; } while (0)

static void release(char *buf)
{
    SAFE_FREE(buf);                 /* "now nobody can double-free it" */
}

int main(void)
{
    char *frame = malloc(8);
    if (frame == NULL)
        return 1;
    strcpy(frame, "CAN");

    release(frame);
    printf("released\n");

    SAFE_FREE(frame);               /* cleanup at the end of main */
    printf("done\n");
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
`release` receives a **copy** of the pointer value. Which variable does `(p) = NULL` inside the macro set to `NULL`: `buf` or `frame`?
@@@ hint
`frame` still holds the address of the block that `release` already freed. `SAFE_FREE(frame)` therefore calls `free` on an already freed block, which is a **double free** and undefined behavior (C11 7.22.3.3p2). Even reading `frame`'s now-indeterminate value is undefined in strict C11 (6.2.4p2).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SAFE_FREE(p) do { free(p); (p) = NULL; } while (0)

static void release(char *buf)      /* buf is a COPY of the caller's pointer      */
{
    SAFE_FREE(buf);                 /* frees the block, then nulls only the copy  */
}

int main(void)
{
    char *frame = malloc(8);
    if (frame == NULL)
        return 1;
    strcpy(frame, "CAN");

    release(frame);                 /* block freed; frame still holds its address */
    printf("released\n");

    SAFE_FREE(frame);               /* free() on an already freed block:
                                       DOUBLE FREE -> undefined behavior          */
    printf("done\n");
    return 0;
}

/* Fix: let the helper null the CALLER's pointer.
 *   static void release(char **buf) { SAFE_FREE(*buf); }
 *   release(&frame);                 // frame == NULL afterwards
 */
@@@ explanation_md
**Answer: Undefined Behavior.**

C passes arguments **by value**. `release(frame)` copies the address into the parameter `buf`. The macro frees the block and sets **`buf`** to `NULL`, then `buf` goes out of scope. The caller's `frame` still holds the old address, which is now a dangling pointer. `SAFE_FREE(frame)` passes that address to `free` a second time: a **double free**, undefined behavior per C11 7.22.3.3p2 ("if the argument ... has been deallocated by a call to free or realloc, the behavior is undefined").

What actually happens:
- **glibc without sanitizers:** often `free(): double free detected in tcache 2` and `SIGABRT`, sometimes (with other allocation patterns) silent heap corruption that crashes much later.
- **AddressSanitizer:** `attempting double-free` at the second `free`, so the output stops after `released`.
- **An RTOS heap:** the block is linked into the free list twice, and two later `malloc` calls return the **same** memory to two different tasks. That is the worst case, because nothing crashes immediately.

`released` may or may not appear before the crash, depending on stdout buffering. With undefined behavior, no output is guaranteed.

**The fix.** A helper that must clear the caller's pointer needs the pointer's **address**: `void release(char **buf) { SAFE_FREE(*buf); }`, called as `release(&frame);`. Alternatively the helper only frees and the caller writes `frame = NULL;`. Keep in mind that `SAFE_FREE` only protects the one variable it names. Any other copy of the pointer (a struct field, a second alias) still dangles.

**Complexity.** O(1); the question is about ownership and lifetime, not cost.

**Common mistakes**
- Believing a `NULL`-ing macro makes double frees impossible. It only helps for the exact lvalue passed to it.
- Expecting `released\ndone`: that would require `frame` to be `NULL`, which it is not.
- Making the macro a function `void safe_free(void *p) { free(p); p = NULL; }`: the same bug, now hidden behind a reassuring name.

**Interview follow-ups**
- Write a `SAFE_FREE`-style **function** that really clears the caller's pointer. Why does `void safe_free(void **pp)` need a cast at most call sites (`char **` does not convert to `void **`)?
- How does the do { ... } while (0) wrapper make the macro safe inside `if`/`else` without braces?
- Which tools catch this in CI (ASan, Valgrind, glibc `MALLOC_CHECK_`, static analyzers' "double free" checks)?
