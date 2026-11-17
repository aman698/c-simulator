@@@ meta
id: MEM-E-04
topic: Dynamic Memory
difficulty: Easy
type: PREDICT_OUTPUT
title: Returning a Freed Label
tags: use-after-free, dangling-pointer, free, undefined-behavior
@@@ statement_md
A junior developer was told "every `malloc` needs a `free`", so the helper below frees its buffer before returning. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdlib.h>

static char *make_tag(int id)
{
    char *s = malloc(16);
    if (s == NULL)
        return NULL;
    snprintf(s, 16, "ECU_%03d", id);

    char *result = s;
    free(s);              /* "never leak!" */
    return result;
}

int main(void)
{
    char *tag = make_tag(7);
    if (tag != NULL)
        printf("%s\n", tag);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc (glibc), compiled with the judge flags.
- `malloc(16)` succeeds.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

static char *make_tag(int id)
{
    char *s = malloc(16);
    if (s == NULL)
        return NULL;
    snprintf(s, 16, "ECU_%03d", id);

    char *result = s;
    free(s);              /* "never leak!" */
    return result;
}

int main(void)
{
    char *tag = make_tag(7);
    if (tag != NULL)
        printf("%s\n", tag);
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
`result` and `s` hold the same address. After `free(s)`, who owns the 16 bytes at that address?
@@@ hint
Copying a pointer never copies the object it points to. Once the block is freed, every copy of the pointer is **dangling**, and `printf("%s", tag)` reads freed memory (C11 7.22.3.3, J.2).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

static char *make_tag(int id)
{
    char *s = malloc(16);
    if (s == NULL)
        return NULL;
    snprintf(s, 16, "ECU_%03d", id);   /* "ECU_007" written into the block */

    char *result = s;     /* copies the ADDRESS, not the string           */
    free(s);              /* block returned to the allocator: the lifetime
                             of the object ends; s AND result now dangle   */
    return result;        /* returns a dangling pointer                    */
}

int main(void)
{
    char *tag = make_tag(7);
    if (tag != NULL)          /* even this read of an indeterminate pointer
                                 value is undefined in strict C11 (6.2.4p2) */
        printf("%s\n", tag);  /* reads freed memory: heap-use-after-free     */
    return 0;
}

/* Correct version: do NOT free inside make_tag. Ownership passes to the caller:
 *     char *tag = make_tag(7);
 *     printf("%s\n", tag);
 *     free(tag);
 */
@@@ explanation_md
**Answer: Undefined Behavior.**

`result = s` copies only the address. `free(s)` ends the lifetime of the 16-byte object, and from then on `s`, `result` and `tag` all hold dangling pointers. C11 6.2.4p2 says a pointer's value becomes indeterminate when the object it points to reaches the end of its lifetime. Reading through it (7.22.3.3, Annex J.2) is undefined behavior.

What you may actually see:
- **Plain glibc, no sanitizers:** often `ECU_007`. The bytes are still there, but the first 16 bytes of a freed chunk are reused for free-list pointers, so you may see garbage instead. The result depends on the allocator version.
- **AddressSanitizer:** `heap-use-after-free READ of size 1`, and the program aborts.
- **An RTOS heap:** another task may already have allocated the block, so you print its data, or worse, it changes under you.

"It printed the right thing once" proves nothing about undefined behavior.

**The fix.** Decide who owns the memory. Here the caller must own it: `make_tag` returns the block without freeing it, and `main` calls `free(tag)` after printing. Document the ownership in the function's comment (for example, "returns a heap string; caller frees").

**Complexity.** O(1) time and space. This question is about lifetime, not cost.

**Common mistakes**
- Thinking `char *result = s;` makes a copy of the string. It copies one pointer.
- "Fixing" the leak by freeing inside the producer. That turns a leak into a use-after-free, which is a much worse bug.
- Returning the address of a local array (`char buf[16]; ... return buf;`). It is the same bug with stack memory.

**Interview follow-ups**
- Give three ways to return a string from a function safely: caller-provided buffer, heap with caller-frees, static buffer (not reentrant). What are the trade-offs on an RTOS?
- Why is setting `s = NULL` after `free(s)` here not enough to prevent the bug?
- How does ASan detect use-after-free? (Shadow memory, a poisoned quarantine, delayed reuse of freed chunks.)
