@@@ meta
id: PAT-E-04
topic: C Patterns
difficulty: Easy
type: FUNCTION
title: Register as an LED Strip
tags: embedded, bit-pattern, register-dump, shift-mask, asked-in-automotive
@@@ statement_md
A debug console in an ECU shows the low bits of a status register as a row of LEDs: `*` for a bit that is **1**, `.` for a bit that is **0**. The most significant shown bit is on the **left**.

Implement

```c
void print_led_strip(uint32_t reg, int width);
```

It prints exactly `width` characters, one for each of the bits `width-1, width-2, ..., 1, 0` of `reg` (in that order). Bits above `width-1` are ignored.

- If `width < 1` or `width > 32`, print **nothing**.
- Do **not** print a newline or any other character. The harness frames your output with `|` on both sides.

**How it is tested.** A hidden `main()` reads `q` queries `reg width` (`reg` in hex). For each one it prints `0x<reg> w=<width> |`, calls your function, and prints `|` and a newline.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `reg` (hexadecimal, without `0x`) and `width` (decimal).

**Output**
- One line per query, as described above.

**Example**
```
Input:
3
A5 8
1 4
80000000 32

Output:
0x000000A5 w= 8 |*.*..*.*|
0x00000001 w= 4 |...*|
0x80000000 w=32 |*...............................|
```
@@@ constraints_md
- `1 <= q <= 20`
- `reg` is any 32-bit value; `-100 <= width <= 100`
- `width` outside `1..32` must print nothing.
- Your function must not print a newline.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

/* Print bits width-1 .. 0 of reg: '*' for 1, '.' for 0. No newline. */
void print_led_strip(uint32_t reg, int width)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        unsigned int reg;
        int width;
        if (scanf("%x %d", &reg, &width) != 2) return 0;
        printf("0x%08X w=%2d |", reg, width);
        print_led_strip((uint32_t)reg, width);
        printf("|\n");
    }
    return 0;
}
@@@ sample_input
3
A5 8
1 4
80000000 32
@@@ sample_output
0x000000A5 w= 8 |*.*..*.*|
0x00000001 w= 4 |...*|
0x80000000 w=32 |*...............................|

@@@ sample_input
2
F0 4
F0 8
@@@ sample_output
0x000000F0 w= 4 |....|
0x000000F0 w= 8 |****....|

@@@ hidden_input
3
FF 0
FF -1
FF 33
@@@ hidden_output
0x000000FF w= 0 ||
0x000000FF w=-1 ||
0x000000FF w=33 ||

@@@ hidden_input
2
FFFFFFFF 32
0 32
@@@ hidden_output
0xFFFFFFFF w=32 |********************************|
0x00000000 w=32 |................................|

@@@ hidden_input
3
1 1
0 1
FFFFFFFE 1
@@@ hidden_output
0x00000001 w= 1 |*|
0x00000000 w= 1 |.|
0xFFFFFFFE w= 1 |.|

@@@ hidden_input
2
DEADBEEF 16
DEADBEEF 32
@@@ hidden_output
0xDEADBEEF w=16 |*.*****.***.****|
0xDEADBEEF w=32 |**.****.*.*.**.**.*****.***.****|

@@@ hidden_input
3
80000001 31
5 3
12345678 12
@@@ hidden_output
0x80000001 w=31 |..............................*|
0x00000005 w= 3 |*.*|
0x12345678 w=12 |.**..****...|

@@@ hint
Bit `b` of `reg` is `(reg >> b) & 1`. Loop `b` from `width - 1` down to `0` so the most significant shown bit comes first.
@@@ hint
Shift `reg` (an unsigned value) right instead of shifting `1` left. `1 << 31` on an `int` is undefined behavior, and `1u << 32` is undefined too, so building a mask with `(1u << width) - 1` breaks at `width == 32`.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

void print_led_strip(uint32_t reg, int width)
{
    if (width < 1 || width > 32)
        return;                                 /* nothing to draw */
    for (int b = width - 1; b >= 0; b--)        /* MSB of the window first */
        putchar(((reg >> b) & 1u) ? '*' : '.');
}
@@@ explanation_md
**Approach.** Walk the bit positions from `width - 1` down to `0` and test each one with `(reg >> b) & 1u`. Shifting the **unsigned** register right is always defined for `0 <= b <= 31`, and the bits above the window are ignored because they are never tested.

```
reg = 0xA5 = 1010 0101, width = 8
b:    7 6 5 4 3 2 1 0
bit:  1 0 1 0 0 1 0 1   ->  *.*..*.*
```

**Complexity.** Time O(width), at most 32 iterations. Space O(1).

**Common mistakes**
- Testing with `reg & (1 << b)`. For `b = 31`, `1 << 31` overflows a signed `int`, which is undefined behavior (UBSan reports it). Use `1u << b` or shift `reg` instead.
- Building a mask `(1u << width) - 1` first. For `width == 32` the shift count equals the type width, which is undefined. On x86 it usually behaves like `1u << 0`, so the mask becomes 0.
- Printing LSB first (reversed strip) or printing a newline. The harness frame `|...|` shows both immediately.
- Declaring the loop counter `unsigned` and looping `for (unsigned b = width - 1; b >= 0; b--)`. That loop never ends.

**Interview follow-ups**
- Group the strip in nibbles (`**.. *.*.`) counted from bit 0, as in a datasheet register diagram.
- Print it from a `volatile uint32_t *` hardware register. Why should you read the register **once** into a local before the loop?
- Count the lit LEDs (population count) without a loop over all 32 bits, e.g. with Kernighan's trick `x &= x - 1`.
- How would you print a 64-bit register (`uint64_t`), and which constant suffix do you need for the mask (`1ULL`)?
