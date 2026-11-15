@@@ meta
id: PTR-M-01
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Implement my_memmove (Overlap-Safe Copy)
tags: embedded, memmove, pointer-arithmetic, void-pointer, asked-in-automotive
@@@ statement_md
Implement

```c
void *my_memmove(void *dst, const void *src, size_t n);
```

It copies `n` bytes from `src` to `dst` and returns `dst`. Unlike `memcpy`, the two regions **may overlap**, and the result must be as if the bytes were first copied to a temporary buffer.

You may **not** use `memmove`, `memcpy`, or a temporary buffer. In bootloaders and BSP code you often have no libc, and an O(n) scratch buffer is not available.

**How it is tested.** A hidden `main()` reads a buffer and a list of moves, calls your function on the buffer for each move, and prints the buffer after every call. It also checks that you return `dst` and that you never write outside the buffer.

**Input (read by the hidden harness)**
- Line 1: the initial buffer contents `s` (no spaces) and the number of operations `q`.
- Next `q` lines: `dst src n`, meaning `my_memmove(buf + dst, buf + src, n)`.

**Output**
- After each operation, one line with the current buffer contents.

**Example**
```
Input:
abcdefghij 2
2 0 5
0 3 4

Output:
ababcdehij
bcdecdehij
```
@@@ constraints_md
- `1 <= strlen(s) <= 40`, `1 <= q <= 20`
- `0 <= dst, src` and `dst + n <= strlen(s)`, `src + n <= strlen(s)` (always in bounds)
- `n` may be `0`; `dst` may equal `src`.
- Do not use any `<string.h>` copy function.
@@@ starter_code
#include <stddef.h>

/*
 * Copy n bytes from src to dst; the regions may overlap.
 * Return dst. Do NOT use memmove/memcpy or a temporary buffer.
 */
void *my_memmove(void *dst, const void *src, size_t n)
{
    /* TODO */
    return dst;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define memmove(d, s, n) memmove_is_not_allowed_in_this_exercise
#define memcpy(d, s, n) memcpy_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef memmove
#undef memcpy

#define GUARD 16
#define CANARY 0xA5

int main(void)
{
    unsigned char arena[GUARD + 41 + GUARD];
    char init[64];
    int q;
    if (scanf("%63s %d", init, &q) != 2) return 0;
    size_t len = strlen(init);
    memset(arena, CANARY, sizeof arena);
    unsigned char *buf = arena + GUARD;
    memcpy(buf, init, len);
    for (int i = 0; i < q; i++) {
        int d, s, n;
        if (scanf("%d %d %d", &d, &s, &n) != 3) return 0;
        void *ret = my_memmove(buf + d, buf + s, (size_t)n);
        if (ret != (void *)(buf + d)) printf("BAD RETURN VALUE\n");
        for (size_t k = 0; k < GUARD; k++) {
            if (arena[k] != CANARY || buf[len + k] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        printf("%.*s\n", (int)len, (const char *)buf);
    }
    return 0;
}
@@@ sample_input
abcdefghij 2
2 0 5
0 3 4
@@@ sample_output
ababcdehij
bcdecdehij

@@@ sample_input
hello 1
0 0 5
@@@ sample_output
hello

@@@ hidden_input
abcdefghij 1
0 2 8
@@@ hidden_output
cdefghijij

@@@ hidden_input
abcdefghij 1
2 0 8
@@@ hidden_output
ababcdefgh

@@@ hidden_input
abcdefghij 2
5 5 0
0 9 0
@@@ hidden_output
abcdefghij
abcdefghij

@@@ hidden_input
x 1
0 0 1
@@@ hidden_output
x

@@@ hidden_input
0123456789ABCDEF 3
8 0 8
1 0 15
0 1 15
@@@ hidden_output
0123456701234567
0012345670123456
0123456701234566

@@@ hidden_input
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn 2
1 0 39
0 1 39
@@@ hidden_output
AABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklm
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmm

@@@ hidden_input
abcdef 3
0 3 3
3 0 3
1 2 1
@@@ hidden_output
defdef
defdef
dffdef

@@@ hint
If `dst` is **before** `src`, copying front-to-back is safe. Each source byte is read before it can be overwritten.
@@@ hint
If `dst` is **after** `src` and the regions overlap, copy **back-to-front**: start at `src + n - 1` and `dst + n - 1` and walk down.
@@@ solution_code
#include <stddef.h>

void *my_memmove(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;

    if (d == s || n == 0)
        return dst;

    if (d < s) {
        /* destination below source: forward copy never clobbers unread bytes */
        while (n--)
            *d++ = *s++;
    } else {
        /* destination above source: copy from the end backwards */
        d += n;
        s += n;
        while (n--)
            *--d = *--s;
    }
    return dst;
}
@@@ explanation_md
**Approach.** The danger is reading a source byte that you have already overwritten. That only happens when `dst` lies inside `(src, src + n)`. In that case, copy from the end towards the start. Otherwise a plain forward copy is correct.

```
src: [a b c d e] f g        dst = src + 2, n = 5
forward copy:  a b a b a b a   <- wrong, re-reads copied bytes
backward copy: a b a b c d e   <- correct
```

Work on `unsigned char *`. You cannot do arithmetic on `void *` in standard C (GCC allows it only as an extension), and `char` may be signed.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Forward copy in all cases. It passes non-overlapping tests and corrupts data when `dst > src` and the regions overlap.
- Arithmetic on `void *` (`dst + 1`). This is a GCC extension, not ISO C, and MISRA-C forbids it.
- Forgetting to return `dst`, or returning the advanced pointer `d`.
- Using a temporary buffer (a VLA or `malloc`), which is not allowed on stack-constrained targets.

**Interview follow-ups**
- Strictly speaking, comparing pointers to *different* objects with `<` is undefined. How would you make the overlap test fully portable? (Cast to `uintptr_t`.)
- Speed it up by copying 4 or 8 bytes per iteration once both pointers are word-aligned. What alignment pitfalls exist on Cortex-M0, which has no unaligned access?
- Why must the copy loop for a DMA descriptor or a memory-mapped FIFO use `volatile` pointers, and why can't you call this function on peripheral registers?
- How does `memmove` differ from `memcpy` in the standard? (`memcpy` with overlapping regions is undefined behavior.)
