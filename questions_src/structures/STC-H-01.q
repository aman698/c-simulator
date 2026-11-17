@@@ meta
id: STC-H-01
topic: Structures
difficulty: Hard
type: PREDICT_OUTPUT
title: Packed Sensor PDU and a Pointer to Its Member
tags: embedded, packed, alignment, undefined-behavior, cortex-m
@@@ statement_md
A sensor PDU is declared `packed` so it matches the 7-byte wire format. A helper takes a `const uint32_t *` to read the value. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**. Compiler warnings do not stop compilation.

```c
#include <stdio.h>
#include <stdint.h>

struct __attribute__((packed)) SensorPdu {
    uint8_t  type;
    uint32_t value;
    uint16_t crc;
};

static uint32_t read_u32(const uint32_t *p)
{
    return *p;
}

int main(void)
{
    _Alignas(4) struct SensorPdu pdu = { 0x01, 0x11223344u, 0xBEEF };

    printf("%zu %zu\n", sizeof pdu, _Alignof(struct SensorPdu));
    printf("%X\n", (unsigned)pdu.value);
    printf("%X\n", (unsigned)read_u32(&pdu.value));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc (GNU C11 with `__attribute__((packed))`).
- `_Alignas(4)` places the variable `pdu` at an address that is a multiple of 4.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

struct __attribute__((packed)) SensorPdu {
    uint8_t  type;
    uint32_t value;
    uint16_t crc;
};

static uint32_t read_u32(const uint32_t *p)
{
    return *p;
}

int main(void)
{
    _Alignas(4) struct SensorPdu pdu = { 0x01, 0x11223344u, 0xBEEF };

    printf("%zu %zu\n", sizeof pdu, _Alignof(struct SensorPdu));
    printf("%X\n", (unsigned)pdu.value);
    printf("%X\n", (unsigned)read_u32(&pdu.value));
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
The first two lines are harmless: a packed struct has no padding and alignment 1, and the compiler knows that `pdu.value` may be misaligned, so it emits a safe load. Now look at the address `&pdu.value`. `pdu` starts at a multiple of 4, so where does `value` start?
@@@ hint
`&pdu.value` is `base + 1`. Its type is `uint32_t *`, which promises 4-byte alignment. `read_u32` dereferences it with a normal aligned load, and the compiler warns about this with `-Waddress-of-packed-member`.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* packed: no padding, sizeof = 1 + 4 + 2 = 7, alignment of the struct = 1.
 * value lives at offset 1. */
struct __attribute__((packed)) SensorPdu {
    uint8_t  type;
    uint32_t value;
    uint16_t crc;
};

static uint32_t read_u32(const uint32_t *p)
{
    return *p;            /* assumes *p is 4-byte aligned */
}

int main(void)
{
    _Alignas(4) struct SensorPdu pdu = { 0x01, 0x11223344u, 0xBEEF };

    printf("%zu %zu\n", sizeof pdu, _Alignof(struct SensorPdu));   /* 7 1: fine            */
    printf("%X\n", (unsigned)pdu.value);                           /* fine: compiler emits an
                                                                      unaligned-safe access */

    /* UB: &pdu.value == (char *)&pdu + 1 is NOT 4-aligned, but its type uint32_t *
     * claims it is (C11 6.3.2.3p7). The dereference in read_u32 is a misaligned
     * access: UBSan reports "load of misaligned address ... requires 4 byte alignment";
     * on a Cortex-M0 or with strict-alignment ARM settings it is a HardFault.
     *
     * Correct version: copy the member, then use the copy:
     *     uint32_t v = pdu.value;          (or memcpy(&v, &pdu.value, sizeof v))
     *     read_u32(&v);
     */
    printf("%X\n", (unsigned)read_u32(&pdu.value));
    return 0;
}
@@@ explanation_md
**Answer: `Undefined Behavior`**

**Approach.**
1. `sizeof pdu` = 7 and `_Alignof(struct SensorPdu)` = 1. Packing removes all padding and drops the struct's alignment to 1.
2. `pdu.value` accessed **through the struct** is fine. The compiler knows the member may be misaligned and generates a safe access: an unaligned `mov` on x86, or byte loads plus shifts on ARMv6-M.
3. `&pdu.value` yields a plain `uint32_t *` that points to `base + 1`, which is guaranteed misaligned because `_Alignas(4)` fixes `base`. The pointer type no longer carries the "packed" information. Converting to a pointer that is not correctly aligned for its type is undefined (C11 6.3.2.3p7), and so is the 4-byte load in `read_u32`. gcc warns: *taking address of packed member of 'struct SensorPdu' may result in an unaligned pointer value* (`-Waddress-of-packed-member`). UBSan aborts with "load of misaligned address".

On x86 without sanitizers it "works" and prints `11223344`, which is why this bug ships. On a Cortex-M0/M0+, an unaligned LDR raises a **HardFault**. On Cortex-M3/M4 it works unless `UNALIGN_TRP` is set, but `LDRD`/`LDM` still fault. With optimization, the compiler may also vectorize under the alignment assumption.

**Complexity.** N/A. Note that every packed-member access costs extra instructions on cores without unaligned support.

**Common mistakes**
- Answering `7 1 / 11223344 / 11223344`, the observed x86 output, without noticing the misaligned pointer.
- Answering `12 4`. That is the unpacked layout (1 + 3 padding + 4 + 2 + 2 tail).
- Thinking `packed` makes *all* uses of the member safe. Only accesses that go through the packed struct type are safe.
- Fixing it with a cast, `read_u32((const uint32_t *)((const uint8_t *)&pdu + 1))`. It silences the warning and keeps the UB.

**Interview follow-ups**
- How would you parse this 7-byte wire format **without** `packed`? (Byte array plus explicit little-endian assembly, or `memcpy` into an aligned local.)
- Why do some code bases forbid `packed` structs entirely and generate (de)serializers instead?
- What does `__attribute__((packed, aligned(4)))` change, and is `&pdu.value` aligned then?
- On a Cortex-M4, which instructions tolerate unaligned addresses and which always fault (`LDRD`, `LDM`, `STRD`)?
