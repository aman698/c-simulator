@@@ meta
id: PTR-H-06
topic: Pointers
difficulty: Hard
type: FIND_THE_BUG
title: DMA Channel Registers Land in the Wrong Channel
tags: embedded, memory-mapped-io, pointer-arithmetic, register-macro, dma, bsp
@@@ statement_md
A BSP engineer wrote register-access macros for a multi-channel DMA controller. The controller is memory-mapped at `DMA_BASE`; in this program a block of RAM (`fake_dma`) stands in for it. The code between the `simulated hardware` markers only shows what the hardware sees, and it is correct.

**Register map** (byte offsets from `DMA_BASE`):

| offset | register |
|---|---|
| `0x000` | `GCR`: global control, bit 0 = controller enable |
| `0x100 + n * 0x20` | start of the register block of channel `n` (`n = 0..7`) |
| `+0x00` | `CFG`: bit 0 = channel enable, bits 5:4 = priority |
| `+0x04` | `SRC`: source address |
| `+0x08` | `DST`: destination address |
| `+0x0C` | `CNT`: transfer count |

Everything else is unmapped and must stay 0.

Symptom from the lab: channel enable and priority work, but in the debugger's memory view `SRC`/`DST`/`CNT` of the configured channel stay 0. Meanwhile the **next** channel's `CFG` contains a destination address, and unmapped words are being written. Find and fix the bug. The driver functions and the output format must stay as they are.

**Input**: commands until end of input.
- `cfg ch src dst cnt prio` (`src`/`dst`/`cnt` in hex, `prio` 0..3): `dma_config(...)`.
- `start ch` / `stop ch`.

**Output** (printed by the simulated hardware at the end):
- `GCR=XXXXXXXX`
- `CHn CFG=... SRC=... DST=... CNT=...` for every channel with a nonzero register.
- `UNMAPPED 0xOOO=XXXXXXXX` for every nonzero unmapped word.

**Example**
```
Input:
cfg 0 20000000 40011004 10 2
start 0

Output:
GCR=00000001
CH0 CFG=00000021 SRC=20000000 DST=40011004 CNT=00000010
```
@@@ constraints_md
- `0 <= ch <= 7`, at most 30 commands.
- Do not change the simulated-hardware section, the register map or the driver API.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ------------------- simulated hardware (correct, do not modify) ------------------- */
static uint32_t fake_dma[0x400];                    /* 4 KiB register window */
#define DMA_BASE ((uintptr_t)fake_dma)

static void hw_dump(void)
{
    printf("GCR=%08X\n", (unsigned)fake_dma[0]);
    for (unsigned ch = 0; ch < 8; ch++) {
        const uint32_t *r = &fake_dma[(0x100u + ch * 0x20u) / 4u];
        if (r[0] | r[1] | r[2] | r[3])
            printf("CH%u CFG=%08X SRC=%08X DST=%08X CNT=%08X\n", ch,
                   (unsigned)r[0], (unsigned)r[1], (unsigned)r[2], (unsigned)r[3]);
    }
    for (unsigned w = 1; w < 0x400; w++) {
        unsigned off = w * 4u;
        int mapped = off >= 0x100u && off < 0x200u && (off - 0x100u) % 0x20u < 0x10u;
        if (!mapped && fake_dma[w] != 0)
            printf("UNMAPPED 0x%03X=%08X\n", off, (unsigned)fake_dma[w]);
    }
}
/* ------------------------------ end of simulated hardware ------------------------------ */

/* Register access layer */
#define DMA_GCR              (*(volatile uint32_t *)(DMA_BASE + 0x000u))
#define DMA_CH_BASE(ch)      ((volatile uint32_t *)(DMA_BASE + 0x100u + (uint32_t)(ch) * 0x20u))
#define DMA_CH_REG(ch, off)  (*(DMA_CH_BASE(ch) + (off)))

#define CH_CFG  0x00u
#define CH_SRC  0x04u
#define CH_DST  0x08u
#define CH_CNT  0x0Cu

#define GCR_EN          (1u << 0)
#define CFG_EN          (1u << 0)
#define CFG_PRIO_SHIFT  4u
#define CFG_PRIO_MASK   (3u << CFG_PRIO_SHIFT)

static void dma_config(int ch, uint32_t src, uint32_t dst, uint32_t cnt, int prio)
{
    DMA_CH_REG(ch, CH_CFG) &= ~CFG_EN;                 /* disable before reprogramming */
    DMA_CH_REG(ch, CH_SRC) = src;
    DMA_CH_REG(ch, CH_DST) = dst;
    DMA_CH_REG(ch, CH_CNT) = cnt;
    DMA_CH_REG(ch, CH_CFG) = (DMA_CH_REG(ch, CH_CFG) & ~CFG_PRIO_MASK)
                           | (((uint32_t)prio << CFG_PRIO_SHIFT) & CFG_PRIO_MASK);
}

static void dma_start(int ch)
{
    DMA_GCR |= GCR_EN;
    DMA_CH_REG(ch, CH_CFG) |= CFG_EN;
}

static void dma_stop(int ch)
{
    DMA_CH_REG(ch, CH_CFG) &= ~CFG_EN;
}

int main(void)
{
    char cmd[16];
    while (scanf("%15s", cmd) == 1) {
        int ch;
        if (scanf("%d", &ch) != 1 || ch < 0 || ch > 7) return 0;
        if (strcmp(cmd, "cfg") == 0) {
            unsigned src, dst, cnt;
            int prio;
            if (scanf("%x %x %x %d", &src, &dst, &cnt, &prio) != 4) return 0;
            dma_config(ch, src, dst, cnt, prio);
        } else if (strcmp(cmd, "start") == 0) {
            dma_start(ch);
        } else if (strcmp(cmd, "stop") == 0) {
            dma_stop(ch);
        }
    }
    hw_dump();
    return 0;
}
@@@ sample_input
cfg 0 20000000 40011004 10 2
start 0
@@@ sample_output
GCR=00000001
CH0 CFG=00000021 SRC=20000000 DST=40011004 CNT=00000010

@@@ sample_input
cfg 1 1000 2000 FF 3
cfg 2 3000 4000 1 0
start 2
@@@ sample_output
GCR=00000001
CH1 CFG=00000030 SRC=00001000 DST=00002000 CNT=000000FF
CH2 CFG=00000001 SRC=00003000 DST=00004000 CNT=00000001

@@@ hidden_input
start 3
start 5
stop 3
@@@ hidden_output
GCR=00000001
CH5 CFG=00000001 SRC=00000000 DST=00000000 CNT=00000000

@@@ hidden_input
cfg 7 FFFFFFFF FFFFFFFC FFFF 1
start 7
cfg 7 1 2 3 2
@@@ hidden_output
GCR=00000001
CH7 CFG=00000020 SRC=00000001 DST=00000002 CNT=00000003

@@@ hidden_input
@@@ hidden_output
GCR=00000000

@@@ hidden_input
cfg 0 A B C 0
@@@ hidden_output
GCR=00000000
CH0 CFG=00000000 SRC=0000000A DST=0000000B CNT=0000000C

@@@ hidden_input
cfg 0 100 200 4 1
cfg 1 110 210 8 2
cfg 2 120 220 C 3
cfg 3 130 230 10 0
start 1
start 3
@@@ hidden_output
GCR=00000001
CH0 CFG=00000010 SRC=00000100 DST=00000200 CNT=00000004
CH1 CFG=00000021 SRC=00000110 DST=00000210 CNT=00000008
CH2 CFG=00000030 SRC=00000120 DST=00000220 CNT=0000000C
CH3 CFG=00000001 SRC=00000130 DST=00000230 CNT=00000010

@@@ hidden_input
cfg 6 DEADBEEF 0 0 3
stop 6
@@@ hidden_output
GCR=00000000
CH6 CFG=00000030 SRC=DEADBEEF DST=00000000 CNT=00000000

@@@ hint
`CFG` (offset 0) always works; `SRC`/`DST`/`CNT` (offsets 4, 8, 12) do not. Compute by hand the address that `DMA_CH_REG(0, CH_DST)` produces, and compare it with the address in the register map.
@@@ hint
`DMA_CH_BASE(ch)` has type `volatile uint32_t *`. Adding `off` to it advances `off` **elements**, that is `4 * off` bytes, but the `CH_*` constants are **byte** offsets. Do the addition on the integer address (or on a `uint8_t *`) *before* casting to the register pointer type.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ------------------- simulated hardware (correct, do not modify) ------------------- */
static uint32_t fake_dma[0x400];                    /* 4 KiB register window */
#define DMA_BASE ((uintptr_t)fake_dma)

static void hw_dump(void)
{
    printf("GCR=%08X\n", (unsigned)fake_dma[0]);
    for (unsigned ch = 0; ch < 8; ch++) {
        const uint32_t *r = &fake_dma[(0x100u + ch * 0x20u) / 4u];
        if (r[0] | r[1] | r[2] | r[3])
            printf("CH%u CFG=%08X SRC=%08X DST=%08X CNT=%08X\n", ch,
                   (unsigned)r[0], (unsigned)r[1], (unsigned)r[2], (unsigned)r[3]);
    }
    for (unsigned w = 1; w < 0x400; w++) {
        unsigned off = w * 4u;
        int mapped = off >= 0x100u && off < 0x200u && (off - 0x100u) % 0x20u < 0x10u;
        if (!mapped && fake_dma[w] != 0)
            printf("UNMAPPED 0x%03X=%08X\n", off, (unsigned)fake_dma[w]);
    }
}
/* ------------------------------ end of simulated hardware ------------------------------ */

/* Register access layer */
#define DMA_GCR              (*(volatile uint32_t *)(DMA_BASE + 0x000u))
#define DMA_CH_ADDR(ch)      (DMA_BASE + 0x100u + (uint32_t)(ch) * 0x20u)
#define DMA_CH_REG(ch, off)  (*(volatile uint32_t *)(DMA_CH_ADDR(ch) + (off)))   /* FIX: add the BYTE offset to the integer address, then cast */

#define CH_CFG  0x00u
#define CH_SRC  0x04u
#define CH_DST  0x08u
#define CH_CNT  0x0Cu

#define GCR_EN          (1u << 0)
#define CFG_EN          (1u << 0)
#define CFG_PRIO_SHIFT  4u
#define CFG_PRIO_MASK   (3u << CFG_PRIO_SHIFT)

static void dma_config(int ch, uint32_t src, uint32_t dst, uint32_t cnt, int prio)
{
    DMA_CH_REG(ch, CH_CFG) &= ~CFG_EN;                 /* disable before reprogramming */
    DMA_CH_REG(ch, CH_SRC) = src;
    DMA_CH_REG(ch, CH_DST) = dst;
    DMA_CH_REG(ch, CH_CNT) = cnt;
    DMA_CH_REG(ch, CH_CFG) = (DMA_CH_REG(ch, CH_CFG) & ~CFG_PRIO_MASK)
                           | (((uint32_t)prio << CFG_PRIO_SHIFT) & CFG_PRIO_MASK);
}

static void dma_start(int ch)
{
    DMA_GCR |= GCR_EN;
    DMA_CH_REG(ch, CH_CFG) |= CFG_EN;
}

static void dma_stop(int ch)
{
    DMA_CH_REG(ch, CH_CFG) &= ~CFG_EN;
}

int main(void)
{
    char cmd[16];
    while (scanf("%15s", cmd) == 1) {
        int ch;
        if (scanf("%d", &ch) != 1 || ch < 0 || ch > 7) return 0;
        if (strcmp(cmd, "cfg") == 0) {
            unsigned src, dst, cnt;
            int prio;
            if (scanf("%x %x %x %d", &src, &dst, &cnt, &prio) != 4) return 0;
            dma_config(ch, src, dst, cnt, prio);
        } else if (strcmp(cmd, "start") == 0) {
            dma_start(ch);
        } else if (strcmp(cmd, "stop") == 0) {
            dma_stop(ch);
        }
    }
    hw_dump();
    return 0;
}
@@@ explanation_md
**Bug.** Pointer arithmetic is scaled by the size of the pointed-to type:

```
DMA_CH_REG(ch, off) = *(DMA_CH_BASE(ch) + off)        DMA_CH_BASE: volatile uint32_t *
                                  ^^^^^^^^^ advances off * 4 bytes!
```

The offsets `0x04`, `0x08`, `0x0C` are **byte** offsets from the datasheet, so the macro accesses `+0x10`, `+0x20` and `+0x30` instead. For channel 0, `SRC` goes to `0x110` (unmapped), `DST` goes to `0x120` (**channel 1's `CFG`**!), and `CNT` goes to `0x130`. `CFG` (offset 0) and `GCR` are unaffected, which is why enable/priority looked fine. The driver even reads back through the same wrong macro, so a software read-back test passes. Only the "hardware" view exposes it. On a real MCU this would start channel 1 with garbage or raise a bus fault.

**Fix.** Add byte offsets to an **integer address** (`uintptr_t`) or to a byte pointer, and cast to `volatile uint32_t *` last:

```c
#define DMA_CH_REG(ch, off) (*(volatile uint32_t *)(DMA_CH_ADDR(ch) + (off)))
```

The alternatives are to keep a `uint32_t *` and use **word** indices (`off / 4`), or best, a struct overlay (`DMA->CH[n].SRC`) where the compiler computes the offsets.

**Complexity.** O(1) per register access. The fix changes no run time; it only changes the address arithmetic.

**Common mistakes**
- "Fixing" the constants to `1, 2, 3`. That works, but now `CH_SRC` no longer matches the datasheet, and the next engineer mixes both conventions.
- Removing the `volatile` from the cast while editing the macro. At `-O2`, polling `CFG` would then be optimised away.
- Casting the base to `uint8_t *` and **dereferencing** that (reading 1 byte instead of 32 bits). Many peripherals fault on sub-word accesses.
- Missing parentheses around macro parameters (`(off)`, `(ch)`), which breaks `DMA_CH_REG(i + 1, CH_SRC)`.

**Interview follow-ups**
- Rewrite the channel registers as `typedef struct { volatile uint32_t CFG, SRC, DST, CNT; uint32_t RESERVED[4]; } dma_ch_t;` with `DMA->CH[n]`. How do you guarantee the 0x20 stride at compile time?
- Why is `(uint32_t *)base + 1` different from `(uint32_t *)(base + 1)`, and which one is a misaligned access?
- What does the CMSIS `__IO` / `__I` / `__O` notation expand to?
- How would a unit test on the host catch this kind of bug without hardware (register-map mocks with access logs)?
