@@@ meta
id: BIT-M-08
topic: Bit Manipulation
difficulty: Medium
type: PREDICT_OUTPUT
title: Sign Extension of a Plain char UART Buffer
tags: embedded, sign-extension, char-signedness, integer-promotion, uart, byte-assembly
@@@ statement_md
A UART driver stores received bytes in a plain `char` array, and the protocol parser assembles 16-bit values from it. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**. On this platform plain `char` is **signed** (8-bit two's complement), and gcc converts out-of-range values to signed types modulo 256.

```c
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    char rx[4] = { 0x12, (char)0x80, (char)0xFF, 0x34 };

    uint16_t v1 = (uint16_t)((rx[0] << 8) | rx[1]);
    uint16_t v2 = (uint16_t)((rx[0] << 8) | (uint8_t)rx[1]);
    uint32_t w  = (uint32_t)rx[2];

    printf("%04X %04X\n", (unsigned)v1, (unsigned)v2);
    printf("%08X %X\n", (unsigned)w, (unsigned)(rx[2] & 0xFF));
    printf("%d %d\n", rx[1] == 0x80, rx[1] == (char)0x80);
    printf("%d\n", rx[2] + rx[3]);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 gcc, plain `char` is signed. (On ARM gcc, plain `char` is unsigned, so the same code prints something else.)
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    char rx[4] = { 0x12, (char)0x80, (char)0xFF, 0x34 };

    uint16_t v1 = (uint16_t)((rx[0] << 8) | rx[1]);
    uint16_t v2 = (uint16_t)((rx[0] << 8) | (uint8_t)rx[1]);
    uint32_t w  = (uint32_t)rx[2];

    printf("%04X %04X\n", (unsigned)v1, (unsigned)v2);
    printf("%08X %X\n", (unsigned)w, (unsigned)(rx[2] & 0xFF));
    printf("%d %d\n", rx[1] == 0x80, rx[1] == (char)0x80);
    printf("%d\n", rx[2] + rx[3]);
    return 0;
}
@@@ predict_answer
FF80 1280
FFFFFFFF FF
0 1
51
@@@ hint
`rx[1]` holds the bit pattern `0x80`, but as a signed `char` its value is -128. When it is promoted to `int` for `|`, it becomes `0xFFFFFF80`. Which bits does that OR into the high byte?
@@@ hint
`0x80` in source code is the `int` 128. A signed `char` can never equal 128. `(char)0x80`, however, is -128 again. And `0xFF` stored in a signed `char` is -1.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    /* rx[1] = (char)0x80 = -128, rx[2] = (char)0xFF = -1 (implementation-defined conversion) */
    char rx[4] = { 0x12, (char)0x80, (char)0xFF, 0x34 };

    /* rx[0] << 8 = 0x00001200 (positive: no UB)
       rx[1] promotes to int -128 = 0xFFFFFF80 -> OR overwrites the high byte with ones
       0xFFFFFF80 -> (uint16_t) 0xFF80 */
    uint16_t v1 = (uint16_t)((rx[0] << 8) | rx[1]);
    /* casting to uint8_t first: 0x80 -> int 128 -> 0x1200 | 0x80 = 0x1280 */
    uint16_t v2 = (uint16_t)((rx[0] << 8) | (uint8_t)rx[1]);
    /* -1 converted to uint32_t = 0xFFFFFFFF (sign extension, then modulo 2^32) */
    uint32_t w  = (uint32_t)rx[2];

    printf("%04X %04X\n", (unsigned)v1, (unsigned)v2);          /* FF80 1280 */
    /* masking the promoted value recovers the raw byte: 0xFFFFFFFF & 0xFF = 0xFF */
    printf("%08X %X\n", (unsigned)w, (unsigned)(rx[2] & 0xFF)); /* FFFFFFFF FF */
    /* -128 == 128 is false; -128 == (char)0x80 == -128 is true */
    printf("%d %d\n", rx[1] == 0x80, rx[1] == (char)0x80);     /* 0 1 */
    /* -1 + 52 = 51, not 0xFF + 0x34 = 307 */
    printf("%d\n", rx[2] + rx[3]);                               /* 51 */
    return 0;
}
@@@ explanation_md
**Answer**
```
FF80 1280
FFFFFFFF FF
0 1
51
```

**What happens.** Whether plain `char` is signed is implementation-defined (C11 6.2.5p15). On x86-64 it is signed, so bytes `0x80..0xFF` hold the values `-128..-1`. Every operator promotes `char` to `int` first, and promotion preserves the **value**, so -128 becomes `0xFFFFFF80`. The leading ones are the sign extension.

| expression | promoted operands | result |
|---|---|---|
| `(rx[0] << 8) \| rx[1]` | `0x00001200 \| 0xFFFFFF80` | `0xFFFFFF80`, then `(uint16_t)` gives `FF80` (the high byte is destroyed) |
| `(rx[0] << 8) \| (uint8_t)rx[1]` | `0x00001200 \| 0x00000080` | `1280` (correct) |
| `(uint32_t)rx[2]` | -1 | `FFFFFFFF` |
| `rx[2] & 0xFF` | `0xFFFFFFFF & 0xFF` | `FF` (masking undoes the sign extension) |
| `rx[1] == 0x80` | `-128 == 128` | 0 |
| `rx[2] + rx[3]` | `-1 + 52` | 51 |

The program has no UB, but note the near-miss: if `rx[0]` were `>= 0x80`, then `rx[0] << 8` would left-shift a **negative** `int`. That is undefined (C11 6.5.7p4).

**Complexity.** N/A.

**Common mistakes**
- Using `char` for binary data. Use `uint8_t` (or `unsigned char`) for every byte buffer: UART, SPI, CAN payloads, file data.
- Checking a protocol byte with `if (rx[i] == 0xAA)`. With signed `char` this is never true, and gcc's `-Wtype-limits` warns "comparison is always false".
- "Fixing" sign extension with a cast to a **wider signed** type (`(int)rx[1]`). That keeps the sign extension. Cast to an **unsigned byte** type first.
- Assuming the bug will show up on the PC simulator. On ARM gcc, plain `char` is *unsigned*, so this exact code prints `1280 1280`, `000000FF FF`, `1 1` and `307`. The same source behaves differently on target and host.

**Interview follow-ups**
- What do `-fsigned-char` / `-funsigned-char` do, and why should portable code never depend on either?
- Write `uint16_t get_be16(const uint8_t *p)` and `int16_t get_be16_signed(const uint8_t *p)` without any implementation-defined behaviour.
- `getchar()` returns `int`, not `char`. Why does storing it in a `char` break the `EOF` check on one platform and binary data on the other?
- MISRA C:2012 Rule 10.1 / the essential type model: which category is plain `char`, and why can't you use it in arithmetic?
