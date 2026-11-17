@@@ meta
id: PTR-E-06
topic: Pointers
difficulty: Easy
type: FIND_THE_BUG
title: Cluster Debug Labels Crash When Upper-Cased
tags: embedded, string-literal, read-only-memory, array-of-pointers, segfault
@@@ statement_md
The instrument-cluster debug screen prints signal readings as `LABEL=value`, with the label in **upper case**. Each reading arrives as a signal id and a value. Labels are stored in a small table indexed by id:

| id | label |
|---|---|
| 0 | `brake` |
| 1 | `throttle` |
| 2 | `steer` |
| 3 | `gear` |
| 4 | `rpm` |

Unknown ids (negative or `>= 5`) print `UNKNOWN=value`.

The code compiles without warnings, but it crashes (**Segmentation fault**) on the first reading with a valid id. On the target ECU the same code triggers a HardFault. Find and fix the bug. Do not change the output format.

**Input**
- Zero or more lines `id value` until end of input.

**Output**
- One line per reading: `LABEL=value` or `UNKNOWN=value`.

**Example**
```
Input:
0 12
2 -30

Output:
BRAKE=12
STEER=-30
```
@@@ constraints_md
- At most 1000 readings.
- `id` and `value` fit in `int`.
- The labels must be printed in upper case exactly as in the table.
@@@ starter_code
#include <stdio.h>
#include <ctype.h>

/* Signal labels shown on the instrument-cluster debug screen. */
static char *labels[] = { "brake", "throttle", "steer", "gear", "rpm" };
#define NUM_LABELS (sizeof labels / sizeof labels[0])

static void to_upper_inplace(char *s)
{
    for (; *s != '\0'; s++)
        *s = (char)toupper((unsigned char)*s);
}

int main(void)
{
    int id, value;
    while (scanf("%d %d", &id, &value) == 2) {
        if (id < 0 || (size_t)id >= NUM_LABELS) {
            printf("UNKNOWN=%d\n", value);
            continue;
        }
        to_upper_inplace(labels[id]);
        printf("%s=%d\n", labels[id], value);
    }
    return 0;
}
@@@ sample_input
0 12
2 -30
@@@ sample_output
BRAKE=12
STEER=-30

@@@ sample_input
4 3000
4 3100
9 1
@@@ sample_output
RPM=3000
RPM=3100
UNKNOWN=1

@@@ hidden_input
1 45
@@@ hidden_output
THROTTLE=45

@@@ hidden_input
3 2
@@@ hidden_output
GEAR=2

@@@ hidden_input
5 0
-1 7
@@@ hidden_output
UNKNOWN=0
UNKNOWN=7

@@@ hidden_input
0 1
1 2
2 3
3 4
4 5
@@@ hidden_output
BRAKE=1
THROTTLE=2
STEER=3
GEAR=4
RPM=5

@@@ hidden_input
@@@ hidden_output

@@@ hidden_input
2 -2147483648
2 2147483647
@@@ hidden_output
STEER=-2147483648
STEER=2147483647

@@@ hint
Where in memory do the characters of `"brake"` live? Who owns them, and are they allowed to be modified?
@@@ hint
`char *labels[]` is an array of **pointers to string literals**. Writing to a string literal is undefined behavior; in practice they are in read-only memory (`.rodata`, or flash on an MCU). `char labels[][9]` instead creates writable **copies** of the characters.
@@@ solution_code
#include <stdio.h>
#include <ctype.h>

/* Signal labels shown on the instrument-cluster debug screen. */
static char labels[][9] = { "brake", "throttle", "steer", "gear", "rpm" };   /* FIX: writable char arrays, not pointers to literals */
#define NUM_LABELS (sizeof labels / sizeof labels[0])

static void to_upper_inplace(char *s)
{
    for (; *s != '\0'; s++)
        *s = (char)toupper((unsigned char)*s);
}

int main(void)
{
    int id, value;
    while (scanf("%d %d", &id, &value) == 2) {
        if (id < 0 || (size_t)id >= NUM_LABELS) {
            printf("UNKNOWN=%d\n", value);
            continue;
        }
        to_upper_inplace(labels[id]);
        printf("%s=%d\n", labels[id], value);
    }
    return 0;
}
@@@ explanation_md
**Bug.** `static char *labels[] = { "brake", ... };` is an array of 5 **pointers**. Each one points to a string literal. String literals have static storage, and modifying one is undefined behavior (C11 6.4.5p7). gcc and clang place them in the read-only `.rodata` section, so `to_upper_inplace` faults on its first write. On a microcontroller the literals are in flash, and the write causes a bus fault or HardFault. C allows `char *` for literals only for historical reasons, so the compiler says nothing.

**Fix.** Declare a 2-D `char` array: `static char labels[][9]`. Each row is a writable copy of the characters (9 = longest label `"throttle"` + NUL). `labels[id]` still decays to a `char *`, so no other line changes. `NUM_LABELS` still works because `sizeof labels[0]` is now the row size (9).

| declaration | storage | `sizeof labels` | writable? |
|---|---|---|---|
| `char *labels[5]` | 5 pointers (40 B) + literals in `.rodata` | 40 | no (UB) |
| `char labels[5][9]` | 45 bytes of `char` in `.data` | 45 | yes |

A cleaner design keeps the table `static const char *const labels[]` (it can then stay in flash) and copies a label into a local buffer before upper-casing it. That is the usual choice on RAM-constrained ECUs.

**Complexity.** O(L) per reading for a label of length L, O(1) extra space.

**Common mistakes**
- "Fixing" it with a cast or by making `to_upper_inplace` take `const char *`. The write is still there.
- Using `char labels[][8]`. `"throttle"` needs 9 bytes; with 8, the array silently drops the terminating NUL (legal in C for an exact fit), and `printf("%s")` reads past the row.
- Assuming this works because it ran on some compiler. Old compilers or MCUs without memory protection let the write succeed and silently corrupt literals that other code shares.

**Interview follow-ups**
- What is the difference between `char s[] = "abc";` and `char *s = "abc";` (storage, `sizeof`, writability)?
- Why should the declaration be `static const char *const labels[]`, and what does each `const` buy you on an MCU?
- Can two identical string literals share the same address? (Unspecified, so never compare strings with `==`.)
- How would you get a compiler warning for this? (`-Wwrite-strings` in C makes literals `const char[]`.)
