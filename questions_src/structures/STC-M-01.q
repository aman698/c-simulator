@@@ meta
id: STC-M-01
topic: Structures
difficulty: Medium
type: PREDICT_OUTPUT
title: Union Size and Byte Views of a Register Word
tags: embedded, union, sizeof, endianness, type-punning
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `double` = 8 bytes with 8-byte alignment, IEEE-754 `float`**.

```c
#include <stdio.h>
#include <stdint.h>

union Reg {
    uint32_t word;
    uint16_t half[2];
    uint8_t  byte[4];
};

union Mixed {
    double d;
    char   tag[9];
};

struct Tagged {
    char        kind;
    union Mixed v;
};

union F32 {
    float    f;
    uint32_t u;
};

int main(void)
{
    union Reg r;
    union F32 x = { .f = -2.0f };

    r.word = 0x12345678u;
    printf("%zu %zu %zu\n", sizeof(union Reg), sizeof(union Mixed), sizeof(struct Tagged));
    printf("%02X %04X\n", r.byte[0], r.half[1]);

    r.byte[3] = 0xAB;
    printf("%08X %08X\n", (unsigned)r.word, (unsigned)x.u);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI, little-endian.
- Reading a union member other than the one last written is defined in C (C11 6.5.2.3, footnote 95): the bytes are reinterpreted.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

union Reg {
    uint32_t word;
    uint16_t half[2];
    uint8_t  byte[4];
};

union Mixed {
    double d;
    char   tag[9];
};

struct Tagged {
    char        kind;
    union Mixed v;
};

union F32 {
    float    f;
    uint32_t u;
};

int main(void)
{
    union Reg r;
    union F32 x = { .f = -2.0f };

    r.word = 0x12345678u;
    printf("%zu %zu %zu\n", sizeof(union Reg), sizeof(union Mixed), sizeof(struct Tagged));
    printf("%02X %04X\n", r.byte[0], r.half[1]);

    r.byte[3] = 0xAB;
    printf("%08X %08X\n", (unsigned)r.word, (unsigned)x.u);
    return 0;
}
@@@ predict_answer
4 16 24
78 1234
AB345678 C0000000
@@@ hint
A union is as large as its largest member, **rounded up to the strictest alignment** of any member. A `char[9]` next to a `double` is not 9 bytes.
@@@ hint
Little-endian: `byte[0]` is the least significant byte of `word`, and `half[1]` holds the upper 16 bits. For `-2.0f`: sign 1, exponent 127 + 1 = 128, mantissa 0.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

union Reg {              /* all members start at offset 0; size = max(4, 4, 4) = 4 */
    uint32_t word;
    uint16_t half[2];
    uint8_t  byte[4];
};

union Mixed {            /* largest member 9 bytes, alignment 8 (double) -> 16 */
    double d;
    char   tag[9];
};

struct Tagged {          /* kind @0, 7 bytes padding, v @8 (16 bytes) -> 24 */
    char        kind;
    union Mixed v;
};

union F32 {
    float    f;
    uint32_t u;
};

int main(void)
{
    union Reg r;
    union F32 x = { .f = -2.0f };   /* designated initializer picks the member to initialise */

    r.word = 0x12345678u;           /* memory: 78 56 34 12 */
    printf("%zu %zu %zu\n", sizeof(union Reg), sizeof(union Mixed), sizeof(struct Tagged));
                                    /* 4 16 24 */
    printf("%02X %04X\n", r.byte[0], r.half[1]);
                                    /* byte[0] = 0x78 (LSB first), half[1] = bytes 34 12 -> 0x1234 */

    r.byte[3] = 0xAB;               /* memory: 78 56 34 AB -> word 0xAB345678 */
    printf("%08X %08X\n", (unsigned)r.word, (unsigned)x.u);
                                    /* -2.0f = 1 10000000 000...0 = 0xC0000000 */
    return 0;
}
@@@ explanation_md
**Answer**
```
4 16 24
78 1234
AB345678 C0000000
```

**Approach.**
1. **Union size** is the size of the largest member, rounded up to the union's alignment, which is the strictest alignment among its members.
   - `union Reg`: every member is 4 bytes, so the size is **4**.
   - `union Mixed`: `char tag[9]` is 9 bytes, but `double` forces 8-byte alignment. 9 rounds up to **16**.
   - `struct Tagged`: `kind` is at offset 0, and the union needs an 8-aligned offset, so 7 padding bytes follow. The union then occupies offsets 8 to 23, giving **24**.
2. **Byte view (little-endian).** `0x12345678` is stored as `78 56 34 12`. So `byte[0] = 0x78`, and `half[1]` is made of the bytes at offsets 2 and 3 (`34 12`), which read as `0x1234`.
3. **Writing through one view changes the others.** `byte[3]` is the most significant byte, so `word` becomes `0xAB345678`.
4. **Float bits.** -2.0 = -1.0 * 2^1: sign 1, biased exponent 128 = `0x80`, mantissa 0. That gives `1 1000 0000 000...` = `0xC0000000`.

**Complexity.** N/A. Union access is a plain load or store of the shared bytes.

**Common mistakes**
- Answering `9` for `union Mixed`, forgetting alignment rounding (and then `17` or `10` for `struct Tagged`).
- Reading the bytes big-endian (`byte[0] = 0x12`, `half[1] = 0x5678`).
- Believing that reading a different union member is undefined behavior. That is true in **C++**, but in C it is defined type punning (C11 6.5.2.3 footnote 95). The result depends only on the representation (endianness, IEEE-754).
- Thinking `= { .f = -2.0f }` converts `-2` into `u`. The initializer sets `f`, and `u` shows the same 4 bytes.

**Interview follow-ups**
- You must send `word` big-endian on the CAN bus. Why is `byte[0..3]` from this union not portable, and what is? (Shifts: `(w >> 24) & 0xFF`, ...)
- How would you build a tagged union (`kind` plus union) for a CAN signal that can be `uint8`, `int16` or `float`, and how do you make its size 8 instead of 24?
- What is the size of `union { char c[5]; int i; }`, and why?
- Is it safe to overlay a `union Reg` on a memory-mapped peripheral register? What qualifier is missing?
