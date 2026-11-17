@@@ meta
id: BIT-H-07
topic: Bit Manipulation
difficulty: Hard
type: PREDICT_OUTPUT
title: Full-Width Mask Built With an Unsigned Shift
tags: undefined-behavior, shift-width, masks, portability, ubsan
@@@ statement_md
A colleague wrote a helper that builds a mask of `len` low ones. They used `1u` "so the shift is unsigned and therefore safe". What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdint.h>

static uint32_t low_mask(unsigned len)
{
    return (1u << len) - 1u;
}

int main(void)
{
    unsigned lens[] = { 1, 12, 31, 32 };
    for (int i = 0; i < 4; i++)
        printf("len=%u mask=%08X\n", lens[i], (unsigned)low_mask(lens[i]));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, `unsigned int` is 32 bits wide.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

static uint32_t low_mask(unsigned len)
{
    return (1u << len) - 1u;
}

int main(void)
{
    unsigned lens[] = { 1, 12, 31, 32 };
    for (int i = 0; i < 4; i++)
        printf("len=%u mask=%08X\n", lens[i], (unsigned)low_mask(lens[i]));
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
The first three calls are fine: `1u << 31` is a perfectly valid unsigned shift. Look at the last element of `lens`, and at the width of the left operand.
@@@ hint
C11 6.5.7p3: "If the value of the right operand is negative or is greater than or equal to the width of the promoted left operand, the behavior is undefined." This applies to unsigned operands too.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

static uint32_t low_mask(unsigned len)
{
    /* len = 32: 1u << 32 shifts by the full width of unsigned int -> UNDEFINED (C11 6.5.7p3).
       Unsigned only protects you from overflow of the RESULT (bits shifted out are discarded),
       not from an out-of-range shift COUNT. */
    return (1u << len) - 1u;
}

/* A safe version:  return len >= 32u ? 0xFFFFFFFFu : (1u << len) - 1u;
   or branch-free:  return 0xFFFFFFFFu >> (32u - len);   for 1 <= len <= 32 */

int main(void)
{
    unsigned lens[] = { 1, 12, 31, 32 };
    for (int i = 0; i < 4; i++)
        printf("len=%u mask=%08X\n", lens[i], (unsigned)low_mask(lens[i]));
    /* len=1 mask=00000001, len=12 mask=00000FFF, len=31 mask=7FFFFFFF,
       then UB: UBSan reports "shift exponent 32 is too large for 32-bit type 'unsigned int'" */
    return 0;
}
@@@ explanation_md
**Answer: Undefined Behavior.**

The first three lines would print `00000001`, `00000FFF` and `7FFFFFFF`. The fourth call evaluates `1u << 32`. For shifts, C11 6.5.7p3 says:

> If the value of the right operand is negative or is greater than or equal to the width of the promoted left operand, the behavior is undefined.

This has nothing to do with signedness. Using `unsigned` makes *overflowing bits* well defined (they are discarded), but the **shift count** must still be in `0..31` for a 32-bit operand. In practice, the results differ by target:

| where | `1u << 32` | `low_mask(32)` |
|---|---|---|
| x86 `SHL` (count masked to 5 bits) | `1u << 0 = 1` | `0x00000000` |
| ARM `LSL` by register (uses the low byte, counts >= 32 give 0) | `0` | `0xFFFFFFFF` |
| gcc/clang constant folding after inlining | anything, the branch can be deleted | anything |
| judge with UBSan | runtime error: *shift exponent 32 is too large* | — |

So the same code gives "mask = 0" on the PC unit test and "mask = all ones" on the ECU. That is exactly the kind of host/target divergence that escapes to the vehicle.

**Complexity.** N/A (O(1) helper).

**Common mistakes**
- Believing `1u`/`uint32_t` makes every shift safe. It only fixes the `1 << 31` signed-overflow problem (C11 6.5.7p4), not the count range.
- "It's fine on x86, we tested it." Your test proves the x86 behaviour, not C.
- Fixing it with `(1ull << len) - 1` for `len <= 32`. This works, but it only moves the cliff to `len == 64`, which the 64-bit version of the same helper (CAN signals, 64-bit registers) will hit.

**Interview follow-ups**
- Write a `low_mask` that is correct for `len` in `0..32` without branches. (`len == 0` needs care too: `0xFFFFFFFF >> 32` is also UB.)
- Is `x >> 32` on a `uint64_t` defined? What about `x << 32` on a `uint32_t` that was promoted from `uint16_t`?
- Why does gcc warn about `1u << 32` with a constant (`-Wshift-count-overflow`) but say nothing for a variable count? Which tools catch it statically (MISRA C:2012 Rule 12.2, Polyspace, `-fsanitize=shift`)?
- Where else in embedded code do variable shift counts come from data (DBC signal lengths, bit-field widths from configuration) and need range checks?
