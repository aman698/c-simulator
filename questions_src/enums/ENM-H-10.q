@@@ meta
id: ENM-H-10
topic: Enums
difficulty: Hard
type: PREDICT_OUTPUT
title: Implicit Enumerator Collision in a switch Statement
tags: switch, duplicate-case, implicit-values, compile-error, state-machine
@@@ statement_md
An FSM event enum was edited by three different people, and the event logger was written later. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

enum Event {
    EV_NONE = -1,
    EV_TICK,
    EV_START = 3,
    EV_STOP = 1,
    EV_PAUSE,
    EV_RESUME,
    EV_COUNT
};

static const char *event_name(enum Event e)
{
    switch (e) {
    case EV_NONE:   return "NONE";
    case EV_TICK:   return "TICK";
    case EV_START:  return "START";
    case EV_STOP:   return "STOP";
    case EV_PAUSE:  return "PAUSE";
    case EV_RESUME: return "RESUME";
    default:        return "?";
    }
}

int main(void)
{
    printf("%d %d\n", EV_RESUME, EV_COUNT);
    printf("%s\n", event_name(EV_PAUSE));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- Remember the difference between what the *enum declaration* allows and what a *switch* allows.
@@@ starter_code
#include <stdio.h>

enum Event {
    EV_NONE = -1,
    EV_TICK,
    EV_START = 3,
    EV_STOP = 1,
    EV_PAUSE,
    EV_RESUME,
    EV_COUNT
};

static const char *event_name(enum Event e)
{
    switch (e) {
    case EV_NONE:   return "NONE";
    case EV_TICK:   return "TICK";
    case EV_START:  return "START";
    case EV_STOP:   return "STOP";
    case EV_PAUSE:  return "PAUSE";
    case EV_RESUME: return "RESUME";
    default:        return "?";
    }
}

int main(void)
{
    printf("%d %d\n", EV_RESUME, EV_COUNT);
    printf("%s\n", event_name(EV_PAUSE));
    return 0;
}
@@@ predict_answer
Compile Error
@@@ hint
Compute every enumerator's value. Each one without `=` is the previous one + 1, and the counting restarts after `EV_STOP = 1`.
@@@ hint
`EV_RESUME` ends up with the same value as `EV_START`. Duplicate values are legal in an enum declaration, but C11 6.8.4.2p3 forbids two `case` labels in the same `switch` from having the same value.
@@@ solution_code
#include <stdio.h>

enum Event {
    EV_NONE = -1,      /* -1                               */
    EV_TICK,           /*  0                               */
    EV_START = 3,      /*  3                               */
    EV_STOP = 1,       /*  1  (explicit, going backwards)  */
    EV_PAUSE,          /*  2                               */
    EV_RESUME,         /*  3  == EV_START  (legal here!)   */
    EV_COUNT           /*  4  -- and no longer a count of the events */
};

static const char *event_name(enum Event e)
{
    switch (e) {
    case EV_NONE:   return "NONE";
    case EV_TICK:   return "TICK";
    case EV_START:  return "START";    /* case 3 */
    case EV_STOP:   return "STOP";
    case EV_PAUSE:  return "PAUSE";
    case EV_RESUME: return "RESUME";   /* case 3 again -> error: duplicate case value */
    default:        return "?";
    }
}

int main(void)
{
    printf("%d %d\n", EV_RESUME, EV_COUNT);
    printf("%s\n", event_name(EV_PAUSE));
    return 0;
}
@@@ explanation_md
**Answer: `Compile Error`**

**Approach.** Assign the values top to bottom: `EV_NONE = -1`, `EV_TICK = 0`, `EV_START = 3`, `EV_STOP = 1`, `EV_PAUSE = 2`, `EV_RESUME = 3`, `EV_COUNT = 4`. The declaration itself is fine, since C allows several enumerators with the same value. The `switch`, however, contains `case EV_START:` and `case EV_RESUME:`, which are both the constant 3. C11 6.8.4.2p3 says *"no two of the case constant expressions in the same switch statement shall have the same value after conversion"*. That is a **constraint**, so a diagnostic is required. gcc reports `error: duplicate case value` and clang `error: duplicate case value: 'EV_START' and 'EV_RESUME' both equal '3'`.

The tempting answer `3 4` / `PAUSE` ignores that the program never builds. Notice also that `EV_COUNT` is 4, while there are 7 enumerators (6 real events). A "COUNT" sentinel only counts correctly when values are implicit and start at 0.

**Complexity.** N/A. The error is detected at compile time, which is the best possible outcome.

**Common mistakes**
- Assuming an implicit value continues from the largest value so far (`EV_PAUSE = 4`). It continues from the **previous** enumerator.
- Thinking the compiler rejects the duplicate in the enum declaration. It does not; only the `switch` exposes it. Without a `switch`, such a collision silently makes two different events compare equal.
- Answering `Undefined Behavior`. This is a constraint violation, caught at compile time, not undefined behavior at run time.

**Interview follow-ups**
- How would you protect a protocol enum with explicit values against accidental duplicates? (A `switch` over all enumerators in a unit test, `_Static_assert` on each value, or generating it from an X-macro whose `switch` expansion catches duplicates.)
- When are intentional duplicate enumerators useful? (Aliases such as `EV_FIRST = EV_TICK` or `EV_LAST = EV_RESUME`, or keeping a deprecated name.)
- Why does the MISRA C:2012 rule on enum values (Rule 8.12) only restrict **implicitly**-specified enumerators?
