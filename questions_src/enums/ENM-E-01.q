@@@ meta
id: ENM-E-01
topic: Enums
difficulty: Easy
type: PREDICT_OUTPUT
title: Implicit Enumerator Values After Explicit Ones
tags: enum-values, implicit-values, negative-enumerator, duplicate-values
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

enum Fault {
    F_NONE,
    F_LOW = 5,
    F_MID,
    F_HIGH = -2,
    F_CRIT,
    F_SHUTDOWN
};

int main(void)
{
    printf("%d %d %d %d\n", F_NONE, F_MID, F_CRIT, F_SHUTDOWN);
    printf("%d %d\n", F_SHUTDOWN == F_NONE, F_CRIT < F_NONE);
    printf("%d\n", F_MID + F_HIGH * F_CRIT);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, `int` = 4 bytes.
- Enumeration constants have type `int` (C11 6.4.4.3).
@@@ starter_code
#include <stdio.h>

enum Fault {
    F_NONE,
    F_LOW = 5,
    F_MID,
    F_HIGH = -2,
    F_CRIT,
    F_SHUTDOWN
};

int main(void)
{
    printf("%d %d %d %d\n", F_NONE, F_MID, F_CRIT, F_SHUTDOWN);
    printf("%d %d\n", F_SHUTDOWN == F_NONE, F_CRIT < F_NONE);
    printf("%d\n", F_MID + F_HIGH * F_CRIT);
    return 0;
}
@@@ predict_answer
0 6 -1 0
1 1
8
@@@ hint
An enumerator without `=` gets the value of the **previous** enumerator plus one. The first one starts at 0. This rule applies after an explicit value too.
@@@ hint
Count on from `F_HIGH = -2`: -1, then 0. Nothing stops two enumerators from having the same value, and enumeration constants are signed `int`s.
@@@ solution_code
#include <stdio.h>

enum Fault {
    F_NONE,          /*  0: first enumerator defaults to 0              */
    F_LOW = 5,       /*  5: explicit                                    */
    F_MID,           /*  6: previous + 1                                */
    F_HIGH = -2,     /* -2: explicit values may be negative and go down */
    F_CRIT,          /* -1: previous + 1                                */
    F_SHUTDOWN       /*  0: previous + 1 -> same value as F_NONE!       */
};

int main(void)
{
    /* 0 6 -1 0 */
    printf("%d %d %d %d\n", F_NONE, F_MID, F_CRIT, F_SHUTDOWN);

    /* F_SHUTDOWN == F_NONE -> 0 == 0 -> 1
     * F_CRIT < F_NONE      -> -1 < 0 (both int, signed compare) -> 1 */
    printf("%d %d\n", F_SHUTDOWN == F_NONE, F_CRIT < F_NONE);

    /* 6 + (-2 * -1) = 6 + 2 = 8 (normal int arithmetic and precedence) */
    printf("%d\n", F_MID + F_HIGH * F_CRIT);
    return 0;
}
@@@ explanation_md
**Answer**
```
0 6 -1 0
1 1
8
```

**Approach.** Assign the values top to bottom:

| enumerator | rule | value |
|---|---|---|
| `F_NONE` | first, no `=` | 0 |
| `F_LOW` | explicit | 5 |
| `F_MID` | previous + 1 | 6 |
| `F_HIGH` | explicit | -2 |
| `F_CRIT` | previous + 1 | -1 |
| `F_SHUTDOWN` | previous + 1 | **0** |

`F_SHUTDOWN` ends up with the same value as `F_NONE`. That is legal C: the standard does not require enumerator values to be unique. The comparison `F_SHUTDOWN == F_NONE` is therefore true. Enumeration constants have type `int`, so `F_CRIT < F_NONE` is an ordinary signed comparison (`-1 < 0`), and the last line is plain integer arithmetic: `6 + (-2) * (-1) = 8`.

**Complexity.** N/A. Enumerator values are compile-time constants and cost nothing at run time.

**Common mistakes**
- Thinking that an implicit value continues from the *largest* value seen so far (giving `F_CRIT = 7`). It always continues from the **previous** enumerator.
- Assuming values must be unique, so that `F_SHUTDOWN` "skips" 0. Duplicates are legal and silent. No compiler warns about them by default.
- The real-world trap: a duplicate value in a fault or state enum makes `switch` dispatch and string tables ambiguous, and two "different" faults compare equal in logs.

**Interview follow-ups**
- Duplicate enumerator values are legal, but what happens if both `F_NONE` and `F_SHUTDOWN` appear as `case` labels in one `switch`? (Compile error: duplicate case value.)
- How would you make the compiler catch an accidental duplicate? (A `switch` over all enumerators, `_Static_assert` on key values, or generate the enum from an X-macro list.)
- Why do many coding standards (MISRA C:2012 Rule 8.12) require that an implicitly-specified enumerator value is unique?
