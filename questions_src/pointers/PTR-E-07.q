@@@ meta
id: PTR-E-07
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Detect Endianness and Dump an Object's Bytes
tags: embedded, endianness, unsigned-char-pointer, object-representation, asked-in-automotive
@@@ statement_md
When a CAN or Ethernet frame looks "byte-swapped", the first thing an embedded engineer does is look at the raw bytes of a variable in memory. Implement two helpers:

```c
int  is_little_endian(void);
void dump_bytes(const void *obj, size_t size, char *out);
```

- `is_little_endian()` returns `1` if the CPU stores the **least significant byte at the lowest address**, otherwise `0`. Detect it at run time **through a pointer**: look at the first byte of a multi-byte integer.
- `dump_bytes()` writes the `size` bytes of the object at `obj` into the string `out`, **in memory order** (lowest address first). Each byte is two **uppercase** hex digits, and bytes are separated by **one space**. There is no trailing space, and `out` is NUL-terminated.
  - `out` has room for exactly `3 * size` characters (or `1` when `size == 0`). The output `"AA BB"` uses `3 * 2 = 6` bytes including the NUL.
  - `size == 0` produces the empty string.

**How it is tested.** A hidden `main()` first prints `little-endian` or `big-endian` according to `is_little_endian()`. Then, for each query, it stores the value in a variable of the requested type and prints `dump_bytes(&var, sizeof var, out)`. The judge machine is x86-64, which is little-endian.

**Input (read by the hidden harness)**
- Line 1: `q`
- Next `q` lines: `TYPE VALUE`. `TYPE` is one of `u8 u16 u32 u64 i16 i32 f32 none`. `VALUE` is decimal or `0x` hex (a decimal real number for `f32`). `none` dumps 0 bytes.

**Output**
- Line 1: `little-endian` or `big-endian`.
- One line per query with the dump.

**Example**
```
Input:
3
u32 0x11223344
u16 0xBEEF
i32 -2

Output:
little-endian
44 33 22 11
EF BE
FE FF FF FF
```
@@@ constraints_md
- `0 <= q <= 20`
- Values fit in the given type.
- Do not write more than `3 * size` bytes into `out` (1 byte when `size == 0`).
@@@ starter_code
#include <stddef.h>

/* 1 if the least significant byte is stored at the lowest address. */
int is_little_endian(void)
{
    /* TODO */
    return 0;
}

/* "44 33 22 11": bytes in memory order, uppercase hex, single spaces. */
void dump_bytes(const void *obj, size_t size, char *out)
{
    /* TODO */
    out[0] = '\0';
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>

/*USER_CODE*/

#define OUT_CAP 64

static void run(const void *obj, size_t size)
{
    char out[OUT_CAP];
    size_t room = size ? 3 * size : 1;
    memset(out, '#', sizeof out);
    dump_bytes(obj, size, out);
    for (size_t k = room; k < sizeof out; k++) {
        if (out[k] != '#') {
            printf("BUFFER OVERFLOW (wrote past %zu bytes)\n", room);
            return;
        }
    }
    if (memchr(out, '\0', room) == NULL) {
        printf("MISSING NUL TERMINATOR\n");
        return;
    }
    printf("%s\n", out);
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    printf("%s\n", is_little_endian() ? "little-endian" : "big-endian");
    for (int i = 0; i < q; i++) {
        char type[8], val[40];
        if (scanf("%7s %39s", type, val) != 2) return 0;
        if (strcmp(type, "u8") == 0) {
            uint8_t v = (uint8_t)strtoull(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "u16") == 0) {
            uint16_t v = (uint16_t)strtoull(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "u32") == 0) {
            uint32_t v = (uint32_t)strtoull(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "u64") == 0) {
            uint64_t v = (uint64_t)strtoull(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "i16") == 0) {
            int16_t v = (int16_t)strtoll(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "i32") == 0) {
            int32_t v = (int32_t)strtoll(val, NULL, 0);
            run(&v, sizeof v);
        } else if (strcmp(type, "f32") == 0) {
            float v = (float)strtod(val, NULL);
            run(&v, sizeof v);
        } else {
            uint32_t v = 0;
            run(&v, 0);
        }
    }
    return 0;
}
@@@ sample_input
3
u32 0x11223344
u16 0xBEEF
i32 -2
@@@ sample_output
little-endian
44 33 22 11
EF BE
FE FF FF FF

@@@ sample_input
2
u8 7
u64 0x0102030405060708
@@@ sample_output
little-endian
07
08 07 06 05 04 03 02 01

@@@ hidden_input
1
i16 -32768
@@@ hidden_output
little-endian
00 80

@@@ hidden_input
2
f32 1.0
f32 -2.5
@@@ hidden_output
little-endian
00 00 80 3F
00 00 20 C0

@@@ hidden_input
2
none 0
u8 0
@@@ hidden_output
little-endian

00

@@@ hidden_input
0
@@@ hidden_output
little-endian

@@@ hidden_input
3
u32 0
u32 4294967295
u16 1
@@@ hidden_output
little-endian
00 00 00 00
FF FF FF FF
01 00

@@@ hidden_input
2
u64 18446744073709551615
i32 -2147483648
@@@ hidden_output
little-endian
FF FF FF FF FF FF FF FF
00 00 00 80

@@@ hidden_input
1
u32 0xDEADBEEF
@@@ hidden_output
little-endian
EF BE AD DE

@@@ hint
`unsigned char` is the one type that may legally inspect the bytes of any object. Convert `obj` to `const unsigned char *` and index it from 0 to `size - 1`.
@@@ hint
For the endianness check, store `1` in a `uint32_t` (or `uint16_t`) and read its **first byte** through an `unsigned char *`. If that byte is `1`, the least significant byte is at the lowest address. Format each byte with `"%02X"` (or a lookup string `"0123456789ABCDEF"`), and add a space only *before* every byte except the first.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

int is_little_endian(void)
{
    const uint32_t probe = 1u;
    const unsigned char *first = (const unsigned char *)&probe;   /* lowest address */
    return *first == 1u;
}

void dump_bytes(const void *obj, size_t size, char *out)
{
    static const char hex[] = "0123456789ABCDEF";
    const unsigned char *p = obj;      /* void * converts implicitly in C */
    char *o = out;

    for (size_t i = 0; i < size; i++) {
        if (i != 0)
            *o++ = ' ';
        *o++ = hex[p[i] >> 4];
        *o++ = hex[p[i] & 0x0Fu];
    }
    *o = '\0';                         /* 3*size - 1 chars + NUL = 3*size bytes */
}
@@@ explanation_md
**Approach.** Every object is a sequence of bytes. A `const unsigned char *` to the object lets you read them one by one, in increasing address order. C11 6.2.6.1p4 calls this the *object representation*, and character types are exempt from strict aliasing (6.5p7), so this is fully defined.

On a **little-endian** CPU (x86, most ARM Cortex-M configurations) the least significant byte comes first:

```
uint32_t v = 0x11223344;
address:  +0  +1  +2  +3
little:   44  33  22  11     <- x86, Cortex-M (default)
big:      11  22  33  44     <- PowerPC (e.g. MPC5xxx), network byte order
```

`is_little_endian` stores 1 and checks whether the first byte is 1. Negative numbers (two's complement `FE FF FF FF`) and floats (IEEE-754 `1.0f = 0x3F800000`) follow the same byte order.

For the output, each byte needs 2 hex digits, plus a separator before every byte except the first: `2*size + (size-1) + 1 (NUL) = 3*size` bytes.

**Complexity.** Time O(size), extra space O(1).

**Common mistakes**
- Using `char *` instead of `unsigned char *`. `char` is signed on x86, so `0xFE` becomes `-2`, and `"%02X"` on the promoted `int` prints `FFFFFFFE`.
- Doing arithmetic on `void *` directly (`obj + i`). That is a GCC extension, not ISO C.
- A trailing space before the NUL. It overflows the `3*size` buffer by one byte.
- Detecting endianness with a union. It works in practice, but the pointer cast to `unsigned char *` is the textbook-clean way. Macros such as `__BYTE_ORDER__` are compile-time only and compiler-specific.

**Interview follow-ups**
- Write `uint32_t load_be32(const uint8_t *p)` that works on **any** host without knowing its endianness. (Shifts: `(uint32_t)p[0] << 24 | ...`.)
- Why is `*(uint32_t *)(frame + 3)` dangerous on a Cortex-M0, even on a little-endian MCU? (Unaligned access fault and strict aliasing.)
- How do `htonl`/`ntohl` behave on a big-endian host?
- Can a CPU be bi-endian? (ARM and PowerPC can be configured; the startup code or a fuse selects the mode.)
