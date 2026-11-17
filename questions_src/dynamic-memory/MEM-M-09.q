@@@ meta
id: MEM-M-09
topic: Dynamic Memory
difficulty: Medium
type: PREDICT_OUTPUT
title: Sizing a PDU With a Flexible Array Member
tags: embedded, flexible-array-member, sizeof, padding, malloc
@@@ statement_md
A diagnostic stack allocates variable-length PDUs as one block: a header followed by a C99 **flexible array member**. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes** (natural alignment: `uint16_t` 2, `uint32_t` 4).

```c
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

struct pdu {
    uint16_t id;
    uint8_t  len;
    uint32_t data[];          /* flexible array member */
};

int main(void)
{
    uint8_t n = 3;
    struct pdu *p = malloc(sizeof *p + n * sizeof p->data[0]);
    if (p == NULL)
        return 1;

    p->id = 0x7DF;
    p->len = n;
    for (uint8_t i = 0; i < n; i++)
        p->data[i] = 0x11u * (i + 1u);

    printf("%zu %zu\n", sizeof(struct pdu), offsetof(struct pdu, data));
    printf("%zu %zu\n", sizeof *p, sizeof *p + n * sizeof p->data[0]);
    printf("%X %u\n", (unsigned)p->id, (unsigned)(p->data[0] + p->data[n - 1]));

    free(p);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI, C11.
- `malloc` succeeds.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

struct pdu {
    uint16_t id;
    uint8_t  len;
    uint32_t data[];          /* flexible array member */
};

int main(void)
{
    uint8_t n = 3;
    struct pdu *p = malloc(sizeof *p + n * sizeof p->data[0]);
    if (p == NULL)
        return 1;

    p->id = 0x7DF;
    p->len = n;
    for (uint8_t i = 0; i < n; i++)
        p->data[i] = 0x11u * (i + 1u);

    printf("%zu %zu\n", sizeof(struct pdu), offsetof(struct pdu, data));
    printf("%zu %zu\n", sizeof *p, sizeof *p + n * sizeof p->data[0]);
    printf("%X %u\n", (unsigned)p->id, (unsigned)(p->data[0] + p->data[n - 1]));

    free(p);
    return 0;
}
@@@ predict_answer
4 4
4 16
7DF 68
@@@ hint
A flexible array member contributes **no** size to the struct. But the struct still gets the padding needed so that `data` (a `uint32_t` array) starts at a 4-byte-aligned offset.
@@@ hint
`id` is at offset 0 (2 bytes), `len` at 2 (1 byte), then 1 padding byte, so `data` is at offset 4 and `sizeof(struct pdu)` is 4. `sizeof *p` is a compile-time constant: it does not know how much you allocated. `data[0] = 0x11`, `data[2] = 0x33`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

/* offset 0: id   (2 bytes)
 * offset 2: len  (1 byte) + 1 padding byte
 * offset 4: data[] (uint32_t, 4-byte aligned) - contributes 0 bytes to sizeof
 * sizeof(struct pdu) = 4 (already a multiple of the struct alignment 4)
 */
struct pdu {
    uint16_t id;
    uint8_t  len;
    uint32_t data[];
};

int main(void)
{
    uint8_t n = 3;
    /* header (4) + 3 elements * 4 bytes = 16 bytes, one block */
    struct pdu *p = malloc(sizeof *p + n * sizeof p->data[0]);
    if (p == NULL)
        return 1;

    p->id = 0x7DF;
    p->len = n;
    for (uint8_t i = 0; i < n; i++)
        p->data[i] = 0x11u * (i + 1u);        /* 0x11, 0x22, 0x33 */

    printf("%zu %zu\n", sizeof(struct pdu), offsetof(struct pdu, data));  /* 4 4  */
    printf("%zu %zu\n", sizeof *p, sizeof *p + n * sizeof p->data[0]);    /* 4 16 */
    printf("%X %u\n", (unsigned)p->id, (unsigned)(p->data[0] + p->data[n - 1])); /* 7DF 68 */

    free(p);                                  /* one block, one free */
    return 0;
}
@@@ explanation_md
**Answer**
```
4 4
4 16
7DF 68
```

- **Layout.** `id` takes bytes 0-1 and `len` byte 2. `data` must be 4-byte aligned, so there is one padding byte and `data` starts at offset **4**. A flexible array member adds nothing to `sizeof`, so `sizeof(struct pdu) == 4`.
- **`sizeof *p` is static.** It is the size of the **type** `struct pdu`, still 4, no matter how many bytes were allocated. The allocation size `sizeof *p + n * sizeof p->data[0]` is `4 + 3*4 = 16`. `sizeof p->data[0]` does not access memory: `sizeof` does not evaluate its operand.
- **Values.** `data[0] = 0x11 = 17`, `data[2] = 0x33 = 51`, sum 68. `0x7DF` prints with `%X` as `7DF`.

Why embedded code likes this pattern: header and payload are **one** allocation (one failure point, one `free`, better cache and DMA locality), and the payload size is chosen at run time.

**Complexity.** O(n) to fill. The memory is exactly `header + n * element` bytes, rounded up only by the allocator.

**Common mistakes**
- Expecting `sizeof(struct pdu) == 3` (forgetting padding before `data`) or `== 16` (thinking the FAM is counted).
- Allocating `sizeof *p + n` (bytes instead of elements). Writing `data[1]` then overflows the block.
- Using `offsetof(struct pdu, data) + n * 4` versus `sizeof *p + n * 4`. Here they agree. They can differ when tail padding exists; both are valid sizes, and `offsetof` gives the tighter one.
- Copying such a struct by value (`struct pdu q = *p;`). Only the header is copied, never the data.

**Interview follow-ups**
- Before C99, people wrote `uint32_t data[1];` (the "struct hack"). Why is indexing beyond `data[0]` undefined behavior there, and why does GCC's `-fstrict-flex-arrays` care?
- Can a struct with a flexible array member be an element of an array, or a member of another struct? (No; constraint violation, C11 6.7.2.1p3.)
- How would you lay out a CAN-FD PDU pool where every PDU has room for 64 data bytes, without any heap?
