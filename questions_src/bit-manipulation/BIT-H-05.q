@@@ meta
id: BIT-H-05
topic: Bit Manipulation
difficulty: Hard
type: FUNCTION
title: Saturating uint8 and int16 Arithmetic With a Q15 Multiply
tags: embedded, saturation, fixed-point, q15, dsp, motor-control, overflow
@@@ statement_md
A field-oriented motor controller runs on a Cortex-M0+ without FPU or DSP instructions. Currents and voltages are **Q15** fixed-point numbers: an `int16_t` value `v` represents `v / 32768`, so the range is `[-1.0, +0.99997]`. PWM duty cycles are `uint8_t`. In a control loop, wrap-around is catastrophic: +0.99 + 0.02 must not become -0.99. All arithmetic must **saturate** instead.

Implement:

```c
uint8_t sat_add_u8 (uint8_t a, uint8_t b);   /* min(a + b, 255)                                  */
int16_t sat_add_i16(int16_t a, int16_t b);   /* a + b clamped to [-32768, 32767]                  */
int16_t sat_sub_i16(int16_t a, int16_t b);   /* a - b clamped to [-32768, 32767]                  */
int16_t q15_mul    (int16_t a, int16_t b);   /* floor((a*b + 2^14) / 2^15), clamped to int16 range */
```

`q15_mul` rounds to nearest with ties toward +infinity: `0.5 * 0.5 = 16384 * 16384 → 8192`, `-16385 * 1 → -1` (floor, not truncation toward zero). The only product that overflows is `-1.0 * -1.0 = (-32768) * (-32768)`, which must give `32767`.

The judge runs with UBSan: no signed overflow anywhere, in your intermediate results too.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines:
  - `U a b`: print `sat_add_u8(a, b)`.
  - `A a b` / `S a b` / `M a b`: print `sat_add_i16`, `sat_sub_i16` or `q15_mul` of `a, b`.
  - `R seed n`: run `n` random rounds (LCG `s = s * 1103515245u + 12345u`, two draws `s1, s2` per round, `a = (s1 >> 16) - 32768`, `b = (s2 >> 16) - 32768`, bytes `(s1 >> 8) & 255` and `(s2 >> 8) & 255`), and print the sums of all four functions' results: `u8=.. add=.. sub=.. mul=..`.

**Example**
```
Input:
4
U 200 100
A 32767 1
S 0 -32768
M -32768 -32768

Output:
255
32767
32767
32767
```
@@@ constraints_md
- `1 <= q <= 30`, `1 <= n <= 100000`
- `0 <= a, b <= 255` for `U`; `-32768 <= a, b <= 32767` otherwise
- Wider intermediates (`int32_t`) are allowed.
@@@ starter_code
#include <stdint.h>

uint8_t sat_add_u8(uint8_t a, uint8_t b)
{
    /* TODO */
    return (uint8_t)(a + b);
}

int16_t sat_add_i16(int16_t a, int16_t b)
{
    /* TODO */
    return a;
}

int16_t sat_sub_i16(int16_t a, int16_t b)
{
    /* TODO */
    return a;
}

int16_t q15_mul(int16_t a, int16_t b)
{
    /* TODO: floor((a*b + 2^14) / 2^15), saturated */
    return a;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'R') {
            unsigned seed;
            int n;
            if (scanf("%u %d", &seed, &n) != 2) return 0;
            uint32_t s = seed;
            long long su = 0, sa = 0, ss = 0, sm = 0;
            for (int i = 0; i < n; i++) {
                s = s * 1103515245u + 12345u;
                uint32_t s1 = s;
                s = s * 1103515245u + 12345u;
                uint32_t s2 = s;
                int16_t a = (int16_t)((int32_t)(s1 >> 16) - 32768);
                int16_t b = (int16_t)((int32_t)(s2 >> 16) - 32768);
                su += sat_add_u8((uint8_t)(s1 >> 8), (uint8_t)(s2 >> 8));
                sa += sat_add_i16(a, b);
                ss += sat_sub_i16(a, b);
                sm += q15_mul(a, b);
            }
            printf("u8=%lld add=%lld sub=%lld mul=%lld\n", su, sa, ss, sm);
            continue;
        }
        int a, b;
        if (scanf("%d %d", &a, &b) != 2) return 0;
        if (op == 'U')
            printf("%u\n", (unsigned)sat_add_u8((uint8_t)a, (uint8_t)b));
        else if (op == 'A')
            printf("%d\n", (int)sat_add_i16((int16_t)a, (int16_t)b));
        else if (op == 'S')
            printf("%d\n", (int)sat_sub_i16((int16_t)a, (int16_t)b));
        else
            printf("%d\n", (int)q15_mul((int16_t)a, (int16_t)b));
    }
    return 0;
}
@@@ sample_input
4
U 200 100
A 32767 1
S 0 -32768
M -32768 -32768
@@@ sample_output
255
32767
32767
32767

@@@ sample_input
4
U 100 100
A 100 -200
S 100 50
M 16384 16384
@@@ sample_output
200
-100
50
8192

@@@ hidden_input
6
U 255 0
U 0 0
U 128 127
U 255 255
U 1 254
U 1 253
@@@ hidden_output
255
0
255
255
255
254

@@@ hidden_input
6
A -32768 -1
A 30000 2768
A 30000 2766
A -32768 32767
A -20000 -20000
A 16384 16384
@@@ hidden_output
-32768
32767
32766
-1
-32768
32767

@@@ hidden_input
7
S -32768 1
S 32767 -1
S -1 32767
S -2 32767
S 0 32767
S -32768 -32768
S 0 0
@@@ hidden_output
-32768
32767
-32768
-32768
-32767
0
0

@@@ hidden_input
10
M -32768 32767
M 32767 32767
M -1 1
M -16384 1
M -16385 1
M 1 16384
M 3 -16384
M 0 -32768
M -32768 16384
M 32767 -32768
@@@ hidden_output
-32767
32766
0
0
-1
1
-1
0
-16384
-32767

@@@ hidden_input
2
R 1 1000
R 0 1
@@@ hidden_output
u8=214672 add=274725 sub=1421522 mul=317996
u8=70 add=-11300 sub=-32768 mul=-21468

@@@ hidden_input
1
R 77 100000
@@@ hidden_output
u8=21235284 add=2625374 sub=-11385612 mul=1633591

@@@ hint
For the 8- and 16-bit versions, the operands are promoted to `int` anyway, so compute the exact result in an `int32_t` (it cannot overflow) and clamp it. For `uint8_t` there is also the branch-free trick: `r = a + b; r |= -(r < a)` on 8-bit unsigned arithmetic.
@@@ hint
For `q15_mul`, the exact product of two `int16_t` fits in `int32_t` (at most 2^30). Add `0x4000`, then divide by 32768 with **floor** semantics. `/` truncates toward zero, so handle negative numbers separately (or use `>> 15` on gcc, where it is arithmetic). Then clamp. Only `(-32768) * (-32768)` needs the clamp.
@@@ solution_code
#include <stdint.h>

static int16_t clamp_i16(int32_t v)
{
    if (v > INT16_MAX) return INT16_MAX;
    if (v < INT16_MIN) return INT16_MIN;
    return (int16_t)v;
}

uint8_t sat_add_u8(uint8_t a, uint8_t b)
{
    unsigned r = (unsigned)a + b;              /* at most 510: no overflow */
    return (uint8_t)(r > 255u ? 255u : r);
}

int16_t sat_add_i16(int16_t a, int16_t b)
{
    return clamp_i16((int32_t)a + b);          /* exact in 32 bits: [-65536, 65534] */
}

int16_t sat_sub_i16(int16_t a, int16_t b)
{
    return clamp_i16((int32_t)a - b);          /* 0 - (-32768) = 32768 -> clamped */
}

int16_t q15_mul(int16_t a, int16_t b)
{
    int32_t p = (int32_t)a * b + 0x4000;       /* |a*b| <= 2^30: fits; + 2^14 still fits */
    /* floor division by 2^15 without relying on implementation-defined >> of negatives */
    int32_t q = (p >= 0) ? p / 32768 : -((-p + 32767) / 32768);
    return clamp_i16(q);
}
@@@ explanation_md
**Approach.**
- **Exact, then clamp.** Both operands are at most 16 bits, so their sum, difference and even product are exact in an `int32_t`. Compute the exact value and clamp it to the target range. No intermediate can overflow (UBSan-clean), and the code is obviously correct, which matters for ISO 26262 reviews.
- **Subtraction trap.** `0 - (-32768) = +32768` does not fit in `int16_t`. Implementing subtraction as `sat_add_i16(a, -b)` is **wrong**: `-b` for `b = -32768` is again `-32768` once truncated to 16 bits, so the result would be `-32768` instead of `32767`.
- **Q15 multiply.** `(a * b) / 2^15` rescales the product (Q30) back to Q15. Adding `2^14` before dividing rounds to nearest. The division must be a **floor**: arithmetic `>> 15` does that in gcc, while `/` truncates toward zero and gives `0` instead of `-1` for `-16385 * 1`. The only overflow is `-1.0 * -1.0 = +1.0`, which is not representable, so clamp it to `32767` (0.99997).

```
-16385 * 1 + 16384 = -1
floor(-1 / 32768)  = -1     (/ would give 0)
```

**Complexity.** O(1) per operation and O(1) space. The `R` test runs 4 × 10^5 operations.

**Common mistakes**
- Checking overflow **after** a 16-bit addition (`int16_t r = a + b; if (r < a) ...`). The addition is done in `int`, so the truncation back to `int16_t` is an implementation-defined conversion, and the check is fragile.
- `uint8_t r = a + b; if (r < a) r = 255;` works for `uint8_t` only because the conversion is modular. It does not carry over to signed types.
- `sat_sub(a, b) = sat_add(a, -b)`: fails for `b = INT16_MIN`.
- Rounding with `/` instead of floor, or forgetting the `+0x4000` rounding constant (that is truncation, which biases a control loop's integrator negative over time).

**Interview follow-ups**
- Cortex-M4 has `QADD16`, `SSAT` and `SMULBB`. How would you use CMSIS intrinsics (`__QADD16`, `__SSAT`) to do the same thing in one instruction?
- Implement saturating **32-bit** add without a 64-bit type. (Compare against `INT32_MAX - b` first, or inspect sign bits after an unsigned add.)
- Why does a PI controller need **anti-windup** even when the arithmetic saturates correctly?
- Branch-free clamping: why do some teams prefer it for constant-time execution or WCET, and how does it look in C?
