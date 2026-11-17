@@@ meta
id: BIT-M-04
topic: Bit Manipulation
difficulty: Medium
type: FUNCTION
title: Sign-Extend an N-Bit Two's Complement Sensor Value
tags: embedded, sign-extension, twos-complement, adc, sensors, undefined-behavior
@@@ statement_md
Sensors rarely deliver nice 32-bit integers:
- a TMP102 temperature sensor returns a **12-bit** two's complement value,
- an ADS1220 ADC returns **24-bit** two's complement samples,
- a MEMS accelerometer packs **10-bit** signed axes,
- a CAN DBC defines signed signals of any length.

The driver reads the raw bits into a `uint32_t`, where only the low `bits` bits are meaningful and the bits above them may contain garbage from neighbouring fields. Implement:

```c
int32_t sign_extend(uint32_t raw, unsigned bits);   /* bits in 1..32 */
```

It interprets the low `bits` bits of `raw` as a two's complement number and returns its value. Bit `bits-1` is the sign bit.

| raw | bits | result |
|---|---|---|
| `0x7FF` | 12 | 2047 |
| `0x800` | 12 | -2048 |
| `0xABCD0F38` | 12 | -200 (only `0xF38` counts) |
| `0x1` | 1 | -1 |
| `0x80000000` | 32 | -2147483648 |

The judge runs with UBSan. Left-shifting a negative value, signed overflow, and shifting by 32 are all undefined behavior.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `raw bits` (`raw` in hex, `bits` in decimal).

**Output**
- One line per query: the result as a signed decimal.

**Example**
```
Input:
3
7FF 12
800 12
ABCD0F38 12

Output:
2047
-2048
-200
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= bits <= 32`, `0 <= raw <= 0xFFFFFFFF`
- The result always fits in `int32_t`.
@@@ starter_code
#include <stdint.h>

int32_t sign_extend(uint32_t raw, unsigned bits)
{
    /* TODO: bits is 1..32; ignore raw's bits at positions >= bits */
    return (int32_t)raw;
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
        unsigned raw, bits;
        if (scanf("%x %u", &raw, &bits) != 2 || bits < 1u || bits > 32u) return 0;
        printf("%d\n", (int)sign_extend(raw, bits));
    }
    return 0;
}
@@@ sample_input
3
7FF 12
800 12
ABCD0F38 12
@@@ sample_output
2047
-2048
-200

@@@ sample_input
3
FFFFFF 24
800000 24
190 12
@@@ sample_output
-1
-8388608
400

@@@ hidden_input
3
80000000 32
7FFFFFFF 32
FFFFFFFF 32
@@@ hidden_output
-2147483648
2147483647
-1

@@@ hidden_input
3
1 1
0 1
FFFFFFFE 1
@@@ hidden_output
-1
0
0

@@@ hidden_input
4
3FF 10
200 10
1FF 10
FFFFFC00 10
@@@ hidden_output
-1
-512
511
0

@@@ hidden_input
4
8000 16
12348000 16
7FFF 16
C0000000 31
@@@ hidden_output
-32768
-32768
32767
-1073741824

@@@ hidden_input
4
2 2
3 2
1 2
FFF 12
@@@ hidden_output
-2
-1
1
-1

@@@ hidden_input
3
7FFFFF 24
0 12
FF800001 24
@@@ hidden_output
8388607
0
-8388607

@@@ hint
First throw away the garbage bits above the field with a mask of `bits` ones. Careful: `(1u << bits) - 1` is undefined for `bits == 32`. Then look at the sign bit, `1u << (bits - 1)`.
@@@ hint
A neat UB-free trick: with `m = 1u << (bits - 1)`, the value is `(raw ^ m) - m`, computed in unsigned arithmetic. If you want to avoid the implementation-defined unsigned-to-signed conversion entirely, return `-(int32_t)(~raw & mask) - 1` for negative values.
@@@ solution_code
#include <stdint.h>

int32_t sign_extend(uint32_t raw, unsigned bits)
{
    /* mask of `bits` ones without ever shifting by 32 */
    uint32_t mask = 0xFFFFFFFFu >> (32u - bits);
    uint32_t sign = 1u << (bits - 1u);

    raw &= mask;                         /* drop garbage above the field */
    if ((raw & sign) == 0u)
        return (int32_t)raw;             /* non-negative: value fits, no conversion issue */

    /* negative: value = -(2^bits - raw) = -((~raw & mask) + 1).
       ~raw & mask <= 2^31 - 1, so negating it and subtracting 1 never overflows. */
    return -(int32_t)(~raw & mask) - 1;
}
@@@ explanation_md
**Approach.**
1. **Mask** the field. `0xFFFFFFFF >> (32 - bits)` builds `bits` ones with a shift count of `0..31`. The usual `(1u << bits) - 1` is UB for `bits = 32` (C11 6.5.7p3).
2. **Test the sign bit** `1u << (bits - 1)`. If it is clear, the value is just `raw`.
3. **Negative values.** In two's complement, a negative n-bit pattern `raw` represents `raw - 2^bits` = `-((~raw & mask) + 1)`. The magnitude `~raw & mask` is at most `2^31 - 1`, so `-(int32_t)magnitude - 1` cannot overflow, even for `INT32_MIN`.

```
raw = 0xF38, bits = 12
~raw & 0xFFF = 0x0C7 = 199  ->  -199 - 1 = -200
```

Two other well-known forms:
- `(int32_t)((raw ^ m) - m)` with `m = 1u << (bits - 1)`. Everything stays unsigned until the final conversion. That conversion is implementation-defined for values above `INT32_MAX` (gcc and clang wrap, as they do on every two's complement target), but not undefined.
- `((int32_t)(raw << (32 - bits))) >> (32 - bits)`. This relies on two implementation-defined behaviours (the conversion and an arithmetic right shift) and needs care for `bits = 32`. It is common in production code, but it is not strictly portable.

**Complexity.** O(1) time and space.

**Common mistakes**
- `((int32_t)raw << (32 - bits)) >> (32 - bits)`. Left-shifting a value into or past the sign bit of a **signed** type is UB (C11 6.5.7p4). UBSan flags it for `raw = 0x800, bits = 12`.
- `raw | ~mask` built from `mask = (1u << bits) - 1`. That is UB for `bits = 32`.
- Not masking first. Garbage bits above the field (the `0xABCD0F38` case) leak into the result.
- Testing the sign with `raw & (1 << (bits - 1))` using a plain `int` `1`. For `bits = 32`, this is `1 << 31`, which is UB.

**Interview follow-ups**
- C bit-fields can do this too: `struct { int32_t v : 12; } s; s.v = raw;`. Why is this implementation-defined, and what does MISRA say about signed bit-fields?
- The TMP102 returns `0xE70` in its 12-bit register. What temperature is that at 0.0625 °C/LSB?
- Sign-extend into an `int64_t` for 1..64-bit CAN signals. Which constants must become 64-bit?
- How does the ARM `SBFX` (signed bit-field extract) instruction do mask + shift + sign extension in one cycle?
