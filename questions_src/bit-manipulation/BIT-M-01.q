@@@ meta
id: BIT-M-01
topic: Bit Manipulation
difficulty: Medium
type: FUNCTION
title: Reverse the Bits of a uint32_t and Reflect an N-Bit Field
tags: bit-reversal, reflect, crc, divide-and-conquer, masks
@@@ statement_md
Reflected CRCs (CRC-32, CRC-16/MODBUS...) are specified with a "reflect" step that mirrors the bits of a value of a given width. For example, the CRC-32 polynomial `0x04C11DB7` reflected over 32 bits is `0xEDB88320`, and the CCITT polynomial `0x1021` reflected over 16 bits is `0x8408`.

Implement:

```c
uint32_t reverse_bits(uint32_t x);             /* bit i moves to bit 31 - i                         */
uint32_t reflect(uint32_t x, unsigned width);  /* mirror the low `width` bits: bit i -> bit width-1-i; */
                                               /* bits of x at positions >= width are ignored, and the */
                                               /* result has zeros at positions >= width              */
```

`width` is in `1..32`. `reflect(x, 32)` must equal `reverse_bits(x)`. Compiler builtins (`__builtin_bitreverse32`) are not allowed.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `R x` (print `reverse_bits(x)`) or `F x width` (print `reflect(x, width)`). `x` is hex and `width` is decimal.

**Output**
- One `%08X` value per command.

**Example**
```
Input:
3
R 00000001
F 00001021 16
F 000000A0 8

Output:
80000000
00008408
00000005
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= width <= 32`
- Shifts by 32 or more are undefined behavior and are caught by UBSan, so handle `width = 32` carefully.
@@@ starter_code
#include <stdint.h>

uint32_t reverse_bits(uint32_t x)
{
    /* TODO */
    return x;
}

uint32_t reflect(uint32_t x, unsigned width)
{
    /* TODO: width is 1..32 */
    return x;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

#define __builtin_bitreverse32(x) builtin_bitreverse_is_not_allowed

/*USER_CODE*/

#undef __builtin_bitreverse32

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        unsigned x, w;
        if (scanf(" %c %x", &op, &x) != 2) return 0;
        if (op == 'R') {
            printf("%08X\n", (unsigned)reverse_bits(x));
        } else {
            if (scanf("%u", &w) != 1 || w < 1u || w > 32u) return 0;
            printf("%08X\n", (unsigned)reflect(x, w));
        }
    }
    return 0;
}
@@@ sample_input
3
R 00000001
F 00001021 16
F 000000A0 8
@@@ sample_output
80000000
00008408
00000005

@@@ sample_input
2
R 12345678
F 04C11DB7 32
@@@ sample_output
1E6A2C48
EDB88320

@@@ hidden_input
4
R 00000000
R FFFFFFFF
R 80000000
R 0000000F
@@@ hidden_output
00000000
FFFFFFFF
00000001
F0000000

@@@ hidden_input
3
R DEADBEEF
R 00FF00FF
R AAAAAAAA
@@@ hidden_output
F77DB57B
FF00FF00
55555555

@@@ hidden_input
4
F FFFFFFFF 1
F FFFFFFFE 1
F FFFFFFFF 5
F C0000003 2
@@@ hidden_output
00000001
00000000
0000001F
00000003

@@@ hidden_input
3
F 80000000 32
F FFFFFFFF 32
F 12345678 31
@@@ hidden_output
00000001
FFFFFFFF
0F351624

@@@ hidden_input
4
F 0000001D 8
F 00008005 16
F 12345678 12
F FFFF0001 16
@@@ hidden_output
000000B8
0000A001
000001E6
00008000

@@@ hidden_input
2
F 00000001 8
F 00000000 32
@@@ hidden_output
00000080
00000000

@@@ hint
Simple version: loop 32 times, shifting the result left and feeding in `x & 1` while shifting `x` right. For a faster version, swap adjacent bits, then adjacent pairs, then nibbles, bytes and half-words with masks such as `0x55555555` and `0x33333333`.
@@@ hint
Reflecting `width` bits is just a full 32-bit reversal followed by a right shift: the low `width` bits of `x` land in the top `width` bits, so `reverse_bits(x) >> (32 - width)` brings them down. For `width = 32` that is a shift by 0, which is fine. Avoid building the mask `(1u << width) - 1`.
@@@ solution_code
#include <stdint.h>

uint32_t reverse_bits(uint32_t x)
{
    /* divide and conquer: swap ever larger groups (5 steps instead of 32 iterations) */
    x = ((x >> 1) & 0x55555555u) | ((x & 0x55555555u) << 1);   /* odd/even bits   */
    x = ((x >> 2) & 0x33333333u) | ((x & 0x33333333u) << 2);   /* bit pairs       */
    x = ((x >> 4) & 0x0F0F0F0Fu) | ((x & 0x0F0F0F0Fu) << 4);   /* nibbles         */
    x = ((x >> 8) & 0x00FF00FFu) | ((x & 0x00FF00FFu) << 8);   /* bytes           */
    x = (x >> 16) | (x << 16);                                 /* half-words      */
    return x;
}

uint32_t reflect(uint32_t x, unsigned width)
{
    /* low `width` bits of x end up in the top `width` bits; shift them down.
       width in 1..32 -> shift amount 0..31, never 32. */
    return reverse_bits(x) >> (32u - width);
}
@@@ explanation_md
**Approach.**
- **reverse_bits** by divide and conquer: a reversal is the same as swapping the two 16-bit halves, then swapping the bytes inside each half, then the nibbles inside each byte, then the bit pairs, then adjacent bits. Each level is one mask, two shifts and one OR. That is 5 steps instead of 32 loop iterations, with no branches.

```
mask        swaps
0x55555555  bit 0<->1, 2<->3, ...
0x33333333  pairs   (bits 0-1 <-> 2-3)
0x0F0F0F0F  nibbles
0x00FF00FF  bytes
<<16 | >>16 half-words
```

- **reflect(x, w)**: after a full reversal, bit `i` of `x` sits at bit `31 - i`. For `i < w` we want it at `w - 1 - i`, which is `31 - i - (32 - w)`. So shift right by `32 - w`. Bits of `x` at positions `>= w` land below bit `32 - w` and fall off the end, so no extra mask is needed.

**Complexity.** O(log w) = 5 steps for 32 bits (the loop version is O(w)). O(1) space. On ARMv7-M and later, `RBIT` does it in one instruction (`__RBIT()` in CMSIS).

**Common mistakes**
- Masking first with `x & ((1u << width) - 1u)`. For `width = 32` that is a shift by 32, which is undefined (C11 6.5.7p3). On x86 it typically gives mask `0`, on ARM `0xFFFFFFFF`.
- Loop version that shifts the result **after** the last bit (`r = (r | (x & 1)) << 1` 32 times). It drops the MSB and leaves a stray zero at bit 0.
- Confusing bit reversal with byte swapping. `reverse_bits(0x00000001)` is `0x80000000`; `bswap32` would give `0x01000000`.
- Using a signed `int` in the loop. `x >>= 1` on a negative value shifts in ones forever.

**Interview follow-ups**
- Implement it with a 256-entry byte-reversal table (4 look-ups plus a byte swap). Compare flash/RAM use and speed against the mask version on a Cortex-M0, which has no `RBIT`.
- Why do some CRC implementations reflect the **algorithm** (shift right with the reflected polynomial) instead of reflecting every input byte?
- Reverse the bit order of a whole 8-byte CAN payload (64 bits) using your 32-bit function.
- How would you check whether a 32-bit value is a bit-palindrome in O(1)?
