@@@ meta
id: BIT-E-08
topic: Bit Manipulation
difficulty: Easy
type: PREDICT_OUTPUT
title: Integer Promotion of uint8_t with ~ and <<
tags: integer-promotion, uint8-t, bitwise-not, sizeof, misra
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t a = 0x0F;
    uint8_t b = ~a;
    uint8_t c = 0x80;

    if (~a == b)
        printf("equal\n");
    else
        printf("different\n");

    printf("%zu %zu %zu\n", sizeof a, sizeof ~a, sizeof(1 << 3));
    printf("%X %X\n", (unsigned)b, (unsigned)~a);
    printf("%X %X\n", (unsigned)((c << 1) >> 1), (unsigned)((uint8_t)(c << 1) >> 1));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, `uint8_t` is `unsigned char`, `int` is 32 bits.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t a = 0x0F;
    uint8_t b = ~a;
    uint8_t c = 0x80;

    if (~a == b)
        printf("equal\n");
    else
        printf("different\n");

    printf("%zu %zu %zu\n", sizeof a, sizeof ~a, sizeof(1 << 3));
    printf("%X %X\n", (unsigned)b, (unsigned)~a);
    printf("%X %X\n", (unsigned)((c << 1) >> 1), (unsigned)((uint8_t)(c << 1) >> 1));
    return 0;
}
@@@ predict_answer
different
1 4 4
F0 FFFFFFF0
80 0
@@@ hint
Before `~`, `<<`, `>>` or `==` is applied, every operand narrower than `int` is first converted to `int` (the *integer promotions*, C11 6.3.1.1). What is `~0x0000000F` as a 32-bit `int`?
@@@ hint
The result is only cut back to 8 bits when it is **stored** in (or cast to) a `uint8_t`. A comparison or a shift on the promoted value still sees all 32 bits.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    uint8_t a = 0x0F;
    uint8_t b = ~a;     /* ~(int)0x0F = 0xFFFFFFF0 (int -16), stored -> truncated to 0xF0 */
    uint8_t c = 0x80;

    /* ~a is the int -16 again; b is promoted to the int 240: -16 != 240 */
    if (~a == b)
        printf("equal\n");
    else
        printf("different\n");                 /* different */

    /* sizeof a = 1; ~a has type int -> 4; 1 << 3 is an int -> 4 */
    printf("%zu %zu %zu\n", sizeof a, sizeof ~a, sizeof(1 << 3));   /* 1 4 4 */

    /* b holds 0xF0; ~a as unsigned is 0xFFFFFFF0 */
    printf("%X %X\n", (unsigned)b, (unsigned)~a);                   /* F0 FFFFFFF0 */

    /* (int)0x80 << 1 = 0x100 keeps bit 8, >> 1 gives 0x80 back.
       Casting to uint8_t first drops bit 8: 0x00 >> 1 = 0. */
    printf("%X %X\n", (unsigned)((c << 1) >> 1), (unsigned)((uint8_t)(c << 1) >> 1)); /* 80 0 */
    return 0;
}
@@@ explanation_md
**Answer**
```
different
1 4 4
F0 FFFFFFF0
80 0
```

**Rule:** in C, arithmetic and bitwise operators never operate on types narrower than `int`. A `uint8_t` operand is first promoted to `int` (C11 6.3.1.1p2), the operator works on 32 bits, and the result has type `int`. The value is only truncated when it is stored into a narrower object or explicitly cast.

- `~a` = `~0x0000000F` = `0xFFFFFFF0`, which is the `int` **-16**. Stored into `b`, it becomes `0xF0` (240).
- `~a == b` compares `-16` with `240`: **different**. This is the classic "my checksum complement check never matches" bug.
- `sizeof ~a` is `sizeof(int)` = 4. So is `sizeof(1 << 3)`. Only `sizeof a` is 1.
- `(c << 1) >> 1`: `0x80` becomes `0x100` in an `int`, so nothing is lost, and shifting back gives `0x80`. Programmers who think in 8 bits expect 0.

**Complexity.** N/A. These are compile-time type rules.

**Common mistakes**
- Checking an inverted copy with `if (~stored == original)` on `uint8_t`/`uint16_t` data (common in safety-critical "redundant variable" patterns). Write `if ((uint8_t)~stored == original)`.
- Expecting `x << n` on a `uint8_t` to drop the high bits automatically. It does not until you cast or assign.
- Shifting a promoted `uint8_t` into bit 31: `(uint8_t)0x80 << 24` is an `int` shift that overflows, which is undefined behavior. Cast to `uint32_t` first.

**Interview follow-ups**
- MISRA C:2012 Rule 10.1/10.4 and the **essential type** model: how would MISRA have you write `uint8_t b = ~a;`?
- On a 16-bit MCU (`int` = 16 bits, for example MSP430), what is `sizeof ~a`, and does `uint16_t` get promoted to `int`?
- Why is `uint16_t x = 0xFFFF; x * x` undefined behavior on a 32-bit target but not on a 16-bit one?
