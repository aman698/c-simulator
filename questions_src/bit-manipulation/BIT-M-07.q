@@@ meta
id: BIT-M-07
topic: Bit Manipulation
difficulty: Medium
type: PREDICT_OUTPUT
title: Right Shift of Signed vs Unsigned Values
tags: right-shift, arithmetic-shift, implementation-defined, int8-t, division
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**. gcc implements `>>` on negative signed values as an **arithmetic** shift, and converts out-of-range values to signed types modulo 2^N.

```c
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t u = 0x80;
    int8_t  s = (int8_t)0x80;
    int     n = -7;

    printf("%d %d\n", u >> 1, s >> 1);
    printf("%d %d\n", n >> 1, n / 2);
    printf("%d %u\n", -1 >> 31, (unsigned)-1 >> 28);
    printf("%X %X\n", (unsigned)(s >> 4), (unsigned)((uint8_t)s >> 4));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc. `int8_t` is `signed char`, `uint8_t` is `unsigned char`, both promoted to `int` before shifting.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t u = 0x80;
    int8_t  s = (int8_t)0x80;
    int     n = -7;

    printf("%d %d\n", u >> 1, s >> 1);
    printf("%d %d\n", n >> 1, n / 2);
    printf("%d %u\n", -1 >> 31, (unsigned)-1 >> 28);
    printf("%X %X\n", (unsigned)(s >> 4), (unsigned)((uint8_t)s >> 4));
    return 0;
}
@@@ predict_answer
64 -64
-4 -3
-1 15
FFFFFFF8 8
@@@ hint
Both `u` and `s` hold the bit pattern `1000 0000`, but promotion to `int` turns one into `128` and the other into `-128`. In gcc, `>>` on a negative `int` copies the sign bit in from the left.
@@@ hint
An arithmetic right shift by 1 divides by 2 rounding toward **minus infinity**. Integer division `/` rounds toward **zero** (C99 and later). They differ for negative odd numbers.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t u = 0x80;            /* 128 */
    int8_t  s = (int8_t)0x80;    /* implementation-defined conversion: -128 in gcc */
    int     n = -7;

    /* u -> int 128 >> 1 = 64;   s -> int -128 (0xFFFFFF80) >> 1 = 0xFFFFFFC0 = -64 */
    printf("%d %d\n", u >> 1, s >> 1);                   /* 64 -64 */

    /* -7 = ...11111001; arithmetic >> 1 = ...11111100 = -4 (floor of -3.5)
       -7 / 2 truncates toward zero = -3 */
    printf("%d %d\n", n >> 1, n / 2);                    /* -4 -3 */

    /* -1 >> 31 stays all ones = -1;  0xFFFFFFFF >> 28 = 0xF = 15 (logical shift) */
    printf("%d %u\n", -1 >> 31, (unsigned)-1 >> 28);     /* -1 15 */

    /* s >> 4: -128 >> 4 = -8 = 0xFFFFFFF8;  (uint8_t)s = 0x80 -> 128 >> 4 = 8 */
    printf("%X %X\n", (unsigned)(s >> 4), (unsigned)((uint8_t)s >> 4));   /* FFFFFFF8 8 */
    return 0;
}
@@@ explanation_md
**Answer**
```
64 -64
-4 -3
-1 15
FFFFFFF8 8
```

**The rules (C11 6.5.7p5).** `E1 >> E2` on an unsigned value, or a non-negative signed value, is a division by 2^E2 with zeros shifted in (a *logical* shift). If `E1` is **negative**, the result is **implementation-defined**. gcc, clang and every mainstream ARM compiler use an *arithmetic* shift, which copies the sign bit. It is not UB, so the program is valid, but it is not portable in theory.

1. Both bytes are `0x80`. Promotion to `int` decides everything: `uint8_t` becomes `0x00000080` (128), `int8_t` becomes `0xFFFFFF80` (-128). So `64` vs `-64`.
2. `-7 >> 1 = -4`, but `-7 / 2 = -3`. An arithmetic shift rounds toward minus infinity, and C division truncates toward zero. "Optimising" `x / 2` into `x >> 1` is therefore wrong for negative values. The compiler adds a fix-up instruction when it does this itself.
3. `-1 >> 31` is still `-1` (all ones). The cast to `unsigned` makes the shift logical: `0xFFFFFFFF >> 28 = 0xF`.
4. To get the "byte" behaviour you expected, cast to an **unsigned** type *before* shifting: `(uint8_t)s >> 4 == 8`.

**Complexity.** N/A. Each shift is one instruction (`SAR` vs `SHR` on x86, `ASR` vs `LSR` on ARM). The *type* picks the instruction.

**Common mistakes**
- Assuming `>>` on a signed byte behaves like an 8-bit unsigned shift. The value is promoted and sign-extended first.
- Replacing `/ 2^k` with `>> k` on signed data (for example, averaging signed ADC samples). Negative results are off by one.
- Mixing up implementation-defined behaviour (right-shifting negatives) with undefined behaviour (**left**-shifting negatives, or shifting by `>=` the width).

**Interview follow-ups**
- Write a portable arithmetic right shift that does not depend on implementation-defined behaviour. (Hint: `x < 0 ? ~(~x >> k) : x >> k`.)
- C23 now guarantees two's complement. Did it also make right shifts of negative values well defined?
- How would you compute the average of two `int32_t` values without overflow and with correct rounding for negatives?
- MISRA C:2012 Rule 10.1 forbids shifting signed operands. How would you rewrite a sign-extending sensor decoder to comply?
