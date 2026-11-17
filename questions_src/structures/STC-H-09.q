@@@ meta
id: STC-H-09
topic: Structures
difficulty: Hard
type: FIND_THE_BUG
title: Freeze-Frame History Shares One Buffer (Shallow Struct Copy)
tags: embedded, shallow-copy, deep-copy, double-free, struct-assignment, diagnostics
@@@ statement_md
An ECU's diagnostic module keeps a **live** measurement frame. Whenever a DTC is confirmed it stores a **frozen snapshot** of that frame in a history ring with 3 entries, evicting the oldest one when full. A tester can dump the history.

```c
struct Frame {
    uint32_t dtc;
    uint16_t len;
    uint8_t *data;     /* heap buffer of FRAME_CAP bytes */
};
```

Commands:
- `SET n b1 .. bn`: overwrite the live frame's payload (`0 <= n <= 16`, hex bytes).
- `FREEZE dtc`: store a snapshot of the live frame tagged with `dtc` (4 hex digits). When 3 snapshots already exist, the oldest is destroyed first.
- `DUMP`: print the history from oldest to newest, one per line, as `P<dtc> [len] bytes`, or `(no history)`.

At exit, all snapshots and the live buffer are freed.

**Symptoms.** Snapshots "change" after they are taken: they show payload bytes that were `SET` later. The judge also reports a **double free** or **heap-use-after-free** whenever at least one snapshot was taken. Programs without `FREEZE` work.

Find and fix the bug with a minimal change. The output format must stay the same.

**Example**
```
Input:
SET 3 11 22 33
FREEZE 0301
SET 2 AA BB
FREEZE 0420
DUMP

Output:
P0301 [3] 11 22 33
P0420 [2] AA BB
```
@@@ constraints_md
- At most 300 commands. `dtc` is 4 hex digits; payload length 0..16.
- Every heap block must be freed exactly once, with no access after free.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define FRAME_CAP 16
#define HIST 3

struct Frame {
    uint32_t dtc;
    uint16_t len;
    uint8_t *data;
};

static struct Frame live;
static struct Frame *hist[HIST];
static int hcount;

static struct Frame *frame_clone(const struct Frame *src, uint32_t dtc)
{
    struct Frame *c = malloc(sizeof *c);
    if (c == NULL)
        return NULL;
    *c = *src;
    c->dtc = dtc;
    return c;
}

static void frame_destroy(struct Frame *f)
{
    if (f == NULL)
        return;
    free(f->data);
    free(f);
}

static void freeze(uint32_t dtc)
{
    struct Frame *snap = frame_clone(&live, dtc);
    if (snap == NULL)
        return;
    if (hcount == HIST) {                       /* ring full: drop the oldest */
        frame_destroy(hist[0]);
        memmove(&hist[0], &hist[1], (HIST - 1) * sizeof hist[0]);
        hcount--;
    }
    hist[hcount++] = snap;
}

static void dump(void)
{
    if (hcount == 0) {
        printf("(no history)\n");
        return;
    }
    for (int i = 0; i < hcount; i++) {
        struct Frame f = *hist[i];              /* local view for printing */
        printf("P%04X [%u]", (unsigned)f.dtc, (unsigned)f.len);
        for (unsigned k = 0; k < f.len; k++)
            printf(" %02X", (unsigned)f.data[k]);
        printf("\n");
    }
}

int main(void)
{
    char cmd[8];
    live.data = calloc(FRAME_CAP, 1);
    if (live.data == NULL)
        return 1;

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "SET") == 0) {
            unsigned n;
            if (scanf("%u", &n) != 1 || n > FRAME_CAP) break;
            for (unsigned i = 0; i < n; i++) {
                unsigned b;
                if (scanf("%x", &b) != 1) b = 0;
                live.data[i] = (uint8_t)b;
            }
            live.len = (uint16_t)n;
        } else if (strcmp(cmd, "FREEZE") == 0) {
            unsigned dtc;
            if (scanf("%x", &dtc) != 1) break;
            freeze(dtc);
        } else if (strcmp(cmd, "DUMP") == 0) {
            dump();
        }
    }

    for (int i = 0; i < hcount; i++)
        frame_destroy(hist[i]);
    free(live.data);
    return 0;
}
@@@ sample_input
SET 3 11 22 33
FREEZE 0301
SET 2 AA BB
FREEZE 0420
DUMP
@@@ sample_output
P0301 [3] 11 22 33
P0420 [2] AA BB

@@@ sample_input
SET 1 01
DUMP
@@@ sample_output
(no history)

@@@ hidden_input
SET 1 01
FREEZE 0001
SET 1 02
FREEZE 0002
SET 1 03
FREEZE 0003
SET 1 04
FREEZE 0004
SET 1 05
DUMP
@@@ hidden_output
P0002 [1] 02
P0003 [1] 03
P0004 [1] 04

@@@ hidden_input
FREEZE 0001
DUMP
@@@ hidden_output
P0001 [0]

@@@ hidden_input
SET 16 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
FREEZE FFFF
SET 0
DUMP
@@@ hidden_output
PFFFF [16] 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F

@@@ hidden_input
SET 4 DE AD BE EF
FREEZE 0118
@@@ hidden_output

@@@ hidden_input
SET 2 10 20
FREEZE 0A0A
FREEZE 0B0B
SET 3 30 40 50
FREEZE 0C0C
DUMP
SET 1 99
FREEZE 0D0D
DUMP
@@@ hidden_output
P0A0A [2] 10 20
P0B0B [2] 10 20
P0C0C [3] 30 40 50
P0B0B [2] 10 20
P0C0C [3] 30 40 50
P0D0D [1] 99

@@@ hidden_input
DUMP
SET 11 07 2C EC AC 6C 2C EC 48 D8 C3 6E
SET 9 15 49 13 47 6B BF 83 92 5A
DUMP
SET 7 68 78 E3 9A C2 CA 32
FREEZE A222
FREEZE 3C2D
FREEZE 08B0
FREEZE 24D0
DUMP
FREEZE 6F60
FREEZE 2300
FREEZE 229F
FREEZE 8DD7
FREEZE 37CF
FREEZE 1E87
SET 14 C3 37 36 64 C4 A4 04 E4 44 BF 83 92 90 80
FREEZE D520
SET 13 F0 60 10 00 CB D6 4E DC 12 DA 02 0A 72
SET 10 EA D2 9A C2 65 31 0D B9 90 80
DUMP
DUMP
SET 15 87 21 73 F8 C8 58 A8 B8 88 18 68 78 E3 D7 BB
DUMP
SET 7 AB FF C3 37 9B 2F 33
SET 3 5F A3 32
FREEZE 7022
FREEZE 60C8
SET 12 53 87 AB 9A C2 CA 32 7A 22 AA 2D 59
SET 9 3D C4 A4 04 E4 44 24 84 64
SET 6 9F E3 D7 56 CE E6
DUMP
FREEZE 7FED
DUMP
DUMP
FREEZE 1BFD
SET 7 C4 3F 39 47 6B BF 83
FREEZE D663
DUMP
SET 11 08 6A 52 1A 42 4A 4D F9 D0 C0 8B
SET 11 96 0E 26 F9 6B 6C 2C EC 48 D8 28
FREEZE CC3D
DUMP
FREEZE E102
FREEZE 3272
SET 1 E9
SET 10 0D 54 F4 14 4F 09 3B 21 3D 29
FREEZE 1D71
FREEZE C1F9
FREEZE A15C
FREEZE 3B5C
SET 0
FREEZE 9F5C
DUMP
DUMP
FREEZE 435C
SET 10 5C 5C 5C 5C F7 5B 8A F2 D5 E1
DUMP
DUMP
FREEZE 7314
DUMP
FREEZE C873
SET 11 CD 79 B5 41 DD 49 45 91 ED B4 D4
SET 0
FREEZE 8E0F
SET 10 EB 40 70 E0 90 80 B0 20 D0 C0
DUMP
FREEZE 37D8
FREEZE 8C38
SET 3 50 40 70
SET 8 1B E6 1E F6 EE 86 D9 95
SET 7 11 08 98 E8 F8 C8 F3
FREEZE 8F1B
SET 9 68 78 48 D8 28 38 08 98 E8
SET 6 58 A8 B8 23 18 68
FREEZE FB48
FREEZE A8C3
SET 6 9C 9C 37 9B 2F CE
SET 3 2B B6 AE
DUMP
FREEZE 3455
FREEZE 4D7D
DUMP
SET 6 BF 83 F7 F6 24 84
SET 8 A4 04 7F 43 52 1A 42 4A
FREEZE A42F
DUMP
FREEZE 5A1B
FREEZE E7B3
FREEZE 7E0A
FREEZE FE55
FREEZE 9BE8
SET 16 EB 3F 03 12 10 D2 9A 38 3E 96 A9 25 8C CC A7 4B
FREEZE 3C62
SET 0
FREEZE 942A
FREEZE F810
FREEZE 1330
SET 12 40 70 E0 90 80 B0 BB D0 C0 F0 60 AB
FREEZE 03C3
SET 2 2F 33
SET 13 5F A3 32 7A 22 AA 2D 59 15 21 3D 29 A5
SET 2 F9 35
FREEZE AAD2
FREEZE 18C2
SET 9 7A 4A B2 22 AA 2D 90 80 4B
FREEZE 60CE
FREEZE 681C
SET 3 1C 1C 1C
DUMP
SET 1 1C
SET 4 F9 35 C1 5D
SET 1 11
FREEZE 7499
SET 12 10 00 30 A0 50 40 70 E0 90 1B AF B3
SET 11 47 6B BF 1E F6 EE 21 3D C4 A4 04
SET 5 BF B9 C7 EB 3F
FREEZE 8777
DUMP
SET 14 BA 62 12 DA 02 A5 71 4D F9 D0 C0 F0 60 10
SET 0
FREEZE 9650
DUMP
FREEZE EBDE
SET 15 6E 06 BE 16 8E A6 DE B6 AE 46 FE 56 CE E6 1E
FREEZE 8DEE
SET 10 F9 35 C1 5D C9 C5 11 6D 99 55
DUMP
FREEZE 63DF
SET 13 FB 0F 93 62 20 06 F4 4A 84 64 C4 3F 03
DUMP
FREEZE AD6F
SET 16 CB 9F E3 D7 56 CE E6 1E F6 EE 21 73 F9 35 C1 5D
SET 13 11 6D 99 55 FC B2 CC 0C 4C 8C CC 0C 4C
SET 1 0B
FREEZE DB23
SET 6 A2 2A 12 DA 2A F9
DUMP
FREEZE 995C
SET 8 5C 5C 5C 5C 5C F7 5B EF
FREEZE D7A7
SET 11 63 57 3B 4F D3 A2 2A AD D9 95 A1
FREEZE C9A9
FREEZE 14F1
SET 15 50 40 70 E0 90 80 B0 20 6B BF 1E F6 EE 86 3E
FREEZE BEA9
FREEZE 91F1
SET 16 B5 41 78 7E D6 4E 01 9D 09 A0 50 40 0B DF 23 17
SET 1 2E
SET 10 66 9E 76 6E 06 BE 16 29 DB 41
SET 2 44 24
SET 16 57 3B 4F D3 A2 2A 12 DA 9D 40 70 E0 90 80 B0 BB
SET 2 87 D3
SET 5 7F 43 B7 1B AF
FREEZE 2567
FREEZE 3C14
SET 1 74
SET 9 E7 26 5E 36 2E C6 7E D6 E9
SET 5 6F 0E 26 86 3E
FREEZE 9944
SET 15 63 F2 3A E2 6A 52 1A 42 4A B2 FA 3D 29 40 70
DUMP
FREEZE A280
SET 12 D0 5B EF 8E A6 DE B6 AE 46 99 55 61
SET 12 E4 44 24 84 64 C4 A4 04 7F 43 B7 1B
FREEZE DF4E
SET 12 76 6E 06 BE 16 8E A6 DE B6 AE 46 FE
SET 3 E5 B1 28
SET 13 98 83 F7 5B F0 60 AB FF C3 37 9B 2F 33
SET 15 5F 3E 96 0E 26 5E 36 C9 C5 11 6D 34 54 8F 13
DUMP
DUMP
SET 5 F7 F6 24 84 64
SET 2 04 E4
SET 6 84 FF F9 07 2B 7F
FREEZE 3252
FREEZE AAB2
FREEZE DEA1
FREEZE F1A8
SET 0
FREEZE B9E5
DUMP
SET 11 58 43 B7 1B B0 20 D0 C0 F0 60 10
FREEZE E02F
FREEZE EDE7
FREEZE 3E5F
DUMP
FREEZE 857B
SET 4 47 6B 5A 82
FREEZE 15F1
DUMP
SET 4 41 DD 49 45
DUMP
DUMP
SET 8 E1 FD E9 65 31 0D B9 90
SET 2 20 D0
DUMP
FREEZE 558E
SET 15 DA 02 0A 72 55 98 E8 93 FD 47 6B BF 83 92 5A
SET 1 F1
DUMP
@@@ hidden_output
(no history)
(no history)
P3C2D [7] 68 78 E3 9A C2 CA 32
P08B0 [7] 68 78 E3 9A C2 CA 32
P24D0 [7] 68 78 E3 9A C2 CA 32
P37CF [7] 68 78 E3 9A C2 CA 32
P1E87 [7] 68 78 E3 9A C2 CA 32
PD520 [14] C3 37 36 64 C4 A4 04 E4 44 BF 83 92 90 80
P37CF [7] 68 78 E3 9A C2 CA 32
P1E87 [7] 68 78 E3 9A C2 CA 32
PD520 [14] C3 37 36 64 C4 A4 04 E4 44 BF 83 92 90 80
P37CF [7] 68 78 E3 9A C2 CA 32
P1E87 [7] 68 78 E3 9A C2 CA 32
PD520 [14] C3 37 36 64 C4 A4 04 E4 44 BF 83 92 90 80
PD520 [14] C3 37 36 64 C4 A4 04 E4 44 BF 83 92 90 80
P7022 [3] 5F A3 32
P60C8 [3] 5F A3 32
P7022 [3] 5F A3 32
P60C8 [3] 5F A3 32
P7FED [6] 9F E3 D7 56 CE E6
P7022 [3] 5F A3 32
P60C8 [3] 5F A3 32
P7FED [6] 9F E3 D7 56 CE E6
P7FED [6] 9F E3 D7 56 CE E6
P1BFD [6] 9F E3 D7 56 CE E6
PD663 [7] C4 3F 39 47 6B BF 83
P1BFD [6] 9F E3 D7 56 CE E6
PD663 [7] C4 3F 39 47 6B BF 83
PCC3D [11] 96 0E 26 F9 6B 6C 2C EC 48 D8 28
PA15C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P3B5C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P9F5C [0]
PA15C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P3B5C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P9F5C [0]
P3B5C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P9F5C [0]
P435C [0]
P3B5C [10] 0D 54 F4 14 4F 09 3B 21 3D 29
P9F5C [0]
P435C [0]
P9F5C [0]
P435C [0]
P7314 [10] 5C 5C 5C 5C F7 5B 8A F2 D5 E1
P7314 [10] 5C 5C 5C 5C F7 5B 8A F2 D5 E1
PC873 [10] 5C 5C 5C 5C F7 5B 8A F2 D5 E1
P8E0F [0]
P8F1B [7] 11 08 98 E8 F8 C8 F3
PFB48 [6] 58 A8 B8 23 18 68
PA8C3 [6] 58 A8 B8 23 18 68
PA8C3 [6] 58 A8 B8 23 18 68
P3455 [3] 2B B6 AE
P4D7D [3] 2B B6 AE
P3455 [3] 2B B6 AE
P4D7D [3] 2B B6 AE
PA42F [8] A4 04 7F 43 52 1A 42 4A
P18C2 [2] F9 35
P60CE [9] 7A 4A B2 22 AA 2D 90 80 4B
P681C [9] 7A 4A B2 22 AA 2D 90 80 4B
P681C [9] 7A 4A B2 22 AA 2D 90 80 4B
P7499 [1] 11
P8777 [5] BF B9 C7 EB 3F
P7499 [1] 11
P8777 [5] BF B9 C7 EB 3F
P9650 [0]
P9650 [0]
PEBDE [0]
P8DEE [15] 6E 06 BE 16 8E A6 DE B6 AE 46 FE 56 CE E6 1E
PEBDE [0]
P8DEE [15] 6E 06 BE 16 8E A6 DE B6 AE 46 FE 56 CE E6 1E
P63DF [10] F9 35 C1 5D C9 C5 11 6D 99 55
P63DF [10] F9 35 C1 5D C9 C5 11 6D 99 55
PAD6F [13] FB 0F 93 62 20 06 F4 4A 84 64 C4 3F 03
PDB23 [1] 0B
P2567 [5] 7F 43 B7 1B AF
P3C14 [5] 7F 43 B7 1B AF
P9944 [5] 6F 0E 26 86 3E
P9944 [5] 6F 0E 26 86 3E
PA280 [15] 63 F2 3A E2 6A 52 1A 42 4A B2 FA 3D 29 40 70
PDF4E [12] E4 44 24 84 64 C4 A4 04 7F 43 B7 1B
P9944 [5] 6F 0E 26 86 3E
PA280 [15] 63 F2 3A E2 6A 52 1A 42 4A B2 FA 3D 29 40 70
PDF4E [12] E4 44 24 84 64 C4 A4 04 7F 43 B7 1B
PDEA1 [6] 84 FF F9 07 2B 7F
PF1A8 [6] 84 FF F9 07 2B 7F
PB9E5 [0]
PE02F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
PEDE7 [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P3E5F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P3E5F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P857B [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P15F1 [4] 47 6B 5A 82
P3E5F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P857B [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P15F1 [4] 47 6B 5A 82
P3E5F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P857B [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P15F1 [4] 47 6B 5A 82
P3E5F [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P857B [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P15F1 [4] 47 6B 5A 82
P857B [11] 58 43 B7 1B B0 20 D0 C0 F0 60 10
P15F1 [4] 47 6B 5A 82
P558E [2] 20 D0

@@@ hint
`*c = *src;` copies every member of `struct Frame`. What exactly does it copy for the `data` member, and who owns that buffer afterwards?
@@@ hint
The snapshot needs its **own** payload buffer: allocate `FRAME_CAP` bytes for `c->data` and `memcpy` the payload into it (a deep copy). The `struct Frame f = *hist[i];` in `dump` is also a shallow copy, but it is harmless, because nothing writes through it or frees it.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define FRAME_CAP 16
#define HIST 3

struct Frame {
    uint32_t dtc;
    uint16_t len;
    uint8_t *data;
};

static struct Frame live;
static struct Frame *hist[HIST];
static int hcount;

static struct Frame *frame_clone(const struct Frame *src, uint32_t dtc)
{
    struct Frame *c = malloc(sizeof *c);
    if (c == NULL)
        return NULL;
    *c = *src;
    c->dtc = dtc;
    c->data = malloc(FRAME_CAP);                       /* FIX: deep copy - own payload buffer ... */
    if (c->data == NULL) { free(c); return NULL; }     /* FIX */
    memcpy(c->data, src->data, FRAME_CAP);             /* FIX: ... with a copy of the bytes */
    return c;
}

static void frame_destroy(struct Frame *f)
{
    if (f == NULL)
        return;
    free(f->data);
    free(f);
}

static void freeze(uint32_t dtc)
{
    struct Frame *snap = frame_clone(&live, dtc);
    if (snap == NULL)
        return;
    if (hcount == HIST) {                       /* ring full: drop the oldest */
        frame_destroy(hist[0]);
        memmove(&hist[0], &hist[1], (HIST - 1) * sizeof hist[0]);
        hcount--;
    }
    hist[hcount++] = snap;
}

static void dump(void)
{
    if (hcount == 0) {
        printf("(no history)\n");
        return;
    }
    for (int i = 0; i < hcount; i++) {
        struct Frame f = *hist[i];              /* local view for printing */
        printf("P%04X [%u]", (unsigned)f.dtc, (unsigned)f.len);
        for (unsigned k = 0; k < f.len; k++)
            printf(" %02X", (unsigned)f.data[k]);
        printf("\n");
    }
}

int main(void)
{
    char cmd[8];
    live.data = calloc(FRAME_CAP, 1);
    if (live.data == NULL)
        return 1;

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "SET") == 0) {
            unsigned n;
            if (scanf("%u", &n) != 1 || n > FRAME_CAP) break;
            for (unsigned i = 0; i < n; i++) {
                unsigned b;
                if (scanf("%x", &b) != 1) b = 0;
                live.data[i] = (uint8_t)b;
            }
            live.len = (uint16_t)n;
        } else if (strcmp(cmd, "FREEZE") == 0) {
            unsigned dtc;
            if (scanf("%x", &dtc) != 1) break;
            freeze(dtc);
        } else if (strcmp(cmd, "DUMP") == 0) {
            dump();
        }
    }

    for (int i = 0; i < hcount; i++)
        frame_destroy(hist[i]);
    free(live.data);
    return 0;
}
@@@ explanation_md
**Bug.** Struct assignment `*c = *src;` copies members **by value**. For `uint8_t *data` that copies the *pointer*, not the 16 bytes it points to. Every snapshot and the live frame therefore share **one** heap buffer:

```
live.data ----+
hist[0]->data-+--> [ 16-byte buffer ]
hist[1]->data-+
```

- `SET` after a `FREEZE` rewrites the buffer, so the "frozen" snapshots change (wrong output).
- Evicting the oldest snapshot calls `free(data)` on the shared buffer. The next `SET` then writes into freed memory (heap-use-after-free).
- At exit, the same buffer is freed once per snapshot plus once for `live` (double free).

**Fix.** Make `frame_clone` a **deep copy**: allocate a new payload buffer and `memcpy` the bytes. Ownership is now unambiguous, because every `struct Frame` owns exactly one buffer and `frame_destroy` frees exactly that one.

The shallow copy in `dump()` (`struct Frame f = *hist[i];`) is a deliberate red herring. It only *reads* through the shared pointer while the original still owns it, so it is safe.

**Complexity.** `FREEZE` is O(FRAME_CAP) for the copy; `DUMP` is O(HIST * len). Space O(HIST * FRAME_CAP).

**Common mistakes**
- "Fixing" the double free by not freeing `data` in `frame_destroy`. Now the snapshots still share and mutate, and the eviction path leaks or reads garbage.
- Copying only `len` bytes but forgetting that `len` can be 0, so `malloc(0)` may return `NULL`, which is then misread as an out-of-memory failure.
- Calling `memcpy(c, src, sizeof *c)`. It is the same shallow copy written another way.
- Freeing `live.data` inside `freeze` "because the snapshot owns it now", which leaves `live.data` dangling.

**Interview follow-ups**
- How would you redesign `struct Frame` so that plain struct assignment *is* a deep copy? (Embed `uint8_t data[FRAME_CAP]` instead of a pointer. This suits fixed-size freeze frames on an ECU.)
- C has no copy constructors. Which naming conventions or APIs make ownership explicit (`_clone`, `_move`, `_borrow`)?
- How would reference counting solve the same problem, and what does it cost in an ISR-shared context?
- Where else does a hidden shallow copy appear in C? (Returning a struct with a pointer member, `qsort` swapping structs, `realloc` of an array of structs that point into themselves.)
