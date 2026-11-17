@@@ meta
id: ENM-H-03
topic: Enums
difficulty: Hard
type: FUNCTION
title: DTC Status Byte Update With Confirmation and Aging
tags: embedded, dtc, uds, iso-14229, bit-flags, diagnostics, asked-in-automotive
@@@ statement_md
Every diagnostic trouble code (DTC) in an ECU carries a **status byte** (ISO 14229-1, D.2). Each bit is a flag. The judge defines the flag enum, the event enum and the DTC record, so do not redefine them:

```c
typedef enum {
    DTC_TF     = 0x01,  /* testFailed                          */
    DTC_TFTOC  = 0x02,  /* testFailedThisOperationCycle        */
    DTC_PDTC   = 0x04,  /* pendingDTC                          */
    DTC_CDTC   = 0x08,  /* confirmedDTC                        */
    DTC_TNCSLC = 0x10,  /* testNotCompletedSinceLastClear      */
    DTC_TFSLC  = 0x20,  /* testFailedSinceLastClear            */
    DTC_TNCTOC = 0x40,  /* testNotCompletedThisOperationCycle  */
    DTC_WIR    = 0x80   /* warningIndicatorRequested           */
} DtcStatusBit;

typedef enum { DTC_EV_PASS, DTC_EV_FAIL, DTC_EV_CYCLE, DTC_EV_CLEAR, DTC_EV_COUNT } DtcEvent;

#define DTC_CONFIRM_CYCLES 2   /* failing operation cycles needed to confirm */
#define DTC_AGING_CYCLES   3   /* consecutive clean cycles to age out        */

typedef struct {
    uint8_t status;
    uint8_t fail_cycles;   /* operation cycles with >= 1 failure, since clear / aging       */
    uint8_t clean_cycles;  /* consecutive clean cycles while confirmed                       */
} Dtc;
```

Implement `void dtc_event(Dtc *d, int ev);` with these rules (our ECU's simplified profile):

- **`CLEAR`** (`ClearDiagnosticInformation`): `status = TNCSLC | TNCTOC`, and both counters become 0.
- **`FAIL`** (the monitor reports a failed test):
  - if `TFTOC` was **not** set yet (first failure in this cycle), `fail_cycles += 1`;
  - set `TF`, `TFTOC`, `PDTC`, `TFSLC`; clear `TNCTOC`, `TNCSLC`; `clean_cycles = 0`;
  - if `fail_cycles >= DTC_CONFIRM_CYCLES`, set `CDTC` and `WIR`.
- **`PASS`** (the monitor reports a passed test): clear `TF`, `TNCTOC`, `TNCSLC`. Nothing else changes.
- **`CYCLE`** (the current operation cycle ends and a new one starts):
  - If the ending cycle was **clean**, meaning a test completed (`TNCTOC` clear) and no failure (`TFTOC` clear): clear `PDTC`. If `CDTC` is set, `clean_cycles += 1`; when it reaches `DTC_AGING_CYCLES` the DTC **ages out**: clear `CDTC` and `WIR`, and set both counters to 0.
  - Then start the new cycle: clear `TFTOC`, set `TNCTOC`.
- Any other `ev` value (including `DTC_EV_COUNT` and negative values) is ignored.

`TFSLC` is only reset by `CLEAR`.

**How it is tested.** The harness starts from `{ 0x50, 0, 0 }` (the state right after a clear) and applies events given as letters: `P`/`F`/`C`/`X` = pass/fail/cycle/clear, `Z` = raw value 4, `N` = raw value -1. After each event it prints the letter, the status in hex and the set flags in bit order (`-` if none).

**Example**
```
Input:
3
X P C

Output:
X 0x50 TNCSLC TNCTOC
P 0x00 -
C 0x40 TNCTOC
```
@@@ constraints_md
- `1 <= n <= 200` events.
- Only modify the bits the rules name. Use `|=` and `&= ~`, never assignments that wipe other flags (except `CLEAR`).
@@@ starter_code
/*
 * Provided by the judge (do not redefine): DtcStatusBit (DTC_TF .. DTC_WIR),
 * DtcEvent (DTC_EV_PASS, DTC_EV_FAIL, DTC_EV_CYCLE, DTC_EV_CLEAR, DTC_EV_COUNT),
 * DTC_CONFIRM_CYCLES, DTC_AGING_CYCLES and
 *   typedef struct { uint8_t status; uint8_t fail_cycles; uint8_t clean_cycles; } Dtc;
 */
#include <stdint.h>

void dtc_event(Dtc *d, int ev)
{
    /* TODO */
    (void)d;
    (void)ev;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

typedef enum {
    DTC_TF     = 0x01,
    DTC_TFTOC  = 0x02,
    DTC_PDTC   = 0x04,
    DTC_CDTC   = 0x08,
    DTC_TNCSLC = 0x10,
    DTC_TFSLC  = 0x20,
    DTC_TNCTOC = 0x40,
    DTC_WIR    = 0x80
} DtcStatusBit;

typedef enum { DTC_EV_PASS, DTC_EV_FAIL, DTC_EV_CYCLE, DTC_EV_CLEAR, DTC_EV_COUNT } DtcEvent;

#define DTC_CONFIRM_CYCLES 2
#define DTC_AGING_CYCLES   3

typedef struct {
    uint8_t status;
    uint8_t fail_cycles;
    uint8_t clean_cycles;
} Dtc;

/*USER_CODE*/

static const char *const h_bits[8] = { "TF", "TFTOC", "PDTC", "CDTC", "TNCSLC", "TFSLC", "TNCTOC", "WIR" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    Dtc d = { 0x50, 0, 0 };
    for (int i = 0; i < n; i++) {
        char c;
        if (scanf(" %c", &c) != 1) return 0;
        int ev = c == 'P' ? DTC_EV_PASS : c == 'F' ? DTC_EV_FAIL : c == 'C' ? DTC_EV_CYCLE
               : c == 'X' ? DTC_EV_CLEAR : c == 'Z' ? 4 : -1;
        dtc_event(&d, ev);
        printf("%c 0x%02X", c, (unsigned)d.status);
        if (d.status == 0) printf(" -");
        for (int b = 0; b < 8; b++)
            if (d.status & (1u << b)) printf(" %s", h_bits[b]);
        printf("\n");
    }
    return 0;
}
@@@ sample_input
3
X P C
@@@ sample_output
X 0x50 TNCSLC TNCTOC
P 0x00 -
C 0x40 TNCTOC

@@@ sample_input
10
F C F C P C P C P C
@@@ sample_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
P 0xAC PDTC CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0x60 TFSLC TNCTOC

@@@ hidden_input
4
F F F C
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
F 0x27 TF TFTOC PDTC TFSLC
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC

@@@ hidden_input
5
F C P C F
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
P 0x24 PDTC TFSLC
C 0x60 TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR

@@@ hidden_input
5
F P C P C
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
P 0x26 TFTOC PDTC TFSLC
C 0x64 PDTC TFSLC TNCTOC
P 0x24 PDTC TFSLC
C 0x60 TFSLC TNCTOC

@@@ hidden_input
3
Z N P
@@@ hidden_output
Z 0x50 TNCSLC TNCTOC
N 0x50 TNCSLC TNCTOC
P 0x00 -

@@@ hidden_input
4
F C F X
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
X 0x50 TNCSLC TNCTOC

@@@ hidden_input
16
F C F C P C P C F C P C P C P C
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
P 0xAC PDTC CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
P 0xAC PDTC CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0x60 TFSLC TNCTOC

@@@ hidden_input
7
F C F C C C C
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR

@@@ hidden_input
12
F C F C P C P C P C F C
@@@ hidden_output
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC
F 0xAF TF TFTOC PDTC CDTC TFSLC WIR
C 0xED TF PDTC CDTC TFSLC TNCTOC WIR
P 0xAC PDTC CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0xE8 CDTC TFSLC TNCTOC WIR
P 0xA8 CDTC TFSLC WIR
C 0x60 TFSLC TNCTOC
F 0x27 TF TFTOC PDTC TFSLC
C 0x65 TF PDTC TFSLC TNCTOC

@@@ hint
Write the four events as a `switch (ev)` with `default:` doing nothing. Set several flags at once with `d->status |= DTC_TF | DTC_TFTOC | ...` and clear with `d->status &= (uint8_t)~(DTC_TNCTOC | DTC_TNCSLC)`. Read `TFTOC` **before** you set it, since that is how you detect the first failure of the cycle.
@@@ hint
In `CYCLE`, evaluate the **ending** cycle first (clean = `!(status & (DTC_TNCTOC | DTC_TFTOC))`), and only then reset `TFTOC` and set `TNCTOC` for the new cycle. The opposite order makes every cycle look "not completed".
@@@ solution_code
#include <stdint.h>

static void set_bits(Dtc *d, unsigned m)   { d->status = (uint8_t)(d->status | m); }
static void clear_bits(Dtc *d, unsigned m) { d->status = (uint8_t)(d->status & ~m); }

void dtc_event(Dtc *d, int ev)
{
    switch (ev) {
    case DTC_EV_CLEAR:
        d->status = (uint8_t)(DTC_TNCSLC | DTC_TNCTOC);
        d->fail_cycles = 0;
        d->clean_cycles = 0;
        break;

    case DTC_EV_FAIL:
        if (!(d->status & DTC_TFTOC) && d->fail_cycles < UINT8_MAX)
            d->fail_cycles++;                       /* count each failing CYCLE once */
        set_bits(d, DTC_TF | DTC_TFTOC | DTC_PDTC | DTC_TFSLC);
        clear_bits(d, DTC_TNCTOC | DTC_TNCSLC);
        d->clean_cycles = 0;
        if (d->fail_cycles >= DTC_CONFIRM_CYCLES)
            set_bits(d, DTC_CDTC | DTC_WIR);
        break;

    case DTC_EV_PASS:
        clear_bits(d, DTC_TF | DTC_TNCTOC | DTC_TNCSLC);
        break;

    case DTC_EV_CYCLE:
        /* 1) evaluate the cycle that is ending */
        if (!(d->status & (DTC_TNCTOC | DTC_TFTOC))) {          /* tested and never failed */
            clear_bits(d, DTC_PDTC);
            if (d->status & DTC_CDTC) {
                if (++d->clean_cycles >= DTC_AGING_CYCLES) {    /* aged out */
                    clear_bits(d, DTC_CDTC | DTC_WIR);
                    d->fail_cycles = 0;
                    d->clean_cycles = 0;
                }
            }
        }
        /* 2) start the new cycle */
        clear_bits(d, DTC_TFTOC);
        set_bits(d, DTC_TNCTOC);
        break;

    default:                                        /* DTC_EV_COUNT, negative, garbage */
        break;
    }
}
@@@ explanation_md
**Approach.** The status byte is eight independent flags packed in one `uint8_t`, defined as a flag enum. Each event touches a specific subset of flags, so the implementation is a `switch` over events, where each case is a few `|=` / `&= ~` operations plus counter updates. Two ordering details carry most of the difficulty:
1. **First failure in a cycle.** `fail_cycles` counts *cycles*, not failures. Test `TFTOC` **before** setting it. Three `FAIL`s in one cycle are one failing cycle and do not confirm the DTC (hidden test `F F F C`).
2. **End of cycle.** Judge the *ending* cycle (`TNCTOC` and `TFTOC` both clear means tested and clean) **before** re-arming the flags for the new cycle. Only clean cycles clear `PDTC` and advance aging. A cycle in which the monitor never ran (`TNCTOC` still set) neither ages nor confirms (hidden test `F C F C C C C` stays confirmed).

`~mask` is computed in `int` (integer promotion), so the result is cast back to `uint8_t` explicitly. That avoids `-Wconversion` noise and documents the intent.

**Complexity.** Time O(1) per event, space O(1) per DTC (3 bytes).

**Common mistakes**
- Counting every `FAIL` instead of every failing cycle. The DTC then confirms within a single drive cycle, which causes false MIL lamps and warranty claims.
- Resetting `TFTOC` before evaluating the cycle. No cycle is ever clean, and aging never happens.
- `status = DTC_TF | ...` (assignment) instead of `|=`, which wipes `CDTC`/`TFSLC`.
- `status &= !DTC_TF` instead of `&= ~DTC_TF`. `!0x01` is 0, which clears **every** flag.
- Forgetting that `WIR` follows `CDTC` here (set together, aged out together), or clearing `TFSLC` on aging.

**Interview follow-ups**
- Why does ISO 14229 distinguish `pendingDTC` from `confirmedDTC`? Which one does a workshop tester see with `19 02 08`?
- The status bytes of 300 DTCs must survive power-off. When do you write them to NVM, and how do you protect the NVM's write endurance?
- How would you add a fault-detection counter (a debounce from -128 to +127) between the raw monitor result and `FAIL`/`PASS`, as AUTOSAR Dem does?
- What is the "DTCStatusAvailabilityMask", and why would an ECU not support `TNCSLC`?
