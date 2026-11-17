@@@ meta
id: BIT-E-01
topic: Bit Manipulation
difficulty: Easy
type: FUNCTION
title: SET_BIT, CLEAR_BIT, TOGGLE_BIT and CHECK_BIT Register Macros
tags: embedded, macros, set-clear-toggle, registers, misra, asked-in-automotive
@@@ statement_md
Every BSP has a header with single-bit helper macros. Write the four classic ones:

```c
#define SET_BIT(reg, n)     /* set bit n of reg            */
#define CLEAR_BIT(reg, n)   /* clear bit n of reg          */
#define TOGGLE_BIT(reg, n)  /* invert bit n of reg         */
#define CHECK_BIT(reg, n)   /* 1 if bit n of reg is set, else 0 */
```

Requirements (all of them are checked by the hidden tests):
- `reg` is a `uint32_t` lvalue, possibly `volatile` (a memory-mapped register). `n` is `0..31`, **including 31**.
- `CHECK_BIT` is an expression whose value is **exactly `0` or `1`** (type `int`). It is used in arithmetic, e.g. `2 * CHECK_BIT(a, 3) + CHECK_BIT(b, 4)`.
- Arguments may be expressions: `SET_BIT(copy, n & 0x1F)`, `CHECK_BIT(hi | lo, n)`, `TOGGLE_BIT(r, n > 15 ? 0 : 31)`.
- Each argument is evaluated **exactly once**: `SET_BIT(arr[i++], n)` increments `i` once.
- `SET_BIT`, `CLEAR_BIT` and `TOGGLE_BIT` are used as statements, including in an `if (...) SET_BIT(r, n); else CLEAR_BIT(r, n);` chain without braces.
- The code is compiled with UBSan: shifting the `int` constant `1` into bit 31 is reported as undefined behavior.

**How it is tested.** A hidden `main()` holds a `volatile uint32_t reg` and applies commands to it.

**Input (read by the hidden harness)**
- Line 1: the initial register value in hex and the number of commands `q`.
- Next `q` lines: a command letter and a bit number `n`:
  - `S n` / `C n` / `T n`: `SET_BIT` / `CLEAR_BIT` / `TOGGLE_BIT` on `reg`, then the harness prints `reg` as `%08X`.
  - `K n`: prints `bit n = CHECK_BIT(reg, n)`.
  - `X n` (`0 <= n <= 30`): runs a battery of expression-argument checks on a copy of `reg` and prints `score=.. copy=.. arr=..,.. i=..`.

**Example**
```
Input:
00000000 5
S 3
S 31
K 31
T 0
C 3

Output:
00000008
80000008
bit 31 = 1
80000009
80000001
```
@@@ constraints_md
- `0 <= n <= 31` (`0 <= n <= 30` for `X`), `1 <= q <= 20`
- Define the four macros only; do not write `main()`.
- No helper functions: these must be macros (the harness uses them on `volatile` registers and as statements).
@@@ starter_code
#include <stdint.h>

/* Replace the placeholder bodies. reg is a uint32_t lvalue, n is 0..31. */
#define SET_BIT(reg, n)     ((void)0)
#define CLEAR_BIT(reg, n)   ((void)0)
#define TOGGLE_BIT(reg, n)  ((void)0)
#define CHECK_BIT(reg, n)   0
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

int main(void)
{
    unsigned init;
    int q;
    if (scanf("%x %d", &init, &q) != 2) return 0;
    volatile uint32_t reg = init;
    for (int k = 0; k < q; k++) {
        char op;
        int n;
        if (scanf(" %c %d", &op, &n) != 2) return 0;
        if (op == 'S')
            SET_BIT(reg, n);
        else if (op == 'C')
            CLEAR_BIT(reg, n);
        else if (op == 'T')
            TOGGLE_BIT(reg, n);
        else if (op == 'K') {
            printf("bit %d = %d\n", n, CHECK_BIT(reg, n));
            continue;
        } else if (op == 'X') {
            uint32_t snap = reg;
            uint32_t hi = snap & 0xFFFF0000u, lo = snap & 0x0000FFFFu;
            uint32_t copy = snap;
            uint32_t arr[2] = { 0u, 0u };
            int i = 0;
            int score = 2 * CHECK_BIT(hi | lo, n) + CHECK_BIT(snap, n + 1);
            SET_BIT(copy, n & 0x1F);
            CLEAR_BIT(copy, (n + 1) & 0x1F);
            TOGGLE_BIT(copy, n > 15 ? 0 : 31);
            SET_BIT(arr[i++], n);
            TOGGLE_BIT(arr[i++], 31);
            printf("score=%d copy=%08X arr=%08X,%08X i=%d\n", score, (unsigned)copy,
                   (unsigned)arr[0], (unsigned)arr[1], i);
            continue;
        } else {
            printf("bad command\n");
            continue;
        }
        printf("%08X\n", (unsigned)reg);
    }
    return 0;
}
@@@ sample_input
00000000 5
S 3
S 31
K 31
T 0
C 3
@@@ sample_output
00000008
80000008
bit 31 = 1
80000009
80000001

@@@ sample_input
F0F0000F 3
K 4
X 3
T 31
@@@ sample_output
bit 4 = 0
score=2 copy=70F0000F arr=00000008,80000000 i=2
70F0000F

@@@ hidden_input
FFFFFFFF 4
C 31
C 0
K 31
K 1
@@@ hidden_output
7FFFFFFF
7FFFFFFE
bit 31 = 0
bit 1 = 1

@@@ hidden_input
00300000 1
X 20
@@@ hidden_output
score=3 copy=00100001 arr=00100000,80000000 i=2

@@@ hidden_input
C0000000 1
X 30
@@@ hidden_output
score=3 copy=40000001 arr=40000000,80000000 i=2

@@@ hidden_input
00000000 4
X 0
T 31
T 31
K 31
@@@ hidden_output
score=0 copy=80000001 arr=00000001,80000000 i=2
80000000
00000000
bit 31 = 0

@@@ hidden_input
00000000 6
S 0
S 7
S 8
S 15
S 16
S 24
@@@ hidden_output
00000001
00000081
00000181
00008181
00018181
01018181

@@@ hidden_input
AAAAAAAA 5
T 1
T 0
K 0
K 1
C 30
@@@ hidden_output
AAAAAAA8
AAAAAAA9
bit 0 = 1
bit 1 = 0
AAAAAAA9

@@@ hidden_input
00008060 2
X 5
X 15
@@@ hidden_output
score=3 copy=80008020 arr=00000020,80000000 i=2
score=2 copy=80008060 arr=00008000,80000000 i=2

@@@ hint
Wrap **every** use of a macro parameter in parentheses, and wrap the whole macro body too. `1u << n & 0x1F` is not `1u << (n & 0x1F)`. Also, `<<` binds tighter than `&`.
@@@ hint
Use an **unsigned** constant (`1u << (n)`), because `1 << 31` overflows `int`. Use a compound assignment (`(reg) |= ...`) so `reg` is evaluated once. For `CHECK_BIT`, shift the register down and mask with `1u`: `(((reg) >> (n)) & 1u)`.
@@@ solution_code
#include <stdint.h>

/*
 * Every parameter is parenthesised (MISRA C:2012 Rule 20.7) and so is the whole body.
 * 1u keeps the shift in unsigned arithmetic: 1 << 31 overflows a 32-bit int (UB).
 * Compound assignment evaluates the lvalue `reg` exactly once.
 */
#define SET_BIT(reg, n)     ((reg) |= (1u << (n)))
#define CLEAR_BIT(reg, n)   ((reg) &= ~(1u << (n)))
#define TOGGLE_BIT(reg, n)  ((reg) ^= (1u << (n)))
#define CHECK_BIT(reg, n)   ((int)(((reg) >> (n)) & 1u))
@@@ explanation_md
**Approach.** Build a one-bit mask `1u << n`, then:

| operation | expression | why |
|---|---|---|
| set | `reg \|= mask` | OR with 1 forces the bit to 1, OR with 0 keeps the others |
| clear | `reg &= ~mask` | `~mask` has a 0 only at bit n |
| toggle | `reg ^= mask` | XOR with 1 inverts, XOR with 0 keeps |
| check | `(reg >> n) & 1u` | moves bit n to bit 0, so the result is exactly 0 or 1 |

The hidden battery checks each defensive detail:
- `SET_BIT(copy, n & 0x1F)` with an unparenthesised `n` expands to `1u << n & 0x1F`, which is `(1u << n) & 0x1F`. That is 0 for `n >= 5`.
- `TOGGLE_BIT(copy, n > 15 ? 0 : 31)` without parentheses becomes `(1u << n > 15) ? 0 : 31`.
- `2 * CHECK_BIT(...)` is wrong if `CHECK_BIT` returns the mask (`reg & (1u << n)`) instead of 0/1, or if the body lacks outer parentheses.
- `SET_BIT(arr[i++], n)` written as `reg = reg | mask` evaluates `arr[i++]` twice. That is two unsequenced modifications of `i`, which is undefined behavior.

**Complexity.** O(1) time and space. Each macro compiles to one or two instructions, such as `ORR`/`BIC`/`EOR` on ARM.

**Common mistakes**
- `1 << 31`: the constant `1` is a signed `int`, and shifting it into the sign bit is undefined (C11 6.5.7p4). UBSan flags it. Always write `1u` (or `1UL` on 16-bit targets where `int` is 16 bits).
- A body in braces `{ reg |= ...; }`: the `;` after the macro ends the `if`, and the following `else` is a syntax error. Use an expression, or `do { ... } while (0)` for multi-statement macros.
- Thinking `SET_BIT` on a `volatile` register is atomic. It is a read-modify-write. If an ISR modifies the same register between the read and the write, its change is lost.

**Interview follow-ups**
- How do STM32 `GPIOx->BSRR`/`BRR` registers, or Cortex-M3/M4 **bit-banding**, give you atomic single-bit set/clear without disabling interrupts?
- MISRA C:2012 Dir 4.9 recommends functions over function-like macros. Write `static inline` versions. What do you lose (type-genericity, use on any register width) and gain (type checking, single evaluation for free)?
- How would you make the macros work for 64-bit registers? (`(uint64_t)1 << (n)`, or `1ull`.)
- Why is `CHECK_BIT(reg, n) == 1` dangerous if someone "optimizes" `CHECK_BIT` to `((reg) & (1u << (n)))`?
