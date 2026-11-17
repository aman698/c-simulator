@@@ meta
id: STR-M-08
topic: Strings
difficulty: Medium
type: PREDICT_OUTPUT
title: Missing Comma in a Bus-Name Table
tags: embedded, string-literal-concatenation, array-initializer, sizeof, missing-terminator
@@@ statement_md
A gateway's diagnostic menu has a table of bus names. Someone edited it in a hurry. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

static const char *bus_names[] = {
    "CAN",
    "LIN"
    "FlexRay",
    "MOST",
};

int main(void)
{
    char id[3] = "ECU";
    char ver[] = "v" "1." "2";

    printf("%zu\n", sizeof bus_names / sizeof bus_names[0]);
    printf("%s|%s\n", bus_names[1], bus_names[2]);
    printf("%zu %zu %c\n", sizeof id, sizeof ver, id[2]);
    printf("%.3s %s\n", id, ver);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, C11. Warnings, if any, do not stop compilation.
@@@ starter_code
#include <stdio.h>

static const char *bus_names[] = {
    "CAN",
    "LIN"
    "FlexRay",
    "MOST",
};

int main(void)
{
    char id[3] = "ECU";
    char ver[] = "v" "1." "2";

    printf("%zu\n", sizeof bus_names / sizeof bus_names[0]);
    printf("%s|%s\n", bus_names[1], bus_names[2]);
    printf("%zu %zu %c\n", sizeof id, sizeof ver, id[2]);
    printf("%.3s %s\n", id, ver);
    return 0;
}
@@@ predict_answer
3
LINFlexRay|MOST
3 5 U
ECU v1.2
@@@ hint
Adjacent string literals are joined into **one** literal during translation (translation phase 6), before the compiler sees the array initializer. Count the commas, not the lines.
@@@ hint
`char id[3] = "ECU";` is legal C: when the array is exactly as long as the characters, the terminator is silently dropped (C11 6.7.9p14). `id` is therefore **not** a string. `%.3s` is safe because the precision limits how many bytes `printf` reads.
@@@ solution_code
#include <stdio.h>

static const char *bus_names[] = {
    "CAN",
    "LIN"           /* <- missing comma: "LIN" "FlexRay" becomes "LINFlexRay" */
    "FlexRay",
    "MOST",         /* trailing comma is allowed and adds no element          */
};                  /* => 3 elements: "CAN", "LINFlexRay", "MOST"             */

int main(void)
{
    char id[3] = "ECU";         /* 'E' 'C' 'U' - no '\0' (legal in C, an error in C++) */
    char ver[] = "v" "1." "2";  /* one literal "v1.2" -> char[5]                      */

    printf("%zu\n", sizeof bus_names / sizeof bus_names[0]);   /* 3                */
    printf("%s|%s\n", bus_names[1], bus_names[2]);            /* LINFlexRay|MOST  */
    printf("%zu %zu %c\n", sizeof id, sizeof ver, id[2]);     /* 3 5 U            */
    printf("%.3s %s\n", id, ver);   /* precision 3: reads at most 3 bytes -> "ECU" */
    return 0;
}
@@@ explanation_md
**Answer**
```
3
LINFlexRay|MOST
3 5 U
ECU v1.2
```

1. **Literal concatenation.** C joins adjacent string literals (`"LIN" "FlexRay"` -> `"LINFlexRay"`) in translation phase 6. The missing comma therefore produces **3** table entries instead of 4. The trailing comma after `"MOST"` is legal and adds nothing. A menu index such as `bus_names[3]` now reads past the end of the array, a bug that compiles cleanly.
2. `bus_names[1]` is `"LINFlexRay"` and `bus_names[2]` is `"MOST"`.
3. `char id[3] = "ECU";` is allowed in C (not in C++). There is room for exactly the three characters, so **no terminator** is stored. `sizeof id` is 3. `"v" "1." "2"` is the single literal `"v1.2"`, so `ver` is `char[5]`.
4. `printf("%.3s", id)` is well defined. C11 7.21.6.1p8 says that with a precision, `printf` writes at most that many bytes and the array needs a `'\0'` only if it is shorter than the precision. A plain `printf("%s", id)` would be **undefined behavior**, because it reads past `id` looking for a terminator.

**Complexity.** N/A: all of this happens at compile time, apart from the `printf` calls.

**Common mistakes**
- Answering `4` for the table size. The line count is not the element count.
- Thinking `char id[3] = "ECU";` is a compile error. It is not in C. GCC only warns about it with `-Wunterminated-string-initialization` (in newer GCC versions as part of `-Wextra`).
- Thinking `%.3s` on a non-terminated array is UB. With a precision that does not exceed the array size, it is fine.

**Interview follow-ups**
- How do you guard a lookup table against this kind of silent miscount? (`_Static_assert(sizeof bus_names / sizeof bus_names[0] == BUS_COUNT, "...")`, or designated initializers `[BUS_LIN] = "LIN"` indexed by an enum.)
- Where is literal concatenation genuinely useful? (Splitting long strings across lines, and building format strings from `<inttypes.h>` macros: `"%" PRIu32 "\n"`.)
- When is a non-terminated `char` array the *right* choice? (Fixed-width protocol fields such as a 17-byte VIN or a 4-byte CAN signal tag, always handled with explicit lengths and `memcpy`/`memcmp`.)
