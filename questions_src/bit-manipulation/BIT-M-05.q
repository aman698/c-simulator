@@@ meta
id: BIT-M-05
topic: Bit Manipulation
difficulty: Medium
type: FUNCTION
title: FIELD_MASK, READ_FIELD and WRITE_FIELD Macros Done Right
tags: embedded, macros, bit-fields, read-modify-write, registers, misra, bsp
@@@ statement_md
Register-level code in a BSP is full of multi-bit fields such as "bits 9..5 = prescaler". Write the three macros your team's `bitops.h` is missing:

```c
#define FIELD_MASK(hi, lo)                  /* uint32_t with bits hi..lo set (0 <= lo <= hi <= 31) */
#define READ_FIELD(reg, mask, shift)        /* value of the field: (reg & mask) >> shift           */
#define WRITE_FIELD(reg, mask, shift, val)  /* statement: field := val, other bits unchanged        */
```

Example: `FIELD_MASK(9, 5) == 0x3E0`. If `reg == 0x12345678`, then `READ_FIELD(reg, 0x3E0, 5) == 0x13`.

Requirements (all of them are tested):
1. `FIELD_MASK(31, 0)` must be `0xFFFFFFFF` **without undefined behavior** (a shift by 32 is UB, and UBSan is on). `FIELD_MASK` must also be an **integer constant expression** when `hi` and `lo` are constants: the harness uses it in a file-scope `static const` initializer and as a `case` label.
2. Arguments may be expressions: `READ_FIELD(a | b, FIELD_MASK(9, 5), 5)`, `2u * READ_FIELD(...) + 1u`, a mask written as `0x3u << 30`, a value written as `vals[j] | 4u`.
3. `WRITE_FIELD` writes `val` truncated to the field width. Bits of `val` that do not fit must not leak into neighbouring fields.
4. `WRITE_FIELD` evaluates `reg` **exactly once** and `val` **exactly once**: `WRITE_FIELD(regs[i++], m, s, vals[j++])` increments `i` and `j` once. `mask` and `shift` are side-effect free and may be evaluated more than once.
5. `WRITE_FIELD` behaves like a single statement, including as the body of an `if` that has an `else` and no braces.
6. `reg` is a `volatile uint32_t` lvalue.

**Input (read by the hidden harness)**
- Line 1: initial register value (hex) and `q`.
- Next `q` lines (all numbers hex except `hi`/`lo`):
  - `M hi lo`: print `FIELD_MASK(hi, lo)` as `%08X`.
  - `R hi lo`: print `READ_FIELD(reg, FIELD_MASK(hi, lo), lo)` as `%X`.
  - `W hi lo val`: `WRITE_FIELD(reg, FIELD_MASK(hi, lo), lo, val)`, then print `reg` as `%08X`.
  - `X`: run the expression and side-effect battery and print `f=.. g=.. r0=.. r1=.. r2=.. i=.. j=.. sw=..`.

**Example**
```
Input:
00000000 4
M 9 5
W 9 5 D
R 9 5
M 31 0

Output:
000003E0
000001A0
D
FFFFFFFF
```
@@@ constraints_md
- `0 <= lo <= hi <= 31`, `1 <= q <= 20`
- Macros only (they must work on any `uint32_t` register and in constant expressions).
- You may use `do { ... } while (0)` and local variables inside `WRITE_FIELD`. Pick names that cannot collide with the caller's (e.g. a trailing underscore).
@@@ starter_code
#include <stdint.h>

/* Replace the placeholders (they compile, but are wrong). */
#define FIELD_MASK(hi, lo)                  (((uint32_t)(hi) << 8) | (uint32_t)(lo))
#define READ_FIELD(reg, mask, shift)        0u
#define WRITE_FIELD(reg, mask, shift, val)  do { } while (0)
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

static const uint32_t k_prescaler_mask = FIELD_MASK(9, 5);   /* must be a constant expression */

int main(void)
{
    unsigned init;
    int q;
    if (scanf("%x %d", &init, &q) != 2) return 0;
    volatile uint32_t reg = init;
    for (int k = 0; k < q; k++) {
        char op;
        int hi = 0, lo = 0;
        if (scanf(" %c", &op) != 1) return 0;
        if (op != 'X' && (scanf("%d %d", &hi, &lo) != 2 || lo < 0 || hi > 31 || lo > hi)) return 0;
        if (op == 'M') {
            printf("%08X\n", (unsigned)FIELD_MASK(hi, lo));
        } else if (op == 'R') {
            printf("%X\n", (unsigned)READ_FIELD(reg, FIELD_MASK(hi, lo), lo));
        } else if (op == 'W') {
            unsigned val;
            if (scanf("%x", &val) != 1) return 0;
            WRITE_FIELD(reg, FIELD_MASK(hi, lo), lo, val);
            printf("%08X\n", (unsigned)reg);
        } else {
            uint32_t snap = reg;
            uint32_t a = snap & 0xFFFF0000u, b = snap & 0x0000FFFFu;
            uint32_t f = READ_FIELD(a | b, k_prescaler_mask, 5);
            uint32_t g = 2u * READ_FIELD(snap, FIELD_MASK(9, 5), 5) + 1u;
            volatile uint32_t regs[3] = { snap, snap, snap };
            uint32_t vals[2] = { 0x1Fu, 0x6u };
            int i = 0, j = 0;
            const char *sw;
            WRITE_FIELD(regs[i++], FIELD_MASK(9, 5), 5, vals[j++]);
            if (i == 1)
                WRITE_FIELD(regs[i++], 0x3u << 30, 30, vals[j++] | 4u);
            else
                WRITE_FIELD(regs[0], 0x1u, 0, 0u);
            switch (READ_FIELD(snap, FIELD_MASK(3, 0), 0)) {
            case FIELD_MASK(3, 0): sw = "all"; break;
            case FIELD_MASK(0, 0): sw = "one"; break;
            default: sw = "other"; break;
            }
            printf("f=%u g=%u r0=%08X r1=%08X r2=%08X i=%d j=%d sw=%s\n", (unsigned)f, (unsigned)g,
                   (unsigned)regs[0], (unsigned)regs[1], (unsigned)regs[2], i, j, sw);
        }
    }
    return 0;
}
@@@ sample_input
00000000 4
M 9 5
W 9 5 D
R 9 5
M 31 0
@@@ sample_output
000003E0
000001A0
D
FFFFFFFF

@@@ sample_input
12345678 1
X
@@@ sample_output
f=19 g=39 r0=123457F8 r1=92345678 r2=12345678 i=2 j=2 sw=other

@@@ hidden_input
FFFFFFFF 4
W 31 0 0
W 31 0 DEADBEEF
R 31 0
R 31 31
@@@ hidden_output
00000000
DEADBEEF
DEADBEEF
1

@@@ hidden_input
00000000 3
W 9 5 FF
W 0 0 2
W 31 31 3
@@@ hidden_output
000003E0
000003E0
800003E0

@@@ hidden_input
A5A5A5A5 4
R 7 0
R 31 24
R 15 4
M 15 4
@@@ hidden_output
A5
A5
A5A
0000FFF0

@@@ hidden_input
FFFFFFFF 1
X
@@@ hidden_output
f=31 g=63 r0=FFFFFFFF r1=BFFFFFFF r2=FFFFFFFF i=2 j=2 sw=all

@@@ hidden_input
00000001 1
X
@@@ hidden_output
f=0 g=1 r0=000003E1 r1=80000001 r2=00000001 i=2 j=2 sw=one

@@@ hidden_input
0000F000 5
W 15 12 0
W 3 0 A
W 30 1 3FFFFFFF
M 30 1
M 0 0
@@@ hidden_output
00000000
0000000A
7FFFFFFE
7FFFFFFE
00000001

@@@ hidden_input
4000020F 1
X
@@@ hidden_output
f=16 g=33 r0=400003EF r1=8000020F r2=4000020F i=2 j=2 sw=all

@@@ hint
Build the mask from two "half-infinite" masks so no shift ever reaches 32: `0xFFFFFFFFu >> (31 - hi)` has bits `hi..0` set, and `0xFFFFFFFFu << lo` has bits `31..lo` set. AND them. Parenthesise every parameter and the whole body.
@@@ hint
To evaluate `reg` only once, take its address once inside a `do { ... } while (0)` block: `volatile uint32_t *p_ = &(reg);`, and copy `val` into a local too. Then `*p_ = (*p_ & ~(mask)) | (((uint32_t)v_ << (shift)) & (mask));`. The final `& (mask)` truncates `val` to the field.
@@@ solution_code
#include <stdint.h>

/* bits hi..0 AND bits 31..lo; shift counts stay in 0..31, and it is a constant expression */
#define FIELD_MASK(hi, lo) \
    ((0xFFFFFFFFu >> (31u - (uint32_t)(hi))) & (0xFFFFFFFFu << (uint32_t)(lo)))

#define READ_FIELD(reg, mask, shift) \
    (((uint32_t)(reg) & (uint32_t)(mask)) >> (shift))

/* reg and val are evaluated exactly once; do/while(0) makes it one statement */
#define WRITE_FIELD(reg, mask, shift, val)                                   \
    do {                                                                     \
        volatile uint32_t *const reg_p_ = &(reg);                            \
        const uint32_t val_v_ = (uint32_t)(val);                             \
        *reg_p_ = (*reg_p_ & ~(uint32_t)(mask)) |                            \
                  ((val_v_ << (shift)) & (uint32_t)(mask));                  \
    } while (0)
@@@ explanation_md
**Approach.**
- **FIELD_MASK(hi, lo)** = `(0xFFFFFFFF >> (31 - hi)) & (0xFFFFFFFF << lo)`. The first term keeps bits `hi..0` and the second keeps bits `31..lo`. Both shift counts are in `0..31`, so `FIELD_MASK(31, 0)` is well defined. The usual `((1u << (hi - lo + 1)) - 1) << lo` shifts by 32 for the full-width field, which is UB (C11 6.5.7p3). With no function calls or statements, the macro is still an integer constant expression, usable in `static const` initializers and `case` labels.
- **READ_FIELD**: mask, then shift down. Parenthesise each parameter (`a | b` must be masked as a whole) and the whole body (`2u * READ_FIELD(...)` must multiply the field, not the masked register).
- **WRITE_FIELD**: the classic read-modify-write `reg = (reg & ~mask) | ((val << shift) & mask)`. The final `& mask` truncates oversized values. To evaluate `reg` once, take its address once. A `volatile uint32_t *` keeps the register access volatile. `do { } while (0)` turns the block into one statement that requires a trailing `;` and works with `if/else`.

What the hidden battery catches:

| written as | expands to | effect |
|---|---|---|
| `~mask` with mask `0x3u << 30` | `~0x3u << 30` | clears the whole register |
| `val << shift` with val `vals[j] \| 4u` | `vals[j] \| (4u << 30)` | value not shifted |
| `reg = (reg & ~m) \| ...` | `regs[i++]` twice | `i` incremented twice (UB) |
| `{ ... }` body | `{...};` before `else` | compile error |

**Complexity.** O(1). Each macro is a handful of ALU instructions. On ARMv7-M, compilers often fuse the read path into a single `UBFX` (unsigned bit-field extract) and the write path into `BFI`.

**Common mistakes**
- Building the mask with `1 << n` on a plain `int` (UB at bit 31), or with `(1u << width) - 1` (UB at width 32).
- No final `& mask` in `WRITE_FIELD`. Writing 0xFF into a 5-bit field silently corrupts the next field (hidden test `W 9 5 FF`).
- Dropping `volatile` on the internal pointer (`uint32_t *p = &(reg)` discards the qualifier). The compiler may then merge or remove the register accesses.
- Using a GNU statement-expression `({ ... })`. It is not ISO C, and MISRA forbids it.

**Interview follow-ups**
- MISRA C:2012 Dir 4.9 prefers `static inline` functions. Rewrite `WRITE_FIELD` as `static inline void write_field(volatile uint32_t *reg, uint32_t mask, unsigned shift, uint32_t val)`. Why does the single-evaluation problem disappear?
- How do vendor headers (CMSIS `_VAL2FLD` / `_FLD2VAL`, or Zephyr `FIELD_PREP` / `FIELD_GET`) derive the shift from the mask automatically? (`__builtin_ctz(mask)`.)
- Is `WRITE_FIELD` safe if an ISR writes another field of the same register? How do you fix it on Cortex-M (critical section, `LDREX/STREX`, or a dedicated set/clear register)?
- Why are C bit-fields (`struct { uint32_t presc : 5; }`) usually banned for register access in automotive code?
