@@@ meta
id: BIT-H-10
topic: Bit Manipulation
difficulty: Hard
type: FIND_THE_BUG
title: Lost Interrupts on a Write-1-to-Clear Pending Register
tags: embedded, w1c, interrupts, registers, read-modify-write, stm32, isr, bsp
@@@ statement_md
An STM32-style external-interrupt controller latches edges on input lines in a pending register. Reference manual excerpt:

> **EXTI_PR** (pending register), access **rc_w1**. Bit *n* reads 1 while line *n* has a pending edge. Writing **1** to bit *n* clears it. Writing **0** has no effect. Bits 0..15 are GPIO lines serviced by `exti_irq_handler()`. Bits 16..22 belong to other sources (PVD, RTC alarm, USB wake-up) that are serviced by **other** handlers.

The BSP (the hidden harness) provides `uint32_t EXTI_PR_read(void)`, `void EXTI_PR_write(uint32_t v)` (with exactly these rc_w1 semantics), and the application callback `void on_exti_line(unsigned line)`. The NVIC keeps re-entering `exti_irq_handler()` while any of bits 0..15 is pending. Each entry must service **one** line, the lowest-numbered pending one. A new edge can arrive on any line, including the line being serviced, **while its callback runs**. Such an edge must lead to one more callback for that line.

Field reports:
- when two buttons are pressed at the same moment, only one press is handled;
- the RTC alarm (line 17) handler sometimes never runs;
- a fast encoder pulse that arrives while the encoder callback is running is missed.

There are **two** defects in `exti_irq_handler()`. Find and fix both.

**Input (simulation script for the harness)**
- Line 1: `q`.
- `C line mask`: the next time `line`'s callback runs, the hardware raises the lines in `mask` (hex) during the callback (once).
- `E mask`: edges arrive on the lines in `mask` (hex). The harness then runs the NVIC until bits 0..15 are clear (more than 1000 entries prints `IRQ STORM`) and prints `--- PR=%08X`.

**Output**
- `line n` for every callback (printed by `on_exti_line`), and `--- PR=XXXXXXXX` after each `E`.

**Example**
```
Input:
1
E 0005

Output:
line 0
line 2
--- PR=00000000
```
@@@ constraints_md
- `1 <= q <= 20`, `0 <= line <= 15`, masks fit in 23 bits.
- Keep the "one line per handler entry, lowest line first" policy.
@@@ starter_code
#include <stdint.h>

/* Provided by the BSP:
 *   uint32_t EXTI_PR_read(void);
 *   void     EXTI_PR_write(uint32_t v);     -- rc_w1 semantics
 *   void     on_exti_line(unsigned line);   -- application callback
 */

/* EXTI0..15 handler: services ONE pending line per entry, lowest line first.
 * The NVIC re-enters it while any line 0..15 is still pending. */
void exti_irq_handler(void)
{
    uint32_t pending = EXTI_PR_read() & 0xFFFFu;
    if (pending == 0u)
        return;

    unsigned line = 0;
    while (((pending >> line) & 1u) == 0u)
        line++;

    on_exti_line(line);                              /* run the application callback */
    EXTI_PR_write(EXTI_PR_read() | (1u << line));    /* acknowledge the line         */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/* ---- simulated EXTI peripheral + application (BSP) ---- */
static uint32_t g_pr;              /* EXTI_PR model */
static uint32_t g_chain[16];       /* edges raised while line n's callback runs (one-shot) */

static uint32_t EXTI_PR_read(void)
{
    return g_pr;
}

static void EXTI_PR_write(uint32_t v)
{
    g_pr &= ~v;                    /* rc_w1: 1 clears, 0 has no effect */
}

static void on_exti_line(unsigned line)
{
    printf("line %u\n", line);
    if (line < 16u) {
        g_pr |= g_chain[line];     /* hardware latches new edges during the callback */
        g_chain[line] = 0u;
    }
}

/*USER_CODE*/

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'C') {
            unsigned line, mask;
            if (scanf("%u %x", &line, &mask) != 2 || line > 15u) return 0;
            g_chain[line] = mask;
        } else {
            unsigned mask;
            if (scanf("%x", &mask) != 1) return 0;
            g_pr |= mask;
            int guard = 0;
            while (g_pr & 0xFFFFu) {
                exti_irq_handler();
                if (++guard > 1000) {
                    printf("IRQ STORM\n");
                    break;
                }
            }
            printf("--- PR=%08X\n", (unsigned)g_pr);
        }
    }
    return 0;
}
@@@ sample_input
1
E 0001
@@@ sample_output
line 0
--- PR=00000000

@@@ sample_input
1
E 0005
@@@ sample_output
line 0
line 2
--- PR=00000000

@@@ hidden_input
2
C 3 0008
E 0008
@@@ hidden_output
line 3
line 3
--- PR=00000000

@@@ hidden_input
2
C 5 0002
E 0020
@@@ hidden_output
line 5
line 1
--- PR=00000000

@@@ hidden_input
2
E 8001
E 0000
@@@ hidden_output
line 0
line 15
--- PR=00000000
--- PR=00000000

@@@ hidden_input
3
C 0 0006
C 2 0001
E 0001
@@@ hidden_output
line 0
line 1
line 2
line 0
--- PR=00000000

@@@ hidden_input
1
E 00010004
@@@ hidden_output
line 2
--- PR=00010000

@@@ hidden_input
3
C 7 0080
C 1 0080
E 0082
@@@ hidden_output
line 1
line 7
line 7
--- PR=00000000

@@@ hidden_input
2
C 4 00030000
E 0010
@@@ hidden_output
line 4
--- PR=00030000

@@@ hint
Expand the acknowledge statement for the "two buttons" case: `EXTI_PR_read()` returns `0x0005`, the OR with `1u << 0` gives `0x0005`, and that value is written. What does writing a 1 do to bit 2 in an rc_w1 register? The same applies to bits 16..22.
@@@ hint
For rc_w1 registers, never read-modify-write. Write **only** the bit you want to clear: `EXTI_PR_write(1u << line)`. Then look at the order: if the line is acknowledged **after** its callback, an edge that arrived during the callback is cleared together with the old one. Acknowledge first, then call the callback.
@@@ solution_code
#include <stdint.h>

/* Provided by the BSP:
 *   uint32_t EXTI_PR_read(void);
 *   void     EXTI_PR_write(uint32_t v);     -- rc_w1 semantics
 *   void     on_exti_line(unsigned line);   -- application callback
 */

/* EXTI0..15 handler: services ONE pending line per entry, lowest line first.
 * The NVIC re-enters it while any line 0..15 is still pending. */
void exti_irq_handler(void)
{
    uint32_t pending = EXTI_PR_read() & 0xFFFFu;
    if (pending == 0u)
        return;

    unsigned line = 0;
    while (((pending >> line) & 1u) == 0u)
        line++;

    EXTI_PR_write(1u << line);   /* FIX 1: rc_w1 -> write ONLY this bit (RMW wrote 1s to every pending line) */
    on_exti_line(line);          /* FIX 2: acknowledge BEFORE the callback, so an edge during it re-pends the line */
}
@@@ explanation_md
**Defect 1: read-modify-write on a write-1-to-clear register.** `EXTI_PR_write(EXTI_PR_read() | bit)` reads **all** pending bits and writes them back as 1s. In an rc_w1 register, writing 1 means "clear", so the handler acknowledges every pending line at once, including lines it has not serviced yet and lines 16..22 that belong to other handlers:

```
PR = 0x00010005 (line 0, line 2, RTC alarm line 16)
RMW ack of line 0: write 0x00010005 -> PR = 0  -> line 2 and line 16 lost
correct ack:       write 0x00000001 -> PR = 0x00010004
```

This is the same reason you must never write `TIMx->SR |= ...` or `EXTI->PR |= (1 << n)` on STM32. The `|=` "habit" that is correct for configuration registers silently loses events on status registers.

**Defect 2: acknowledging after the callback.** The pending flag is a latch: a new edge sets it again. If the line is cleared **after** the callback, an edge that arrived *during* the callback is merged into the old event and cleared with it. That is the lost encoder pulse. Acknowledging **before** calling the application means a new edge re-pends the line, and the NVIC re-enters the handler (tests `C 3 0008` and `C 7 0080`).

Each defect alone fails different hidden tests. Both must be fixed.

**Complexity.** O(16) per handler entry to find the lowest pending line (or O(1) with `__builtin_ctz`/`CLZ+RBIT`). O(1) space.

**Common mistakes**
- Fixing defect 1 with `EXTI_PR_write(EXTI_PR_read() & (1u << line))`. That happens to work here, but it is still a pointless read and race-prone. Write the constant bit.
- Writing `0` to clear (`PR &= ~bit`). On rc_w1 that writes 1s to every **other** pending bit (clearing them) and 0 to the target bit (not clearing it), which causes an interrupt storm.
- Clearing the flag as the **last** instruction of the ISR on a Cortex-M with a write buffer. The write may not have reached the peripheral when the ISR returns, so the IRQ fires again spuriously. Clear early, or add a read-back or `__DSB()`.

**Interview follow-ups**
- List the register access types you know (rw, r, w, rc_w1, rc_w0, rs, rt_w...) and the correct way to clear a flag for each.
- Why do STM32 timers use rc_w0 for `TIMx->SR` (write 0 to clear)? What does `TIMx->SR &= ~TIM_SR_UIF` risk there? (An RMW race with flags set between the read and the write.)
- How does the NVIC "tail-chaining" re-entry work, and what is the cost of servicing one line per entry versus all pending lines in one loop?
- How would you debounce mechanical buttons without losing presses, given that the EXTI flag only latches "at least one edge"?
