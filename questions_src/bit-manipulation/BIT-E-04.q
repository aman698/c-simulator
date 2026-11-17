@@@ meta
id: BIT-E-04
topic: Bit Manipulation
difficulty: Easy
type: FUNCTION
title: Swap Nibbles and Swap Byte Order (16 and 32 Bit)
tags: embedded, endianness, byte-swap, nibble-swap, masks, asked-in-automotive
@@@ statement_md
Your little-endian Cortex-M receives big-endian values from a sensor over SPI, and from a gateway that uses network byte order. The RTC stores time as BCD, with tens and units in the two nibbles of a byte. You need three tiny helpers:

```c
uint8_t  swap_nibbles(uint8_t b);   /* 0xA5       -> 0x5A       */
uint16_t bswap16(uint16_t x);       /* 0x1234     -> 0x3412     */
uint32_t bswap32(uint32_t x);       /* 0x12345678 -> 0x78563412 */
```

Use shifts and masks only. Compiler intrinsics such as `__builtin_bswap32` are not allowed.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: one 32-bit value `v` in hex.

**Output**
- For each `v`: `nib=NN b16=HHHH b32=WWWWWWWW`, where
  `NN = swap_nibbles((uint8_t)v)`, `HHHH = bswap16((uint16_t)v)`, `WWWWWWWW = bswap32(v)`.

**Example**
```
Input:
1
12345678

Output:
nib=87 b16=7856 b32=78563412
```
(`(uint8_t)v = 0x78` and `(uint16_t)v = 0x5678`.)
@@@ constraints_md
- `1 <= q <= 20`, `0 <= v <= 0xFFFFFFFF`
- No `__builtin_bswap16/32`, no `htonl`/`ntohs`, no loops needed.
@@@ starter_code
#include <stdint.h>

uint8_t swap_nibbles(uint8_t b)
{
    /* TODO */
    return b;
}

uint16_t bswap16(uint16_t x)
{
    /* TODO */
    return x;
}

uint32_t bswap32(uint32_t x)
{
    /* TODO */
    return x;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

#define __builtin_bswap16(x) builtin_bswap_is_not_allowed
#define __builtin_bswap32(x) builtin_bswap_is_not_allowed

/*USER_CODE*/

#undef __builtin_bswap16
#undef __builtin_bswap32

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        unsigned v;
        if (scanf("%x", &v) != 1) return 0;
        unsigned n = swap_nibbles((uint8_t)v);
        unsigned h = bswap16((uint16_t)v);
        unsigned w = bswap32(v);
        printf("nib=%02X b16=%04X b32=%08X\n", n, h, w);
    }
    return 0;
}
@@@ sample_input
1
12345678
@@@ sample_output
nib=87 b16=7856 b32=78563412

@@@ sample_input
2
000000A5
00000000
@@@ sample_output
nib=5A b16=A500 b32=A5000000
nib=00 b16=0000 b32=00000000

@@@ hidden_input
1
FFFFFFFF
@@@ hidden_output
nib=FF b16=FFFF b32=FFFFFFFF

@@@ hidden_input
2
000000FF
80000001
@@@ hidden_output
nib=FF b16=FF00 b32=FF000000
nib=10 b16=0100 b32=01000080

@@@ hidden_input
1
DEADBEEF
@@@ hidden_output
nib=FE b16=EFBE b32=EFBEADDE

@@@ hidden_input
2
0000F00F
01020304
@@@ hidden_output
nib=F0 b16=0FF0 b32=0FF00000
nib=40 b16=0403 b32=04030201

@@@ hidden_input
2
00008000
7F000000
@@@ hidden_output
nib=00 b16=0080 b32=00800000
nib=00 b16=0000 b32=0000007F

@@@ hidden_input
3
0000009C
00001234
C3000081
@@@ hidden_output
nib=C9 b16=9C00 b32=9C000000
nib=43 b16=3412 b32=34120000
nib=18 b16=8100 b32=810000C3

@@@ hint
A nibble swap moves the low nibble up 4 places and the high nibble down 4 places: `(b << 4) | (b >> 4)`. Mind the type: `b` is promoted to `int`, so cast the result back to `uint8_t`.
@@@ hint
For 32 bits, isolate each byte with a mask and move it to its mirror position. Byte 0 goes `<< 24`, byte 1 `<< 8`, byte 2 `>> 8`, byte 3 `>> 24`. Mask **after** a right shift, or **before** a left shift, so no stray bits survive.
@@@ solution_code
#include <stdint.h>

uint8_t swap_nibbles(uint8_t b)
{
    /* b is promoted to int: (b << 4) may have bits 8..11 set, the cast drops them */
    return (uint8_t)((b << 4) | (b >> 4));
}

uint16_t bswap16(uint16_t x)
{
    return (uint16_t)((x << 8) | (x >> 8));
}

uint32_t bswap32(uint32_t x)
{
    return ((x & 0x000000FFu) << 24) |
           ((x & 0x0000FF00u) << 8)  |
           ((x & 0x00FF0000u) >> 8)  |
           ((x & 0xFF000000u) >> 24);
}
@@@ explanation_md
**Approach.** Each swap moves fixed-size groups of bits to mirrored positions with shifts. Masks keep each group isolated.

```
bswap32(0x12345678):
  (x & 0x000000FF) << 24 -> 0x78000000
  (x & 0x0000FF00) << 8  -> 0x00560000
  (x & 0x00FF0000) >> 8  -> 0x00003400
  (x & 0xFF000000) >> 24 -> 0x00000012
  OR                     -> 0x78563412
```

For `swap_nibbles` and `bswap16`, the operand is promoted to `int` first, so `(b << 4)` can be wider than 8 bits. The final cast truncates the result back to the target width. The values involved never exceed 0xFFFFF0, so no signed overflow can occur.

**Complexity.** O(1) time and space. gcc and clang recognise the `bswap32` pattern and emit a single `BSWAP` (x86) or `REV` (ARM) instruction.

**Common mistakes**
- Swapping with a `union { uint32_t w; uint8_t b[4]; }` or by casting `uint8_t *`. That depends on the host's endianness, so the "swap" is wrong on a big-endian core such as some PowerPC MCUs. Shifts are endian-agnostic.
- Shifting a `uint8_t` byte left by 24 without a cast: `((uint8_t)x) << 24` is an `int` shift and overflows for bytes `>= 0x80` (UB). Masking the `uint32_t` (`x & 0xFF`) keeps everything unsigned.
- Forgetting the mask after `x >> 8` in a 16-bit swap of a wider variable, so stray high bits leak into the result.
- Confusing a byte swap with a **bit** reversal. `bswap32(0x00000001)` is `0x01000000`, not `0x80000000`.

**Interview follow-ups**
- Write `uint32_t read_be32(const uint8_t *p)` that works on any host without knowing its endianness. Why is this better than `bswap32(*(uint32_t *)p)`? (Alignment, strict aliasing.)
- How can you detect the host's endianness at run time? And at compile time? (`__BYTE_ORDER__`.)
- Swap the nibbles of every byte of a `uint32_t` at once: `((x & 0x0F0F0F0F) << 4) | ((x >> 4) & 0x0F0F0F0F)`.
- Convert a packed-BCD byte from an RTC (for example `0x59` = 59 seconds) to binary and back.
