@@@ meta
id: ENM-E-02
topic: Enums
difficulty: Easy
type: PREDICT_OUTPUT
title: sizeof an Enum Variable, an Enumerator and an Enum Member
tags: embedded, sizeof, enum-size, struct-padding, can-frame
@@@ statement_md
A junior engineer wants to save RAM in a CAN signal buffer and assumes an enum with four values "only needs 1 byte". What does this program print?

Assume **x86-64 Linux, gcc (no `-fshort-enums`), little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdint.h>

enum Gear { GEAR_P, GEAR_R, GEAR_N, GEAR_D };

struct GearMsg {
    uint8_t   id;
    uint8_t   dlc;
    enum Gear gear;
    uint8_t   crc;
};

int main(void)
{
    enum Gear g = GEAR_D;
    enum Gear history[GEAR_D + 1];

    printf("%zu %zu %zu\n", sizeof g, sizeof GEAR_R, sizeof(uint8_t) * GEAR_D);
    printf("%zu %zu\n", sizeof history, sizeof(struct GearMsg));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI, default options (enums are not packed).
- `uint8_t` = 1 byte, `int` = 4 bytes with 4-byte alignment.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

enum Gear { GEAR_P, GEAR_R, GEAR_N, GEAR_D };

struct GearMsg {
    uint8_t   id;
    uint8_t   dlc;
    enum Gear gear;
    uint8_t   crc;
};

int main(void)
{
    enum Gear g = GEAR_D;
    enum Gear history[GEAR_D + 1];

    printf("%zu %zu %zu\n", sizeof g, sizeof GEAR_R, sizeof(uint8_t) * GEAR_D);
    printf("%zu %zu\n", sizeof history, sizeof(struct GearMsg));
    return 0;
}
@@@ predict_answer
4 4 3
16 12
@@@ hint
The values 0..3 would fit in one byte, but on this ABI gcc gives every enum type the size of `int` unless its values need more. An enumeration **constant** like `GEAR_R` has type `int` in C.
@@@ hint
`GEAR_D` is 3, so the array has 4 elements. In the struct, the 4-byte enum member must start at an offset that is a multiple of 4, and the total size is rounded up to a multiple of 4.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

enum Gear { GEAR_P, GEAR_R, GEAR_N, GEAR_D };   /* 0, 1, 2, 3 */

/* Layout:
 *  0: id    (1)
 *  1: dlc   (1) + 2 padding  -> enum Gear needs 4-byte alignment
 *  4: gear  (4)
 *  8: crc   (1) + 3 tail padding -> size rounded up to a multiple of 4
 * sizeof = 12
 */
struct GearMsg {
    uint8_t   id;
    uint8_t   dlc;
    enum Gear gear;
    uint8_t   crc;
};

int main(void)
{
    enum Gear g = GEAR_D;
    enum Gear history[GEAR_D + 1];          /* 3 + 1 = 4 elements */

    (void)g;
    /* sizeof g        -> 4 (enum type is int-sized; gcc uses unsigned int here)
     * sizeof GEAR_R   -> 4 (an enumeration constant has type int)
     * 1 * GEAR_D      -> 3                                                  */
    printf("%zu %zu %zu\n", sizeof g, sizeof GEAR_R, sizeof(uint8_t) * GEAR_D);

    /* 4 elements * 4 bytes = 16; struct = 12 (see layout above) */
    printf("%zu %zu\n", sizeof history, sizeof(struct GearMsg));
    return 0;
}
@@@ explanation_md
**Answer**
```
4 4 3
16 12
```

**Approach.**
- **`sizeof g` = 4.** C11 6.7.2.2p4 only requires the enum type to be compatible with `char`, a signed integer type or an unsigned integer type that can hold all its values. The choice is up to the implementation. gcc on x86-64 picks `unsigned int` (4 bytes) when there are no negative enumerators, and `int` when there are. It shrinks enums only with `-fshort-enums` or `__attribute__((packed))`.
- **`sizeof GEAR_R` = 4.** In C (unlike C++), an enumeration *constant* has type `int`, whatever the enum's own type is.
- **`sizeof(uint8_t) * GEAR_D` = 3.** `GEAR_D` is 3, so this is `1 * 3`.
- **`sizeof history` = 16.** The array has `GEAR_D + 1 = 4` elements of 4 bytes each.
- **`sizeof(struct GearMsg)` = 12.** `id` and `dlc` take offsets 0 and 1. Two padding bytes put `gear` at offset 4. `crc` is at offset 8, then 3 bytes of tail padding round the size up to 12. That is 7 bytes of data in a 12-byte struct.

**Complexity.** N/A. Sizes are compile-time constants. The cost is memory: an `enum` member can quadruple the size of a signal record.

**Common mistakes**
- Assuming the compiler picks "the smallest type that fits". Some embedded toolchains do (IAR and Keil options, some ARM EABI variants built with short enums), and gcc/clang on desktop Linux do not. That makes a struct with an enum member **ABI-fragile** across compilers.
- Putting an `enum` directly into a struct that is `memcpy`'d into a CAN payload, EEPROM record or IPC message. Its size and alignment are not fixed by the standard.
- Confusing C with C++. In C++, `sizeof GEAR_R == sizeof(enum Gear)`, and C++11 lets you write `enum Gear : uint8_t`. C23 added the same fixed underlying type syntax, but C11 code cannot use it.

**Interview follow-ups**
- How do you store a gear position in a 1-byte field portably? (Use a `uint8_t` member and convert to and from the enum at the API boundary, with range validation.)
- What does `-fshort-enums` change, and why must every object file and library in a project be built with the same setting?
- Add a compile-time guard that fails the build if `sizeof(struct GearMsg)` changes. (`_Static_assert(sizeof(struct GearMsg) == 12, "...")`)
