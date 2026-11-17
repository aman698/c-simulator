@@@ meta
id: ENM-M-01
topic: Enums
difficulty: Medium
type: PREDICT_OUTPUT
title: OR-ed Flags in a switch and a Negative Enumerator vs unsigned
tags: switch-default, bit-flags, usual-arithmetic-conversions, signed-unsigned
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

enum Perm { P_NONE = 0, P_READ = 1, P_WRITE = 2, P_EXEC = 4 };
enum Temp { T_COLD = -1, T_OK, T_HOT };

static const char *classify(enum Perm p)
{
    switch (p) {
    case P_NONE:  return "none";
    case P_READ:  return "read";
    case P_WRITE: return "write";
    case P_EXEC:  return "exec";
    default:      return "other";
    }
}

int main(void)
{
    enum Perm p = P_READ | P_WRITE;
    unsigned limit = 2;

    printf("%d %s\n", (int)p, classify(p));
    printf("%s %s\n", classify(P_EXEC), classify(P_READ | P_EXEC));
    printf("%d %d\n", p == 3, (p & P_WRITE) == P_WRITE);
    printf("%d %d\n", T_COLD < limit, T_COLD < (int)limit);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, `int` = 4 bytes, `unsigned` = 4 bytes.
- Enumeration constants have type `int`.
@@@ starter_code
#include <stdio.h>

enum Perm { P_NONE = 0, P_READ = 1, P_WRITE = 2, P_EXEC = 4 };
enum Temp { T_COLD = -1, T_OK, T_HOT };

static const char *classify(enum Perm p)
{
    switch (p) {
    case P_NONE:  return "none";
    case P_READ:  return "read";
    case P_WRITE: return "write";
    case P_EXEC:  return "exec";
    default:      return "other";
    }
}

int main(void)
{
    enum Perm p = P_READ | P_WRITE;
    unsigned limit = 2;

    printf("%d %s\n", (int)p, classify(p));
    printf("%s %s\n", classify(P_EXEC), classify(P_READ | P_EXEC));
    printf("%d %d\n", p == 3, (p & P_WRITE) == P_WRITE);
    printf("%d %d\n", T_COLD < limit, T_COLD < (int)limit);
    return 0;
}
@@@ predict_answer
3 other
exec other
1 1
0 1
@@@ hint
An enum variable is just an integer. It can hold `P_READ | P_WRITE` = 3 even though no enumerator has that value. Which `case` matches 3?
@@@ hint
`T_COLD` is the `int` -1. Comparing an `int` with an `unsigned` converts the `int` to `unsigned` first (the usual arithmetic conversions).
@@@ solution_code
#include <stdio.h>

enum Perm { P_NONE = 0, P_READ = 1, P_WRITE = 2, P_EXEC = 4 };
enum Temp { T_COLD = -1, T_OK, T_HOT };

static const char *classify(enum Perm p)
{
    switch (p) {
    case P_NONE:  return "none";
    case P_READ:  return "read";
    case P_WRITE: return "write";
    case P_EXEC:  return "exec";
    default:      return "other";     /* every value without a case label lands here */
    }
}

int main(void)
{
    enum Perm p = P_READ | P_WRITE;   /* 1 | 2 = 3: legal, but not a named enumerator */
    unsigned limit = 2;

    /* "3 other": the switch has no case 3 -> default */
    printf("%d %s\n", (int)p, classify(p));

    /* "exec other": P_READ | P_EXEC = 5 -> default */
    printf("%s %s\n", classify(P_EXEC), classify(P_READ | P_EXEC));

    /* "1 1": p is just the integer 3; bit 1 (P_WRITE) is set */
    printf("%d %d\n", p == 3, (p & P_WRITE) == P_WRITE);

    /* "0 1": T_COLD (int -1) < limit (unsigned 2) -> -1 becomes 4294967295 -> false.
     *        With an explicit (int) cast both sides are int -> -1 < 2 -> true.       */
    printf("%d %d\n", T_COLD < limit, T_COLD < (int)limit);
    return 0;
}
@@@ explanation_md
**Answer**
```
3 other
exec other
1 1
0 1
```

**Approach.**
1. `P_READ | P_WRITE` is the `int` 3. C lets any value of the enum's underlying integer type be stored in an enum variable, so `p == 3` with no error and no diagnostic. The `switch` compares against the case labels 0, 1, 2 and 4, finds no match and takes `default`, so `classify` returns `"other"`. `P_READ | P_EXEC` (5) also gives `"other"`.
2. To test a flag in a combined value, use `&`: `(p & P_WRITE) == P_WRITE` is 1.
3. `T_COLD < limit` mixes `int` and `unsigned int`. The usual arithmetic conversions (C11 6.3.1.8) convert the `int` -1 to `unsigned`, which gives 4294967295, and `4294967295 < 2` is false. gcc warns with `-Wsign-compare` (part of `-Wextra`). After the explicit `(int)` cast it is an ordinary signed comparison.

None of this is undefined behavior. Storing 3 in `enum Perm` is fine because the enum's integer type can represent it, and the signed-to-unsigned conversion is fully defined (modulo 2³²).

**Complexity.** N/A (constant work).

**Common mistakes**
- Expecting a `switch` on a flag enum to match a single flag when several are set. A combined value matches no case. Flag sets must be tested with `&`, not `switch`/`==`.
- Assuming `default:` is unreachable when every enumerator has a `case`. Corrupted memory, casts from CAN data and OR-ed flags all reach it, which is why safety standards require a `default:`.
- Reading `T_COLD < limit` as `-1 < 2`. Mixed signed and unsigned comparisons are a classic source of "impossible" bugs in bounds checks, for example `if (index < sizeof buf)` with a negative `index`.

**Interview follow-ups**
- How would you write `classify` for flag enums so that it prints every set flag (`READ|WRITE`)?
- gcc has `-Wswitch-enum`, which warns about a missing enumerator even when there is a `default`. Why might a team enable it?
- What would `T_COLD < sizeof(int)` print, and why does the same trap appear with `size_t`?
