@@@ meta
id: ENM-E-03
topic: Enums
difficulty: Easy
type: FUNCTION
title: Gear Selector Enum to Display String
tags: embedded, enum-to-string, lookup-table, range-check, asked-in-automotive
@@@ statement_md
The instrument cluster shows the selected gear of an automatic transmission. The gear arrives from the transmission ECU and is stored in this enum. The judge already defines it, so do not redefine it:

```c
typedef enum { GEAR_P, GEAR_R, GEAR_N, GEAR_D, GEAR_S, GEAR_COUNT } Gear;
```

Implement

```c
const char *gear_name(Gear g);
```

It returns the display text for `g`:

| value | text |
|---|---|
| `GEAR_P` | `PARK` |
| `GEAR_R` | `REVERSE` |
| `GEAR_N` | `NEUTRAL` |
| `GEAR_D` | `DRIVE` |
| `GEAR_S` | `SPORT` |
| anything else | `INVALID` |

The value comes from a CAN frame. A `Gear` variable can hold **any** integer value, not just the named ones, so `GEAR_COUNT`, negative values and large values must all return `"INVALID"`. They must never crash or read outside a table. Return pointers to string literals or other static storage, never to a local buffer.

**How it is tested.** A hidden `main()` reads integers, converts each one to `Gear` and prints `<value> <gear_name(value)>`.

**Input (read by the hidden harness)**
- Line 1: `n`.
- Line 2: `n` integers.

**Output**
- One line per integer: the integer, a space, and the returned text.

**Example**
```
Input:
3
3 5 -1

Output:
3 DRIVE
5 INVALID
-1 INVALID
```
@@@ constraints_md
- `1 <= n <= 100`
- Each value fits in an `int` (`INT_MIN` and `INT_MAX` may appear).
- No dynamic memory and no printing inside `gear_name`.
@@@ starter_code
/*
 * Provided by the judge (do not redefine):
 *   typedef enum { GEAR_P, GEAR_R, GEAR_N, GEAR_D, GEAR_S, GEAR_COUNT } Gear;
 */
const char *gear_name(Gear g)
{
    /* TODO: map g to "PARK", "REVERSE", "NEUTRAL", "DRIVE", "SPORT" or "INVALID" */
    (void)g;
    return "INVALID";
}
@@@ harness_code
#include <stdio.h>

typedef enum { GEAR_P, GEAR_R, GEAR_N, GEAR_D, GEAR_S, GEAR_COUNT } Gear;

/*USER_CODE*/

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        int raw;
        if (scanf("%d", &raw) != 1) return 0;
        const char *s = gear_name((Gear)raw);
        printf("%d %s\n", raw, s ? s : "(null)");
    }
    return 0;
}
@@@ sample_input
3
3 5 -1
@@@ sample_output
3 DRIVE
5 INVALID
-1 INVALID

@@@ sample_input
5
0 1 2 3 4
@@@ sample_output
0 PARK
1 REVERSE
2 NEUTRAL
3 DRIVE
4 SPORT

@@@ hidden_input
1
2147483647
@@@ hidden_output
2147483647 INVALID

@@@ hidden_input
2
-2147483648 4
@@@ hidden_output
-2147483648 INVALID
4 SPORT

@@@ hidden_input
4
6 255 256 1
@@@ hidden_output
6 INVALID
255 INVALID
256 INVALID
1 REVERSE

@@@ hidden_input
6
4 3 2 1 0 5
@@@ hidden_output
4 SPORT
3 DRIVE
2 NEUTRAL
1 REVERSE
0 PARK
5 INVALID

@@@ hidden_input
1
0
@@@ hidden_output
0 PARK

@@@ hidden_input
5
2 2 -2 -5 2
@@@ hidden_output
2 NEUTRAL
2 NEUTRAL
-2 INVALID
-5 INVALID
2 NEUTRAL

@@@ hint
Put the five strings in an array indexed by the enum. `GEAR_COUNT` is exactly the number of real gears, so it can size the array.
@@@ hint
Check the range **before** indexing. A single unsigned comparison, `(unsigned)g >= GEAR_COUNT`, rejects `GEAR_COUNT`, larger values and negative values, because a negative value converts to a huge unsigned number.
@@@ solution_code
const char *gear_name(Gear g)
{
    /* Designated initializers tie each string to its enumerator,
     * so reordering the enum cannot silently shift the table. */
    static const char *const names[GEAR_COUNT] = {
        [GEAR_P] = "PARK",
        [GEAR_R] = "REVERSE",
        [GEAR_N] = "NEUTRAL",
        [GEAR_D] = "DRIVE",
        [GEAR_S] = "SPORT",
    };
    _Static_assert(sizeof names / sizeof names[0] == GEAR_COUNT, "gear name table out of sync");

    /* One unsigned compare catches negatives, GEAR_COUNT and anything larger. */
    if ((unsigned)g >= (unsigned)GEAR_COUNT)
        return "INVALID";
    return names[g];
}
@@@ explanation_md
**Approach.** Use a `const` lookup table indexed by the enum, sized with the `GEAR_COUNT` sentinel. Validate the value before using it as an index. A `switch` with a `default:` branch is an equally good answer:

```c
switch (g) {
case GEAR_P: return "PARK";
/* ... */
default:     return "INVALID";
}
```

The table makes the lookup O(1) and keeps the strings together. Designated initializers (`[GEAR_D] = "DRIVE"`) plus a `_Static_assert` on the table size stop the strings from silently drifting out of order when someone adds a gear.

**Complexity.** Time O(1) per call, space O(1) (one static table of `GEAR_COUNT` pointers).

**Common mistakes**
- Indexing `names[g]` with no range check. A corrupted CAN value such as `0xFF` reads outside the table, which is undefined behavior and on a real ECU is often a HardFault.
- Writing `if (g > GEAR_COUNT)`, an off-by-one that treats the sentinel `GEAR_COUNT` as a valid gear.
- Writing `if (g < 0 || ...)`. gcc gives an enum without negative enumerators the type `unsigned int`, so `g < 0` is always false. `-Wextra` warns "comparison is always false", and negative inputs then rely entirely on the upper-bound check.
- Returning a pointer to a local `char buf[16]`. It dangles as soon as the function returns.

**Interview follow-ups**
- How would you keep the enum and the string table in sync automatically? (X-macros: one list generates both.)
- In the instrument cluster, should an invalid gear show `INVALID`, the last valid gear, or a blank, and for how long? (Signal qualification and substitute values.)
- `switch` without `default:` and `-Wswitch`: what does the compiler warn about, and why do MISRA C:2012 Rule 16.4 and many style guides still require a `default`?
