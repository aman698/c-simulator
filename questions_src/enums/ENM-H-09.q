@@@ meta
id: ENM-H-09
topic: Enums
difficulty: Hard
type: PREDICT_OUTPUT
title: Signed or Unsigned - The Hidden Underlying Type of an Enum
tags: embedded, underlying-type, implementation-defined, signed-unsigned, range-check
@@@ statement_md
A reviewer claims the check `if (lv < 0 || lv > LV_HIGH)` in a sensor driver "catches negative garbage twice". What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

enum Level  { LV_LOW, LV_MID, LV_HIGH };
enum Offset { OFS_NEG = -1, OFS_ZERO, OFS_POS };

int main(void)
{
    enum Level  lv = -1;
    enum Offset of = -1;

    printf("%d %d\n", lv < 0, of < 0);
    printf("%d %d\n", lv > LV_HIGH, LV_LOW - 1 < 0);
    printf("%u\n", (unsigned)lv);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI, `int`/`unsigned` = 4 bytes.
- The compatible integer type of an enum is implementation-defined (C11 6.7.2.2p4). Here: gcc's documented choice.
@@@ starter_code
#include <stdio.h>

enum Level  { LV_LOW, LV_MID, LV_HIGH };
enum Offset { OFS_NEG = -1, OFS_ZERO, OFS_POS };

int main(void)
{
    enum Level  lv = -1;
    enum Offset of = -1;

    printf("%d %d\n", lv < 0, of < 0);
    printf("%d %d\n", lv > LV_HIGH, LV_LOW - 1 < 0);
    printf("%u\n", (unsigned)lv);
    return 0;
}
@@@ predict_answer
0 1
1 1
4294967295
@@@ hint
The standard lets the compiler choose the integer type behind each enum. gcc picks `unsigned int` if no enumerator is negative, and `int` otherwise. So `enum Level` and `enum Offset` are different integer types here.
@@@ hint
Storing -1 in an `unsigned int` object gives 4294967295 (a well-defined conversion). The enumeration **constants** (`LV_LOW`, ...) are still plain `int`, so `LV_LOW - 1` is the `int` -1.
@@@ solution_code
#include <stdio.h>

enum Level  { LV_LOW, LV_MID, LV_HIGH };          /* no negatives -> gcc: unsigned int */
enum Offset { OFS_NEG = -1, OFS_ZERO, OFS_POS };   /* has a negative -> gcc: int        */

int main(void)
{
    enum Level  lv = -1;     /* -1 converted to unsigned int -> 4294967295 */
    enum Offset of = -1;     /* int -> stays -1                            */

    /* lv < 0: unsigned compared with 0 -> always false (gcc -Wextra: "comparison is always false")
     * of < 0: signed -> true                                                   -> "0 1" */
    printf("%d %d\n", lv < 0, of < 0);

    /* lv > LV_HIGH: LV_HIGH (int 2) converted to unsigned -> 4294967295 > 2 -> 1
     * LV_LOW - 1 < 0: enumeration constants are int -> -1 < 0 -> 1           -> "1 1" */
    printf("%d %d\n", lv > LV_HIGH, LV_LOW - 1 < 0);

    printf("%u\n", (unsigned)lv);                  /* 4294967295 */
    return 0;
}
@@@ explanation_md
**Answer**
```
0 1
1 1
4294967295
```

**Approach.** C11 6.7.2.2p4 says each enumerated type is compatible with `char`, a signed integer type or an unsigned integer type, **chosen by the implementation**, as long as it can represent all the enumerators. gcc (and clang, for compatibility) documents its choice: `unsigned int` when no enumerator is negative, otherwise `int`. Hence:
- `enum Level lv = -1` stores 4294967295. Signed-to-unsigned conversion is well defined (modulo 2³²), so there is no UB.
- `lv < 0` is an unsigned comparison and is **always false**. gcc even warns: `comparison of unsigned expression in '< 0' is always false [-Wtype-limits]`.
- `lv > LV_HIGH` converts `LV_HIGH` (an `int` constant) to `unsigned`, and 4294967295 > 2.
- `enum Offset` has a negative enumerator, so `of` is a signed `int`, and `of < 0` behaves as expected.
- The enumeration *constants* are always `int` in C, so `LV_LOW - 1` is `-1`, not 4294967295.

So the reviewer is wrong: the `lv < 0` half of the check is dead code with gcc. It still "works" only because the huge unsigned value fails the `> LV_HIGH` half. If someone "simplifies" the check to `if (lv < 0)`, negative garbage passes straight through.

**Complexity.** N/A (constant work).

**Common mistakes**
- Believing every enum is a signed `int` in C. That is true for the *constants*, but not necessarily for the enum *type*.
- Writing range checks that rely on `x < 0` for enum-typed variables. Prefer `(unsigned)x >= COUNT`, which is correct for both signed and unsigned underlying types.
- Assuming the result is portable. Another compiler (or `-fshort-enums`) may pick a different type, for example `unsigned char`, where `lv = -1` gives 255.

**Interview follow-ups**
- How does adding `LV_INVALID = -1` to `enum Level` change every line of the output?
- C23 lets you write `enum Level : uint8_t { ... }`. What problems does a fixed underlying type solve for CAN signal and NVM layouts?
- Why do MISRA C:2012's "essential type" rules (Rule 10.x) treat enums as their own essential type category instead of as `int`?
