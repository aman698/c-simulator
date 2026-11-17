@@@ meta
id: ENM-H-08
topic: Enums
difficulty: Hard
type: FIND_THE_BUG
title: ReadDTCInformation 19 02 Misses Confirmed DTCs
tags: embedded, uds, dtc, bit-flags, logical-vs-bitwise, asked-in-automotive
@@@ statement_md
The ECU implements UDS service `19 02` (*reportDTCByStatusMask*). The tester sends a status mask, and the ECU answers with every DTC whose status byte has at least one bit in common with that mask. Only the status bits this ECU supports count. Those are its **DTCStatusAvailabilityMask**:

```c
typedef enum {
    DTC_TF = 0x01, DTC_TFTOC = 0x02, DTC_PDTC = 0x04, DTC_CDTC = 0x08,
    DTC_TNCSLC = 0x10, DTC_TFSLC = 0x20, DTC_TNCTOC = 0x40, DTC_WIR = 0x80
} DtcStatusBit;

#define DTC_AVAILABILITY_MASK (DTC_TF | DTC_TFTOC | DTC_PDTC | DTC_CDTC | DTC_TFSLC)   /* 0x2F */
```

Intended behaviour for each request mask `m`:
- The effective mask is `m & DTC_AVAILABILITY_MASK`.
- A DTC is reported if `status & effective_mask` is non-zero. Its reported status is `status & DTC_AVAILABILITY_MASK`.
- Print one response line: `59 02 2F`, followed by ` HH MM LL SS` (3 DTC bytes + reported status) for each reported DTC, in database order. All bytes are two uppercase hex digits.

Workshop testers report that `19 02 08` (confirmed DTCs) returns only some of the confirmed DTCs, even though the MIL is on, and that `19 02 FF` misses DTCs as well. Requests with mask `01` look fine. Find and fix the bug.

**Input**
- Line 1: `n`, the number of DTCs in the database. Next `n` lines: `DTC status` (6 and 2 hex digits).
- Next line: `q`. Next `q` lines: a request mask (2 hex digits).

**Example**
```
Input:
4
C07300 09
050100 2C
A10012 50
D10087 24
2
01
04

Output:
59 02 2F C0 73 00 09
59 02 2F 05 01 00 2C D1 00 87 24
```
@@@ constraints_md
- `0 <= n <= 100`, `1 <= q <= 20`
- The fix is one character.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

typedef enum {
    DTC_TF = 0x01, DTC_TFTOC = 0x02, DTC_PDTC = 0x04, DTC_CDTC = 0x08,
    DTC_TNCSLC = 0x10, DTC_TFSLC = 0x20, DTC_TNCTOC = 0x40, DTC_WIR = 0x80
} DtcStatusBit;

#define DTC_AVAILABILITY_MASK (DTC_TF | DTC_TFTOC | DTC_PDTC | DTC_CDTC | DTC_TFSLC)

#define MAX_DTC 100

struct DtcRecord {
    uint32_t dtc;       /* 3-byte DTC number */
    uint8_t  status;
};

static struct DtcRecord db[MAX_DTC];
static int db_count;

static void report_dtc_by_status_mask(uint8_t req_mask)
{
    uint8_t effective_mask = req_mask && DTC_AVAILABILITY_MASK;

    printf("59 02 %02X", (unsigned)DTC_AVAILABILITY_MASK);
    for (int i = 0; i < db_count; i++) {
        if (db[i].status & effective_mask) {
            printf(" %02X %02X %02X %02X",
                   (unsigned)(db[i].dtc >> 16) & 0xFFu,
                   (unsigned)(db[i].dtc >> 8) & 0xFFu,
                   (unsigned)db[i].dtc & 0xFFu,
                   (unsigned)(db[i].status & DTC_AVAILABILITY_MASK));
        }
    }
    printf("\n");
}

int main(void)
{
    if (scanf("%d", &db_count) != 1 || db_count < 0 || db_count > MAX_DTC) return 0;
    for (int i = 0; i < db_count; i++) {
        unsigned dtc, st;
        if (scanf("%x %x", &dtc, &st) != 2) return 0;
        db[i].dtc = dtc;
        db[i].status = (uint8_t)st;
    }
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        unsigned m;
        if (scanf("%x", &m) != 1) return 0;
        report_dtc_by_status_mask((uint8_t)m);
    }
    return 0;
}
@@@ sample_input
4
C07300 09
050100 2C
A10012 50
D10087 24
2
01
04
@@@ sample_output
59 02 2F C0 73 00 09
59 02 2F 05 01 00 2C D1 00 87 24

@@@ sample_input
2
C07300 89
D10087 01
1
FF
@@@ sample_output
59 02 2F C0 73 00 09 D1 00 87 01

@@@ hidden_input
4
C07300 09
050100 2C
A10012 50
D10087 24
1
08
@@@ hidden_output
59 02 2F C0 73 00 09 05 01 00 2C

@@@ hidden_input
4
C07300 09
050100 2C
A10012 50
D10087 24
1
FF
@@@ hidden_output
59 02 2F C0 73 00 09 05 01 00 2C D1 00 87 24

@@@ hidden_input
4
C07300 09
050100 2C
A10012 50
D10087 24
2
00
50
@@@ hidden_output
59 02 2F
59 02 2F

@@@ hidden_input
0
1
FF
@@@ hidden_output
59 02 2F

@@@ hidden_input
3
000001 FF
000002 00
FFFFFF 20
2
20
02
@@@ hidden_output
59 02 2F 00 00 01 2F FF FF FF 20
59 02 2F 00 00 01 2F

@@@ hidden_input
4
C07300 09
050100 2C
A10012 50
D10087 24
1
09
@@@ hidden_output
59 02 2F C0 73 00 09 05 01 00 2C

@@@ hint
Requests with mask `01` work, and mask `08` loses exactly the DTCs whose `TF` bit is clear. Print `effective_mask` for request `08`. Is it what you expect?
@@@ hint
`&&` is a **logical** operator: it yields 0 or 1. `req_mask && 0x2F` is 1 for any non-zero request, so only bit 0 (`testFailed`) is ever tested. Combining two masks needs the **bitwise** `&`.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

typedef enum {
    DTC_TF = 0x01, DTC_TFTOC = 0x02, DTC_PDTC = 0x04, DTC_CDTC = 0x08,
    DTC_TNCSLC = 0x10, DTC_TFSLC = 0x20, DTC_TNCTOC = 0x40, DTC_WIR = 0x80
} DtcStatusBit;

#define DTC_AVAILABILITY_MASK (DTC_TF | DTC_TFTOC | DTC_PDTC | DTC_CDTC | DTC_TFSLC)

#define MAX_DTC 100

struct DtcRecord {
    uint32_t dtc;       /* 3-byte DTC number */
    uint8_t  status;
};

static struct DtcRecord db[MAX_DTC];
static int db_count;

static void report_dtc_by_status_mask(uint8_t req_mask)
{
    uint8_t effective_mask = req_mask & DTC_AVAILABILITY_MASK;   /* FIX: bitwise &, not logical && */

    printf("59 02 %02X", (unsigned)DTC_AVAILABILITY_MASK);
    for (int i = 0; i < db_count; i++) {
        if (db[i].status & effective_mask) {
            printf(" %02X %02X %02X %02X",
                   (unsigned)(db[i].dtc >> 16) & 0xFFu,
                   (unsigned)(db[i].dtc >> 8) & 0xFFu,
                   (unsigned)db[i].dtc & 0xFFu,
                   (unsigned)(db[i].status & DTC_AVAILABILITY_MASK));
        }
    }
    printf("\n");
}

int main(void)
{
    if (scanf("%d", &db_count) != 1 || db_count < 0 || db_count > MAX_DTC) return 0;
    for (int i = 0; i < db_count; i++) {
        unsigned dtc, st;
        if (scanf("%x %x", &dtc, &st) != 2) return 0;
        db[i].dtc = dtc;
        db[i].status = (uint8_t)st;
    }
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        unsigned m;
        if (scanf("%x", &m) != 1) return 0;
        report_dtc_by_status_mask((uint8_t)m);
    }
    return 0;
}
@@@ explanation_md
**Bug.** `req_mask && DTC_AVAILABILITY_MASK` is a *logical* AND. It evaluates to `1` when both operands are non-zero, and to `0` otherwise. For every non-zero request, `effective_mask` becomes `0x01`, so only the `testFailed` bit is ever compared:
- `19 02 01` works by coincidence, which is why the bug survived testing;
- `19 02 08` returns only confirmed DTCs that *also* currently fail. A confirmed DTC whose test passed in this cycle (status `0x2C`) is missing, although it keeps the MIL on;
- `19 02 50` (unsupported bits only) wrongly returns every failing DTC instead of nothing.

gcc's `-Wall -Wextra` does not warn about this line. Clang does (`-Wconstant-logical-operand`: "use of logical '&&' with constant operand").

**Fix.** Use the bitwise `&`: `effective_mask = req_mask & DTC_AVAILABILITY_MASK;`.

**Complexity.** Time O(n) per request, space O(n) for the database.

**Common mistakes**
- Mixing up `&&`/`&` and `||`/`|` with flag enums. The logical operators collapse a mask into a single truth value.
- Reporting the raw status instead of `status & availability` (the tester would see `0x89` with an unsupported `WIR` bit).
- Filtering with the raw request mask, `status & req_mask`. Bits the ECU does not support (for example `TNCTOC`) would then select DTCs.
- Testing "all requested bits" (`(status & m) == m`) when the service means "any requested bit".

**Interview follow-ups**
- How would you produce the response for 3000 DTCs when the CAN-TP buffer is only 4095 bytes? (Segmented transmission and paged buffers, or `NRC 0x14` responseTooLong.)
- Why does `19 01` (number of DTCs by status mask) exist when the tester could count the entries of `19 02`?
- Which static-analysis rule would have flagged this line? (MISRA C:2012 Rule 10.1: the operand of a logical operator must be essentially Boolean.)
