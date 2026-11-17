@@@ meta
id: BIT-M-10
topic: Bit Manipulation
difficulty: Medium
type: FIND_THE_BUG
title: Big-Endian Frame Parser With an Overflowing Byte Shift
tags: embedded, endianness, integer-promotion, undefined-behavior, ubsan, byte-assembly, asked-in-automotive
@@@ statement_md
A wheel-speed sensor sends 8-byte frames in **big-endian** (network) byte order:

| bytes | field | type |
|---|---|---|
| 0..3 | `ts`: timestamp in microseconds | `uint32_t` |
| 4..5 | `speed`: raw wheel speed | `uint16_t` |
| 6..7 | `temp`: temperature in 0.1 °C | `int16_t` (two's complement) |

The parser assembles the fields byte by byte so that it works on any host endianness. It passed every bench test, but on the endurance rig the sanitizer build stops with a **runtime error** as soon as the timestamp passes 35 minutes (about 2^31 microseconds). On some targets, timestamps from then on are garbage.

Find and fix the bug. Do not change the output format.

**Input**
- Line 1: `n`, the number of frames.
- Next `n` lines: 8 bytes in hex.

**Output**
- One line per frame: `ts=<unsigned> speed=<unsigned> temp=<signed>`.

**Example**
```
Input:
1
00 00 12 34 05 DC 09 C4

Output:
ts=4660 speed=1500 temp=2500
```
@@@ constraints_md
- `1 <= n <= 100`
- Every byte value `0x00..0xFF` may appear in any position.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

static uint32_t get_be32(const uint8_t *p)
{
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

static uint16_t get_be16(const uint8_t *p)
{
    return (uint16_t)((p[0] << 8) | p[1]);
}

static int get_be16_signed(const uint8_t *p)
{
    int v = get_be16(p);
    return v >= 0x8000 ? v - 0x10000 : v;      /* portable two's complement decode */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int f = 0; f < n; f++) {
        uint8_t frame[8];
        for (int i = 0; i < 8; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            frame[i] = (uint8_t)b;
        }
        uint32_t ts = get_be32(&frame[0]);
        unsigned speed = get_be16(&frame[4]);
        int temp = get_be16_signed(&frame[6]);
        printf("ts=%u speed=%u temp=%d\n", (unsigned)ts, speed, temp);
    }
    return 0;
}
@@@ sample_input
1
00 00 12 34 05 DC 09 C4
@@@ sample_output
ts=4660 speed=1500 temp=2500

@@@ sample_input
1
80 00 00 00 00 00 FF 38
@@@ sample_output
ts=2147483648 speed=0 temp=-200

@@@ hidden_input
1
FF FF FF FF FF FF 7F FF
@@@ hidden_output
ts=4294967295 speed=65535 temp=32767

@@@ hidden_input
1
7F FF FF FF 00 01 80 00
@@@ hidden_output
ts=2147483647 speed=1 temp=-32768

@@@ hidden_input
2
DE AD BE EF 12 34 00 00
01 02 03 04 AB CD FF FF
@@@ hidden_output
ts=3735928559 speed=4660 temp=0
ts=16909060 speed=43981 temp=-1

@@@ hidden_input
1
00 00 00 00 00 00 00 00
@@@ hidden_output
ts=0 speed=0 temp=0

@@@ hidden_input
1
C0 00 00 01 00 64 00 0A
@@@ hidden_output
ts=3221225473 speed=100 temp=10

@@@ hidden_input
3
00 FF FF FF 80 00 80 01
00 00 00 80 00 80 00 80
81 00 00 00 FF 00 FE 0C
@@@ hidden_output
ts=16777215 speed=32768 temp=-32767
ts=128 speed=128 temp=128
ts=2164260864 speed=65280 temp=-500

@@@ hint
`p[0]` is a `uint8_t`. What type does it have when the compiler evaluates `p[0] << 24`? What is `0x80 << 24` in that type?
@@@ hint
Integer promotion turns `uint8_t` into a **signed** `int`. Shifting a 1 into bit 31 of a signed `int` is undefined behavior (C11 6.5.7p4). Convert each byte to `uint32_t` **before** shifting.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

static uint32_t get_be32(const uint8_t *p)
{
    /* FIX: widen to uint32_t BEFORE shifting; p[0] alone would be promoted to (signed) int */
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static uint16_t get_be16(const uint8_t *p)
{
    return (uint16_t)((p[0] << 8) | p[1]);
}

static int get_be16_signed(const uint8_t *p)
{
    int v = get_be16(p);
    return v >= 0x8000 ? v - 0x10000 : v;      /* portable two's complement decode */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int f = 0; f < n; f++) {
        uint8_t frame[8];
        for (int i = 0; i < 8; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            frame[i] = (uint8_t)b;
        }
        uint32_t ts = get_be32(&frame[0]);
        unsigned speed = get_be16(&frame[4]);
        int temp = get_be16_signed(&frame[6]);
        printf("ts=%u speed=%u temp=%d\n", (unsigned)ts, speed, temp);
    }
    return 0;
}
@@@ explanation_md
**Bug.** In `p[0] << 24`, the `uint8_t` operand is promoted to **`int`**, not to `unsigned` (C11 6.3.1.1). For `p[0] >= 0x80`, the mathematical result (`0x80 << 24 = 2^31` and up) does not fit in a 32-bit `int`. C11 6.5.7p4 says a left shift of a signed value whose result is not representable is **undefined behavior**. The code therefore works for timestamps below `0x80000000` (about 35.8 minutes in µs) and breaks after that.
- UBSan: `left shift of 128 by 24 places cannot be represented in type 'int'`.
- Without a sanitizer, x86 usually produces the "expected" bit pattern by accident. But if the expression is later widened (for example, `uint64_t t = p[0] << 24 | ...`), the negative `int` is sign-extended to `0xFFFFFFFF80000000`. An optimiser may also assume the UB never happens.

**Fix.** Make the shift happen in an unsigned 32-bit type: `(uint32_t)p[0] << 24`. Strictly, only the byte that reaches bit 31 needs the cast (`p[1] << 16` is at most `0x00FF0000`), but casting every term is the MISRA-friendly, review-proof form. `get_be16` is fine because `0xFF << 8` fits easily in `int`.

**Complexity.** O(1) per field, O(n) per run, O(1) space.

**Common mistakes**
- Casting the **result** instead of the operand: `(uint32_t)(p[0] << 24)`. The UB has already happened inside the parentheses.
- "Fixing" it by reading the field with `*(uint32_t *)p` plus a byte swap. That has unaligned-access and strict-aliasing problems, and it is endian-dependent.
- Thinking `uint8_t` arithmetic is unsigned. After promotion, it is signed `int` arithmetic.
- The same bug in a 64-bit variant: `(uint64_t)p[0] << 56` is needed, and `(uint32_t)p[0] << 56` is a shift by `>=` 32 bits (UB).

**Interview follow-ups**
- Write `put_be32(uint8_t *p, uint32_t v)` (serialisation). Which casts are needed there?
- Why do MISRA C:2012 Rules 10.1 and 10.8 and CERT INT34-C exist? Which category does `uint8_t << 24` violate?
- How would you implement `get_be64` and `get_le64`, and what changes for a CAN FD payload of 64 bytes?
- On a 16-bit MCU (`int` = 16 bits), which shift in this file becomes undefined as well?
