@@@ meta
id: STC-E-06
topic: Structures
difficulty: Easy
type: FUNCTION
title: CAN Frame Acceptance Filter (ID/Mask)
tags: embedded, can-bus, struct-array, bitmask, asked-in-automotive
@@@ statement_md
A CAN controller keeps a bank of **acceptance filters**. Each filter has an ID, a mask and a frame-format flag. Implement the software model of that filter bank:

```c
struct CanFrame {
    uint32_t id;       /* 11-bit (standard) or 29-bit (extended) identifier */
    uint8_t  ide;      /* 0 = standard, 1 = extended                        */
    uint8_t  dlc;      /* data length code                                  */
    uint8_t  data[8];
};

struct CanFilter {
    uint32_t id;
    uint32_t mask;     /* 1-bit = "this ID bit must match", 0-bit = "don't care" */
    uint8_t  ide;      /* the filter only applies to frames with the same format */
};

int can_accept(const struct CanFrame *f, const struct CanFilter *flt, size_t nflt);
```

Both structs are already defined by the judge. Rules, in this order:

1. **Malformed frame -> return `-2`.** A frame is malformed if `ide == 0` and `id > 0x7FF`, or `ide == 1` and `id > 0x1FFFFFFF`, or `dlc > 8`.
2. Filter `i` **matches** when `flt[i].ide == f->ide` and every ID bit selected by the mask is equal. Only the valid ID bits take part: the mask is first limited to `0x7FF` for standard frames and to `0x1FFFFFFF` for extended frames. Bits of `flt[i].id` and `flt[i].mask` above that width are ignored.
3. Return the **lowest index** `i` of a matching filter, or `-1` if none matches. With `nflt == 0`, `flt` may be `NULL`.

**Input (read by the hidden harness)**
- Line 1: `nf`. Then `nf` lines `S|E <id hex> <mask hex>`.
- Next line: `q`. Then `q` lines `S|E <id hex> <dlc> <bytes...>`. Each frame line carries `min(dlc, 8)` hex data bytes.

**Output (printed by the harness)**, one line per frame (standard IDs printed as `%03X`, extended IDs as `%08X`):
- `ACCEPT f<i> <S|E> <ID> [<dlc>] <data bytes>`
- `REJECT <S|E> <ID>`
- `MALFORMED <S|E> <ID>`

**Example**
```
Input:
3
S 120 7F0
E 18DAF100 1FFFFF00
S 7DF 7FF
5
S 123 2 AA BB
S 7DF 8 02 01 0C 00 00 00 00 00
E 18DAF110 3 03 22 F1
S 130 0
E 120 1 FF

Output:
ACCEPT f0 S 123 [2] AA BB
ACCEPT f2 S 7DF [8] 02 01 0C 00 00 00 00 00
ACCEPT f1 E 18DAF110 [3] 03 22 F1
REJECT S 130
REJECT E 00000120
```
The last frame has ID `0x120` but is **extended**, so the standard filter `f0` does not apply.
@@@ constraints_md
- `0 <= nf <= 16`, `1 <= q <= 100`
- Frame and filter IDs are given as up to 8 hex digits and may contain bits above the valid width.
- `0 <= dlc <= 15` (a raw 4-bit DLC field). Values above 8 are malformed for classic CAN.
- Do not modify the frame or the filters.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>

/* Already defined by the judge:
 *
 * struct CanFrame  { uint32_t id; uint8_t ide; uint8_t dlc; uint8_t data[8]; };
 * struct CanFilter { uint32_t id; uint32_t mask; uint8_t ide; };
 */

int can_accept(const struct CanFrame *f, const struct CanFilter *flt, size_t nflt)
{
    /* TODO: -2 malformed, index of first matching filter, or -1 */
    (void)f;
    (void)flt;
    (void)nflt;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct CanFrame {
    uint32_t id;
    uint8_t  ide;
    uint8_t  dlc;
    uint8_t  data[8];
};

struct CanFilter {
    uint32_t id;
    uint32_t mask;
    uint8_t  ide;
};

/*USER_CODE*/

static void print_id(const struct CanFrame *f)
{
    if (f->ide) printf("E %08X", (unsigned)f->id);
    else printf("S %03X", (unsigned)f->id);
}

int main(void)
{
    static struct CanFilter flt[16];
    int nf, q;
    char t[4];
    if (scanf("%d", &nf) != 1 || nf < 0 || nf > 16) return 0;
    for (int i = 0; i < nf; i++) {
        unsigned id, mask;
        if (scanf("%3s %x %x", t, &id, &mask) != 3) return 0;
        flt[i].id = (uint32_t)id;
        flt[i].mask = (uint32_t)mask;
        flt[i].ide = (uint8_t)(t[0] == 'E');
    }
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        struct CanFrame f;
        unsigned id;
        int dlc;
        memset(&f, 0, sizeof f);
        if (scanf("%3s %x %d", t, &id, &dlc) != 3) return 0;
        f.id = (uint32_t)id;
        f.ide = (uint8_t)(t[0] == 'E');
        f.dlc = (uint8_t)dlc;
        int nb = dlc > 8 ? 8 : dlc;
        for (int i = 0; i < nb; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            f.data[i] = (uint8_t)b;
        }
        struct CanFilter before[16];
        memcpy(before, flt, sizeof before);
        int r = can_accept(&f, nf ? flt : NULL, (size_t)nf);
        if (memcmp(before, flt, sizeof before) != 0) {
            printf("FAIL: filters were modified\n");
            return 0;
        }
        if (r >= 0 && r < nf) {
            printf("ACCEPT f%d ", r);
            print_id(&f);
            printf(" [%d]", f.dlc);
            for (int i = 0; i < f.dlc; i++) printf(" %02X", (unsigned)f.data[i]);
            printf("\n");
        } else if (r == -1) {
            printf("REJECT ");
            print_id(&f);
            printf("\n");
        } else if (r == -2) {
            printf("MALFORMED ");
            print_id(&f);
            printf("\n");
        } else {
            printf("BAD RETURN %d\n", r);
        }
    }
    return 0;
}
@@@ sample_input
3
S 120 7F0
E 18DAF100 1FFFFF00
S 7DF 7FF
5
S 123 2 AA BB
S 7DF 8 02 01 0C 00 00 00 00 00
E 18DAF110 3 03 22 F1
S 130 0
E 120 1 FF
@@@ sample_output
ACCEPT f0 S 123 [2] AA BB
ACCEPT f2 S 7DF [8] 02 01 0C 00 00 00 00 00
ACCEPT f1 E 18DAF110 [3] 03 22 F1
REJECT S 130
REJECT E 00000120

@@@ sample_input
0
2
S 000 0
E 1FFFFFFF 8 11 22 33 44 55 66 77 88
@@@ sample_output
REJECT S 000
REJECT E 1FFFFFFF

@@@ hidden_input
2
S 000 000
E 00000000 00000000
6
S 7FF 0
S 800 1 01
E 1FFFFFFF 8 01 02 03 04 05 06 07 08
E 20000000 0
S 100 9 1 2 3 4 5 6 7 8
E 0 8 FF FF FF FF FF FF FF FF
@@@ hidden_output
ACCEPT f0 S 7FF [0]
MALFORMED S 800
ACCEPT f1 E 1FFFFFFF [8] 01 02 03 04 05 06 07 08
MALFORMED E 20000000
MALFORMED S 100
ACCEPT f1 E 00000000 [8] FF FF FF FF FF FF FF FF

@@@ hidden_input
2
S F123 FFFFFFFF
E 00000ABC FFFFFFFF
4
S 123 1 00
S 124 0
E 00000ABC 2 10 20
E 10000ABC 0
@@@ hidden_output
ACCEPT f0 S 123 [1] 00
REJECT S 124
ACCEPT f1 E 00000ABC [2] 10 20
REJECT E 10000ABC

@@@ hidden_input
3
S 100 700
S 1A0 7F0
S 000 000
3
S 1A5 1 01
S 2A5 0
S 0FF 2 FF 00
@@@ hidden_output
ACCEPT f0 S 1A5 [1] 01
ACCEPT f2 S 2A5 [0]
ACCEPT f2 S 0FF [2] FF 00

@@@ hidden_input
1
S 7FF 7FF
2
E 000007FF 0
S 7FF 0
@@@ hidden_output
REJECT E 000007FF
ACCEPT f0 S 7FF [0]

@@@ hidden_input
1
E 00FEF100 03FFFF00
3
E 18FEF100 8 00 11 22 33 44 55 66 77
E 0CFEF117 2 AB CD
E 18FEF200 0
@@@ hidden_output
ACCEPT f0 E 18FEF100 [8] 00 11 22 33 44 55 66 77
ACCEPT f0 E 0CFEF117 [2] AB CD
REJECT E 18FEF200

@@@ hidden_input
2
E 1FFFFFFF 1FFFFFFF
S 7FF 7FF
4
E 1FFFFFFF 1 5A
S 7FF 1 A5
E 1FFFFFFE 0
S 7FF 15 1 2 3 4 5 6 7 8
@@@ hidden_output
ACCEPT f0 E 1FFFFFFF [1] 5A
ACCEPT f1 S 7FF [1] A5
REJECT E 1FFFFFFE
MALFORMED S 7FF

@@@ hint
Check that the frame is valid first, and return `-2` before you look at any filter. Then compute the width mask once: `0x7FF` for standard, `0x1FFFFFFF` for extended.
@@@ hint
A filter matches when `flt[i].ide == f->ide && ((f->id ^ flt[i].id) & (flt[i].mask & width)) == 0`. XOR leaves a 1 wherever the two IDs differ, and the mask keeps only the bits you care about.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>

#define CAN_STD_MASK 0x7FFu
#define CAN_EXT_MASK 0x1FFFFFFFu

int can_accept(const struct CanFrame *f, const struct CanFilter *flt, size_t nflt)
{
    uint32_t width = f->ide ? CAN_EXT_MASK : CAN_STD_MASK;

    /* 1. reject malformed frames before touching the filter bank */
    if (f->id > width || f->dlc > 8)
        return -2;

    /* 2. first matching filter wins (lowest index = highest priority) */
    for (size_t i = 0; i < nflt; i++) {
        if (flt[i].ide != f->ide)
            continue;                             /* format must match */
        uint32_t care = flt[i].mask & width;      /* ignore bits above the ID width */
        if (((f->id ^ flt[i].id) & care) == 0)
            return (int)i;
    }
    return -1;
}
@@@ explanation_md
**Approach.** `(id ^ filter_id) & mask == 0` is the standard hardware acceptance test: XOR marks the differing bits, and the mask keeps only the bits the filter cares about. Two struct-level details matter:
- The `ide` member is part of the match. A standard filter must never accept an extended frame that happens to have a small ID (`0x120` in the sample).
- Only the valid width of the ID counts. Masking with `0x7FF` or `0x1FFFFFFF` stops stray upper bits in a filter configuration from breaking the match.

```
filter E 00FEF100 mask 03FFFF00   (J1939 PGN 0xFEF1, any priority, any source)
frame  0CFEF117 ^ 00FEF100 = 0C000017
                & 03FFFF00 = 00000000  -> accept
```

**Complexity.** Time O(nf) per frame, space O(1). Hardware does all filters in parallel.

**Common mistakes**
- Not comparing `ide`, so an extended frame `0x00000120` passes a standard filter for `0x120`.
- Using the raw mask, so upper garbage bits in the filter config make an exact-match filter reject everything.
- Testing `(id & mask) == filter_id` without masking `filter_id` as well. This fails as soon as the filter ID has a 1 in a don't-care position.
- Treating DLC 9..15 as valid. In CAN FD these codes mean 12..64 bytes, but a classic `data[8]` buffer would overflow.
- Returning the last matching filter instead of the first.

**Interview follow-ups**
- How does a filter in "list mode" (exact IDs) differ from "mask mode", and when do you prefer each on bxCAN/FDCAN?
- How would you extend `struct CanFrame` for CAN FD (64-byte payload, BRS/ESI flags) without breaking existing code?
- With 200 IDs to accept and only 14 hardware filters, how do you choose masks, and what does the software then have to filter?
- What is the J1939 29-bit ID layout (priority, PGN, source address), and how do you build a mask for "PGN X from any source"?
