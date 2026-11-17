@@@ meta
id: PTR-H-05
topic: Pointers
difficulty: Hard
type: PREDICT_OUTPUT
title: NULL, Wild or Dangling? A Guarded Pointer to a Freed CAN Frame
tags: dangling-pointer, use-after-free, null-pointer, undefined-behavior, can
@@@ statement_md
A CAN receive handler keeps only the newest frame on the heap and frees the previous one. The application took a copy of the pointer earlier and "safely" checks it before use. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes.**

```c
#include <stdio.h>
#include <stdlib.h>

struct frame {
    int id;
    int dlc;
};

static struct frame *last_rx;     /* static storage: starts as NULL */

static void on_rx(int id, int dlc)
{
    struct frame *f = malloc(sizeof *f);
    if (f == NULL)
        return;
    f->id = id;
    f->dlc = dlc;
    free(last_rx);                /* free(NULL) is a no-op */
    last_rx = f;
}

int main(void)
{
    if (last_rx)
        printf("%d\n", last_rx->id);
    else
        printf("none\n");

    on_rx(0x101, 8);
    struct frame *seen = last_rx;
    on_rx(0x202, 4);

    if (seen != NULL)
        printf("%X %d\n", (unsigned)seen->id, seen->dlc);

    free(last_rx);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- Consider every pointer's value **and** whether the object it points to is still alive.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

struct frame {
    int id;
    int dlc;
};

static struct frame *last_rx;     /* static storage: starts as NULL */

static void on_rx(int id, int dlc)
{
    struct frame *f = malloc(sizeof *f);
    if (f == NULL)
        return;
    f->id = id;
    f->dlc = dlc;
    free(last_rx);                /* free(NULL) is a no-op */
    last_rx = f;
}

int main(void)
{
    if (last_rx)
        printf("%d\n", last_rx->id);
    else
        printf("none\n");

    on_rx(0x101, 8);
    struct frame *seen = last_rx;
    on_rx(0x202, 4);

    if (seen != NULL)
        printf("%X %d\n", (unsigned)seen->id, seen->dlc);

    free(last_rx);
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
The first part is fine: `last_rx` has static storage, so it is guaranteed to start as `NULL`, and `free(NULL)` does nothing. Now follow the object that `seen` points to through the second call of `on_rx`.
@@@ hint
`free(last_rx)` releases the frame `0x101`, but only `last_rx` gets a new value. `seen` still holds the old address: it is not `NULL`, so the check passes, yet the object is dead. Reading `seen->id` is a use-after-free.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

struct frame {
    int id;
    int dlc;
};

static struct frame *last_rx;     /* NULL pointer: well defined, and can be tested */

static void on_rx(int id, int dlc)
{
    struct frame *f = malloc(sizeof *f);
    if (f == NULL)
        return;
    f->id = id;
    f->dlc = dlc;
    free(last_rx);                /* 1st call: free(NULL) -> no-op
                                     2nd call: frees frame 0x101, which `seen` still points to */
    last_rx = f;
}

int main(void)
{
    if (last_rx)                  /* NULL -> prints "none" (defined so far) */
        printf("%d\n", last_rx->id);
    else
        printf("none\n");

    on_rx(0x101, 8);
    struct frame *seen = last_rx; /* alias of frame 0x101 */
    on_rx(0x202, 4);              /* frame 0x101 freed -> seen is now DANGLING */

    if (seen != NULL)             /* passes: free() does not change other copies of the pointer */
        printf("%X %d\n", (unsigned)seen->id, seen->dlc);   /* UNDEFINED: use after free */

    free(last_rx);
    return 0;
}
@@@ explanation_md
**Answer: `Undefined Behavior`.** `seen->id` reads an object whose lifetime has ended.

After the second `on_rx`, the frame that `seen` points to has been released by `free`. C11 7.22.3.3 deallocates the object, and 6.2.4p2 says that "the value of a pointer becomes indeterminate when the object it points to reaches the end of its lifetime". Dereferencing it is undefined. The program might print `101 8`, print garbage (the allocator reuses the block for its free-list metadata), or crash. AddressSanitizer reports *heap-use-after-free*. Since the behavior of the whole program is undefined, "none" followed by something is **not** a guaranteed output.

The three kinds of "bad" pointer:

| kind | how you get one | can `if (p)` detect it? |
|---|---|---|
| **NULL** | explicit `NULL`, static/global zero-initialisation, a failed `malloc` | **yes**, and it is the only one |
| **wild** | an uninitialised automatic pointer (`int *p;`) | no: an indeterminate value, and even reading it is a bug |
| **dangling** | after `free`, after `realloc` moved the block, a pointer to a local after its function returns or its block ends | no: the address still looks valid |

A `NULL` check only protects against `NULL`. `free(last_rx)` cannot reset **other copies** of the pointer (`seen`), because `free` receives the address by value.

**Complexity.** N/A (O(1) operations). The real cost is debugging time: a use-after-free often "works" until the allocator reuses the block.

**Common mistakes**
- Answering `none` then `101 8`. That is a common *observed* output, but it is not guaranteed by the language.
- Believing `free()` sets the pointer to `NULL`. It cannot, because it only gets a copy of the address.
- Thinking `last_rx` is a wild pointer at the first check. Objects with static storage duration are zero-initialised, so it is a well-defined `NULL`.
- Thinking `free(NULL)` is a crash. It is explicitly a no-op (C11 7.22.3.3p2).

**Interview follow-ups**
- Fix the design: should the application copy the frame by value, take ownership (`last_rx = NULL` after handing it over), or use a reference count?
- Why does the idiom `free(p); p = NULL;` help with double frees, but not with this bug?
- How would you implement "handles with generation counters" so that a stale reference can be *detected* instead of being undefined? (Common in RTOS object pools.)
- In an ISR-plus-task setting, what extra race exists between `on_rx` freeing a frame and the task reading it?
