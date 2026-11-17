@@@ meta
id: STC-M-02
topic: Structures
difficulty: Medium
type: PREDICT_OUTPUT
title: Bit-Field Sizes, Truncation and Signed Wrap
tags: embedded, bit-fields, sizeof, implementation-defined, status-word
@@@ statement_md
A status word is modelled with bit-fields. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, System V bit-field layout** (bit-fields are allocated from the least significant bit, and a bit-field never straddles a storage unit of its declared type).

```c
#include <stdio.h>
#include <stdint.h>

struct Status {
    unsigned int ready : 1;
    unsigned int mode  : 3;
    signed int   delta : 4;
    unsigned int count : 30;
};

struct Small {
    uint8_t a : 4;
    uint8_t b : 4;
    uint8_t c : 1;
};

int main(void)
{
    struct Status s = { 0 };

    s.mode = 9;
    s.ready = 3;
    s.delta = 7;
    s.delta += 1;

    printf("%zu %zu\n", sizeof(struct Status), sizeof(struct Small));
    printf("%u %d %u\n", (unsigned)s.mode, (int)s.delta, (unsigned)s.ready);

    const unsigned char *raw = (const unsigned char *)&s;
    printf("%02X\n", raw[0]);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI (gcc is the reference compiler; the warnings it prints do not stop compilation).
- Converting an out-of-range value to a **signed** bit-field is implementation-defined, not undefined. gcc wraps modulo 2^width.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

struct Status {
    unsigned int ready : 1;
    unsigned int mode  : 3;
    signed int   delta : 4;
    unsigned int count : 30;
};

struct Small {
    uint8_t a : 4;
    uint8_t b : 4;
    uint8_t c : 1;
};

int main(void)
{
    struct Status s = { 0 };

    s.mode = 9;
    s.ready = 3;
    s.delta = 7;
    s.delta += 1;

    printf("%zu %zu\n", sizeof(struct Status), sizeof(struct Small));
    printf("%u %d %u\n", (unsigned)s.mode, (int)s.delta, (unsigned)s.ready);

    const unsigned char *raw = (const unsigned char *)&s;
    printf("%02X\n", raw[0]);
    return 0;
}
@@@ predict_answer
8 2
1 -8 1
83
@@@ hint
`ready + mode + delta` use 8 bits of the first 32-bit unit. Can a 30-bit field fit into the remaining 24 bits without crossing into the next `unsigned int`?
@@@ hint
Unsigned bit-fields keep the value modulo 2^width (`9 mod 8`, `3 mod 2`). A signed 4-bit field holds -8..7, so 7 + 1 wraps to -8 with gcc. Then assemble byte 0 from bit 0 upward: `ready`, then `mode`, then `delta`.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

struct Status {
    unsigned int ready : 1;   /* bit 0                                      */
    unsigned int mode  : 3;   /* bits 1..3                                  */
    signed int   delta : 4;   /* bits 4..7                                  */
    unsigned int count : 30;  /* 8 + 30 > 32: starts a NEW unit at bit 32   */
};                            /* 64 bits -> sizeof = 8                      */

struct Small {
    uint8_t a : 4;            /* byte 0, bits 0..3 */
    uint8_t b : 4;            /* byte 0, bits 4..7 */
    uint8_t c : 1;            /* byte 0 is full -> byte 1; sizeof = 2 (alignment 1) */
};

int main(void)
{
    struct Status s = { 0 };

    s.mode = 9;               /* 1001b, only 3 bits kept -> 001b = 1 (well-defined, unsigned)    */
    s.ready = 3;              /* 11b, 1 bit kept -> 1                                             */
    s.delta = 7;              /* 0111b, fits in -8..7                                             */
    s.delta += 1;             /* int 8 -> signed 4-bit: implementation-defined, gcc gives -8 (1000b) */

    printf("%zu %zu\n", sizeof(struct Status), sizeof(struct Small));          /* 8 2    */
    printf("%u %d %u\n", (unsigned)s.mode, (int)s.delta, (unsigned)s.ready);   /* 1 -8 1 */

    /* byte 0 = delta(1000) mode(001) ready(1) = 1000 0011b = 0x83 */
    const unsigned char *raw = (const unsigned char *)&s;
    printf("%02X\n", raw[0]);                                                  /* 83     */
    return 0;
}
@@@ explanation_md
**Answer**
```
8 2
1 -8 1
83
```

**Approach.**
1. **Layout of `struct Status`.** In the System V ABI, bit-fields are packed from the LSB of an `unsigned int` unit. `ready` (1) + `mode` (3) + `delta` (4) = 8 bits. `count` needs 30 bits, but only 24 remain in the first unit and a field may not straddle its unit. So `count` starts at bit 32, and the struct is **8** bytes.
2. **`struct Small`.** The declared type is `uint8_t`, so the unit is one byte. `a` and `b` fill byte 0, and `c` starts byte 1. With alignment 1 the size is **2**. A `uint8_t` bit-field is itself an implementation-defined extension: C11 only guarantees `_Bool`, `signed int` and `unsigned int`, which is one more reason bit-field layouts are not portable.
3. **Truncation.** Assigning to an unsigned bit-field keeps the low bits (well-defined): `9 -> 1`, `3 -> 1`.
4. **Signed wrap.** A signed 4-bit field holds -8..7. `s.delta += 1` computes `int 8` and converts it back. That conversion is **implementation-defined** (C11 6.3.1.3p3). gcc documents modulo-2^N wrapping, so the result is `-8`.
5. **Raw byte.** From bit 7 down: delta `1000`, mode `001`, ready `1`, which is `1000 0011` = `0x83`.

**Complexity.** N/A. Every bit-field access compiles to load, mask and shift (read-modify-write for stores), so bit-fields are slower than plain integer members.

**Common mistakes**
- `sizeof(struct Status) == 5` (counting 38 bits) or `== 4` (assuming fields may straddle units).
- Expecting `mode == 9` or a compile error. gcc only **warns** (`-Woverflow`) and truncates.
- Expecting `delta == 8`. A 4-bit signed field cannot hold 8.
- Writing `int delta : 4`. Whether a plain `int` bit-field is signed is implementation-defined (C11 6.7.2p5). Always write `signed` or `unsigned` explicitly. MISRA C:2012 Rule 6.1 requires an explicitly signed or unsigned type.
- Reading `raw[0]` MSB-first (`ready` as bit 7), which gives `0x98`.

**Interview follow-ups**
- Why do many automotive coding guidelines forbid bit-fields for mapping hardware registers or CAN payloads? (Allocation order, unit size and straddling are implementation-defined.)
- What does `unsigned int : 0;` do inside a bit-field struct?
- Can you take the address of a bit-field (`&s.mode`)? Why not, and how do you pass it to a function?
- How would you write `delta` and `mode` with explicit masks and shifts on a `uint32_t` instead, so the layout is portable?
