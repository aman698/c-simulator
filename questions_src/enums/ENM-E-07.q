@@@ meta
id: ENM-E-07
topic: Enums
difficulty: Easy
type: FIND_THE_BUG
title: Wiper Stalk Controller That Skips a Speed
tags: embedded, switch, fallthrough, state-machine, wiper
@@@ statement_md
The wiper control unit reads stalk events and keeps the wiper mode in an enum:

```
OFF  <->  INT (intermittent)  <->  LOW  <->  HIGH
```

Intended behaviour:
- `UP` moves one step faster (`OFF -> INT -> LOW -> HIGH`). At `HIGH` it stays at `HIGH`.
- `DOWN` moves one step slower (`HIGH -> LOW -> INT -> OFF`). At `OFF` it stays at `OFF`.
- `MIST` performs one single sweep, but **only** when the mode is `OFF`. The mode stays `OFF` and the line is printed as `OFF +mist`. In any other mode `MIST` has no effect.
- Any other token is ignored and printed as `ignored <token>`.

After every event the program prints the current mode (`OFF`, `INT`, `LOW` or `HIGH`).

A test driver reports that the wipers **sometimes skip a speed** when the stalk is pushed up. Find and fix the bug.

**Input**
- Line 1: `n`.
- Then `n` event tokens.

**Output**
- One line per event as described above.

**Example**
```
Input:
3
UP UP UP

Output:
INT
LOW
HIGH
```
@@@ constraints_md
- `1 <= n <= 100`
- Keep the structure of the program. The fix is one line.
@@@ starter_code
#include <stdio.h>
#include <string.h>

typedef enum { WIPER_OFF, WIPER_INT, WIPER_LOW, WIPER_HIGH, WIPER_MODE_COUNT } WiperMode;

static const char *const mode_name[WIPER_MODE_COUNT] = { "OFF", "INT", "LOW", "HIGH" };

static WiperMode step_up(WiperMode m)
{
    WiperMode next = m;
    switch (m) {
    case WIPER_OFF:
        next = WIPER_INT;
        break;
    case WIPER_INT:
        next = WIPER_LOW;
    case WIPER_LOW:
        next = WIPER_HIGH;
        break;
    case WIPER_HIGH:            /* already the fastest mode */
        break;
    default:                    /* corrupted value: fail safe */
        next = WIPER_OFF;
        break;
    }
    return next;
}

static WiperMode step_down(WiperMode m)
{
    switch (m) {
    case WIPER_HIGH: return WIPER_LOW;
    case WIPER_LOW:  return WIPER_INT;
    case WIPER_INT:  return WIPER_OFF;
    case WIPER_OFF:  return WIPER_OFF;
    default:         return WIPER_OFF;
    }
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    WiperMode mode = WIPER_OFF;
    for (int i = 0; i < n; i++) {
        char ev[16];
        if (scanf("%15s", ev) != 1) break;

        if (strcmp(ev, "UP") == 0) {
            mode = step_up(mode);
            printf("%s\n", mode_name[mode]);
        } else if (strcmp(ev, "DOWN") == 0) {
            mode = step_down(mode);
            printf("%s\n", mode_name[mode]);
        } else if (strcmp(ev, "MIST") == 0) {
            printf("%s%s\n", mode_name[mode], mode == WIPER_OFF ? " +mist" : "");
        } else {
            printf("ignored %s\n", ev);
        }
    }
    return 0;
}
@@@ sample_input
3
UP UP UP
@@@ sample_output
INT
LOW
HIGH

@@@ sample_input
4
UP DOWN MIST DOWN
@@@ sample_output
INT
OFF
OFF +mist
OFF

@@@ hidden_input
5
UP UP DOWN DOWN DOWN
@@@ hidden_output
INT
LOW
INT
OFF
OFF

@@@ hidden_input
6
UP UP UP UP DOWN DOWN
@@@ hidden_output
INT
LOW
HIGH
HIGH
LOW
INT

@@@ hidden_input
3
MIST MIST UP
@@@ hidden_output
OFF +mist
OFF +mist
INT

@@@ hidden_input
4
UP MIST UP MIST
@@@ hidden_output
INT
INT
LOW
LOW

@@@ hidden_input
1
DOWN
@@@ hidden_output
OFF

@@@ hidden_input
3
UP WASH UP
@@@ hidden_output
INT
ignored WASH
LOW

@@@ hint
Trace `UP` starting from `INT` by hand, statement by statement, inside `step_up`. Which statements execute after `next = WIPER_LOW;`?
@@@ hint
A `case` label is only a jump target. It does not end the previous case. Without a `break`, execution falls through into the next `case` body.
@@@ solution_code
#include <stdio.h>
#include <string.h>

typedef enum { WIPER_OFF, WIPER_INT, WIPER_LOW, WIPER_HIGH, WIPER_MODE_COUNT } WiperMode;

static const char *const mode_name[WIPER_MODE_COUNT] = { "OFF", "INT", "LOW", "HIGH" };

static WiperMode step_up(WiperMode m)
{
    WiperMode next = m;
    switch (m) {
    case WIPER_OFF:
        next = WIPER_INT;
        break;
    case WIPER_INT:
        next = WIPER_LOW;
        break;                  /* FIX: missing break fell through into WIPER_LOW -> HIGH */
    case WIPER_LOW:
        next = WIPER_HIGH;
        break;
    case WIPER_HIGH:            /* already the fastest mode */
        break;
    default:                    /* corrupted value: fail safe */
        next = WIPER_OFF;
        break;
    }
    return next;
}

static WiperMode step_down(WiperMode m)
{
    switch (m) {
    case WIPER_HIGH: return WIPER_LOW;
    case WIPER_LOW:  return WIPER_INT;
    case WIPER_INT:  return WIPER_OFF;
    case WIPER_OFF:  return WIPER_OFF;
    default:         return WIPER_OFF;
    }
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    WiperMode mode = WIPER_OFF;
    for (int i = 0; i < n; i++) {
        char ev[16];
        if (scanf("%15s", ev) != 1) break;

        if (strcmp(ev, "UP") == 0) {
            mode = step_up(mode);
            printf("%s\n", mode_name[mode]);
        } else if (strcmp(ev, "DOWN") == 0) {
            mode = step_down(mode);
            printf("%s\n", mode_name[mode]);
        } else if (strcmp(ev, "MIST") == 0) {
            printf("%s%s\n", mode_name[mode], mode == WIPER_OFF ? " +mist" : "");
        } else {
            printf("ignored %s\n", ev);
        }
    }
    return 0;
}
@@@ explanation_md
**Bug.** In `step_up`, `case WIPER_INT:` sets `next = WIPER_LOW` but has no `break`. Execution falls through into `case WIPER_LOW:`, which overwrites `next` with `WIPER_HIGH`. Every `UP` from `INT` jumps straight to `HIGH`, and `LOW` can only be reached by stepping down from `HIGH`.

**Fix.** Add `break;` after `next = WIPER_LOW;`. The compiler already pointed at it: with `-Wextra`, gcc reports `this statement may fall through [-Wimplicit-fallthrough]` on exactly that line.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Ignoring the fall-through warning. Many automotive builds use `-Werror=implicit-fallthrough` for this reason.
- "Fixing" the symptom by changing `case WIPER_LOW: next = WIPER_HIGH` into something else. The `LOW` case is correct; the problem is that `INT` reaches it.
- When fall-through is **intended** (several states sharing one action), not marking it. Write the labels back to back with no statement between them, or put a `/* fallthrough */` comment (or C23 `[[fallthrough]];`) directly before the next label, so the next reader and the compiler both know it is deliberate.

**Interview follow-ups**
- Rewrite `step_up` without a `switch`: since the modes are consecutive enumerators, `return (m < WIPER_HIGH) ? m + 1 : WIPER_HIGH;`. What validation does this version still need for a corrupted `m`?
- MISRA C:2012 Rule 16.3 requires every non-empty switch clause to end with an unconditional `break`. Why is that rule so strict in safety-critical code?
- How would you add a rain-sensor `AUTO` mode between `INT` and `LOW` without breaking the existing stalk behaviour?
