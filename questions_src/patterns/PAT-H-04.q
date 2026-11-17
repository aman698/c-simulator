@@@ meta
id: PAT-H-04
topic: C Patterns
difficulty: Hard
type: FUNCTION
title: Register Bit-Field Map Dump
tags: embedded, register-dump, bit-fields, mask-extraction, validation, bsp
@@@ statement_md
BSP engineers debug peripherals by dumping a register **together with its field layout** from the datasheet. Implement

```c
struct reg_field { const char *name; int msb; int lsb; };   /* provided by the harness */

void dump_register(const char *reg_name, uint32_t value,
                   const struct reg_field *fields, int nfields);
```

`fields` lists the named fields of a 32-bit register in **any order**. A field covers bits `lsb..msb` (inclusive). Bits that belong to no field are **reserved**.

**Validation.** The map is invalid if `nfields < 0` or `nfields > 32`, or any field has `lsb < 0`, `msb > 31` or `msb < lsb`, or two fields share a bit. For an invalid map print only `<reg_name>: BAD FIELD MAP`.

**Output for a valid map**
1. `<reg_name> = 0x<value as 8 uppercase hex digits>`
2. The **bit strip** for bits 31 down to 0: `*` for a 1, `.` for a 0, and `-` for a reserved bit (whatever its value). The strip starts and ends with `|`, and a `|` is inserted between two neighbouring bits that belong to different fields (a reserved run counts as one group).
3. One line per field, ordered by **msb from high to low**:
   `printf("  %-*s [%2d:%2d] = %u (0x%X)\n", W, name, msb, lsb, field_value, field_value)`,
   where `W` is the length of the longest field name and `field_value` is the field's bits shifted down to bit 0.

**How it is tested.** A hidden `main()` reads `q` registers: `name hexvalue nfields`, then `max(nfields, 0)` lines `fieldname msb lsb`, and calls your function once per register.

**Example**
```
Input:
1
CTRL 8000A5C3 5
DIV 3 0
EN 31 31
PRESC 15 8
MODE 29 27
IRQ 4 4

Output:
CTRL = 0x8000A5C3
|*|-|...|-----------|*.*..*.*|---|.|..**|
  EN    [31:31] = 1 (0x1)
  MODE  [29:27] = 0 (0x0)
  PRESC [15: 8] = 165 (0xA5)
  IRQ   [ 4: 4] = 0 (0x0)
  DIV   [ 3: 0] = 3 (0x3)
```
The judge ignores trailing spaces and trailing blank lines.
@@@ constraints_md
- `1 <= q <= 10`; register and field names have 1..31 characters, no spaces.
- `-5 <= nfields <= 40`; `-5 <= lsb, msb <= 40` in the input.
- A field may be 32 bits wide (`[31:0]`).
- No `long`; the value is `uint32_t`.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* struct reg_field { const char *name; int msb; int lsb; };  is provided by the harness */

void dump_register(const char *reg_name, uint32_t value,
                   const struct reg_field *fields, int nfields)
{
    /* TODO: validate, print header, bit strip, field lines (msb high to low) */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

struct reg_field { const char *name; int msb; int lsb; };

/*USER_CODE*/

static char names[40][32];
static struct reg_field fl[40];

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int r = 0; r < q; r++) {
        char rname[32];
        unsigned int val;
        int n;
        if (scanf("%31s %x %d", rname, &val, &n) != 3) return 0;
        int cnt = n < 0 ? 0 : (n > 40 ? 40 : n);
        for (int i = 0; i < cnt; i++) {
            if (scanf("%31s %d %d", names[i], &fl[i].msb, &fl[i].lsb) != 3) return 0;
            fl[i].name = names[i];
        }
        dump_register(rname, (uint32_t)val, fl, n);
    }
    return 0;
}
@@@ sample_input
1
CTRL 8000A5C3 5
DIV 3 0
EN 31 31
PRESC 15 8
MODE 29 27
IRQ 4 4
@@@ sample_output
CTRL = 0x8000A5C3
|*|-|...|-----------|*.*..*.*|---|.|..**|
  EN    [31:31] = 1 (0x1)
  MODE  [29:27] = 0 (0x0)
  PRESC [15: 8] = 165 (0xA5)
  IRQ   [ 4: 4] = 0 (0x0)
  DIV   [ 3: 0] = 3 (0x3)

@@@ sample_input
2
DATA DEADBEEF 1
VAL 31 0
RSVD 12345678 0
@@@ sample_output
DATA = 0xDEADBEEF
|**.****.*.*.**.**.*****.***.****|
  VAL [31: 0] = 3735928559 (0xDEADBEEF)
RSVD = 0x12345678
|--------------------------------|

@@@ hidden_input
5
OVL FF 2
A 7 4
B 4 0
REV FF 1
X 2 5
HI FF 1
Y 32 30
LO FF 1
Z 3 -1
NEG FF -1
@@@ hidden_output
OVL: BAD FIELD MAP
REV: BAD FIELD MAP
HI: BAD FIELD MAP
LO: BAD FIELD MAP
NEG: BAD FIELD MAP

@@@ hidden_input
1
GPIO_MODER 55AA00FF 4
M0 7 0
M1 15 8
M2 23 16
M3 31 24
@@@ hidden_output
GPIO_MODER = 0x55AA00FF
|.*.*.*.*|*.*.*.*.|........|********|
  M3 [31:24] = 85 (0x55)
  M2 [23:16] = 170 (0xAA)
  M1 [15: 8] = 0 (0x0)
  M0 [ 7: 0] = 255 (0xFF)

@@@ hidden_input
1
CAN_ESR 00A70065 6
EWGF 0 0
EPVF 1 1
BOFF 2 2
LEC 6 4
TEC 23 16
REC 31 24
@@@ hidden_output
CAN_ESR = 0x00A70065
|........|*.*..***|---------|**.|-|*|.|*|
  REC  [31:24] = 0 (0x0)
  TEC  [23:16] = 167 (0xA7)
  LEC  [ 6: 4] = 6 (0x6)
  BOFF [ 2: 2] = 1 (0x1)
  EPVF [ 1: 1] = 0 (0x0)
  EWGF [ 0: 0] = 1 (0x1)

@@@ hidden_input
1
UART_CR1 0000A00C 4
UE 13 13
TE 3 3
RE 2 2
OVERSAMPLING 15 15
@@@ hidden_output
UART_CR1 = 0x0000A00C
|----------------|*|-|*|---------|*|*|--|
  OVERSAMPLING [15:15] = 1 (0x1)
  UE           [13:13] = 1 (0x1)
  TE           [ 3: 3] = 1 (0x1)
  RE           [ 2: 2] = 1 (0x1)

@@@ hidden_input
1
BITS F0F0A55A 32
B0 0 0
B1 1 1
B2 2 2
B3 3 3
B4 4 4
B5 5 5
B6 6 6
B7 7 7
B8 8 8
B9 9 9
B10 10 10
B11 11 11
B12 12 12
B13 13 13
B14 14 14
B15 15 15
B16 16 16
B17 17 17
B18 18 18
B19 19 19
B20 20 20
B21 21 21
B22 22 22
B23 23 23
B24 24 24
B25 25 25
B26 26 26
B27 27 27
B28 28 28
B29 29 29
B30 30 30
B31 31 31
@@@ hidden_output
BITS = 0xF0F0A55A
|*|*|*|*|.|.|.|.|*|*|*|*|.|.|.|.|*|.|*|.|.|*|.|*|.|*|.|*|*|.|*|.|
  B31 [31:31] = 1 (0x1)
  B30 [30:30] = 1 (0x1)
  B29 [29:29] = 1 (0x1)
  B28 [28:28] = 1 (0x1)
  B27 [27:27] = 0 (0x0)
  B26 [26:26] = 0 (0x0)
  B25 [25:25] = 0 (0x0)
  B24 [24:24] = 0 (0x0)
  B23 [23:23] = 1 (0x1)
  B22 [22:22] = 1 (0x1)
  B21 [21:21] = 1 (0x1)
  B20 [20:20] = 1 (0x1)
  B19 [19:19] = 0 (0x0)
  B18 [18:18] = 0 (0x0)
  B17 [17:17] = 0 (0x0)
  B16 [16:16] = 0 (0x0)
  B15 [15:15] = 1 (0x1)
  B14 [14:14] = 0 (0x0)
  B13 [13:13] = 1 (0x1)
  B12 [12:12] = 0 (0x0)
  B11 [11:11] = 0 (0x0)
  B10 [10:10] = 1 (0x1)
  B9  [ 9: 9] = 0 (0x0)
  B8  [ 8: 8] = 1 (0x1)
  B7  [ 7: 7] = 0 (0x0)
  B6  [ 6: 6] = 1 (0x1)
  B5  [ 5: 5] = 0 (0x0)
  B4  [ 4: 4] = 1 (0x1)
  B3  [ 3: 3] = 1 (0x1)
  B2  [ 2: 2] = 0 (0x0)
  B1  [ 1: 1] = 1 (0x1)
  B0  [ 0: 0] = 0 (0x0)

@@@ hidden_input
1
TOOMANY 1 33
F0 0 0
F1 1 1
F2 2 2
F3 3 3
F4 4 4
F5 5 5
F6 6 6
F7 7 7
F8 8 8
F9 9 9
F10 10 10
F11 11 11
F12 12 12
F13 13 13
F14 14 14
F15 15 15
F16 16 16
F17 17 17
F18 18 18
F19 19 19
F20 20 20
F21 21 21
F22 22 22
F23 23 23
F24 24 24
F25 25 25
F26 26 26
F27 27 27
F28 28 28
F29 29 29
F30 30 30
F31 31 31
F32 0 0
@@@ hidden_output
TOOMANY: BAD FIELD MAP

@@@ hidden_input
2
TOP 80000001 2
HIGH 31 1
LOW 0 0
MID FFFFFFFF 1
CORE 23 8
@@@ hidden_output
TOP = 0x80000001
|*..............................|*|
  HIGH [31: 1] = 1073741824 (0x40000000)
  LOW  [ 0: 0] = 1 (0x1)
MID = 0xFFFFFFFF
|--------|****************|--------|
  CORE [23: 8] = 65535 (0xFFFF)

@@@ hint
Build an `owner[32]` table first: `owner[b]` is the index of the field that contains bit `b`, or `-1` for reserved. Filling it also detects overlaps (a bit that already has an owner). After that, the strip, the separators and the field order all come from walking `b = 31..0`.
@@@ hint
Extract a field with `(value >> lsb) & mask`, where `mask` has `msb - lsb + 1` low bits set. Build the mask so that a 32-bit field works: `1u << 32` is undefined behavior, so use `width == 32 ? 0xFFFFFFFFu : (1u << width) - 1u`. A field is printed when the walk reaches its `msb`, which gives the "high to low" order without sorting.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

void dump_register(const char *reg_name, uint32_t value,
                   const struct reg_field *fields, int nfields)
{
    int owner[32];
    int ok = (nfields >= 0 && nfields <= 32);

    for (int b = 0; b < 32; b++)
        owner[b] = -1;                          /* -1 = reserved bit */
    for (int f = 0; ok && f < nfields; f++) {
        int msb = fields[f].msb, lsb = fields[f].lsb;
        if (lsb < 0 || msb > 31 || msb < lsb) {
            ok = 0;
            break;
        }
        for (int b = lsb; b <= msb; b++) {
            if (owner[b] != -1) {               /* two fields claim this bit */
                ok = 0;
                break;
            }
            owner[b] = f;
        }
    }
    if (!ok) {
        printf("%s: BAD FIELD MAP\n", reg_name);
        return;
    }

    printf("%s = 0x%08X\n", reg_name, (unsigned)value);

    putchar('|');
    for (int b = 31; b >= 0; b--) {
        char c = owner[b] < 0 ? '-' : (((value >> b) & 1u) ? '*' : '.');
        putchar(c);
        if (b > 0 && owner[b - 1] != owner[b])
            putchar('|');                       /* group boundary */
    }
    printf("|\n");

    int w = 0;
    for (int f = 0; f < nfields; f++) {
        int len = (int)strlen(fields[f].name);
        if (len > w)
            w = len;
    }
    for (int b = 31; b >= 0; b--) {             /* msb high to low, no sort needed */
        int f = owner[b];
        if (f < 0 || fields[f].msb != b)
            continue;
        int width = fields[f].msb - fields[f].lsb + 1;
        uint32_t mask = (width == 32) ? 0xFFFFFFFFu : ((1u << width) - 1u);
        uint32_t v = (value >> fields[f].lsb) & mask;
        printf("  %-*s [%2d:%2d] = %u (0x%X)\n", w, fields[f].name,
               fields[f].msb, fields[f].lsb, (unsigned)v, (unsigned)v);
    }
}
@@@ explanation_md
**Approach.** Turn the field list into a per-bit **ownership table** `owner[32]`. One pass over the fields fills it and validates it at the same time: bounds, `msb >= lsb`, and overlaps (a bit that already has an owner). Everything else is a walk over `b = 31..0`:
- the strip character comes from `owner[b]` and bit `b` of the value;
- a separator goes between `b` and `b-1` exactly when their owners differ, which automatically merges a run of reserved bits into one group;
- a field line is printed when the walk reaches the field's `msb`, which yields "high to low" order without sorting.

```
CTRL = 0x8000A5C3, owner (31..0): EN | rsv | MODE MODE MODE | rsv x11 | PRESC x8 | rsv x3 | IRQ | DIV x4
|*|-|...|-----------|*.*..*.*|---|.|..**|
```

**Field extraction.** `(value >> lsb) & mask` with `mask = (1u << width) - 1u`. For `width == 32` the shift count equals the type width, which is **undefined behavior**; on x86 it typically produces mask `0`. Hence the special case.

**Complexity.** Time O(32 + total field width + nfields) = O(1) for a 32-bit register. Space O(32).

**Common mistakes**
- Printing fields in input order. Datasheets list fields MSB first, and the spec requires it.
- Using `1 << width` on a signed `int`: for `width = 31` that overflows (undefined behavior), and for 32 it is undefined anyway.
- Shifting a field value up instead of down (printing `value & (mask << lsb)`), so `PRESC` shows `42240` instead of `165`.
- Printing a separator between every two reserved bits, or none between two adjacent fields (`M3`/`M2`).
- Forgetting to validate overlaps. On real silicon, two drivers that disagree about a field cause read-modify-write bugs.

**Interview follow-ups**
- Write the matching `reg_field_write(uint32_t *reg, field, v)` as a read-modify-write. Why must it be atomic when an ISR touches the same register (and why do STM32 GPIOs have a separate `BSRR` register)?
- Compare this table-driven approach with C bit-fields (`struct { uint32_t div:4; ... }`). Why do most BSPs avoid bit-fields for hardware registers? (Layout and access width are implementation-defined.)
- Generate the field table automatically from an SVD/IP-XACT file. What would you validate at build time with `_Static_assert`?
