@@@ meta
id: STC-E-04
topic: Structures
difficulty: Easy
type: FUNCTION
title: Dissect a Float with a Union (IEEE-754 View)
tags: embedded, union, type-punning, ieee-754, endianness
@@@ statement_md
A calibration tool sends `float` parameters to an ECU over CAN, so you must know exactly which bytes go on the wire. Implement

```c
void f32_dissect(float x, struct F32Parts *out);
```

using a **union** that overlays a `float`, a `uint32_t` and a `uint8_t[4]`. The judge already defines:

```c
enum F32Kind { F32_ZERO, F32_SUBNORMAL, F32_NORMAL, F32_INF, F32_NAN };

struct F32Parts {
    uint8_t      bytes[4];   /* the 4 bytes in MEMORY order (bytes[0] = lowest address) */
    unsigned     sign;       /* bit 31: 0 or 1                                         */
    unsigned     exponent;   /* bits 30..23: biased exponent, 0..255                    */
    uint32_t     mantissa;   /* bits 22..0: fraction field                              */
    enum F32Kind kind;
};
```

Classification of an IEEE-754 single:

| exponent | mantissa | kind |
|---|---|---|
| 0 | 0 | `F32_ZERO` (this includes -0.0) |
| 0 | != 0 | `F32_SUBNORMAL` |
| 1..254 | any | `F32_NORMAL` |
| 255 | 0 | `F32_INF` |
| 255 | != 0 | `F32_NAN` |

The target is little-endian, so `bytes[0]` is the **least** significant byte of the bit pattern.

**Input (read by the hidden harness)**: whitespace-separated tokens. Each token is a decimal number (converted to `float`), `inf`, `-inf`, or `x` followed by 8 hex digits giving the raw bit pattern (for example `x7FC00000`).

**Output (printed by the harness)**: one line per token:
```
<token>: bytes=B0 B1 B2 B3 sign=S exp=E mant=0xMMMMMM kind=KIND
```

**Example**
```
Input:
1.5 -2

Output:
1.5: bytes=00 00 C0 3F sign=0 exp=127 mant=0x400000 kind=NORMAL
-2: bytes=00 00 00 C0 sign=1 exp=128 mant=0x000000 kind=NORMAL
```
@@@ constraints_md
- Up to 50 tokens.
- Use a union (or `memcpy`) to reinterpret the bits. Do not use `*(uint32_t *)&x`, which breaks the strict-aliasing rule.
- Do not use `<math.h>` classification macros (`isnan`, `fpclassify`, ...). Derive everything from the bits.
@@@ starter_code
#include <stdint.h>

/* Already defined by the judge:
 *
 * enum F32Kind { F32_ZERO, F32_SUBNORMAL, F32_NORMAL, F32_INF, F32_NAN };
 * struct F32Parts {
 *     uint8_t bytes[4]; unsigned sign; unsigned exponent;
 *     uint32_t mantissa; enum F32Kind kind;
 * };
 */

void f32_dissect(float x, struct F32Parts *out)
{
    /* TODO: declare a union of float / uint32_t / uint8_t[4] */
    (void)x;
    (void)out;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

enum F32Kind { F32_ZERO, F32_SUBNORMAL, F32_NORMAL, F32_INF, F32_NAN };

struct F32Parts {
    uint8_t      bytes[4];
    unsigned     sign;
    unsigned     exponent;
    uint32_t     mantissa;
    enum F32Kind kind;
};

#undef isnan
#undef isinf
#undef fpclassify
#define isnan(x) isnan_is_not_allowed_here
#define isinf(x) isinf_is_not_allowed_here
#define fpclassify(x) fpclassify_is_not_allowed_here

/*USER_CODE*/

#undef isnan
#undef isinf
#undef fpclassify

int main(void)
{
    static const char *kind_name[] = { "ZERO", "SUBNORMAL", "NORMAL", "INF", "NAN" };
    char tok[64];
    while (scanf("%63s", tok) == 1) {
        float x;
        if (tok[0] == 'x') {
            unsigned u = 0;
            if (sscanf(tok + 1, "%x", &u) != 1) return 0;
            uint32_t w = (uint32_t)u;
            memcpy(&x, &w, sizeof x);
        } else if (strcmp(tok, "inf") == 0) {
            x = INFINITY;
        } else if (strcmp(tok, "-inf") == 0) {
            x = -INFINITY;
        } else {
            x = (float)strtod(tok, NULL);
        }
        struct F32Parts p;
        memset(&p, 0xEE, sizeof p);
        f32_dissect(x, &p);
        int k = (int)p.kind;
        printf("%s: bytes=%02X %02X %02X %02X sign=%u exp=%u mant=0x%06X kind=%s\n", tok,
               (unsigned)p.bytes[0], (unsigned)p.bytes[1], (unsigned)p.bytes[2], (unsigned)p.bytes[3],
               p.sign, p.exponent, (unsigned)p.mantissa,
               (k >= 0 && k <= 4) ? kind_name[k] : "?");
    }
    return 0;
}
@@@ sample_input
1.5 -2
@@@ sample_output
1.5: bytes=00 00 C0 3F sign=0 exp=127 mant=0x400000 kind=NORMAL
-2: bytes=00 00 00 C0 sign=1 exp=128 mant=0x000000 kind=NORMAL

@@@ sample_input
0 -0
@@@ sample_output
0: bytes=00 00 00 00 sign=0 exp=0 mant=0x000000 kind=ZERO
-0: bytes=00 00 00 80 sign=1 exp=0 mant=0x000000 kind=ZERO

@@@ hidden_input
0.1
@@@ hidden_output
0.1: bytes=CD CC CC 3D sign=0 exp=123 mant=0x4CCCCD kind=NORMAL

@@@ hidden_input
inf -inf
@@@ hidden_output
inf: bytes=00 00 80 7F sign=0 exp=255 mant=0x000000 kind=INF
-inf: bytes=00 00 80 FF sign=1 exp=255 mant=0x000000 kind=INF

@@@ hidden_input
x7FC00000 xFFC00001
@@@ hidden_output
x7FC00000: bytes=00 00 C0 7F sign=0 exp=255 mant=0x400000 kind=NAN
xFFC00001: bytes=01 00 C0 FF sign=1 exp=255 mant=0x400001 kind=NAN

@@@ hidden_input
x00000001 x807FFFFF x00800000
@@@ hidden_output
x00000001: bytes=01 00 00 00 sign=0 exp=0 mant=0x000001 kind=SUBNORMAL
x807FFFFF: bytes=FF FF 7F 80 sign=1 exp=0 mant=0x7FFFFF kind=SUBNORMAL
x00800000: bytes=00 00 80 00 sign=0 exp=1 mant=0x000000 kind=NORMAL

@@@ hidden_input
x7F7FFFFF
@@@ hidden_output
x7F7FFFFF: bytes=FF FF 7F 7F sign=0 exp=254 mant=0x7FFFFF kind=NORMAL

@@@ hidden_input
-118.625 1
@@@ hidden_output
-118.625: bytes=00 40 ED C2 sign=1 exp=133 mant=0x6D4000 kind=NORMAL
1: bytes=00 00 80 3F sign=0 exp=127 mant=0x000000 kind=NORMAL

@@@ hidden_input
16777217
@@@ hidden_output
16777217: bytes=00 00 80 4B sign=0 exp=151 mant=0x000000 kind=NORMAL

@@@ hint
Declare `union { float f; uint32_t u; uint8_t b[4]; } v;`, store `v.f = x`, then read `v.u` for the bit fields and `v.b[i]` for the memory bytes.
@@@ hint
`sign = u >> 31`, `exponent = (u >> 23) & 0xFF`, `mantissa = u & 0x7FFFFF`. Classify from `exponent` first (0, 255 or anything else), then look at `mantissa`.
@@@ solution_code
#include <stdint.h>

void f32_dissect(float x, struct F32Parts *out)
{
    union {
        float    f;
        uint32_t u;
        uint8_t  b[4];
    } v;

    v.f = x;                 /* write one member ...                         */
    uint32_t u = v.u;        /* ... read another: well-defined in C (6.5.2.3) */

    for (int i = 0; i < 4; i++)
        out->bytes[i] = v.b[i];          /* memory order: little-endian -> LSB first */

    out->sign = (unsigned)(u >> 31);
    out->exponent = (unsigned)((u >> 23) & 0xFFu);
    out->mantissa = u & 0x7FFFFFu;

    if (out->exponent == 0)
        out->kind = out->mantissa ? F32_SUBNORMAL : F32_ZERO;
    else if (out->exponent == 0xFF)
        out->kind = out->mantissa ? F32_NAN : F32_INF;
    else
        out->kind = F32_NORMAL;
}
@@@ explanation_md
**Approach.** Write the `float` into one union member and read the same storage back as `uint32_t` (for bit fields) and as `uint8_t[4]` (for memory bytes). C11 6.5.2.3 (footnote 95) says that reading a union member other than the one last written reinterprets the object representation. This is the sanctioned way to do type punning in C. `memcpy(&u, &x, 4)` is the other one.

```
-118.625 = -1.110110101b * 2^6
sign=1  exponent=127+6=133=0x85  fraction=110110101000...b = 0x6D4000
bits  = 1 10000101 11011010100000000000000 = 0xC2ED4000
bytes in memory (little-endian): 00 40 ED C2
```

`16777217` prints as `2^24`: a `float` has only a 24-bit significand, so integers above 16777216 are no longer all exactly representable.

**Complexity.** Time O(1), space O(1).

**Common mistakes**
- `*(uint32_t *)&x`. This violates strict aliasing (C11 6.5p7). At `-O2` the compiler may reorder or drop the access.
- Printing the bytes big-endian (`3F C0 00 00`) when the question asks for **memory order**.
- Treating -0.0 as non-zero, or reporting NaN for every value with exponent 255. Infinity has mantissa 0.
- Using `(uint32_t)x`. That converts the **value** (1.5 becomes 1); it does not reinterpret the bits.

**Interview follow-ups**
- Type punning through a union is defined in C but undefined in C++. What would you use in C++? (`std::memcpy` or C++20 `std::bit_cast`.)
- The CAN DBC specifies the signal as big-endian (Motorola). How do you put this `float` on the bus in a way that is portable to a big-endian host?
- How would you check whether two floats are "equal within 4 ULPs" using the integer view?
- Why does this union not need `__attribute__((packed))`? What are its `sizeof` and alignment?
