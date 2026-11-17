@@@ meta
id: ENM-E-10
topic: Enums
difficulty: Easy
type: FUNCTION
title: Weekday Enum Arithmetic With Negative Offsets
tags: enum-arithmetic, modulo, integer-overflow, wraparound
@@@ statement_md
An EV's departure timer lets the driver pick a day of the week, and the scheduler needs "the weekday `delta` days from now". The judge already defines the weekday enum, so do not redefine it:

```c
typedef enum { WD_MON, WD_TUE, WD_WED, WD_THU, WD_FRI, WD_SAT, WD_SUN, WD_COUNT } Weekday;
```

Implement

```c
Weekday weekday_add(Weekday d, int delta);
```

It returns the weekday `delta` days after `d`. A negative `delta` means days **before** `d`. The week wraps around: `WD_SUN + 1` is `WD_MON`, and `WD_MON - 1` is `WD_SUN`.

If `d` is not a valid weekday (`WD_MON`..`WD_SUN`), return `WD_COUNT` as an error marker.

`delta` can be any `int`, including `INT_MIN` and `INT_MAX`. Your function must not overflow (signed overflow is undefined behavior, and the judge runs with UBSan).

**How it is tested.** The hidden harness reads pairs `d delta`, casts `d` to `Weekday` and prints `<d> <delta> -> <NAME>`, where `NAME` is `MON`..`SUN` or `INVALID` for `WD_COUNT`.

**Example**
```
Input:
3
0 1
6 1
2 -3

Output:
0 1 -> TUE
6 1 -> MON
2 -3 -> SUN
```
@@@ constraints_md
- `1 <= n <= 100` pairs (first input line is `n`).
- `d` and `delta` are any 32-bit `int` values.
- O(1) per call: no loop that steps one day at a time.
@@@ starter_code
/*
 * Provided by the judge (do not redefine):
 *   typedef enum { WD_MON, WD_TUE, WD_WED, WD_THU, WD_FRI, WD_SAT, WD_SUN, WD_COUNT } Weekday;
 */
Weekday weekday_add(Weekday d, int delta)
{
    /* TODO */
    (void)delta;
    return d;
}
@@@ harness_code
#include <stdio.h>

typedef enum { WD_MON, WD_TUE, WD_WED, WD_THU, WD_FRI, WD_SAT, WD_SUN, WD_COUNT } Weekday;

/*USER_CODE*/

static const char *const h_day[WD_COUNT] = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        int d, delta;
        if (scanf("%d %d", &d, &delta) != 2) return 0;
        Weekday r = weekday_add((Weekday)d, delta);
        unsigned ri = (unsigned)r;
        printf("%d %d -> %s\n", d, delta, ri < (unsigned)WD_COUNT ? h_day[ri] : ri == (unsigned)WD_COUNT ? "INVALID" : "OUT_OF_RANGE");
    }
    return 0;
}
@@@ sample_input
3
0 1
6 1
2 -3
@@@ sample_output
0 1 -> TUE
6 1 -> MON
2 -3 -> SUN

@@@ sample_input
2
4 100
7 0
@@@ sample_output
4 100 -> SUN
7 0 -> INVALID

@@@ hidden_input
2
0 2147483647
6 2147483647
@@@ hidden_output
0 2147483647 -> TUE
6 2147483647 -> MON

@@@ hidden_input
2
0 -2147483648
3 -2147483648
@@@ hidden_output
0 -2147483648 -> SAT
3 -2147483648 -> TUE

@@@ hidden_input
3
3 -7
3 -8
3 -1000000000
@@@ hidden_output
3 -7 -> THU
3 -8 -> WED
3 -1000000000 -> FRI

@@@ hidden_input
3
-1 0
100 5
-2147483648 1
@@@ hidden_output
-1 0 -> INVALID
100 5 -> INVALID
-2147483648 1 -> INVALID

@@@ hidden_input
7
0 0
1 0
2 0
3 0
4 0
5 0
6 0
@@@ hidden_output
0 0 -> MON
1 0 -> TUE
2 0 -> WED
3 0 -> THU
4 0 -> FRI
5 0 -> SAT
6 0 -> SUN

@@@ hidden_input
2
5 13
5 -13
@@@ hidden_output
5 13 -> FRI
5 -13 -> SUN

@@@ hint
Reduce first: `delta % WD_COUNT` lies in `-6..6`, so adding it to `d` can never overflow. Never compute `d + delta` with the raw `delta`.
@@@ hint
In C, `%` keeps the sign of the left operand (`-3 % 7 == -3`). After `r = (d + delta % 7) % 7`, add 7 if `r` is negative. Validate `d` before any of this, with an unsigned compare against `WD_COUNT`.
@@@ solution_code
Weekday weekday_add(Weekday d, int delta)
{
    if ((unsigned)d >= (unsigned)WD_COUNT)
        return WD_COUNT;                         /* invalid input day */

    int r = ((int)d + delta % WD_COUNT) % WD_COUNT;   /* delta % 7 is in -6..6: no overflow */
    if (r < 0)
        r += WD_COUNT;                           /* C's % truncates toward zero */
    return (Weekday)r;
}
@@@ explanation_md
**Approach.** Consecutive enumerators starting at 0 can be used directly in arithmetic. Adding days is addition modulo `WD_COUNT` (7). Two C details make this an interview question:

1. **Overflow.** `d + delta` with `delta = INT_MAX` overflows, which is undefined behavior. Reducing `delta % 7` **first** keeps every intermediate value in `-6..12`.
2. **Negative modulo.** Since C99, integer division truncates toward zero, so `-3 % 7 == -3`, not 4. Normalize with `if (r < 0) r += 7`.

`INT_MIN % 7` is well defined (`-2`). Only `INT_MIN / -1` and `INT_MIN % -1` overflow. Do **not** write `delta = -delta` to "make it positive": negating `INT_MIN` is undefined behavior.

**Complexity.** Time O(1), space O(1).

**Common mistakes**
- `(d + delta) % 7`. It overflows for large `delta` and goes negative for negative `delta`.
- A `while (delta--)` loop. That is O(|delta|), up to 2·10⁹ iterations.
- `abs(delta)` or `-delta` on `INT_MIN`. UBSan reports "negation of -2147483648 cannot be represented".
- Checking `d < 0` on the enum. gcc gives this enum type `unsigned int`, so the test is always false (and `-Wextra` warns). Cast to `unsigned` and compare with `WD_COUNT` instead.
- Returning `(Weekday)r` without the `r < 0` fix-up, which hands out the invalid value `-3`.

**Interview follow-ups**
- Write `days_between(Weekday from, Weekday to)` that returns the forward distance in `0..6`.
- Why is `enum`-based arithmetic fragile? What happens if someone reorders the enum to start the week on Sunday, or inserts a `WD_HOLIDAY`?
- The RTC on your MCU stores the weekday as 1..7 (ISO) in BCD. How do you convert to and from this enum safely?
