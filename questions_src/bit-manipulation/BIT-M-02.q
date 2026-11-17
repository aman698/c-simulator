@@@ meta
id: BIT-M-02
topic: Bit Manipulation
difficulty: Medium
type: FUNCTION
title: Rotate Left and Right by Any Count Without Undefined Behavior
tags: embedded, rotate, shifts, undefined-behavior, uds, security-access
@@@ statement_md
A UDS **SecurityAccess (0x27)** seed-to-key algorithm in your ECU uses 32-bit rotations, with a rotation count derived from the seed itself. That count can be **0**, **32** or any other value. Implement:

```c
uint32_t rotl32(uint32_t x, unsigned n);   /* rotate left by n positions  */
uint32_t rotr32(uint32_t x, unsigned n);   /* rotate right by n positions */
```

A rotation by `n` is the same as a rotation by `n % 32`, so `rotl32(x, 0) == rotl32(x, 32) == x`. Bits shifted out at one end come back in at the other end:
`rotl32(0x80000001, 1) = 0x00000003`, `rotr32(0x12345678, 4) = 0x81234567`.

The judge runs with UBSan. **Any** shift of a 32-bit value by 32 or more positions is undefined behavior (C11 6.5.7p3) and is reported as a runtime error, even if the result would be masked away.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines:
  - `L x n`: print `rotl32(x, n)`.
  - `R x n`: print `rotr32(x, n)`.
  - `K seed`: print the security key the harness computes with your functions:
    `k = rotl32(seed ^ 0xA5A5A5A5, seed & 31); k ^= rotr32(seed, seed >> 27); key = k + 0x1234`.

`x` and `seed` are hex, `n` is decimal (`0..4294967295`). Every result is printed as `%08X`.

**Example**
```
Input:
3
L 80000001 1
R 12345678 4
K 00000000

Output:
00000003
81234567
A5A5B7D9
```
@@@ constraints_md
- `1 <= q <= 20`
- `0 <= n <= 4294967295` (any `unsigned` value)
- No compiler intrinsics (`__builtin_rotateleft32`, `_rotl`).
@@@ starter_code
#include <stdint.h>

uint32_t rotl32(uint32_t x, unsigned n)
{
    /* TODO */
    return x;
}

uint32_t rotr32(uint32_t x, unsigned n)
{
    /* TODO */
    return x;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

#define __builtin_rotateleft32(x, n) builtin_rotate_is_not_allowed
#define __builtin_rotateright32(x, n) builtin_rotate_is_not_allowed

/*USER_CODE*/

#undef __builtin_rotateleft32
#undef __builtin_rotateright32

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        unsigned x, n;
        if (scanf(" %c %x", &op, &x) != 2) return 0;
        if (op == 'K') {
            uint32_t k = rotl32(x ^ 0xA5A5A5A5u, x & 31u);
            k ^= rotr32(x, x >> 27);
            printf("%08X\n", (unsigned)(k + 0x1234u));
            continue;
        }
        if (scanf("%u", &n) != 1) return 0;
        printf("%08X\n", (unsigned)(op == 'L' ? rotl32(x, n) : rotr32(x, n)));
    }
    return 0;
}
@@@ sample_input
3
L 80000001 1
R 12345678 4
K 00000000
@@@ sample_output
00000003
81234567
A5A5B7D9

@@@ sample_input
3
L 12345678 0
L 12345678 32
R 12345678 0
@@@ sample_output
12345678
12345678
12345678

@@@ hidden_input
4
L 12345678 36
L 12345678 64
L 12345678 4294967295
R 12345678 4294967295
@@@ hidden_output
23456781
12345678
091A2B3C
2468ACF0

@@@ hidden_input
4
L FFFFFFFF 17
L 00000000 5
L 00000001 31
R 80000000 31
@@@ hidden_output
FFFFFFFF
00000000
80000000
00000001

@@@ hidden_input
4
R 00000003 1
R 00000001 1
R F000000F 4
R 12345678 100
@@@ hidden_output
80000001
80000000
FF000000
81234567

@@@ hidden_input
2
L DEADBEEF 8
R DEADBEEF 8
@@@ hidden_output
ADBEEFDE
EFDEADBE

@@@ hidden_input
6
K 12345660
K DEADBEEF
K FFFFFFFF
K 00000001
K 80000020
K 7FFFFFFF
@@@ hidden_output
B31CF891
D812F2B3
D2D2E506
4B4B5D7C
258537B9
92D3E506

@@@ hint
`(x << n) | (x >> (32 - n))` is the textbook rotate, but think about `n = 0`: the right shift becomes `x >> 32`. Reduce `n` first with `n %= 32` (or `n &= 31`).
@@@ hint
Even after reducing, `32 - n` is 32 when `n == 0`. Either return `x` early for `n == 0`, or use `(x >> ((32u - n) & 31u))`, which is `x >> 0 = x` for `n == 0`, and OR-ing `x` with itself is harmless. `rotr32(x, n)` is `rotl32(x, 32 - n % 32)`.
@@@ solution_code
#include <stdint.h>

uint32_t rotl32(uint32_t x, unsigned n)
{
    n &= 31u;                                    /* rotation is modulo 32 */
    /* (32 - n) & 31 is 0 when n == 0: both halves are x, x | x == x. No shift by 32. */
    return (x << n) | (x >> ((32u - n) & 31u));
}

uint32_t rotr32(uint32_t x, unsigned n)
{
    n &= 31u;
    return (x >> n) | (x << ((32u - n) & 31u));
}
@@@ explanation_md
**Approach.** A rotate is the OR of two shifts: the bits that move left, and the bits that wrap around from the top to the bottom.

```
rotl32(x, n) = (x << n) | (x >> (32 - n))      for 1 <= n <= 31
```

The trap is the boundary. For `n = 0` (or 32, 64...), the second shift is `x >> 32`, which is **undefined behavior** (C11 6.5.7p3: the shift count must be less than the width of the promoted left operand). It is not "0" or "x". x86 masks the count to 5 bits (so `x >> 32 == x`, which happens to work), ARM uses the low 8 bits (so `x >> 32 == 0`), and the optimiser may assume it never happens. Fix it by:
1. reducing `n &= 31` (rotations are periodic modulo 32), and
2. masking the complementary count, `(32 - n) & 31`. For `n = 0` both halves are `x`, and `x | x == x`.

gcc and clang recognise exactly this pattern and emit a single `ROL`/`ROR` instruction (`ROR` on ARM). The masked form is branch-free.

**Complexity.** O(1) time and space.

**Common mistakes**
- No reduction: `rotl32(x, 36)` shifts by 36 (UB) instead of rotating by 4.
- Reducing `n` but not handling `n == 0`. The naive formula then does `x >> 32`, and UBSan reports it on the `K` tests whose seed has `seed & 31 == 0`.
- Rotating a signed `int`. Right shifts of negative values copy the sign bit in, which corrupts the wrapped bits, and left shifts into the sign bit are UB.
- Rotating a `uint8_t`/`uint16_t` with the 32-bit formula. The value is promoted to `int`, so you must use the narrow width (`8 - n`) and cast the result back.

**Interview follow-ups**
- Write a generic `ROTL(x, n, width)` macro for 8/16/32/64-bit types. Which type issues come from promotion?
- Why do hash functions (Murmur, xxHash) and ciphers (ChaCha, SHA-256) prefer rotates over shifts?
- Real UDS seed/key algorithms are often just rotates and XORs with a secret constant. Why is that weak, and what does ISO 14229 SecurityAccess or UDS authentication (service 0x29) do instead?
- How does the CMSIS `__ROR()` intrinsic map to the Cortex-M instruction set, and why is there no `ROL` instruction on ARM?
