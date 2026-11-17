@@@ meta
id: STR-H-07
topic: Strings
difficulty: Hard
type: PREDICT_OUTPUT
title: Plain char Bytes in a Checksum, a Compare and a Shift
tags: embedded, char-signedness, sign-extension, integer-promotion, checksum, implementation-defined
@@@ statement_md
A UART driver stores received bytes in a plain `char` buffer, and the protocol code computes an 8-bit additive checksum and inspects a status byte. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, plain `char` is signed (8 bits, two's complement)**.

```c
#include <stdio.h>

int main(void)
{
    char frame[] = { 0x10, (char)0xF0, 0x7F, (char)0x80 };
    int sum = 0;
    unsigned int usum = 0;

    for (int i = 0; i < 4; i++) {
        sum  += frame[i];
        usum += (unsigned char)frame[i];
    }

    char c = (char)0xE9;

    printf("%d %u\n", sum, usum);
    printf("%d %d\n", c, (unsigned char)c);
    printf("%x\n", (unsigned int)c);
    printf("%d\n", c == 0xE9);
    printf("%d %d\n", c >> 4, (unsigned char)c >> 4);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc. `char` is signed; conversion of an out-of-range value to `char` wraps modulo 256 (gcc's documented implementation-defined behavior), and `>>` on a negative `int` is an arithmetic shift.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    char frame[] = { 0x10, (char)0xF0, 0x7F, (char)0x80 };
    int sum = 0;
    unsigned int usum = 0;

    for (int i = 0; i < 4; i++) {
        sum  += frame[i];
        usum += (unsigned char)frame[i];
    }

    char c = (char)0xE9;

    printf("%d %u\n", sum, usum);
    printf("%d %d\n", c, (unsigned char)c);
    printf("%x\n", (unsigned int)c);
    printf("%d\n", c == 0xE9);
    printf("%d %d\n", c >> 4, (unsigned char)c >> 4);
    return 0;
}
@@@ predict_answer
-1 511
-23 233
ffffffe9
0
-2 14
@@@ hint
Convert every byte to its **signed** value first: `0xF0` stored in a signed `char` is `-16`, `0x80` is `-128`, `0xE9` is `-23`. In every expression, a `char` is promoted to `int` **with its sign** before the arithmetic happens.
@@@ hint
`(unsigned int)c` converts the `int` value `-23` modulo 2^32, which gives `0xFFFFFFE9`. `c == 0xE9` compares `-23` with `233`. `c >> 4` shifts the promoted `int` `-23` (arithmetic shift in gcc), whereas `(unsigned char)c >> 4` shifts `233`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    /* stored values (signed char): 16, -16, 127, -128 */
    char frame[] = { 0x10, (char)0xF0, 0x7F, (char)0x80 };
    int sum = 0;
    unsigned int usum = 0;

    for (int i = 0; i < 4; i++) {
        sum  += frame[i];                   /* 16 - 16 + 127 - 128 = -1       */
        usum += (unsigned char)frame[i];    /* 16 + 240 + 127 + 128 = 511      */
    }

    char c = (char)0xE9;                    /* 233 does not fit: c == -23      */

    printf("%d %u\n", sum, usum);                       /* -1 511              */
    printf("%d %d\n", c, (unsigned char)c);             /* -23 233             */
    printf("%x\n", (unsigned int)c);                    /* -23 mod 2^32 = ffffffe9 */
    printf("%d\n", c == 0xE9);                          /* -23 == 233 -> 0     */
    printf("%d %d\n", c >> 4, (unsigned char)c >> 4);   /* -23>>4 = -2 (arith), 233>>4 = 14 */
    return 0;
}
@@@ explanation_md
**Answer**
```
-1 511
-23 233
ffffffe9
0
-2 14
```

On x86-64, plain `char` is **signed** (on most ARM Linux ABIs it is unsigned). Bytes `0x80..0xFF` are stored as `-128..-1`, and every use of a `char` in an expression first promotes it to `int` **with sign extension**:

| expression | value | why |
|---|---|---|
| `sum` | `-1` | `16 + (-16) + 127 + (-128)` |
| `usum` | `511` | `16 + 240 + 127 + 128` after the `unsigned char` cast |
| `c` | `-23` | `0xE9 - 256` |
| `(unsigned int)c` | `0xFFFFFFE9` | the `int` `-23` taken modulo 2^32: the sign-extended byte |
| `c == 0xE9` | `0` | `0xE9` is the `int` 233, and `-23 != 233`, so this test can **never** be true |
| `c >> 4` | `-2` | arithmetic shift of `-23` (implementation-defined; gcc shifts in sign bits) |
| `(unsigned char)c >> 4` | `14` | `233 >> 4`: the high nibble `0xE` you actually wanted |

Nothing here is undefined: out-of-range conversion to a signed type and right-shifting a negative value are **implementation-defined**, and gcc documents both. That is exactly why the same source behaves differently on an ARM target where `char` is unsigned.

**Complexity.** N/A. The cost is correctness, not speed: a checksum over `char` bytes differs from the one over `uint8_t` bytes as soon as any byte is `>= 0x80`.

**Common mistakes**
- Expecting `sum` to equal `usum`. They only agree when all bytes are below `0x80`, which is why ASCII-only tests never catch this.
- Thinking `c == 0xE9` is true because "the bits are the same". The comparison happens on promoted `int` values. gcc even warns: *comparison is always false due to limited range of data type*.
- Printing a byte with `printf("%02x", c)` and getting `ffffffe9`. Use `uint8_t` or cast to `unsigned char` first.
- Extracting a nibble with `c >> 4` for a hex dump or a lookup table: the index is `-2`, which is out of bounds.

**Interview follow-ups**
- Why do automotive coding standards (MISRA C:2012 Rules 10.1 and 10.3, the "essential type" model) forbid arithmetic on plain `char`, and require `uint8_t` for raw data?
- What do `-fsigned-char` and `-funsigned-char` change, and why can porting code from x86 to an ARM Linux target flip the results above?
- Compute a correct 8-bit two's-complement checksum (`(uint8_t)(0x100 - (sum & 0xFF))`) over a `const char *` buffer without any sign-extension issue.
