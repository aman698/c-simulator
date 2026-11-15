@@@ meta
id: STC-E-01
topic: Structures
difficulty: Easy
type: PREDICT_OUTPUT
title: Padding in a Telemetry Frame Struct
tags: embedded, struct-padding, sizeof, offsetof, alignment
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `double` = 8 bytes with 8-byte alignment**.

```c
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

struct Frame {
    char     tag;
    int32_t  value;
    char     flag;
    double   scale;
    uint16_t crc;
};

int main(void)
{
    printf("%zu %zu %zu\n",
           sizeof(struct Frame),
           offsetof(struct Frame, scale),
           offsetof(struct Frame, crc));
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, System V ABI (natural alignment: `int32_t` 4, `double` 8, `uint16_t` 2).
@@@ starter_code
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

struct Frame {
    char     tag;
    int32_t  value;
    char     flag;
    double   scale;
    uint16_t crc;
};

int main(void)
{
    printf("%zu %zu %zu\n",
           sizeof(struct Frame),
           offsetof(struct Frame, scale),
           offsetof(struct Frame, crc));
    return 0;
}
@@@ predict_answer
32 16 24
@@@ hint
Each member starts at an offset that is a multiple of its own alignment. The compiler inserts padding bytes to make that true.
@@@ hint
The total size is rounded up to a multiple of the **largest** member alignment (8 here), so arrays of the struct stay aligned.
@@@ solution_code
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

/* Layout (offset: member)
 *  0: tag      (1)  + 3 padding
 *  4: value    (4)
 *  8: flag     (1)  + 7 padding  -> double needs an 8-aligned offset
 * 16: scale    (8)
 * 24: crc      (2)  + 6 tail padding -> size rounded up to 8
 * sizeof = 32
 *
 * Reordered largest-first (double, int32_t, uint16_t, char, char) it is 16 bytes.
 */
struct Frame {
    char     tag;
    int32_t  value;
    char     flag;
    double   scale;
    uint16_t crc;
};

int main(void)
{
    printf("%zu %zu %zu\n",
           sizeof(struct Frame),
           offsetof(struct Frame, scale),
           offsetof(struct Frame, crc));
    return 0;
}
@@@ explanation_md
**Answer: `32 16 24`**

| offset | member | size | padding after |
|---|---|---|---|
| 0 | `tag` | 1 | 3 (to align `int32_t` at 4) |
| 4 | `value` | 4 | 0 |
| 8 | `flag` | 1 | 7 (to align `double` at 16) |
| 16 | `scale` | 8 | 0 |
| 24 | `crc` | 2 | 6 tail padding (size must be a multiple of 8) |

The raw data is only 16 bytes; half of the 32-byte struct is padding. Reordering members **largest-first** (`double`, `int32_t`, `uint16_t`, `char`, `char`) gives `sizeof == 16`.

**Complexity.** N/A. Padding is fixed at compile time and costs no CPU time, but it wastes RAM and bus bandwidth (for example in CAN/Ethernet frame buffers or NVM records).

**Common mistakes**
- Adding up member sizes (1+4+1+8+2 = 16) and forgetting padding.
- Forgetting **tail padding**. Without it, `struct Frame arr[2]` would misalign `arr[1].scale`.
- Assuming the layout is the same on every target. On 32-bit x86 Linux, `double` inside a struct is only 4-byte aligned, which gives a different size.

**Interview follow-ups**
- What does `__attribute__((packed))` do to this struct, and why can taking `&frame.value` in a packed struct crash on a Cortex-M0?
- Why should you never `memcpy` a struct directly into a CAN payload or a file, even if the sizes match? (Padding, endianness, ABI differences.)
- How would you add a compile-time check that a struct stays exactly 16 bytes? (`_Static_assert(sizeof(struct X) == 16, "...")`)
