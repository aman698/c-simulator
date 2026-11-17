@@@ meta
id: PTR-E-10
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Sum a Raw Sensor Buffer Through a void Pointer
tags: embedded, void-pointer, casting, sign-extension, pointer-arithmetic
@@@ statement_md
A data-logger task receives sensor buffers as raw memory: a `const void *` plus an element count and a type tag that tells what is really stored there. Implement

```c
typedef enum { ELEM_I8, ELEM_U8, ELEM_I16, ELEM_U16, ELEM_I32, ELEM_U32 } elem_type;

long long sum_elements(const void *buf, size_t count, elem_type type);
```

It returns the exact mathematical sum of the `count` elements. Each element is interpreted with the type given by `type`: `int8_t`, `uint8_t`, `int16_t`, `uint16_t`, `int32_t` or `uint32_t`. When `count == 0`, return `0` (`buf` may be `NULL` then).

The buffer holds exactly `count` elements, so reading even one byte past it is a bug. The judge runs AddressSanitizer.

**How it is tested.** A hidden `main()` stores the values in a heap block of exactly `count` elements of the right type and prints your return value.

**Input (read by the hidden harness)**
- Line 1: the type name (`i8 u8 i16 u16 i32 u32`) and `count`.
- Line 2: `count` integers that fit in that type.

**Output**
- The sum.

**Example**
```
Input:
i8 3
-128 127 -1

Output:
-2
```
@@@ constraints_md
- `0 <= count <= 1000`
- The sum of 1000 `uint32_t` values fits in `long long`.
- Do not read outside the buffer.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

typedef enum { ELEM_I8, ELEM_U8, ELEM_I16, ELEM_U16, ELEM_I32, ELEM_U32 } elem_type;

long long sum_elements(const void *buf, size_t count, elem_type type)
{
    /* TODO: interpret buf according to type */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>

/*USER_CODE*/

int main(void)
{
    char name[8];
    int count;
    if (scanf("%7s %d", name, &count) != 2) return 0;

    static const char *names[] = {"i8", "u8", "i16", "u16", "i32", "u32"};
    static const size_t sizes[] = {1, 1, 2, 2, 4, 4};
    int t = -1;
    for (int k = 0; k < 6; k++)
        if (strcmp(name, names[k]) == 0) t = k;
    if (t < 0) return 0;

    void *buf = NULL;
    if (count > 0) {
        buf = malloc((size_t)count * sizes[t]);
        if (buf == NULL) return 0;
    }
    for (int i = 0; i < count; i++) {
        long long v;
        if (scanf("%lld", &v) != 1) {
            free(buf);
            return 0;
        }
        switch (t) {
        case 0: ((int8_t *)buf)[i] = (int8_t)v; break;
        case 1: ((uint8_t *)buf)[i] = (uint8_t)v; break;
        case 2: ((int16_t *)buf)[i] = (int16_t)v; break;
        case 3: ((uint16_t *)buf)[i] = (uint16_t)v; break;
        case 4: ((int32_t *)buf)[i] = (int32_t)v; break;
        default: ((uint32_t *)buf)[i] = (uint32_t)v; break;
        }
    }
    printf("%lld\n", sum_elements(buf, (size_t)count, (elem_type)t));
    free(buf);
    return 0;
}
@@@ sample_input
i8 3
-128 127 -1
@@@ sample_output
-2

@@@ sample_input
u16 2
65535 1
@@@ sample_output
65536

@@@ hidden_input
u8 2
255 255
@@@ hidden_output
510

@@@ hidden_input
i16 3
-32768 32767 1
@@@ hidden_output
0

@@@ hidden_input
i32 2
-2147483648 -2147483648
@@@ hidden_output
-4294967296

@@@ hidden_input
u32 2
4294967295 4294967295
@@@ hidden_output
8589934590

@@@ hidden_input
u8 0
@@@ hidden_output
0

@@@ hidden_input
i8 5
1 2 3 4 5
@@@ hidden_output
15

@@@ hidden_input
u16 4
1 256 4096 65535
@@@ hidden_output
69888

@@@ hidden_input
i32 1
2147483647
@@@ hidden_output
2147483647

@@@ hint
A `void *` has no element size, so `buf[i]` does not compile. In each `case` of a `switch (type)`, convert `buf` to a pointer of the **right** type, e.g. `const int16_t *p = buf;`, and then `p[i]` steps by `sizeof(int16_t)`.
@@@ hint
Accumulate in a `long long` and convert each element to `long long` *before* adding. Adding two `int32_t` or two `uint32_t` values first overflows (or wraps) 32 bits. Signed types are then sign-extended correctly (`(int8_t)0xFF` is -1) and unsigned ones are not.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

typedef enum { ELEM_I8, ELEM_U8, ELEM_I16, ELEM_U16, ELEM_I32, ELEM_U32 } elem_type;

long long sum_elements(const void *buf, size_t count, elem_type type)
{
    long long sum = 0;
    if (buf == NULL || count == 0)
        return 0;

    switch (type) {
    case ELEM_I8: {
        const int8_t *p = buf;                 /* each p[i] reads 1 byte, sign-extended */
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    case ELEM_U8: {
        const uint8_t *p = buf;
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    case ELEM_I16: {
        const int16_t *p = buf;                /* p + 1 advances 2 bytes */
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    case ELEM_U16: {
        const uint16_t *p = buf;
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    case ELEM_I32: {
        const int32_t *p = buf;                /* p + 1 advances 4 bytes */
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    case ELEM_U32: {
        const uint32_t *p = buf;
        for (size_t i = 0; i < count; i++) sum += (long long)p[i];
        break;
    }
    default:
        break;                                 /* unknown tag: defensive, return 0 */
    }
    return sum;
}
@@@ explanation_md
**Approach.** A `void *` is an address with no type, so it carries no element size. Pointer arithmetic and indexing need the element size, which is why `((const void *)buf)[i]` does not compile. The type tag supplies that information. Convert `buf` (implicitly; no cast is needed from `void *` in C) to the matching typed pointer, then `p[i]` reads `sizeof *p` bytes at offset `i * sizeof *p`:

```
bytes in memory: 80 7F FF            (i8 3: -128 127 -1)
as int8_t  : -128 + 127 + -1  = -2
as uint8_t :  128 + 127 + 255 = 510   <- same bytes, different type
```

Converting each element to `long long` before the addition keeps the sum exact: sign extension for signed types, zero extension for unsigned ones.

**Complexity.** Time O(count), space O(1).

**Common mistakes**
- Using one pointer type for all cases, e.g. `const int *p = buf;` for an `int8_t` buffer. That reads 4 bytes per element: wrong values, and a heap overread that ASan reports.
- Stepping a `const unsigned char *` by 1 for multi-byte types and reading only the low byte.
- Reading `int8_t` data through `unsigned char` (or vice versa), which loses or invents the sign.
- Summing in `int`/`uint32_t`. Two `INT_MIN` values or two `UINT32_MAX` values overflow 32 bits.

**Interview follow-ups**
- The buffer comes from a CAN frame at offset 1, so the `int32_t` elements are **misaligned**. Why is `*(const int32_t *)p` then undefined, and how do you read it safely? (`memcpy` into a local, or assemble from bytes.)
- How would you replace the `switch` with a table of function pointers indexed by `elem_type`?
- What does C11 `_Generic` offer here, and why does it not help when the type is only known at run time?
- Why does `qsort`'s comparator receive `const void *` instead of a typed pointer?
