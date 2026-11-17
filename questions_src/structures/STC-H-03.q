@@@ meta
id: STC-H-03
topic: Structures
difficulty: Hard
type: FUNCTION
title: CAN Controller Register Map Overlay (TX/RX Mailboxes)
tags: embedded, register-map, volatile, can-bus, bsp, bit-manipulation, asked-in-automotive
@@@ statement_md
You are writing the low-level driver for a bxCAN-style CAN controller. Its registers are memory-mapped from the base address:

| offset | register(s) | notes |
|---|---|---|
| `0x000` | `MCR`, `MSR`, `TSR`, `RF0R`, `RF1R`, `IER`, `ESR`, `BTR` | 8 consecutive 32-bit registers |
| `0x020 - 0x17F` | reserved | |
| `0x180` | `sTxMailBox[3]` | each mailbox: `TIR`, `TDTR`, `TDLR`, `TDHR` (16 bytes) |
| `0x1B0` | `sFIFOMailBox[2]` | each mailbox: `RIR`, `RDTR`, `RDLR`, `RDHR` (16 bytes) |
| `0x1D0 - 0x1FF` | reserved | |
| `0x200` | `FMR` | last register, so `sizeof == 0x204` |

**Part 1.** Define `CANX_TxMailBox`, `CANX_FIFOMailBox` and `CANX_TypeDef` (use exactly these type and member names, all registers `volatile uint32_t`) so that a `CANX_TypeDef *` can be overlaid on the base address. The harness checks every offset and prints `LAYOUT OK` or the first wrong register.

**Bit definitions**
- `TSR`: `TME0..TME2` = bits 26..28. 1 means TX mailbox k is empty.
- `TIR` / `RIR`: standard ID in bits 31:21; extended (29-bit) ID in bits 31:3; `IDE` = bit 2 (1 = extended); `RTR` = bit 1; `TXRQ` = bit 0 (TIR only; RIR bit 0 reads 0). For a **received** standard frame, bits 20:3 contain junk.
- `TDTR` / `RDTR`: `DLC` = bits 3:0. In `RDTR`, bits 15:8 (filter index) and 31:16 (timestamp) are also set.
- `TDLR` / `RDLR`: data bytes 0..3 (byte 0 in bits 7:0). `TDHR` / `RDHR`: data bytes 4..7.
- `RF0R` / `RF1R`: `FMP` = bits 1:0 (number of pending frames, 0..3); `RFOM` = bit 5 (write 1 to release the oldest frame).

**Part 2.** Implement, with the frame struct defined by the judge:

```c
struct CanFrame { uint32_t id; uint8_t ide; uint8_t rtr; uint8_t dlc; uint8_t data[8]; };

int canx_transmit(CANX_TypeDef *can, const struct CanFrame *f);
int canx_receive(CANX_TypeDef *can, int fifo, struct CanFrame *out);
```

`canx_transmit`:
1. Return `-2` (no register touched) if the frame is invalid: standard ID > `0x7FF`, extended ID > `0x1FFFFFFF`, or `dlc > 8`.
2. Pick the **lowest** k whose `TMEk` bit is 1. If there is none, return `-1` (no register touched).
3. Write `TDTR = dlc` and `TDLR`/`TDHR` with the data. Bytes at index >= `dlc`, and all bytes of a remote (RTR) frame, are written as 0.
4. Write `TIR` **last**: ID field | `IDE` | `RTR` | `TXRQ`. Return k.

`canx_receive`:
1. If `FMP` of the selected FIFO (0 or 1) is 0, return 0 and touch nothing.
2. Decode the FIFO mailbox into `*out`: `ide`, `id`, `rtr`, `dlc` (mask it!) and `data[0..7]`. Bytes at index >= `dlc`, and all bytes of a remote frame, must be 0.
3. Release the frame by setting `RFOM` in `RF0R`/`RF1R`, then return 1.

**How it is tested.** The harness owns a `static CANX_TypeDef` and simulates the hardware. At reset `TSR = 0x1C000000`. When `TXRQ` is set, it clears `TMEk`. It queues up to 3 RX frames per FIFO, and it pops one when `RFOM` is set.

**Input**: one command per line. Frames are written `S|E <id hex> D|R <dlc> <bytes>`, with `dlc` hex bytes only for data frames with `dlc <= 8`.
- `TX <frame>` prints `TX mb=<k> TIR=%08X TDTR=%08X TDLR=%08X TDHR=%08X`, `TX FULL` or `TX INVALID`.
- `DONE <k>`: mailbox k finished sending (TME set, TXRQ cleared). Prints `DONE k`.
- `RXQ <fifo> <frame>`: a frame arrives. Prints `RXQ f fmp=<n>` or `RXQ f OVERRUN`.
- `RX <fifo>` prints `RX f: S|E <ID> D|R [<dlc>] <bytes>` (data frames print `dlc` bytes) or `RX f: EMPTY`. ` DIRTY` is appended if a byte that must be 0 is not.

**Example**
```
Input:
TX S 123 D 3 11 22 33
TX E 18DAF110 D 8 02 10 03 00 00 00 00 00
TX S 7DF R 2
TX S 100 D 0
DONE 1
TX S 100 D 0

Output:
LAYOUT OK
TX mb=0 TIR=24600001 TDTR=00000003 TDLR=00332211 TDHR=00000000
TX mb=1 TIR=C6D78885 TDTR=00000008 TDLR=00031002 TDHR=00000000
TX mb=2 TIR=FBE00003 TDTR=00000002 TDLR=00000000 TDHR=00000000
TX FULL
DONE 1
TX mb=1 TIR=20000001 TDTR=00000000 TDLR=00000000 TDHR=00000000
```
@@@ constraints_md
- At most 100 commands; `fifo` is 0 or 1; `k` is 0..2.
- Use only the register struct. No magic addresses or byte offsets in your functions.
- Received frames always have `dlc <= 8`.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>

typedef struct {
    volatile uint32_t TIR;
    volatile uint32_t TDTR;
    volatile uint32_t TDLR;
    volatile uint32_t TDHR;
} CANX_TxMailBox;

typedef struct {
    volatile uint32_t RIR;
    volatile uint32_t RDTR;
    volatile uint32_t RDLR;
    volatile uint32_t RDHR;
} CANX_FIFOMailBox;

typedef struct {
    volatile uint32_t MCR;
    volatile uint32_t MSR;
    volatile uint32_t TSR;
    volatile uint32_t RF0R;
    volatile uint32_t RF1R;
    volatile uint32_t IER;
    volatile uint32_t ESR;
    volatile uint32_t BTR;
    /* TODO: reserved gap 0x020 - 0x17F */
    CANX_TxMailBox    sTxMailBox[3];
    CANX_FIFOMailBox  sFIFOMailBox[2];
    /* TODO: reserved gap 0x1D0 - 0x1FF */
    volatile uint32_t FMR;
} CANX_TypeDef;

/* Already defined by the judge:
 * struct CanFrame { uint32_t id; uint8_t ide; uint8_t rtr; uint8_t dlc; uint8_t data[8]; };
 */

int canx_transmit(CANX_TypeDef *can, const struct CanFrame *f)
{
    /* TODO */
    (void)can;
    (void)f;
    return -1;
}

int canx_receive(CANX_TypeDef *can, int fifo, struct CanFrame *out)
{
    /* TODO */
    (void)can;
    (void)fifo;
    (void)out;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct CanFrame {
    uint32_t id;
    uint8_t  ide;
    uint8_t  rtr;
    uint8_t  dlc;
    uint8_t  data[8];
};

/*USER_CODE*/

static CANX_TypeDef g_can;

#define OFF(m) ((size_t)((const volatile char *)&g_can.m - (const volatile char *)&g_can))

static int check_layout(void)
{
    const struct { const char *name; size_t got, want; } t[] = {
        { "MCR", OFF(MCR), 0x000 }, { "MSR", OFF(MSR), 0x004 }, { "TSR", OFF(TSR), 0x008 },
        { "RF0R", OFF(RF0R), 0x00C }, { "RF1R", OFF(RF1R), 0x010 }, { "IER", OFF(IER), 0x014 },
        { "ESR", OFF(ESR), 0x018 }, { "BTR", OFF(BTR), 0x01C },
        { "sTxMailBox[0].TIR", OFF(sTxMailBox[0].TIR), 0x180 },
        { "sTxMailBox[0].TDTR", OFF(sTxMailBox[0].TDTR), 0x184 },
        { "sTxMailBox[1].TDLR", OFF(sTxMailBox[1].TDLR), 0x198 },
        { "sTxMailBox[2].TDHR", OFF(sTxMailBox[2].TDHR), 0x1AC },
        { "sFIFOMailBox[0].RIR", OFF(sFIFOMailBox[0].RIR), 0x1B0 },
        { "sFIFOMailBox[0].RDTR", OFF(sFIFOMailBox[0].RDTR), 0x1B4 },
        { "sFIFOMailBox[1].RDLR", OFF(sFIFOMailBox[1].RDLR), 0x1C8 },
        { "sFIFOMailBox[1].RDHR", OFF(sFIFOMailBox[1].RDHR), 0x1CC },
        { "FMR", OFF(FMR), 0x200 },
        { "sizeof(CANX_TypeDef)", sizeof(CANX_TypeDef), 0x204 },
    };
    for (size_t i = 0; i < sizeof t / sizeof t[0]; i++) {
        if (t[i].got != t[i].want) {
            printf("LAYOUT BAD: %s at 0x%03X, expected 0x%03X\n", t[i].name, (unsigned)t[i].got, (unsigned)t[i].want);
            return 0;
        }
    }
    printf("LAYOUT OK\n");
    return 1;
}

/* ---- hardware model of the RX FIFOs ---- */
static struct CanFrame hwq[2][3];
static int hwn[2];
static unsigned rx_seq;

static volatile uint32_t *rfr(int f) { return f ? &g_can.RF1R : &g_can.RF0R; }

static void hw_load(int f)
{
    *rfr(f) = (*rfr(f) & ~3u) | (uint32_t)hwn[f];
    if (hwn[f] == 0) return;                       /* mailbox keeps stale content */
    const struct CanFrame *fr = &hwq[f][0];
    uint32_t rir = fr->ide ? (fr->id << 3) | 4u : (fr->id << 21) | (0x15A5Au << 3);
    rir |= (uint32_t)fr->rtr << 1;
    uint8_t b[8];
    for (int i = 0; i < 8; i++) b[i] = (!fr->rtr && i < fr->dlc) ? fr->data[i] : 0xEE;
    g_can.sFIFOMailBox[f].RIR = rir;
    g_can.sFIFOMailBox[f].RDTR = (uint32_t)fr->dlc | ((3u + (uint32_t)f) << 8) |
                                 (((0x1234u + rx_seq * 0x111u) & 0xFFFFu) << 16);
    g_can.sFIFOMailBox[f].RDLR = (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16 | (uint32_t)b[3] << 24;
    g_can.sFIFOMailBox[f].RDHR = (uint32_t)b[4] | (uint32_t)b[5] << 8 | (uint32_t)b[6] << 16 | (uint32_t)b[7] << 24;
    rx_seq++;
}

static int read_frame(struct CanFrame *f)
{
    char fmt[4], kind[4];
    unsigned id;
    int dlc;
    memset(f, 0, sizeof *f);
    if (scanf("%3s %x %3s %d", fmt, &id, kind, &dlc) != 4) return 0;
    f->ide = (uint8_t)(fmt[0] == 'E');
    f->id = (uint32_t)id;
    f->rtr = (uint8_t)(kind[0] == 'R');
    f->dlc = (uint8_t)dlc;
    if (!f->rtr && dlc <= 8)
        for (int i = 0; i < dlc; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            f->data[i] = (uint8_t)b;
        }
    return 1;
}

static void print_frame(const struct CanFrame *f)
{
    if (f->ide) printf("E %08X", (unsigned)f->id);
    else printf("S %03X", (unsigned)f->id);
    printf(" %c [%u]", f->rtr ? 'R' : 'D', (unsigned)f->dlc);
    int dirty = 0;
    for (int i = 0; i < 8; i++) {
        int used = !f->rtr && i < f->dlc;
        if (used) printf(" %02X", (unsigned)f->data[i]);
        else if (f->data[i] != 0) dirty = 1;
    }
    printf("%s\n", dirty ? " DIRTY" : "");
}

int main(void)
{
    char cmd[8];
    if (!check_layout()) return 0;
    g_can.TSR = 0x1C000000u;
    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "TX") == 0) {
            struct CanFrame f;
            uint32_t before[12], after[12];
            if (!read_frame(&f)) break;
            for (int k = 0; k < 3; k++) {
                before[4 * k] = g_can.sTxMailBox[k].TIR;  before[4 * k + 1] = g_can.sTxMailBox[k].TDTR;
                before[4 * k + 2] = g_can.sTxMailBox[k].TDLR; before[4 * k + 3] = g_can.sTxMailBox[k].TDHR;
            }
            int r = canx_transmit(&g_can, &f);
            if (r >= 0 && r <= 2) {
                CANX_TxMailBox *mb = &g_can.sTxMailBox[r];
                printf("TX mb=%d TIR=%08X TDTR=%08X TDLR=%08X TDHR=%08X%s\n", r, (unsigned)mb->TIR,
                       (unsigned)mb->TDTR, (unsigned)mb->TDLR, (unsigned)mb->TDHR,
                       (mb->TIR & 1u) ? "" : " (TXRQ not set)");
                if (mb->TIR & 1u) g_can.TSR &= ~(1u << (26 + r));
            } else {
                for (int k = 0; k < 3; k++) {
                    after[4 * k] = g_can.sTxMailBox[k].TIR;  after[4 * k + 1] = g_can.sTxMailBox[k].TDTR;
                    after[4 * k + 2] = g_can.sTxMailBox[k].TDLR; after[4 * k + 3] = g_can.sTxMailBox[k].TDHR;
                }
                printf("TX %s%s\n", r == -1 ? "FULL" : r == -2 ? "INVALID" : "BAD RETURN",
                       memcmp(before, after, sizeof before) ? " (mailbox modified!)" : "");
            }
        } else if (strcmp(cmd, "DONE") == 0) {
            int k;
            if (scanf("%d", &k) != 1 || k < 0 || k > 2) break;
            g_can.TSR |= 1u << (26 + k);
            g_can.sTxMailBox[k].TIR &= ~1u;
            printf("DONE %d\n", k);
        } else if (strcmp(cmd, "RXQ") == 0) {
            int fi;
            struct CanFrame f;
            if (scanf("%d", &fi) != 1 || fi < 0 || fi > 1 || !read_frame(&f)) break;
            if (hwn[fi] == 3) {
                printf("RXQ %d OVERRUN\n", fi);
                continue;
            }
            hwq[fi][hwn[fi]++] = f;
            if (hwn[fi] == 1) hw_load(fi);
            else *rfr(fi) = (*rfr(fi) & ~3u) | (uint32_t)hwn[fi];
            printf("RXQ %d fmp=%d\n", fi, hwn[fi]);
        } else if (strcmp(cmd, "RX") == 0) {
            int fi;
            struct CanFrame out;
            if (scanf("%d", &fi) != 1 || fi < 0 || fi > 1) break;
            memset(&out, 0xCC, sizeof out);
            int r = canx_receive(&g_can, fi, &out);
            printf("RX %d: ", fi);
            if (r == 1) print_frame(&out);
            else printf("EMPTY\n");
            if (*rfr(fi) & (1u << 5)) {                   /* hardware: RFOM releases the oldest frame */
                *rfr(fi) &= ~(1u << 5);
                if (hwn[fi] > 0) {
                    memmove(&hwq[fi][0], &hwq[fi][1], sizeof hwq[fi][0] * 2);
                    hwn[fi]--;
                    hw_load(fi);
                }
            }
        }
    }
    return 0;
}
@@@ sample_input
TX S 123 D 3 11 22 33
TX E 18DAF110 D 8 02 10 03 00 00 00 00 00
TX S 7DF R 2
TX S 100 D 0
DONE 1
TX S 100 D 0
@@@ sample_output
LAYOUT OK
TX mb=0 TIR=24600001 TDTR=00000003 TDLR=00332211 TDHR=00000000
TX mb=1 TIR=C6D78885 TDTR=00000008 TDLR=00031002 TDHR=00000000
TX mb=2 TIR=FBE00003 TDTR=00000002 TDLR=00000000 TDHR=00000000
TX FULL
DONE 1
TX mb=1 TIR=20000001 TDTR=00000000 TDLR=00000000 TDHR=00000000

@@@ sample_input
RX 0
RXQ 0 S 7E8 D 3 02 50 03
RXQ 0 E 18DAF1F1 R 0
RX 0
RX 0
RX 0
@@@ sample_output
LAYOUT OK
RX 0: EMPTY
RXQ 0 fmp=1
RXQ 0 fmp=2
RX 0: S 7E8 D [3] 02 50 03
RX 0: E 18DAF1F1 R [0]
RX 0: EMPTY

@@@ hidden_input
TX S 800 D 0
TX E 20000000 D 1 AA
TX S 7FF D 9
TX E 1FFFFFFF D 8 FF FE FD FC FB FA F9 F8
TX S 000 D 8 01 02 03 04 05 06 07 08
TX E 00000000 R 8
TX S 7FF D 1 A5
@@@ hidden_output
LAYOUT OK
TX INVALID
TX INVALID
TX INVALID
TX mb=0 TIR=FFFFFFFD TDTR=00000008 TDLR=FCFDFEFF TDHR=F8F9FAFB
TX mb=1 TIR=00000001 TDTR=00000008 TDLR=04030201 TDHR=08070605
TX mb=2 TIR=00000007 TDTR=00000008 TDLR=00000000 TDHR=00000000
TX FULL

@@@ hidden_input
RXQ 1 S 100 D 1 01
RXQ 1 S 101 D 2 01 02
RXQ 1 S 102 D 3 01 02 03
RXQ 1 S 103 D 4 01 02 03 04
RX 0
RX 1
RX 1
RX 1
RX 1
@@@ hidden_output
LAYOUT OK
RXQ 1 fmp=1
RXQ 1 fmp=2
RXQ 1 fmp=3
RXQ 1 OVERRUN
RX 0: EMPTY
RX 1: S 100 D [1] 01
RX 1: S 101 D [2] 01 02
RX 1: S 102 D [3] 01 02 03
RX 1: EMPTY

@@@ hidden_input
RXQ 0 S 7FF D 8 11 22 33 44 55 66 77 88
RXQ 0 S 000 R 8
RXQ 0 E 1FFFFFFF D 0
RX 0
RX 0
RX 0
RXQ 1 S 3A5 D 5 DE AD BE EF 01
RX 1
@@@ hidden_output
LAYOUT OK
RXQ 0 fmp=1
RXQ 0 fmp=2
RXQ 0 fmp=3
RX 0: S 7FF D [8] 11 22 33 44 55 66 77 88
RX 0: S 000 R [8]
RX 0: E 1FFFFFFF D [0]
RXQ 1 fmp=1
RX 1: S 3A5 D [5] DE AD BE EF 01

@@@ hidden_input
TX S 001 D 1 01
TX S 002 D 1 02
TX S 003 D 1 03
DONE 2
TX S 004 D 1 04
DONE 0
DONE 2
TX E 1ABCDEF0 D 2 BE EF
TX S 005 D 0
TX S 006 D 0
@@@ hidden_output
LAYOUT OK
TX mb=0 TIR=00200001 TDTR=00000001 TDLR=00000001 TDHR=00000000
TX mb=1 TIR=00400001 TDTR=00000001 TDLR=00000002 TDHR=00000000
TX mb=2 TIR=00600001 TDTR=00000001 TDLR=00000003 TDHR=00000000
DONE 2
TX mb=2 TIR=00800001 TDTR=00000001 TDLR=00000004 TDHR=00000000
DONE 0
DONE 2
TX mb=0 TIR=D5E6F785 TDTR=00000002 TDLR=0000EFBE TDHR=00000000
TX mb=2 TIR=00A00001 TDTR=00000000 TDLR=00000000 TDHR=00000000
TX FULL

@@@ hidden_input
TX S 7E0 D 8 02 10 03 00 00 00 00 00
RXQ 0 S 7E8 D 8 06 50 03 00 32 01 F4 AA
RXQ 1 E 18DAF110 D 4 03 7F 22 31
RX 1
RX 0
DONE 0
TX S 7E0 D 3 02 3E 00
RX 0
RX 1
@@@ hidden_output
LAYOUT OK
TX mb=0 TIR=FC000001 TDTR=00000008 TDLR=00031002 TDHR=00000000
RXQ 0 fmp=1
RXQ 1 fmp=1
RX 1: E 18DAF110 D [4] 03 7F 22 31
RX 0: S 7E8 D [8] 06 50 03 00 32 01 F4 AA
DONE 0
TX mb=0 TIR=FC000001 TDTR=00000003 TDLR=00003E02 TDHR=00000000
RX 0: EMPTY
RX 1: EMPTY

@@@ hint
Count words: `0x020..0x17F` is `0x160` bytes, which is `uint32_t RESERVED0[88]`. `0x1D0..0x1FF` is `0x30` bytes, which is `RESERVED1[12]`. Two 16-byte mailbox types, and arrays of them, give you `sTxMailBox[k].TIR` with no address arithmetic.
@@@ hint
Transmit: `id << 21` (standard) or `id << 3 | 4` (extended), then `| rtr << 1 | 1`, written last. Receive: read `RIR` once into a local, `ide = (rir >> 2) & 1`, `id = ide ? rir >> 3 : rir >> 21`, `dlc = RDTR & 0xF`, unpack the bytes with shifts and zero the unused ones, then `RFxR |= 1u << 5`.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>

typedef struct {
    volatile uint32_t TIR;           /* +0x0 */
    volatile uint32_t TDTR;          /* +0x4 */
    volatile uint32_t TDLR;          /* +0x8 */
    volatile uint32_t TDHR;          /* +0xC */
} CANX_TxMailBox;

typedef struct {
    volatile uint32_t RIR;
    volatile uint32_t RDTR;
    volatile uint32_t RDLR;
    volatile uint32_t RDHR;
} CANX_FIFOMailBox;

typedef struct {
    volatile uint32_t MCR;           /* 0x000 */
    volatile uint32_t MSR;           /* 0x004 */
    volatile uint32_t TSR;           /* 0x008 */
    volatile uint32_t RF0R;          /* 0x00C */
    volatile uint32_t RF1R;          /* 0x010 */
    volatile uint32_t IER;           /* 0x014 */
    volatile uint32_t ESR;           /* 0x018 */
    volatile uint32_t BTR;           /* 0x01C */
    uint32_t          RESERVED0[88]; /* 0x020 - 0x17F: 0x160 / 4 = 88 words */
    CANX_TxMailBox    sTxMailBox[3]; /* 0x180 - 0x1AF */
    CANX_FIFOMailBox  sFIFOMailBox[2]; /* 0x1B0 - 0x1CF */
    uint32_t          RESERVED1[12]; /* 0x1D0 - 0x1FF: 0x30 / 4 = 12 words */
    volatile uint32_t FMR;           /* 0x200 */
} CANX_TypeDef;

#define CAN_TSR_TME0     (1u << 26)
#define CAN_TIR_TXRQ     (1u << 0)
#define CAN_TIR_RTR      (1u << 1)
#define CAN_TIR_IDE      (1u << 2)
#define CAN_RFR_FMP_Msk  0x3u
#define CAN_RFR_RFOM     (1u << 5)
#define CAN_DTR_DLC_Msk  0xFu

int canx_transmit(CANX_TypeDef *can, const struct CanFrame *f)
{
    if (f->dlc > 8 || f->id > (f->ide ? 0x1FFFFFFFu : 0x7FFu))
        return -2;

    uint32_t tsr = can->TSR;                         /* one volatile read */
    int k = -1;
    for (int i = 0; i < 3; i++)
        if (tsr & (CAN_TSR_TME0 << i)) { k = i; break; }
    if (k < 0)
        return -1;

    uint8_t b[8] = { 0 };
    if (!f->rtr)
        for (int i = 0; i < f->dlc; i++) b[i] = f->data[i];

    CANX_TxMailBox *mb = &can->sTxMailBox[k];
    mb->TDTR = f->dlc;
    mb->TDLR = (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16 | (uint32_t)b[3] << 24;
    mb->TDHR = (uint32_t)b[4] | (uint32_t)b[5] << 8 | (uint32_t)b[6] << 16 | (uint32_t)b[7] << 24;

    uint32_t tir = f->ide ? (f->id << 3) | CAN_TIR_IDE : f->id << 21;
    if (f->rtr) tir |= CAN_TIR_RTR;
    mb->TIR = tir | CAN_TIR_TXRQ;                    /* last: this starts the transmission */
    return k;
}

int canx_receive(CANX_TypeDef *can, int fifo, struct CanFrame *out)
{
    volatile uint32_t *rfr = fifo ? &can->RF1R : &can->RF0R;
    if ((*rfr & CAN_RFR_FMP_Msk) == 0)
        return 0;

    const CANX_FIFOMailBox *mb = &can->sFIFOMailBox[fifo];
    uint32_t rir = mb->RIR;
    uint32_t lo = mb->RDLR, hi = mb->RDHR;

    out->ide = (uint8_t)((rir & CAN_TIR_IDE) ? 1 : 0);
    out->rtr = (uint8_t)((rir & CAN_TIR_RTR) ? 1 : 0);
    out->id = out->ide ? rir >> 3 : rir >> 21;       /* std: ignore junk in bits 20:3 */
    out->dlc = (uint8_t)(mb->RDTR & CAN_DTR_DLC_Msk); /* ignore FMI and timestamp */
    for (int i = 0; i < 8; i++) {
        uint8_t v = (uint8_t)((i < 4 ? lo >> (8 * i) : hi >> (8 * (i - 4))) & 0xFFu);
        out->data[i] = (!out->rtr && i < out->dlc) ? v : 0;
    }
    *rfr |= CAN_RFR_RFOM;                            /* release the output mailbox */
    return 1;
}
@@@ explanation_md
**Approach.**
1. **Register overlay.** Describe the peripheral as a struct whose members fall exactly on the datasheet offsets. Pad the gaps with `uint32_t RESERVEDn[count]`, where count = gap bytes / 4. Repeated blocks become arrays of sub-structs (`sTxMailBox[3]`), so driver code reads `can->sTxMailBox[k].TIR` instead of `*(volatile uint32_t *)(base + 0x180 + 16*k)`. This is exactly how CMSIS device headers are written. Every hardware register is `volatile`, because each access must really happen, in program order.
2. **Transmit.** Validate first, without touching the hardware. Find a free mailbox from one snapshot of `TSR`. Fill DLC and data, and write `TIR` **last**, because setting `TXRQ` hands the mailbox to the hardware.
3. **Receive.** Check `FMP`, read the mailbox, and **mask** every field: `DLC` shares `RDTR` with the filter index and the timestamp, and a standard ID must be taken from bits 31:21 only. Release with `RFOM`, or the FIFO never advances and the next read returns the same frame.

```
std 0x123:   0x123 << 21           = 0x24600000, | TXRQ          -> 0x24600001
ext 18DAF110: 0x18DAF110 << 3 | IDE = 0xC6D78884, | TXRQ          -> 0xC6D78885
data 11 22 33 -> TDLR = 0x00332211 (byte 0 in the low bits)
```

**Complexity.** O(1) per call: at most 3 mailbox checks and 8 bytes.

**Common mistakes**
- Wrong reserved sizes: `RESERVED0[0x160]` (bytes instead of words), or forgetting the gap before `FMR`.
- Writing `TIR` (with `TXRQ`) **before** the data registers. Real hardware may start sending stale data.
- `out->dlc = RDTR`, which picks up the timestamp. `out->id = (rir >> 3) & 0x7FF` for standard frames, which reads the junk bits.
- Forgetting `RFOM`, so the FIFO overruns after three frames.
- Read-modify-write on `TSR` (e.g. `TSR &= ~TME`). In real silicon many status bits are *rc_w1* (write 1 to clear), and an RMW can clear flags you did not intend to touch.

**Interview follow-ups**
- How do you place this struct at the real address? (`#define CAN1 ((CANX_TypeDef *)0x40006400u)`, or a linker-script section.)
- Why must the reserved arrays not be `volatile`, and what happens if someone `memset`s the whole struct?
- How do you stop the compiler from reordering the `TDTR`/`TDLR` writes after `TIR` on a core with a write buffer? (`volatile` orders them for the compiler; you may still need a `DSB` or a device-memory attribute.)
- Add `_Static_assert(offsetof(CANX_TypeDef, FMR) == 0x200, "...")`. Why is it better than a runtime check?
