@@@ meta
id: BIT-E-03
topic: Bit Manipulation
difficulty: Easy
type: FUNCTION
title: Power-of-Two Check, Lowest Set Bit and Align-Up
tags: embedded, power-of-two, alignment, lowest-set-bit, mpu, dma
@@@ statement_md
You are writing helpers for the memory-protection and DMA setup code of a Cortex-M ECU:
- On ARMv7-M, an **MPU region** size must be a power of two, and the region base must be aligned to that size.
- **DMA buffers** must start on a 32-byte cache-line boundary.

Implement three branch-light, loop-free helpers:

```c
int      is_pow2(uint32_t x);              /* 1 if x is a power of two, else 0 (0 is NOT a power of two) */
uint32_t lowest_set_bit(uint32_t x);       /* x with every bit cleared except its lowest 1-bit; 0 if x == 0 */
uint32_t align_up(uint32_t x, uint32_t a); /* smallest multiple of a that is >= x; a is a power of two */
```

Examples: `is_pow2(64) = 1`, `is_pow2(96) = 0`, `lowest_set_bit(0x6C) = 0x04`, `align_up(108, 32) = 128`, `align_up(128, 32) = 128`.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `x a`, both in hex (`a` is always a power of two).

**Output**
- For each line: `is_pow2=P lowest=LLLLLLLL align=AAAAAAAA` with `P` = `is_pow2(x)`, `L` = `lowest_set_bit(x)` and `A` = `align_up(x, a)`, both printed as `%08X`.

**Example**
```
Input:
2
00000040 00000010
0000006C 00000020

Output:
is_pow2=1 lowest=00000040 align=00000040
is_pow2=0 lowest=00000004 align=00000080
```
@@@ constraints_md
- `0 <= x <= 0xFFFFFFFF`, `a` is a power of two (`1 <= a <= 0x80000000`)
- `x + a - 1 <= 0xFFFFFFFF` (the aligned value always fits)
- Use O(1) bit tricks: no loops, no division or `%`.
@@@ starter_code
#include <stdint.h>

int is_pow2(uint32_t x)
{
    /* TODO */
    return 0;
}

uint32_t lowest_set_bit(uint32_t x)
{
    /* TODO */
    return 0;
}

uint32_t align_up(uint32_t x, uint32_t a)
{
    /* TODO: a is a power of two */
    return x;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        unsigned x, a;
        if (scanf("%x %x", &x, &a) != 2) return 0;
        int p = is_pow2(x);
        uint32_t l = lowest_set_bit(x);
        uint32_t al = align_up(x, a);
        printf("is_pow2=%d lowest=%08X align=%08X\n", p, (unsigned)l, (unsigned)al);
    }
    return 0;
}
@@@ sample_input
2
00000040 00000010
0000006C 00000020
@@@ sample_output
is_pow2=1 lowest=00000040 align=00000040
is_pow2=0 lowest=00000004 align=00000080

@@@ sample_input
2
00000000 00000008
00000001 00000001
@@@ sample_output
is_pow2=0 lowest=00000000 align=00000000
is_pow2=1 lowest=00000001 align=00000001

@@@ hidden_input
1
80000000 80000000
@@@ hidden_output
is_pow2=1 lowest=80000000 align=80000000

@@@ hidden_input
2
FFFFFFFF 00000001
7FFFFFFF 80000000
@@@ hidden_output
is_pow2=0 lowest=00000001 align=FFFFFFFF
is_pow2=0 lowest=00000001 align=80000000

@@@ hidden_input
3
00001001 00001000
00030000 00000100
FFFFE001 00001000
@@@ hidden_output
is_pow2=0 lowest=00000001 align=00002000
is_pow2=0 lowest=00010000 align=00030000
is_pow2=0 lowest=00000001 align=FFFFF000

@@@ hidden_input
3
00000003 00000004
00000002 00000002
C0000000 40000000
@@@ hidden_output
is_pow2=0 lowest=00000001 align=00000004
is_pow2=1 lowest=00000002 align=00000002
is_pow2=0 lowest=40000000 align=C0000000

@@@ hidden_input
4
00000020 00000020
00000021 00000020
0000001F 00000020
00000000 80000000
@@@ hidden_output
is_pow2=1 lowest=00000020 align=00000020
is_pow2=0 lowest=00000001 align=00000040
is_pow2=0 lowest=00000001 align=00000020
is_pow2=0 lowest=00000000 align=00000000

@@@ hidden_input
2
00010000 00000004
40000000 00000400
@@@ hidden_output
is_pow2=1 lowest=00010000 align=00010000
is_pow2=1 lowest=40000000 align=40000000

@@@ hint
A power of two has exactly one 1-bit. `x & (x - 1)` clears the lowest 1-bit, so for a power of two it gives 0. Watch out for `x == 0`.
@@@ hint
In two's complement, `-x == ~x + 1`. For unsigned `x`, `x & -x` keeps only the lowest set bit. For alignment, `a - 1` is a mask of the low bits that must become zero: add `a - 1`, then clear those bits with `& ~(a - 1)`.
@@@ solution_code
#include <stdint.h>

int is_pow2(uint32_t x)
{
    /* exactly one bit set: nonzero, and clearing the lowest bit leaves nothing */
    return x != 0u && (x & (x - 1u)) == 0u;
}

uint32_t lowest_set_bit(uint32_t x)
{
    /* unsigned negation is well defined: -x == ~x + 1 (mod 2^32) */
    return x & (~x + 1u);
}

uint32_t align_up(uint32_t x, uint32_t a)
{
    uint32_t mask = a - 1u;         /* e.g. a = 32 -> 0x1F */
    return (x + mask) & ~mask;      /* bump past the boundary, then truncate */
}
@@@ explanation_md
**Approach.**
- **is_pow2:** a power of two is a single 1-bit. `x - 1` turns that bit into 0 and all lower bits into 1, so `x & (x - 1) == 0`. The trick also returns true for `x == 0`, so test `x != 0` first.
- **lowest_set_bit:** `~x + 1` (that is, `-x`) flips every bit above the lowest 1-bit and keeps that bit and the zeros below it. ANDing with `x` leaves only the lowest 1-bit:
  ```
  x      = 0110 1100
  -x     = 1001 0100
  x & -x = 0000 0100
  ```
- **align_up:** with `mask = a - 1` (the low bits that must be zero), `(x + mask) & ~mask` rounds up. An already-aligned value stays unchanged because adding `mask` never crosses the next boundary.

**Complexity.** O(1) time and space for all three. Each one is 2 or 3 ALU instructions, with no division. Division is slow, and some cores (for example, Cortex-M0) do not have a divide instruction at all.

**Common mistakes**
- `is_pow2(0)` returning 1, because `0 & (0 - 1) == 0`.
- `align_up` as `(x + a) & ~(a - 1)`. That moves already-aligned values one whole block up: `align_up(32, 32)` becomes 64. This wastes an MPU region or DMA buffer.
- `x & -x` on a **signed** `int`. `-INT_MIN` overflows, which is UB. On `uint32_t`, negation is modular and well defined.
- Using `%` and `/` (`x + (a - x % a) % a`). It is correct, but slow on an MCU without a hardware divider, and it misses the point of the question.

**Interview follow-ups**
- Write `align_down(x, a)`, and an `IS_ALIGNED(ptr, a)` check for a pointer (hint: cast to `uintptr_t`).
- Round `x` up to the **next power of two** (`1 -> 1`, `5 -> 8`, `0x80000001 -> ?`) with the bit-smearing trick `x |= x >> 1; x |= x >> 2; ...`.
- How do you get the **index** of the lowest set bit (count trailing zeros)? Mention `__builtin_ctz` / the `RBIT` + `CLZ` instructions on ARM, and a de Bruijn table where no such instruction exists.
- Why do lock-free ring buffers insist on a power-of-two size? (`index & (N - 1)` instead of `%`.)
