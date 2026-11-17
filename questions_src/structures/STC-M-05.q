@@@ meta
id: STC-M-05
topic: Structures
difficulty: Medium
type: FUNCTION
title: Timer Control Register as a Union with a Bit-Field View
tags: embedded, union, bit-fields, register, reserved-bits, bsp
@@@ statement_md
The datasheet of a timer peripheral describes its 32-bit control register `TIMx_CTRL` like this:

| bits | field | meaning |
|---|---|---|
| 0 | `EN` | counter enable |
| 2:1 | `MODE` | 0 = up, 1 = down, 2 = center-aligned, **3 = reserved (invalid)** |
| 3 | - | reserved, must be 0 |
| 11:4 | `PRESC` | prescaler (0..255) |
| 15:12 | - | reserved, must be 0 |
| 18:16 | `IRQ` | interrupt enables (update, compare, overflow) |
| 23:19 | - | reserved, must be 0 |
| 31:24 | `ID` | peripheral ID |

Your BSP wants two views of the same 32 bits: the raw word for register reads and writes, and named fields for readable code. Define

```c
typedef union {
    uint32_t raw;
    struct {
        /* fields EN, MODE, PRESC, IRQ, ID at the positions above,
           reserved ranges as unnamed (or RSVDn) bit-fields */
    } bits;
} TimCtrl;
```

so that `bits.X` maps exactly onto the table. The target uses the System V layout: the first bit-field occupies the least significant bit. Then implement

```c
uint32_t tim_check(TimCtrl r);
```

which returns a bitmask of configuration errors (0 means valid):

| bit | value | error |
|---|---|---|
| 0 | `0x1` | any reserved bit (3, 15:12, 23:19) is 1 |
| 1 | `0x2` | `MODE == 3` |
| 2 | `0x4` | `EN == 1` and `PRESC == 0` |
| 3 | `0x8` | `IRQ != 0` and `EN == 0` (interrupts on a stopped timer) |

**How it is tested.** The hidden harness keeps one `TimCtrl r` and runs commands:
- `RAW <hex>`: `r.raw = value`
- `SET <EN|MODE|PRESC|IRQ|ID> <decimal>`: `r.bits.<field> = value`. Values that are too wide are truncated by the bit-field, as in real C.
- `CHECK`: prints `check=0x<hex>` with the result of `tim_check(r)`

After `RAW` and `SET` it prints `raw=0x%08X EN=.. MODE=.. PRESC=.. IRQ=.. ID=0x%02X`, reading the fields through `r.bits`.

**Example**
```
Input:
RAW 0x2A000000
SET EN 1
SET MODE 2
SET PRESC 99
CHECK

Output:
raw=0x2A000000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000001 EN=1 MODE=0 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000005 EN=1 MODE=2 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000635 EN=1 MODE=2 PRESC=99 IRQ=0 ID=0x2A
check=0x0
```
@@@ constraints_md
- `sizeof(TimCtrl)` must be 4.
- Use `uint32_t` (or `unsigned int`) as the bit-field type for every field.
- At most 50 commands.
@@@ starter_code
#include <stdint.h>

typedef union {
    uint32_t raw;
    struct {
        /* TODO: this layout ignores the reserved bits - fix it (LSB first) */
        uint32_t EN    : 1;
        uint32_t MODE  : 2;
        uint32_t PRESC : 8;
        uint32_t IRQ   : 3;
        uint32_t ID    : 8;
    } bits;
} TimCtrl;

uint32_t tim_check(TimCtrl r)
{
    /* TODO: return the error bitmask */
    (void)r;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/*USER_CODE*/

static void show(TimCtrl r)
{
    printf("raw=0x%08X EN=%u MODE=%u PRESC=%u IRQ=%u ID=0x%02X\n",
           (unsigned)r.raw, (unsigned)r.bits.EN, (unsigned)r.bits.MODE,
           (unsigned)r.bits.PRESC, (unsigned)r.bits.IRQ, (unsigned)r.bits.ID);
}

int main(void)
{
    TimCtrl r;
    char cmd[8], field[8];
    memset(&r, 0, sizeof r);
    if (sizeof(TimCtrl) != 4) {
        printf("BAD SIZE %u\n", (unsigned)sizeof(TimCtrl));
        return 0;
    }
    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "RAW") == 0) {
            unsigned v;
            if (scanf("%x", &v) != 1) break;
            r.raw = (uint32_t)v;
            show(r);
        } else if (strcmp(cmd, "SET") == 0) {
            unsigned v;
            if (scanf("%7s %u", field, &v) != 2) break;
            if (strcmp(field, "EN") == 0) r.bits.EN = v;
            else if (strcmp(field, "MODE") == 0) r.bits.MODE = v;
            else if (strcmp(field, "PRESC") == 0) r.bits.PRESC = v;
            else if (strcmp(field, "IRQ") == 0) r.bits.IRQ = v;
            else if (strcmp(field, "ID") == 0) r.bits.ID = v;
            show(r);
        } else if (strcmp(cmd, "CHECK") == 0) {
            printf("check=0x%X\n", (unsigned)tim_check(r));
        }
    }
    return 0;
}
@@@ sample_input
RAW 0x2A000000
SET EN 1
SET MODE 2
SET PRESC 99
CHECK
@@@ sample_output
raw=0x2A000000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000001 EN=1 MODE=0 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000005 EN=1 MODE=2 PRESC=0 IRQ=0 ID=0x2A
raw=0x2A000635 EN=1 MODE=2 PRESC=99 IRQ=0 ID=0x2A
check=0x0

@@@ sample_input
RAW 0xFFFFFFFF
CHECK
@@@ sample_output
raw=0xFFFFFFFF EN=1 MODE=3 PRESC=255 IRQ=7 ID=0xFF
check=0x3

@@@ hidden_input
RAW 0x0
SET PRESC 300
SET MODE 5
SET IRQ 9
SET ID 427
CHECK
@@@ hidden_output
raw=0x00000000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
raw=0x000002C0 EN=0 MODE=0 PRESC=44 IRQ=0 ID=0x00
raw=0x000002C2 EN=0 MODE=1 PRESC=44 IRQ=0 ID=0x00
raw=0x000102C2 EN=0 MODE=1 PRESC=44 IRQ=1 ID=0x00
raw=0xAB0102C2 EN=0 MODE=1 PRESC=44 IRQ=1 ID=0xAB
check=0x8

@@@ hidden_input
RAW 0x00000008
CHECK
RAW 0x0000F000
CHECK
RAW 0x00F80000
CHECK
RAW 0x00070000
CHECK
@@@ hidden_output
raw=0x00000008 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
check=0x1
raw=0x0000F000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
check=0x1
raw=0x00F80000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
check=0x1
raw=0x00070000 EN=0 MODE=0 PRESC=0 IRQ=7 ID=0x00
check=0x8

@@@ hidden_input
RAW 0x00000001
CHECK
RAW 0x00000007
CHECK
@@@ hidden_output
raw=0x00000001 EN=1 MODE=0 PRESC=0 IRQ=0 ID=0x00
check=0x4
raw=0x00000007 EN=1 MODE=3 PRESC=0 IRQ=0 ID=0x00
check=0x6

@@@ hidden_input
RAW 0x00F8F008
SET PRESC 255
SET EN 1
CHECK
@@@ hidden_output
raw=0x00F8F008 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
raw=0x00F8FFF8 EN=0 MODE=0 PRESC=255 IRQ=0 ID=0x00
raw=0x00F8FFF9 EN=1 MODE=0 PRESC=255 IRQ=0 ID=0x00
check=0x1

@@@ hidden_input
RAW 0x80000000
SET ID 0
CHECK
@@@ hidden_output
raw=0x80000000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x80
raw=0x00000000 EN=0 MODE=0 PRESC=0 IRQ=0 ID=0x00
check=0x0

@@@ hidden_input
SET EN 1
SET MODE 3
SET PRESC 255
SET IRQ 7
SET ID 255
CHECK
@@@ hidden_output
raw=0x00000001 EN=1 MODE=0 PRESC=0 IRQ=0 ID=0x00
raw=0x00000007 EN=1 MODE=3 PRESC=0 IRQ=0 ID=0x00
raw=0x00000FF7 EN=1 MODE=3 PRESC=255 IRQ=0 ID=0x00
raw=0x00070FF7 EN=1 MODE=3 PRESC=255 IRQ=7 ID=0x00
raw=0xFF070FF7 EN=1 MODE=3 PRESC=255 IRQ=7 ID=0xFF
check=0x2

@@@ hidden_input
RAW 0x12345678
CHECK
@@@ hidden_output
raw=0x12345678 EN=0 MODE=0 PRESC=103 IRQ=4 ID=0x12
check=0x9

@@@ hint
List the fields LSB-first and include every gap: `EN:1`, a 2-bit `MODE`, then **a 1-bit unnamed field** for bit 3, `PRESC:8`, a 4-bit gap, `IRQ:3`, a 5-bit gap, `ID:8`. The widths must add up to 32.
@@@ hint
For the reserved check, the raw view is simplest: `r.raw & 0x00F8F008u`. Read the other rules from `r.bits`.
@@@ solution_code
#include <stdint.h>

typedef union {
    uint32_t raw;
    struct {                       /* System V: first field = bit 0 */
        uint32_t EN    : 1;        /* bit 0      */
        uint32_t MODE  : 2;        /* bits 2:1   */
        uint32_t       : 1;        /* bit 3      reserved */
        uint32_t PRESC : 8;        /* bits 11:4  */
        uint32_t       : 4;        /* bits 15:12 reserved */
        uint32_t IRQ   : 3;        /* bits 18:16 */
        uint32_t       : 5;        /* bits 23:19 reserved */
        uint32_t ID    : 8;        /* bits 31:24 */
    } bits;                        /* 1+2+1+8+4+3+5+8 = 32 */
} TimCtrl;

#define TIM_CTRL_RESERVED_MASK 0x00F8F008u   /* bit 3 | bits 15:12 | bits 23:19 */

uint32_t tim_check(TimCtrl r)
{
    uint32_t err = 0;
    if (r.raw & TIM_CTRL_RESERVED_MASK)       err |= 0x1u;   /* raw view    */
    if (r.bits.MODE == 3u)                    err |= 0x2u;   /* field view  */
    if (r.bits.EN && r.bits.PRESC == 0u)      err |= 0x4u;
    if (r.bits.IRQ != 0u && !r.bits.EN)       err |= 0x8u;
    return err;
}
@@@ explanation_md
**Approach.** A union gives two names to the same 4 bytes. `raw` is the whole word, and `bits` slices it into named fields. Each reserved range must appear as an **unnamed bit-field** of the right width. Otherwise every field after the gap moves down. The widths must add up to exactly 32.

```
bit: 31      24 23   19 18 16 15  12 11        4  3  2 1  0
     [   ID   ][ rsvd ][IRQ][ rsvd ][  PRESC   ][r][MODE][EN]
0x12345678: ID=0x12, IRQ=0b100=4, PRESC=0x67=103, MODE=0, EN=0
            reserved bits 15:12 = 0x5 -> err 0x1; IRQ on a stopped timer -> err 0x8  => 0x9
```

Writes through the bit-field view are read-modify-write operations on the containing word. That is why `SET PRESC 255` on `0x00F8F008` keeps the reserved bits that were already 1.

**Complexity.** Time O(1), space O(1).

**Common mistakes**
- Leaving out the reserved gaps. `PRESC` then starts at bit 3, `SET PRESC 99` gives `0x318` instead of `0x630`, and every later field is off.
- Listing fields MSB-first (`ID` first). On System V/ARM EABI, the first declared field is the **least** significant.
- Using signed `int` fields: `MODE = 3` would read back as `-1` in a signed 2-bit field.
- Expecting `SET PRESC 300` to fail or saturate. It silently keeps the low 8 bits (44). Validate ranges before writing.

**Interview follow-ups**
- Why do vendor headers (CMSIS) give you both this union style **and** `_Pos`/`_Msk` macros, and which one does MISRA prefer? (Bit-field allocation is implementation-defined, C11 6.7.2.1p11.)
- On a real peripheral, the struct must be `volatile`. What bus accesses does `TIM->CTRL.bits.EN = 1;` generate, and why is that dangerous for **write-1-to-clear** status bits?
- How do you set `MODE` and `PRESC` together in a single register write?
- How would you add a compile-time check that `bits` really is 32 bits wide and that `PRESC` starts at bit 4? (`_Static_assert(sizeof(TimCtrl) == 4, ...)`, plus a known-value unit test, because `offsetof` does not work on bit-fields.)
