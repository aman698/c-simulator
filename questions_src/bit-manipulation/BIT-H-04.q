@@@ meta
id: BIT-H-04
topic: Bit Manipulation
difficulty: Hard
type: CODE
title: Decode and Encode J1939 29-Bit CAN Identifiers
tags: embedded, j1939, can, extended-id, bit-fields, commercial-vehicle, asked-in-automotive
@@@ statement_md
Trucks, buses and off-highway machines use **SAE J1939** on top of CAN 2.0B. Every frame has a 29-bit extended identifier:

```
bit:  28 27 26 | 25  | 24 | 23 ........ 16 | 15 ......... 8 | 7 .......... 0
      priority | EDP | DP |   PF (8 bit)   |   PS (8 bit)   |   SA (8 bit)
```

- **priority** (0 = highest, 7 = lowest), **EDP** (extended data page, also called R), **DP** (data page), **PF** (PDU format), **PS** (PDU specific), **SA** (source address).
- **PDU1** (`PF < 240`): PS is the **destination address** (255 = global). The 18-bit PGN is `EDP:DP:PF:00`, so the PS byte is **not** part of the PGN.
- **PDU2** (`PF >= 240`): PS is the **group extension** and **is** part of the PGN: `EDP:DP:PF:PS`. The message is always broadcast.

So `PGN = (EDP << 17) | (DP << 16) | (PF << 8) | (PF >= 240 ? PS : 0)`.

Write a tool that decodes and encodes identifiers.

**Input**
- Line 1: `q`.
- Next `q` lines, one of:
  - `D id`: decode `id` (hex, up to 32 bits).
  - `E prio pgn da sa`: encode (all decimal). For PDU1 PGNs, `da` goes into PS. For PDU2 PGNs, `da` is ignored.

**Output**
- `D`: `prio=P pgn=<decimal> (0x<5 hex digits>) pdu1 da=<DA> sa=<SA>`, or `... pdu2 ge=<PS> sa=<SA>`. If `id` does not fit in 29 bits, print `invalid id`.
- `E`: `id=0x<8 hex digits>`, or `invalid` if `prio > 7`, `pgn > 0x3FFFF`, `da > 255`, `sa > 255`, or the PGN is a PDU1 PGN (`PF < 240`) whose low byte is not 0.

All hex output is uppercase.

**Example**
```
Input:
3
D 0CF00400
D 18EAFF00
E 6 59904 255 0

Output:
prio=3 pgn=61444 (0x0F004) pdu2 ge=4 sa=0
prio=6 pgn=59904 (0x0EA00) pdu1 da=255 sa=0
id=0x18EAFF00
```
`0x0CF00400` is EEC1 (engine speed) from the engine (SA 0). `0x18EAFF00` is a global Request (PGN 59904).
@@@ constraints_md
- `1 <= q <= 50`
- `0 <= id <= 0xFFFFFFFF`; `0 <= prio, pgn, da, sa <= 10^6`
- Use shifts and masks, no string manipulation of hex digits.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'D') {
            unsigned id;
            if (scanf("%x", &id) != 1) return 0;
            /* TODO: decode */
        } else {
            unsigned prio, pgn, da, sa;
            if (scanf("%u %u %u %u", &prio, &pgn, &da, &sa) != 4) return 0;
            /* TODO: encode */
        }
    }
    return 0;
}
@@@ sample_input
3
D 0CF00400
D 18EAFF00
E 6 59904 255 0
@@@ sample_output
prio=3 pgn=61444 (0x0F004) pdu2 ge=4 sa=0
prio=6 pgn=59904 (0x0EA00) pdu1 da=255 sa=0
id=0x18EAFF00

@@@ sample_input
2
D 18FEF100
E 3 61444 255 0
@@@ sample_output
prio=6 pgn=65265 (0x0FEF1) pdu2 ge=241 sa=0
id=0x0CF00400

@@@ hidden_input
4
D 18EFFF21
D 18F00121
D 0C00000B
D 00000000
@@@ hidden_output
prio=6 pgn=61184 (0x0EF00) pdu1 da=255 sa=33
prio=6 pgn=61441 (0x0F001) pdu2 ge=1 sa=33
prio=3 pgn=0 (0x00000) pdu1 da=0 sa=11
prio=0 pgn=0 (0x00000) pdu1 da=0 sa=0

@@@ hidden_input
4
D 1FFFFFFF
D 20000000
D FFFFFFFF
D 1CFECA03
@@@ hidden_output
prio=7 pgn=262143 (0x3FFFF) pdu2 ge=255 sa=255
invalid id
invalid id
prio=7 pgn=65226 (0x0FECA) pdu2 ge=202 sa=3

@@@ hidden_input
2
D 01ECFF00
D 03FE1234
@@@ hidden_output
prio=0 pgn=125952 (0x1EC00) pdu1 da=255 sa=0
prio=0 pgn=261650 (0x3FE12) pdu2 ge=18 sa=52

@@@ hidden_input
5
E 6 59905 255 0
E 8 0 0 0
E 6 262144 0 0
E 6 65226 0 256
E 7 262143 0 255
@@@ hidden_output
invalid
invalid
invalid
invalid
id=0x1FFFFFFF

@@@ hidden_input
4
E 0 125952 37 128
E 3 0 0 11
E 6 61184 23 249
E 7 65226 255 3
@@@ hidden_output
id=0x01EC2580
id=0x0C00000B
id=0x18EF17F9
id=0x1CFECA03

@@@ hint
Extract each field with "shift down, then mask to its width": `prio = (id >> 26) & 0x7`, `pf = (id >> 16) & 0xFF`, `ps = (id >> 8) & 0xFF`, `sa = id & 0xFF`, and `EDP:DP = (id >> 24) & 0x3`. The only branch is `pf < 240`.
@@@ hint
For encoding, everything above the PS byte comes straight from the PGN: `((pgn >> 8) & 0x3FF) << 16` covers EDP, DP and PF. Then `PS = pf < 240 ? da : (pgn & 0xFF)`, and `id = (prio << 26) | that | (PS << 8) | sa`. Validate the inputs before building the ID.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

#define J1939_PDU2_MIN_PF 240u

static void decode(uint32_t id)
{
    if (id > 0x1FFFFFFFu) {                      /* bits 29..31 must be zero */
        printf("invalid id\n");
        return;
    }
    uint32_t prio = (id >> 26) & 0x7u;
    uint32_t dp2  = (id >> 24) & 0x3u;           /* EDP:DP */
    uint32_t pf   = (id >> 16) & 0xFFu;
    uint32_t ps   = (id >> 8) & 0xFFu;
    uint32_t sa   = id & 0xFFu;
    uint32_t pgn  = (dp2 << 16) | (pf << 8) | (pf >= J1939_PDU2_MIN_PF ? ps : 0u);

    printf("prio=%u pgn=%u (0x%05X) ", (unsigned)prio, (unsigned)pgn, (unsigned)pgn);
    if (pf < J1939_PDU2_MIN_PF)
        printf("pdu1 da=%u sa=%u\n", (unsigned)ps, (unsigned)sa);
    else
        printf("pdu2 ge=%u sa=%u\n", (unsigned)ps, (unsigned)sa);
}

static void encode(uint32_t prio, uint32_t pgn, uint32_t da, uint32_t sa)
{
    if (prio > 7u || pgn > 0x3FFFFu || da > 255u || sa > 255u) {
        printf("invalid\n");
        return;
    }
    uint32_t pf = (pgn >> 8) & 0xFFu;
    uint32_t ps;
    if (pf < J1939_PDU2_MIN_PF) {
        if ((pgn & 0xFFu) != 0u) {               /* PDU1 PGNs have a zero PS byte */
            printf("invalid\n");
            return;
        }
        ps = da;
    } else {
        ps = pgn & 0xFFu;                        /* group extension, da ignored */
    }
    uint32_t id = (prio << 26) | (((pgn >> 8) & 0x3FFu) << 16) | (ps << 8) | sa;
    printf("id=0x%08X\n", (unsigned)id);
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'D') {
            unsigned id;
            if (scanf("%x", &id) != 1) return 0;
            decode(id);
        } else {
            unsigned prio, pgn, da, sa;
            if (scanf("%u %u %u %u", &prio, &pgn, &da, &sa) != 4) return 0;
            encode(prio, pgn, da, sa);
        }
    }
    return 0;
}
@@@ explanation_md
**Approach.** Every field is extracted with "shift right by its LSB position, AND with its width mask". The PGN is then assembled according to the PDU format:

```
0x18EAFF00 = 110 0 0 11101010 11111111 00000000
             prio=6, EDP=0, DP=0, PF=0xEA (234 < 240 -> PDU1)
             PS=0xFF -> destination = global, SA=0x00
             PGN = 0:0:0xEA:00 = 0x0EA00 = 59904 (Request)
```

Encoding is the reverse: the PGN's upper 10 bits (EDP, DP, PF) go to id bits 25..16, PS is either the destination (PDU1) or the PGN's low byte (PDU2), and priority and SA are OR-ed in. Validation rejects anything that would not round-trip, such as a PDU1 PGN with a non-zero low byte (`59905`).

**Complexity.** O(1) per identifier, O(q) overall, O(1) space.

**Common mistakes**
- Including PS in the PGN for **PDU1** messages. A Request sent to address 0x21 would then decode as PGN `0xEA21` instead of `0xEA00`. This is the classic J1939 bug: two nodes "send different PGNs" that are really the same message to different destinations.
- Off-by-one at the boundary: `PF = 239` (`0xEF`, Proprietary A) is PDU1 and `PF = 240` is PDU2.
- Forgetting EDP and DP. The PGN is 18 bits, not 16, so DP = 1 doubles the PGN space (`0x1EC00`).
- Treating the CAN identifier as 32 bits. Bits 29..31 are not part of the identifier. Many CAN drivers store an IDE flag there (for example, Linux SocketCAN's `CAN_EFF_FLAG` is bit 31), so mask it before decoding.
- Printing the PGN with `%04X`. PGNs above `0xFFFF` need 5 hex digits.

**Interview follow-ups**
- How does J1939 **address claiming** (PGN 60928) use the 64-bit NAME, and what happens when two ECUs claim the same SA?
- Transport Protocol: how are messages longer than 8 bytes sent (TP.CM / TP.DT, BAM vs RTS/CTS)?
- Why does a lower priority **number** win arbitration on CAN? Relate that to the dominant/recessive bit levels of the identifier MSBs.
- Configure a hardware acceptance filter/mask that accepts PGN 61444 from **any** source address, but only that PGN.
