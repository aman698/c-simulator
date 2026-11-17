@@@ meta
id: STC-H-02
topic: Structures
difficulty: Hard
type: PREDICT_OUTPUT
title: Flexible Array in the Tail Padding and Designated Initializers
tags: flexible-array-member, designated-initializer, offsetof, nested-struct, sizeof
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

struct Ver { uint8_t major, minor; };

struct Pdu {
    uint32_t   seq;
    struct Ver ver;
    uint8_t    kind;
    uint8_t    data[];
};

int main(void)
{
    struct Pdu tmpl = { .ver.minor = 7, .seq = 42 };
    uint8_t map[6] = { [3] = 0x30, 0x40, [1] = 0x10 };
    size_t need = offsetof(struct Pdu, data) + 3;

    struct Pdu *p = malloc(sizeof(struct Pdu) + 3);
    if (!p) return 1;
    *p = tmpl;
    p->data[0] = map[1];
    p->data[1] = map[4];
    p->data[2] = map[5];

    printf("%zu %zu %zu\n", sizeof(struct Pdu), offsetof(struct Pdu, data), need);
    printf("%u.%u %u %u\n", p->ver.major, p->ver.minor, p->kind, (unsigned)p->seq);
    printf("%02X %02X %02X %02X\n", map[0], map[3], map[4], p->data[0] + p->data[1] + p->data[2]);
    free(p);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI (`uint32_t` 4-byte aligned).
- A flexible array member contributes nothing to `sizeof`, except that the struct may have more trailing padding (C11 6.7.2.1p18).
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

struct Ver { uint8_t major, minor; };

struct Pdu {
    uint32_t   seq;
    struct Ver ver;
    uint8_t    kind;
    uint8_t    data[];
};

int main(void)
{
    struct Pdu tmpl = { .ver.minor = 7, .seq = 42 };
    uint8_t map[6] = { [3] = 0x30, 0x40, [1] = 0x10 };
    size_t need = offsetof(struct Pdu, data) + 3;

    struct Pdu *p = malloc(sizeof(struct Pdu) + 3);
    if (!p) return 1;
    *p = tmpl;
    p->data[0] = map[1];
    p->data[1] = map[4];
    p->data[2] = map[5];

    printf("%zu %zu %zu\n", sizeof(struct Pdu), offsetof(struct Pdu, data), need);
    printf("%u.%u %u %u\n", p->ver.major, p->ver.minor, p->kind, (unsigned)p->seq);
    printf("%02X %02X %02X %02X\n", map[0], map[3], map[4], p->data[0] + p->data[1] + p->data[2]);
    free(p);
    return 0;
}
@@@ predict_answer
8 7 10
0.7 0 42
00 30 40 50
@@@ hint
Lay out the members: `seq` at 0..3, `ver` (two bytes, alignment 1) at 4..5, `kind` at 6. A `uint8_t` FAM needs no alignment, so where does `data` start? Then round the struct up to its alignment (4).
@@@ hint
Members missing from a designated initializer are zero, even nested ones such as `.ver.major`. In an array initializer, an element without a designator continues **after the previous designated element**: `[3] = 0x30, 0x40` fills indices 3 and 4.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

struct Ver { uint8_t major, minor; };   /* size 2, alignment 1 */

struct Pdu {
    uint32_t   seq;      /* 0..3                                        */
    struct Ver ver;      /* 4..5                                        */
    uint8_t    kind;     /* 6                                           */
    uint8_t    data[];   /* starts at 7 - INSIDE the 1 byte of tail     */
};                       /* padding; sizeof = round_up(7, 4) = 8        */

int main(void)
{
    /* .seq = 42, .ver.minor = 7; everything not named is zero: ver.major = 0, kind = 0 */
    struct Pdu tmpl = { .ver.minor = 7, .seq = 42 };

    /* [3]=0x30, next element -> [4]=0x40, [1]=0x10; others 0:  {00,10,00,30,40,00} */
    uint8_t map[6] = { [3] = 0x30, 0x40, [1] = 0x10 };

    size_t need = offsetof(struct Pdu, data) + 3;          /* 7 + 3 = 10 (exact minimum) */

    struct Pdu *p = malloc(sizeof(struct Pdu) + 3);        /* 11 bytes: 1 byte more than needed */
    if (!p) return 1;
    *p = tmpl;            /* copies sizeof(struct Pdu) = 8 bytes: that includes byte 7,
                             i.e. data[0]! Safe here only because data is written AFTER. */
    p->data[0] = map[1];  /* 0x10 */
    p->data[1] = map[4];  /* 0x40 */
    p->data[2] = map[5];  /* 0x00 */

    printf("%zu %zu %zu\n", sizeof(struct Pdu), offsetof(struct Pdu, data), need);  /* 8 7 10      */
    printf("%u.%u %u %u\n", p->ver.major, p->ver.minor, p->kind, (unsigned)p->seq);/* 0.7 0 42    */
    printf("%02X %02X %02X %02X\n", map[0], map[3], map[4],
           p->data[0] + p->data[1] + p->data[2]);                                  /* 00 30 40 50 */
    free(p);
    return 0;
}
@@@ explanation_md
**Answer**
```
8 7 10
0.7 0 42
00 30 40 50
```

**Approach.**
1. **Layout.** `seq` 0..3, `ver` 4..5 (a struct of two bytes has alignment 1), `kind` 6. `data` is a `uint8_t` array, so it starts right at offset **7**. Without the FAM, the struct would be 7 bytes rounded up to its alignment 4, so **`sizeof` is 8**. The FAM starts *inside* the tail padding: `offsetof(data) = 7 < sizeof = 8`.
2. **Allocation size.** The common idiom `sizeof(struct Pdu) + n` over-allocates by one byte here (11 instead of 10). It is safe, just slightly wasteful. `offsetof(struct Pdu, data) + n` is the exact minimum.
3. **Designated initializers.** Every member not mentioned is zero-initialized (C11 6.7.9p19), and nested designators like `.ver.minor` work. The order of designators does not matter.
4. **Array designators.** An initializer without a designator continues at the element **after** the last designated one, so `0x40` goes to index 4. A later `[1]` can jump backwards. Result: `{00, 10, 00, 30, 40, 00}`.
5. **Payload.** `0x10 + 0x40 + 0x00 = 0x50`.

**The hidden trap.** `*p = tmpl;` copies `sizeof(struct Pdu)` = 8 bytes, and byte 7 is `data[0]`. Had the payload been written first, the struct assignment would have overwritten `data[0]` with a padding byte (an unspecified value). Always assign or `memcpy` the header **before** filling the FAM.

**Complexity.** N/A (compile-time layout plus three stores).

**Common mistakes**
- Answering `sizeof = 7`, forgetting tail padding, or `12`, assuming the FAM adds its own aligned slot.
- Assuming `offsetof(data) == sizeof(struct Pdu)`. That holds only when the FAM's alignment pushes it past the padding.
- Reading `[3] = 0x30, 0x40` as `map[0] = 0x40`, or thinking `[1] = 0x10` overrides `map[3]`.
- Expecting garbage in `ver.major`/`kind`. A partial initializer zeroes the rest.

**Interview follow-ups**
- What is wrong with `struct Pdu arr[4];` or `struct Pdu copy = *p;` when `p` carries payload? (Copies do not include the FAM.)
- Why does `sizeof(struct Pdu) + n` remain the most common allocation idiom despite the slack?
- How would a nested designator like `.ver = { .major = 2 }` differ from `.ver.major = 2` if `.ver.minor` was set earlier in the same initializer?
- Rewrite the struct for a wire format where `data` must start at a 4-byte boundary. (`uint32_t data[]` or `_Alignas(4) uint8_t data[]`.)
