@@@ meta
id: BIT-H-08
topic: Bit Manipulation
difficulty: Hard
type: PREDICT_OUTPUT
title: Bit-Field Register Overlay With a Plain int Field
tags: embedded, bit-fields, union, implementation-defined, registers, misra
@@@ statement_md
A legacy driver overlays a control register with a union of a raw word and a bit-field struct. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**, System V ABI: bit-fields are allocated starting at the **least significant bit** of the storage unit, a plain `int` bit-field is **signed**, and gcc stores an out-of-range value into a bit-field by reducing it modulo 2^width.

```c
#include <stdio.h>
#include <stdint.h>

union CtrlReg {
    uint32_t raw;
    struct {
        unsigned int en   : 1;
        unsigned int mode : 3;
        unsigned int prio : 4;
        int          trim : 4;
    } f;
};

int main(void)
{
    union CtrlReg r;
    r.raw = 0x00000CA5u;
    printf("%u %u %u %d\n", r.f.en, r.f.mode, r.f.prio, r.f.trim);

    r.f.mode = 9;
    r.f.trim = 7;
    printf("%08X\n", r.raw);

    r.f.trim = r.f.trim + 1;
    printf("%d %d\n", r.f.trim, r.f.trim == 8);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 gcc, System V bit-field layout (LSB first), plain `int` bit-fields are signed.
- Reading a union member other than the one last written reinterprets the bytes (C11 6.5.2.3 footnote 95). It is not undefined behavior in C.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

union CtrlReg {
    uint32_t raw;
    struct {
        unsigned int en   : 1;
        unsigned int mode : 3;
        unsigned int prio : 4;
        int          trim : 4;
    } f;
};

int main(void)
{
    union CtrlReg r;
    r.raw = 0x00000CA5u;
    printf("%u %u %u %d\n", r.f.en, r.f.mode, r.f.prio, r.f.trim);

    r.f.mode = 9;
    r.f.trim = 7;
    printf("%08X\n", r.raw);

    r.f.trim = r.f.trim + 1;
    printf("%d %d\n", r.f.trim, r.f.trim == 8);
    return 0;
}
@@@ predict_answer
1 2 10 -4
000007A3
-8 0
@@@ hint
Write `0xCA5` in binary and cut it from the right: 1 bit for `en`, 3 bits for `mode`, 4 bits for `prio`, 4 bits for `trim`. A 4-bit **signed** field holds -8..7.
@@@ hint
Storing 9 into a 3-bit unsigned field keeps only the low 3 bits (it is reduced modulo 8, which the standard defines for unsigned types). Storing 8 into a 4-bit signed field is out of range: gcc wraps it modulo 16.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

/* SysV / gcc: fields fill the 32-bit unit from bit 0 upwards
 *   bit  0      : en
 *   bits 1..3   : mode
 *   bits 4..7   : prio
 *   bits 8..11  : trim  (plain int -> signed in gcc, range -8..7)
 */
union CtrlReg {
    uint32_t raw;
    struct {
        unsigned int en   : 1;
        unsigned int mode : 3;
        unsigned int prio : 4;
        int          trim : 4;
    } f;
};

int main(void)
{
    union CtrlReg r;
    r.raw = 0x00000CA5u;   /* 1100 1010 0101 : trim=1100 prio=1010 mode=010 en=1 */
    printf("%u %u %u %d\n", r.f.en, r.f.mode, r.f.prio, r.f.trim);   /* 1 2 10 -4 */

    r.f.mode = 9;          /* 9 = 1001b -> low 3 bits 001 -> mode = 1 (gcc warns -Woverflow) */
    r.f.trim = 7;          /* fits: 0111 */
    /* raw = trim 0111 | prio 1010 | mode 001 | en 1 = 0111 1010 0011 = 0x7A3 */
    printf("%08X\n", r.raw);                                          /* 000007A3 */

    r.f.trim = r.f.trim + 1;   /* 8 does not fit in -8..7: implementation-defined, gcc -> -8 */
    printf("%d %d\n", r.f.trim, r.f.trim == 8);                       /* -8 0 */
    return 0;
}
@@@ explanation_md
**Answer**
```
1 2 10 -4
000007A3
-8 0
```

**Step by step.** `0xCA5 = 1100 1010 0101`. With LSB-first allocation:

| field | bits | value |
|---|---|---|
| `en` | 0 | `1` |
| `mode` | 3..1 = `010` | 2 |
| `prio` | 7..4 = `1010` | 10 |
| `trim` | 11..8 = `1100` | signed 4-bit: **-4** (not 12) |

Then `mode = 9` keeps `001` (unsigned bit-fields wrap modulo 2^3, which is well defined), and `trim = 7` gives `0111`. Reassembled: trim `0111` | prio `1010` | mode `001` | en `1` = `0111 1010 0011` = `0x7A3`. Finally `trim = 7 + 1 = 8` cannot be represented in a signed 4-bit field. The conversion is **implementation-defined** (C11 6.3.1.3p3, not UB), and gcc wraps it to `1000` = **-8**. So `trim == 8` is false.

Four implementation-defined choices decide this output:
1. **Bit order** inside the storage unit (LSB first in the SysV ABI; some big-endian ABIs allocate from the MSB).
2. Whether a plain `int` bit-field is **signed** (gcc: yes, unless `-funsigned-bitfields`; some embedded compilers say no).
3. The result of storing an out-of-range value into a **signed** bit-field.
4. Storage-unit size, padding and straddling rules (here everything fits in one 32-bit unit).

**Complexity.** N/A.

**Common mistakes**
- Reading `trim` as 12. A plain `int` bit-field is signed in gcc.
- Assuming `mode = 9` stores 9 or "saturates" to 7. It silently keeps the low bits, a classic configuration corruption.
- Assuming the layout is portable. The same header compiled for a big-endian PowerPC (MSB-first bit-field allocation) maps `en` to bit 31, and every register access is wrong.

**Interview follow-ups**
- Why do MISRA C:2012 (Rule 6.1: bit-fields only of `unsigned int`/`signed int`/`_Bool`; Rule 6.2: single-bit fields must be unsigned) and most automotive guidelines restrict bit-fields, and why do CMSIS headers use masks and shifts instead?
- If you **must** use a bit-field overlay for a peripheral register, which problems remain? (A write to one field is a read-modify-write of the whole register, and the access width may not match.)
- Rewrite the overlay with `READ_FIELD`/`WRITE_FIELD` macros and masks so that it is fully portable.
- What does `_Static_assert(sizeof(union CtrlReg) == 4, "...")` protect against, and what does it *not* protect against?
