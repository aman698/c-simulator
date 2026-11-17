@@@ meta
id: MEM-H-10
topic: Dynamic Memory
difficulty: Hard
type: PREDICT_OUTPUT
title: Offsets in a Bump Arena With Mark and Release
tags: embedded, arena-allocator, alignment, bump-allocator, misra, no-malloc
@@@ statement_md
Many ECUs replace `malloc` with a **bump (linear) arena**: allocation only moves a `top` offset forward (rounded up to the requested alignment), and a whole group of allocations is released at once by resetting `top` to a saved mark. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes** (`_Alignof(uint32_t)` = 4, `_Alignof(double)` = 8, `_Alignof(uint16_t)` = 2).

```c
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

_Alignas(16) static unsigned char arena[64];
static size_t top;

static void *bump(size_t size, size_t align)
{
    size_t off = (top + align - 1) & ~(align - 1);
    if (off > sizeof arena || size > sizeof arena - off)
        return NULL;                      /* top is NOT moved on failure */
    top = off + size;
    return arena + off;
}

static long long at(const void *p)
{
    return p ? (long long)((const unsigned char *)p - arena) : -1;
}

int main(void)
{
    char     *a = bump(3, 1);
    uint32_t *b = bump(sizeof *b, _Alignof(uint32_t));
    double   *c = bump(sizeof *c, _Alignof(double));
    uint16_t *d = bump(5 * sizeof *d, _Alignof(uint16_t));
    void     *e = bump(40, 8);
    printf("%lld %lld %lld %lld %lld\n", at(a), at(b), at(c), at(d), at(e));

    void *f = bump(16, 16);
    size_t mark = top;
    void *g = bump(12, 4);
    void *h = bump(8, 8);
    top = mark;                           /* release g and h together */
    void *i = bump(1, 1);
    printf("%lld %lld %lld %lld\n", at(f), at(g), at(h), at(i));
    printf("%zu\n", top);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11. `arena` is 16-byte aligned, so offsets that are multiples of an alignment give correctly aligned addresses.
- No pointer returned by `bump` is dereferenced.
@@@ starter_code
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

_Alignas(16) static unsigned char arena[64];
static size_t top;

static void *bump(size_t size, size_t align)
{
    size_t off = (top + align - 1) & ~(align - 1);
    if (off > sizeof arena || size > sizeof arena - off)
        return NULL;                      /* top is NOT moved on failure */
    top = off + size;
    return arena + off;
}

static long long at(const void *p)
{
    return p ? (long long)((const unsigned char *)p - arena) : -1;
}

int main(void)
{
    char     *a = bump(3, 1);
    uint32_t *b = bump(sizeof *b, _Alignof(uint32_t));
    double   *c = bump(sizeof *c, _Alignof(double));
    uint16_t *d = bump(5 * sizeof *d, _Alignof(uint16_t));
    void     *e = bump(40, 8);
    printf("%lld %lld %lld %lld %lld\n", at(a), at(b), at(c), at(d), at(e));

    void *f = bump(16, 16);
    size_t mark = top;
    void *g = bump(12, 4);
    void *h = bump(8, 8);
    top = mark;                           /* release g and h together */
    void *i = bump(1, 1);
    printf("%lld %lld %lld %lld\n", at(f), at(g), at(h), at(i));
    printf("%zu\n", top);
    return 0;
}
@@@ predict_answer
0 4 8 16 -1
32 48 -1 48
49
@@@ hint
Track `top` by hand. Each call first rounds `top` up to a multiple of `align` (`(top + align - 1) & ~(align - 1)`), then checks that `size` bytes still fit in the 64-byte arena. A failed request returns `NULL` and leaves `top` unchanged.
@@@ hint
`a`: 0..2 (top 3). `b`: round 3 up to 4. `c`: round 8 up to 8. `d`: 10 bytes at 16 (top 26). `e`: 40 bytes at 32 do not fit (only 32 left), so it returns NULL. `f`: round 26 up to 32 (top 48). After the mark (48): `g` takes 48..59, and `h` would start at 64 with 0 bytes left. Resetting `top` to 48 releases `g`, so `i` lands at 48.
@@@ solution_code
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

_Alignas(16) static unsigned char arena[64];
static size_t top;

static void *bump(size_t size, size_t align)
{
    size_t off = (top + align - 1) & ~(align - 1);   /* round up (align = power of 2) */
    if (off > sizeof arena || size > sizeof arena - off)
        return NULL;                                  /* overflow-safe fit check     */
    top = off + size;
    return arena + off;
}

static long long at(const void *p)
{
    return p ? (long long)((const unsigned char *)p - arena) : -1;
}

int main(void)
{
    char     *a = bump(3, 1);                          /* off 0,  top 3              */
    uint32_t *b = bump(sizeof *b, _Alignof(uint32_t)); /* 3 -> 4: off 4,  top 8      */
    double   *c = bump(sizeof *c, _Alignof(double));   /* 8 -> 8: off 8,  top 16     */
    uint16_t *d = bump(5 * sizeof *d, _Alignof(uint16_t)); /* off 16, top 26 (10 B)  */
    void     *e = bump(40, 8);                         /* 26 -> 32, 40 > 32 left: NULL,
                                                          top stays 26               */
    printf("%lld %lld %lld %lld %lld\n", at(a), at(b), at(c), at(d), at(e)); /* 0 4 8 16 -1 */

    void *f = bump(16, 16);                            /* 26 -> 32: off 32, top 48   */
    size_t mark = top;                                 /* mark = 48                  */
    void *g = bump(12, 4);                             /* off 48, top 60             */
    void *h = bump(8, 8);                              /* 60 -> 64, 0 bytes left: NULL */
    top = mark;                                        /* release everything after 48 */
    void *i = bump(1, 1);                              /* off 48, top 49             */
    printf("%lld %lld %lld %lld\n", at(f), at(g), at(h), at(i));             /* 32 48 -1 48 */
    printf("%zu\n", top);                                                    /* 49          */
    return 0;
}
@@@ explanation_md
**Answer**
```
0 4 8 16 -1
32 48 -1 48
49
```

| call | top before | aligned offset | fits? | top after |
|---|---|---|---|---|
| `a` (3, 1) | 0 | 0 | yes | 3 |
| `b` (4, 4) | 3 | 4 | yes | 8 |
| `c` (8, 8) | 8 | 8 | yes | 16 |
| `d` (10, 2) | 16 | 16 | yes | 26 |
| `e` (40, 8) | 26 | 32 | no (32 left) | 26 |
| `f` (16, 16) | 26 | 32 | yes | 48 |
| `g` (12, 4) | 48 | 48 | yes | 60 |
| `h` (8, 8) | 60 | 64 | no (0 left) | 60 |
| `top = mark` | | | | 48 |
| `i` (1, 1) | 48 | 48 | yes | 49 |

Everything here is well defined: unsigned arithmetic, pointer subtraction within one array, and pointers are only compared and subtracted, never dereferenced. Note the fit test `size > sizeof arena - off` (after checking `off <= sizeof arena`). The naive `off + size > sizeof arena` can wrap for huge `size`.

**Why arenas are popular in automotive software.**
- Allocation is a few instructions with a **bounded, constant WCET**. There is no free list to search, unlike `malloc`.
- There is **no fragmentation**: memory is released in LIFO groups (`mark`/`release`) or all at once, for example per diagnostic session or per 10 ms task cycle (a "frame allocator").
- Memory use is visible and bounded at link time (a static array). That is the spirit of MISRA C:2012 **Directive 4.12** and **Rule 21.3**, which forbid the standard heap. Projects that need run-time sizing use arenas or pools instead.
- The trade-off: there is no individual `free`. Padding wastes bytes (here 1 + 6 = 7 bytes before `b` and `f`), and objects must not outlive their mark.

**Complexity.** Every `bump` is O(1). `mark`/`release` are O(1) (one assignment).

**Common mistakes**
- Forgetting that a **failed** request does not move `top` (it leaves 26, not 72).
- Rounding wrongly: `top & ~(align-1)` rounds **down** and overlaps the previous object.
- Counting `d` as 5 bytes instead of `5 * sizeof(uint16_t)` = 10.
- Thinking `h` fits because `60 + 8 = 68`, when alignment pushed it to 64 first.

**Interview follow-ups**
- Make the arena reject non-power-of-two alignments, and explain why the mask trick fails for `align = 24`.
- How would you implement a **double-buffered** frame arena for a producer/consumer pair of tasks?
- What goes wrong if an object allocated after `mark` is still referenced after `top = mark`? How could a debug build detect it? (Poison the released range, as ASan does.)
