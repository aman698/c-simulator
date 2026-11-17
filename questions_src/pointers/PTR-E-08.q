@@@ meta
id: PTR-E-08
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Implement my_memcpy and my_memset for a Bare-Metal Target
tags: embedded, memcpy, memset, void-pointer, freestanding, asked-in-automotive
@@@ statement_md
A bootloader is built with `-ffreestanding -nostdlib`, so there is no C library. Implement the two most basic memory routines yourself:

```c
void *my_memcpy(void *dst, const void *src, size_t n);
void *my_memset(void *dst, int c, size_t n);
```

- `my_memcpy` copies `n` bytes from `src` to `dst`. The regions never overlap (this is the contract of `memcpy`). It returns `dst`.
- `my_memset` sets `n` bytes starting at `dst` to the value `c` **converted to `unsigned char`**, so `c = 0x141` writes `0x41` and `c = -1` writes `0xFF`. It returns `dst`.
- `n` may be `0`. In that case nothing is written, and the pointers may point one past the end of a buffer.
- `memcpy`, `memset` and `memmove` are not available (using them is a compile error).

**How it is tested.** A hidden `main()` owns a destination buffer `buf` and a separate source buffer `src`. It applies a list of operations and prints `buf` in hex after each one. It also checks the return value and that nothing outside the target range was written.

**Input (read by the hidden harness)**
- Line 1: the initial contents of `buf` (a word, no spaces), the contents of `src` (a word), and `q`.
- Next `q` lines, one of:
  - `S off n c`: `my_memset(buf + off, c, n)`
  - `C d s n`: `my_memcpy(buf + d, src + s, n)`

**Output**
- After each operation, the bytes of `buf` as two-digit uppercase hex values separated by spaces.

**Example**
```
Input:
ABCDEFGH 0123456789 3
S 2 3 42
C 0 4 2
S 0 8 -1

Output:
41 42 2A 2A 2A 46 47 48
34 35 2A 2A 2A 46 47 48
FF FF FF FF FF FF FF FF
```
@@@ constraints_md
- `1 <= len(buf), len(src) <= 32`, `1 <= q <= 20`
- All operations stay in bounds: `off + n <= len(buf)`, `d + n <= len(buf)`, `s + n <= len(src)`.
- `c` is any `int`.
@@@ starter_code
#include <stddef.h>

/* Copy n bytes (no overlap). Return dst. */
void *my_memcpy(void *dst, const void *src, size_t n)
{
    /* TODO */
    return dst;
}

/* Fill n bytes with (unsigned char)c. Return dst. */
void *my_memset(void *dst, int c, size_t n)
{
    /* TODO */
    return dst;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define memcpy(d, s, n) memcpy_is_not_allowed_in_this_exercise
#define memset(d, c, n) memset_is_not_allowed_in_this_exercise
#define memmove(d, s, n) memmove_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef memcpy
#undef memset
#undef memmove

#define GUARD 16
#define CAP 32
#define CANARY 0xA5

static unsigned char arena[GUARD + CAP + GUARD];
static unsigned char src_arena[GUARD + CAP + GUARD];

static int guards_ok(const unsigned char *a, size_t len)
{
    for (size_t k = 0; k < GUARD + CAP + GUARD; k++) {
        if (k >= GUARD && k < GUARD + len) continue;
        if (a[k] != CANARY) return 0;
    }
    return 1;
}

int main(void)
{
    char init[40], srcs[40];
    int q;
    if (scanf("%39s %39s %d", init, srcs, &q) != 3) return 0;
    size_t len = strlen(init), slen = strlen(srcs);
    memset(arena, CANARY, sizeof arena);
    memset(src_arena, CANARY, sizeof src_arena);
    unsigned char *buf = arena + GUARD;
    unsigned char *src = src_arena + GUARD;
    memcpy(buf, init, len);
    memcpy(src, srcs, slen);

    for (int i = 0; i < q; i++) {
        char op;
        int a, b, c;
        if (scanf(" %c %d %d %d", &op, &a, &b, &c) != 4) return 0;
        void *ret, *want;
        if (op == 'S') {
            want = buf + a;
            ret = my_memset(buf + a, c, (size_t)b);
        } else {
            want = buf + a;
            ret = my_memcpy(buf + a, src + b, (size_t)c);
        }
        if (ret != want) printf("BAD RETURN VALUE\n");
        if (!guards_ok(arena, len)) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
        if (!guards_ok(src_arena, slen) || memcmp(src, srcs, slen) != 0) {
            printf("SOURCE WAS MODIFIED\n");
            return 0;
        }
        for (size_t k = 0; k < len; k++) printf("%02X%c", buf[k], k + 1 == len ? '\n' : ' ');
    }
    return 0;
}
@@@ sample_input
ABCDEFGH 0123456789 3
S 2 3 42
C 0 4 2
S 0 8 -1
@@@ sample_output
41 42 2A 2A 2A 46 47 48
34 35 2A 2A 2A 46 47 48
FF FF FF FF FF FF FF FF

@@@ sample_input
hello world 2
C 0 0 5
S 5 0 0
@@@ sample_output
77 6F 72 6C 64
77 6F 72 6C 64

@@@ hidden_input
x y 2
S 0 1 321
C 0 0 1
@@@ hidden_output
41
79

@@@ hidden_input
abcdefghijklmnopqrstuvwxyz012345 ZYXWVUTSRQPONMLKJIHGFEDCBA987654 2
C 0 0 32
S 0 32 0
@@@ hidden_output
5A 59 58 57 56 55 54 53 52 51 50 4F 4E 4D 4C 4B 4A 49 48 47 46 45 44 43 42 41 39 38 37 36 35 34
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

@@@ hidden_input
abc def 3
C 1 1 0
S 3 0 255
C 3 3 0
@@@ hidden_output
61 62 63
61 62 63
61 62 63

@@@ hidden_input
AAAAAAAA BBBB 3
C 2 0 4
S 7 1 -1
S 0 1 256
@@@ hidden_output
41 41 42 42 42 42 41 41
41 41 42 42 42 42 41 FF
00 41 42 42 42 42 41 FF

@@@ hidden_input
0123456789 abcdefghij 2
C 5 5 5
C 0 9 1
@@@ hidden_output
30 31 32 33 34 66 67 68 69 6A
6A 31 32 33 34 66 67 68 69 6A

@@@ hidden_input
q w 1
S 0 1 -128
@@@ hidden_output
80

@@@ hint
You cannot dereference or do arithmetic on a `void *`. Convert it to `unsigned char *` (and `const unsigned char *` for the source) and copy one byte per iteration.
@@@ hint
Keep the original `dst` to return it, and walk a separate cursor pointer. For memset, convert once: `unsigned char v = (unsigned char)c;`. The loop `while (n--) *d++ = v;` handles `n == 0` without touching memory.
@@@ solution_code
#include <stddef.h>

void *my_memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;            /* implicit conversion from void * */
    const unsigned char *s = src;

    while (n--)
        *d++ = *s++;
    return dst;                        /* the ORIGINAL pointer, not the advanced cursor */
}

void *my_memset(void *dst, int c, size_t n)
{
    unsigned char *d = dst;
    const unsigned char v = (unsigned char)c;   /* 0x141 -> 0x41, -1 -> 0xFF */

    while (n--)
        *d++ = v;
    return dst;
}
@@@ explanation_md
**Approach.** `void *` is a "pointer to raw memory" without an element size. You cannot dereference it, and arithmetic on it is only a GCC extension. Convert it to `unsigned char *`, the byte type that may alias any object, and move one byte per iteration with the classic `*d++ = *s++` idiom. `memset` takes an `int` for historical reasons; the standard says the value is converted to `unsigned char`, so only the low 8 bits matter.

Both functions return the **original** `dst`. This allows chaining such as `strcpy(my_memset(buf, 0, n), "x")`.

**Complexity.** Time O(n), extra space O(1).

**Common mistakes**
- Returning the advanced cursor `d` instead of `dst`.
- Using `char *` and comparing/sign-extending bytes. Harmless for copying, but a habit that breaks byte comparisons (`memcmp`) and checksums.
- `for (size_t i = n - 1; i >= 0; i--)`. A `size_t` is never negative, so the loop never ends (and `n - 1` wraps when `n == 0`).
- Calling `my_memcpy` on overlapping regions. That is `memmove`'s job; `memcpy` with overlap is undefined behavior (C11 7.24.2.1).
- On a real freestanding build, gcc may recognise your loop and turn it **back** into a call to `memcpy`, which then does not link. Bootloaders build these files with `-fno-builtin` / `-fno-tree-loop-distribute-patterns`.

**Interview follow-ups**
- Make `my_memcpy` faster by copying 32-bit words once both pointers are 4-byte aligned. How do you handle the unaligned head and tail, and why does an unaligned word access fault on Cortex-M0?
- Why must you never use `memset`/`memcpy` on a peripheral register block, and what would a `volatile`-correct `reg_copy()` look like?
- Why might `memset(key, 0, sizeof key)` before returning from a crypto function be removed by the optimiser, and what is `memset_s` / `explicit_bzero` for?
- What does `restrict` add to the prototype `void *memcpy(void *restrict, const void *restrict, size_t)`?
