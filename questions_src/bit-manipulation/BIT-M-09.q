@@@ meta
id: BIT-M-09
topic: Bit Manipulation
difficulty: Medium
type: FIND_THE_BUG
title: Overflow Check That Is Itself Undefined Behavior
tags: signed-overflow, undefined-behavior, ubsan, int32-t, bms, misra
@@@ statement_md
The battery management system keeps a **coulomb counter** `charge` (in mAs) as an `int32_t`. Every measurement cycle adds a signed current delta. If an addition would overflow `int32_t`, the delta must be **rejected**: the counter keeps its old value and the program prints `OVERFLOW (kept <value>)`. Otherwise the new value is printed.

`checked_add_i32` looks right, and on the PC simulator the results look right. But:
- the judge (UBSan) reports a runtime error on several tests, and
- in the `-O2` target build, `OVERFLOW` is **never** printed, and the counter jumps from about +2.1 billion to a huge negative value.

Find and fix the bug. Keep the function's contract and the output format. You may not use a wider type (`int64_t`), because the same helper is also used for 64-bit counters.

**Input**
- Line 1: the initial `charge` and the number of deltas `n`.
- Next line(s): `n` deltas.

**Output**
- One line per delta: the new counter value, or `OVERFLOW (kept X)`.

**Example**
```
Input:
2147483000 2
600 100

Output:
2147483600
OVERFLOW (kept 2147483600)
```
@@@ constraints_md
- `INT32_MIN <= charge, delta <= INT32_MAX`, `1 <= n <= 100`
- Do not use `int64_t`/`long long` or compiler builtins such as `__builtin_add_overflow` for the check.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

/* Adds b to a. Returns 1 and stores the sum in *out if it fits in int32_t,
 * otherwise returns 0 and leaves *out unchanged. */
static int checked_add_i32(int32_t a, int32_t b, int32_t *out)
{
    int32_t sum = a + b;
    if ((a > 0 && b > 0 && sum < 0) || (a < 0 && b < 0 && sum >= 0))
        return 0;                       /* wrapped around -> overflow */
    *out = sum;
    return 1;
}

int main(void)
{
    int32_t charge;
    int n;
    if (scanf("%d %d", &charge, &n) != 2) return 0;
    for (int i = 0; i < n; i++) {
        int32_t delta;
        if (scanf("%d", &delta) != 1) return 0;
        if (checked_add_i32(charge, delta, &charge))
            printf("%d\n", charge);
        else
            printf("OVERFLOW (kept %d)\n", charge);
    }
    return 0;
}
@@@ sample_input
0 3
100 -50 25
@@@ sample_output
100
50
75

@@@ sample_input
2147483000 2
600 100
@@@ sample_output
2147483600
OVERFLOW (kept 2147483600)

@@@ hidden_input
2147483647 1
1
@@@ hidden_output
OVERFLOW (kept 2147483647)

@@@ hidden_input
-2147483648 2
-1 1
@@@ hidden_output
OVERFLOW (kept -2147483648)
-2147483647

@@@ hidden_input
-2147483648 1
2147483647
@@@ hidden_output
-1

@@@ hidden_input
2147483647 2
-2147483648 0
@@@ hidden_output
-1
-1

@@@ hidden_input
-1000 3
-2147482648 -1 5
@@@ hidden_output
-2147483648
OVERFLOW (kept -2147483648)
-2147483643

@@@ hidden_input
2147483646 3
1 1 -2147483647
@@@ hidden_output
2147483647
OVERFLOW (kept 2147483647)
0

@@@ hidden_input
5 1
-5
@@@ hidden_output
0

@@@ hint
The check runs **after** `a + b` has been computed. In C, what does the standard say happens when a signed addition overflows? Is there a "wrapped-around" result to inspect at all?
@@@ hint
Decide *before* adding: for `b > 0` the sum overflows exactly when `a > INT32_MAX - b`; for `b < 0` exactly when `a < INT32_MIN - b`. Neither subtraction can overflow.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

/* Adds b to a. Returns 1 and stores the sum in *out if it fits in int32_t,
 * otherwise returns 0 and leaves *out unchanged. */
static int checked_add_i32(int32_t a, int32_t b, int32_t *out)
{
    /* FIX: test BEFORE adding; a + b that overflows is undefined behavior,
       so a post-check on the "wrapped" sum is meaningless (and removed by -O2) */
    if ((b > 0 && a > INT32_MAX - b) || (b < 0 && a < INT32_MIN - b))
        return 0;
    *out = a + b;
    return 1;
}

int main(void)
{
    int32_t charge;
    int n;
    if (scanf("%d %d", &charge, &n) != 2) return 0;
    for (int i = 0; i < n; i++) {
        int32_t delta;
        if (scanf("%d", &delta) != 1) return 0;
        if (checked_add_i32(charge, delta, &charge))
            printf("%d\n", charge);
        else
            printf("OVERFLOW (kept %d)\n", charge);
    }
    return 0;
}
@@@ explanation_md
**Bug.** `int32_t sum = a + b;` overflows **before** the check runs. Signed integer overflow is undefined behavior (C11 6.5p5). There is no "wrapped-around value" for the code to inspect, so the program is already broken when it reaches the `if`.
- UBSan reports `signed integer overflow: 2147483600 + 100 cannot be represented in type 'int'`.
- An optimiser may assume UB never happens. Under that assumption, `a > 0 && b > 0` implies `a + b > 0`, so `sum < 0` is always false. gcc `-O2` deletes the whole check, which is the symptom on target.

**Fix.** Decide with arithmetic that cannot overflow:

| sign of b | overflow iff | why it is safe |
|---|---|---|
| `b > 0` | `a > INT32_MAX - b` | `INT32_MAX - b` is in `[0, INT32_MAX)` |
| `b < 0` | `a < INT32_MIN - b` | `INT32_MIN - b` is in `[INT32_MIN + 1, 0]` |
| `b == 0` | never | |

An alternative is to add in **unsigned** arithmetic (well defined, wraps) and inspect the sign bits: `uint32_t s = (uint32_t)a + (uint32_t)b;` overflow iff `((s ^ (uint32_t)a) & (s ^ (uint32_t)b)) >> 31`, meaning the result's sign differs from both operands' signs.

**Complexity.** O(1) per addition, O(n) overall, O(1) space.

**Common mistakes**
- "It works on my PC." At `-O0` x86 wraps, so the post-check seems to work. It breaks with optimisation, which is the worst possible time to find out.
- `if (a + b > INT32_MAX)`. This is always false for an `int32_t` expression, and it is UB when the sum overflows.
- Using `-fwrapv` to "define" the overflow. It hides the bug on one compiler and fails MISRA C:2012 Rule 1.3 (no UB).
- Forgetting the negative direction (`INT32_MIN + (-1)`). Both directions are tested.

**Interview follow-ups**
- Write `checked_mul_i32` without a wider type. (Hint: compare against `INT32_MAX / b`, with care for negative operands and `-1 * INT32_MIN`.)
- When is `__builtin_add_overflow` (gcc/clang) acceptable in automotive code, and why might a MISRA deviation be needed?
- Why is **unsigned** overflow well defined in C but signed overflow is not? What optimisations does that enable (loop induction variables)?
- Convert this into a **saturating** add that clamps to `INT32_MIN`/`INT32_MAX` instead of rejecting the delta.
