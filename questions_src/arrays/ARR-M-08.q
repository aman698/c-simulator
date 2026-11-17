@@@ meta
id: ARR-M-08
topic: Arrays
difficulty: Medium
type: PREDICT_OUTPUT
title: Signed vs Unsigned Traps in Array Index Math
tags: embedded, integer-promotion, signed-unsigned, sizeof, ring-buffer-index, misra
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `size_t` = 8 bytes (unsigned)**, two's complement integers.

```c
#include <stdio.h>
#include <stdint.h>

static const uint8_t lut[8] = {0, 10, 20, 30, 40, 50, 60, 70};

int main(void)
{
    int a[] = {1, 2, 3, 4, 5};
    int count = 0;
    for (int i = -1; i < sizeof a / sizeof a[0]; i++)
        count++;
    printf("%d\n", count);

    uint8_t x = 200, y = 100;
    uint8_t sum8 = x + y;
    printf("%u %d\n", (unsigned)sum8, x + y);

    uint8_t head = 2, tail = 5;
    printf("%d %u\n", head - tail, (unsigned)(uint8_t)(head - tail));
    printf("%u\n", (unsigned)lut[(head - tail) & 7]);

    unsigned idx = 3;
    printf("%u\n", (unsigned)lut[(idx - 4u) % 8u]);

    int k = -1;
    puts(k < sizeof lut ? "in range" : "out of range");
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc. `sizeof` yields `size_t` (`unsigned`, 64-bit).
- `-Wall -Wextra` prints `-Wsign-compare` warnings for this program; it still compiles and runs.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

static const uint8_t lut[8] = {0, 10, 20, 30, 40, 50, 60, 70};

int main(void)
{
    int a[] = {1, 2, 3, 4, 5};
    int count = 0;
    for (int i = -1; i < sizeof a / sizeof a[0]; i++)
        count++;
    printf("%d\n", count);

    uint8_t x = 200, y = 100;
    uint8_t sum8 = x + y;
    printf("%u %d\n", (unsigned)sum8, x + y);

    uint8_t head = 2, tail = 5;
    printf("%d %u\n", head - tail, (unsigned)(uint8_t)(head - tail));
    printf("%u\n", (unsigned)lut[(head - tail) & 7]);

    unsigned idx = 3;
    printf("%u\n", (unsigned)lut[(idx - 4u) % 8u]);

    int k = -1;
    puts(k < sizeof lut ? "in range" : "out of range");
    return 0;
}
@@@ predict_answer
0
44 300
-3 253
50
70
out of range
@@@ hint
`sizeof` yields an **unsigned** `size_t`. When a signed `int` is compared with it, the `int` is converted to unsigned first. What does `-1` become?
@@@ hint
`uint8_t` operands are **promoted to `int`** before any arithmetic. `x + y` is 300 as an `int`; it only wraps when stored back into a `uint8_t`. `head - tail` is the `int` `-3`, not 253.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

static const uint8_t lut[8] = {0, 10, 20, 30, 40, 50, 60, 70};

int main(void)
{
    int a[] = {1, 2, 3, 4, 5};
    int count = 0;
    /* i < (size_t)5: i is converted to size_t, -1 -> 18446744073709551615 -> false at once */
    for (int i = -1; i < sizeof a / sizeof a[0]; i++)
        count++;
    printf("%d\n", count);                                     /* 0 */

    uint8_t x = 200, y = 100;
    uint8_t sum8 = x + y;              /* int 300, stored mod 256 -> 44 */
    printf("%u %d\n", (unsigned)sum8, x + y);                  /* 44 300 */

    uint8_t head = 2, tail = 5;
    /* promoted to int: 2 - 5 = -3; converted to uint8_t: 256 - 3 = 253 */
    printf("%d %u\n", head - tail, (unsigned)(uint8_t)(head - tail));  /* -3 253 */
    /* -3 & 7: two's complement ...11111101 & 00000111 = 5 -> lut[5] */
    printf("%u\n", (unsigned)lut[(head - tail) & 7]);          /* 50 */

    unsigned idx = 3;
    /* unsigned wrap: 3u - 4u = 4294967295, % 8 = 7 -> lut[7] */
    printf("%u\n", (unsigned)lut[(idx - 4u) % 8u]);            /* 70 */

    int k = -1;
    /* k converted to size_t -> huge, so the comparison is false */
    puts(k < sizeof lut ? "in range" : "out of range");        /* out of range */
    return 0;
}
@@@ explanation_md
**Answer:**
```
0
44 300
-3 253
50
70
out of range
```

**Rules at work**
1. **Usual arithmetic conversions** (C11 6.3.1.8). With `int < size_t`, the `int` is converted to the unsigned type. `-1` becomes `SIZE_MAX`, so `-1 < 5u` is **false** and the loop body never runs. The same rule gives `k < sizeof lut` false, so `-1` is reported "out of range" even though it is less than 8.
2. **Integer promotion** (C11 6.3.1.1p2). `uint8_t` operands are promoted to `int` before `+` or `-`. `200 + 100` is the `int` 300, which wraps to `44` only when assigned to `uint8_t`. `head - tail` is the `int` `-3`.
3. **Converting to an unsigned type is modular** (C11 6.3.1.3p2): `(uint8_t)-3 == 253`, and `3u - 4u == UINT_MAX`.
4. `(head - tail) & 7` on the `int -3` gives `5` in two's complement. It looks like ring-buffer math "working by accident". With `head = 2, tail = 5` in an 8-slot buffer the fill level really is `(2 - 5) mod 8 = 5`. But `% 8` on the signed `-3` would give `-3`, a negative index, which is UB.

**Complexity.** N/A. These are compile-time typing rules with no runtime cost.

**Common mistakes**
- Expecting the loop to run 6 times. Signed/unsigned comparison is one of the most common causes of "loop never executes" and "bounds check always passes" bugs. Never ignore `-Wsign-compare`.
- Believing `uint8_t` arithmetic happens in 8 bits. It happens in `int`, and the truncation occurs only at the assignment.
- Mixing `&` and `%` for wrap-around. `& (N-1)` works for power-of-two `N` even on negative intermediates (two's complement); `%` on a negative `int` yields a negative remainder.

**Interview follow-ups**
- Why does MISRA C:2012 (essential type model, Rules 10.1-10.8) forbid mixing signed and unsigned operands, and how would you rewrite the loop? (`for (size_t i = 0; i < ARRAY_SIZE(a); i++)`.)
- On a 16-bit MCU where `int` is 16 bits, what does `uint16_t u = 40000; u * 2` do? (`uint16_t` promotes to `unsigned int`, so it wraps modulo 65536 without UB. On 32-bit targets, `uint16_t * uint16_t` can be **signed** overflow: `65535 * 65535` overflows `int`.)
- Rewrite a ring-buffer "fill level" computation that is correct for any buffer size `N`. (`(head - tail + N) % N` with unsigned indices, or free-running counters with unsigned subtraction.)
