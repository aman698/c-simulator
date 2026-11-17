@@@ meta
id: PTR-H-01
topic: Pointers
difficulty: Hard
type: FUNCTION
title: UART Driver over Memory-Mapped Registers (volatile, RMW, W1C)
tags: embedded, volatile, memory-mapped-io, register-overlay, bsp, asked-in-automotive
@@@ statement_md
You are writing the transmit path of a bare-metal UART driver. The peripheral is **memory-mapped** at `UART0_BASE`. In this exercise that address is an array of RAM, and a **hardware simulator** reacts to what your code writes. Access the registers through a CMSIS-style **struct overlay**:

```c
#define UART0 ((uart_regs_t *)UART0_BASE)   /* UART0_BASE is provided (a uintptr_t) */
```

**Register map** (byte offsets from `UART0_BASE`, all registers 32-bit):

| offset | name | access | bits |
|---|---|---|---|
| `0x00` | `CR` | read/write | bit 0 `UE` (enable), bit 2 `RE` (rx enable), bit 3 `TE` (tx enable). **All other bits are reserved and must be preserved** (reset value `0xC0000000`). |
| `0x04` | `SR` | read / **write-1-to-clear** | bit 0 `PE`, bit 1 `FE`, bit 3 `ORE` are error flags: **writing 1 clears a flag, writing 0 has no effect**. Bit 7 `TXE` (transmit register empty) is read-only. Bits 31:8 are reserved and read as 1. |
| `0x08` | `DR` | write | writing loads bits 7:0 into the transmitter. Never read it. |
| `0x0C` | - | reserved | must never be accessed |
| `0x10` | `BRR` | read/write | baud divisor in bits 15:0 |

**Tasks**
1. Complete `uart_regs_t` so that the member offsets match the map exactly, and so that every register access is a `volatile` access. Use the member names `CR`, `SR`, `DR`, `BRR`.
2. `int uart_init(uint32_t divisor)`
   - If `divisor` is 0 or greater than `0xFFFF`, return `-1` and access nothing.
   - Otherwise write `BRR = divisor`, then set `UE` and `TE` in `CR` **without changing any other `CR` bit**, and return `0`.
3. `int uart_putc(uint8_t ch, uint32_t max_polls)`
   - If `UE` or `TE` is not set in `CR`, return `-2`.
   - Otherwise check `TXE` up to `max_polls` times. When `TXE` is set, write `ch` to `DR` once and return `0`. After every check that finds `TXE` clear, call **`hw_delay()`** once (on the target this would be a `__NOP()` or a short wait; here it advances the simulated hardware by one tick).
   - If all checks fail, return `-1` (timeout) without writing `DR`.
4. `uint32_t uart_clear_flags(uint32_t mask)`
   - Let `pending` be the error flags (`PE`/`FE`/`ORE`) that are currently set in `SR` **and** in `mask`.
   - Clear exactly those flags with **one** write to `SR`, leaving every other pending flag set, and return `pending`.
   - If `pending == 0`, write nothing and return 0.

**Simulator rules.** After the hardware accepts a byte, `TXE` stays 0 for the next `txtime` calls of `hw_delay()` and becomes 1 during the `txtime`-th call. The simulator cannot see individual bus cycles: it inspects the registers at each `hw_delay()` and when your function returns. So access the registers exactly as specified. Write `SR` only to clear flags, and never touch the reserved word or memory outside the UART.

**Input (read by the hidden harness)**: one command per line.
- `init D`: prints `init -> R CR=XXXXXXXX BRR=XXXXXXXX`.
- `putc C P`: prints `  TX 'C'` for every byte the hardware accepts, then `putc 'C' -> R`.
- `clear M` (hex): prints `clear -> 0xRR SR=XXXXXXXX`.
- `err F` (hex): the hardware raises error flags `F`; prints `err SR=XXXXXXXX`.
- `cr V` (hex): another driver writes `CR = V`; prints `cr CR=XXXXXXXX`.
- `txtime K`: sets `txtime` (default 2); prints nothing.

If your struct layout or qualifiers are wrong, the harness prints a `FAIL:` line instead.

**Example**
```
Input:
init 26
putc A 5
putc B 5
putc C 1
putc D 5

Output:
init -> 0 CR=C0000009 BRR=0000001A
  TX 'A'
putc 'A' -> 0
  TX 'B'
putc 'B' -> 0
putc 'C' -> -1
  TX 'D'
putc 'D' -> 0
```
After `A` is sent, `TXE` is 0 for 2 ticks. `putc B` checks, delays, checks, delays (`TXE` is now 1), checks again and sends. `putc C` gets only one check and times out. Its single `hw_delay()` still counts, so `putc D` needs only one delay.
@@@ constraints_md
- `1 <= max_polls <= 1000`, `1 <= txtime <= 100`, at most 50 commands.
- Use the `UART0` overlay for every register access; never cast `UART0_BASE` to a non-volatile pointer.
- `stdint.h` types only; no `long`.
@@@ starter_code
#include <stdint.h>

/* TODO: make this overlay match the register map exactly
 *       (offsets, reserved words, qualifiers). */
typedef struct {
    uint32_t CR;
    uint32_t SR;
    uint32_t DR;
    uint32_t BRR;
} uart_regs_t;

#define UART0 ((uart_regs_t *)UART0_BASE)

#define CR_UE   (1u << 0)
#define CR_RE   (1u << 2)
#define CR_TE   (1u << 3)
#define SR_PE   (1u << 0)
#define SR_FE   (1u << 1)
#define SR_ORE  (1u << 3)
#define SR_TXE  (1u << 7)
#define SR_ERR_MASK (SR_PE | SR_FE | SR_ORE)

/* provided by the platform: void hw_delay(void); */

int uart_init(uint32_t divisor)
{
    /* TODO */
    return -1;
}

int uart_putc(uint8_t ch, uint32_t max_polls)
{
    /* TODO */
    return -1;
}

uint32_t uart_clear_flags(uint32_t mask)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define WIN 8                                   /* UART window starts at word 8 */
static uint32_t fake_periph[32];                /* fake peripheral bus */
#define UART0_BASE ((uintptr_t)&fake_periph[WIN])
void hw_delay(void);

/*USER_CODE*/

#define R_CR 0
#define R_SR 1
#define R_DR 2
#define R_RSVD 3
#define R_BRR 4
#define REG(i) fake_periph[WIN + (i)]
#define S_TXE (1u << 7)
#define S_ERR 0x0Bu
#define RSVD_PATTERN 0x5EED5EEDu
#define DR_IDLE 0xFFFFFFFFu

static uint32_t pub_sr, hw_err, busy, txtime = 2;
static int txe = 1, bus_fault;

static uint32_t guard_value(int k) { return 0xDEAD0000u | (uint32_t)k; }

static void publish(void)
{
    pub_sr = 0xFFFFFF00u | (txe ? S_TXE : 0u) | hw_err;
    REG(R_SR) = pub_sr;
    REG(R_DR) = DR_IDLE;
}

static void sim_sync(void)
{
    for (int k = 0; k < 32; k++)
        if ((k < WIN || k >= WIN + 5) && fake_periph[k] != guard_value(k)) bus_fault = 1;
    if (REG(R_RSVD) != RSVD_PATTERN) bus_fault = 1;
    if (REG(R_SR) != pub_sr)                         /* SR was written: W1C semantics */
        hw_err &= ~(REG(R_SR) & S_ERR);
    if (REG(R_DR) != DR_IDLE) {                      /* DR was written: transmit */
        unsigned b = REG(R_DR) & 0xFFu;
        uint32_t cr = REG(R_CR);
        if (!(cr & 1u) || !(cr & 8u)) printf("  TX WHILE DISABLED\n");
        else if (!txe) printf("  TX OVERRUN '%c'\n", (char)b);
        else {
            printf("  TX '%c'\n", (char)b);
            txe = 0;
            busy = txtime;
        }
    }
    publish();
}

void hw_delay(void)
{
    sim_sync();
    if (busy > 0 && --busy == 0) txe = 1;
    publish();
}

int main(void)
{
    for (int k = 0; k < 32; k++) fake_periph[k] = guard_value(k);
    REG(R_CR) = 0xC0000000u;
    REG(R_RSVD) = RSVD_PATTERN;
    REG(R_BRR) = 0;
    publish();

    int vol = _Generic(&UART0->CR, volatile uint32_t *: 1, default: 0) &&
              _Generic(&UART0->SR, volatile uint32_t *: 1, default: 0) &&
              _Generic(&UART0->DR, volatile uint32_t *: 1, default: 0) &&
              _Generic(&UART0->BRR, volatile uint32_t *: 1, default: 0);
    if (!vol) {
        printf("FAIL: UART registers must be accessed through volatile lvalues\n");
        return 0;
    }
    if (offsetof(uart_regs_t, CR) != 0x00 || offsetof(uart_regs_t, SR) != 0x04 ||
        offsetof(uart_regs_t, DR) != 0x08 || offsetof(uart_regs_t, BRR) != 0x10) {
        printf("FAIL: register map mismatch (CR@0x%02zX SR@0x%02zX DR@0x%02zX BRR@0x%02zX)\n",
               offsetof(uart_regs_t, CR), offsetof(uart_regs_t, SR),
               offsetof(uart_regs_t, DR), offsetof(uart_regs_t, BRR));
        return 0;
    }

    char cmd[16];
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "init") == 0) {
            unsigned d;
            if (scanf("%u", &d) != 1) return 0;
            int r = uart_init(d);
            sim_sync();
            printf("init -> %d CR=%08X BRR=%08X\n", r, (unsigned)REG(R_CR), (unsigned)REG(R_BRR));
        } else if (strcmp(cmd, "putc") == 0) {
            char c;
            unsigned p;
            if (scanf(" %c %u", &c, &p) != 2) return 0;
            int r = uart_putc((uint8_t)c, p);
            sim_sync();
            printf("putc '%c' -> %d\n", c, r);
        } else if (strcmp(cmd, "clear") == 0) {
            unsigned m;
            if (scanf("%x", &m) != 1) return 0;
            uint32_t r = uart_clear_flags(m);
            sim_sync();
            printf("clear -> 0x%02X SR=%08X\n", (unsigned)r, (unsigned)REG(R_SR));
        } else if (strcmp(cmd, "err") == 0) {
            unsigned f;
            if (scanf("%x", &f) != 1) return 0;
            hw_err |= f & S_ERR;
            publish();
            printf("err SR=%08X\n", (unsigned)REG(R_SR));
        } else if (strcmp(cmd, "cr") == 0) {
            unsigned v;
            if (scanf("%x", &v) != 1) return 0;
            REG(R_CR) = v;
            printf("cr CR=%08X\n", (unsigned)REG(R_CR));
        } else if (strcmp(cmd, "txtime") == 0) {
            unsigned k;
            if (scanf("%u", &k) != 1) return 0;
            txtime = k;
        }
        if (bus_fault) {
            printf("BUS FAULT: access outside the UART registers or to the reserved word\n");
            return 0;
        }
    }
    return 0;
}
@@@ sample_input
init 26
putc A 5
putc B 5
putc C 1
putc D 5
@@@ sample_output
init -> 0 CR=C0000009 BRR=0000001A
  TX 'A'
putc 'A' -> 0
  TX 'B'
putc 'B' -> 0
putc 'C' -> -1
  TX 'D'
putc 'D' -> 0

@@@ sample_input
err 0B
clear 08
clear 08
clear FF
@@@ sample_output
err SR=FFFFFF8B
clear -> 0x08 SR=FFFFFF83
clear -> 0x00 SR=FFFFFF83
clear -> 0x03 SR=FFFFFF80

@@@ hidden_input
putc X 3
init 0
init 65536
init 65535
putc X 3
@@@ hidden_output
putc 'X' -> -2
init -> -1 CR=C0000000 BRR=00000000
init -> -1 CR=C0000000 BRR=00000000
init -> 0 CR=C0000009 BRR=0000FFFF
  TX 'X'
putc 'X' -> 0

@@@ hidden_input
cr C0000004
init 104
cr C0000005
putc Q 2
@@@ hidden_output
cr CR=C0000004
init -> 0 CR=C000000D BRR=00000068
cr CR=C0000005
putc 'Q' -> -2

@@@ hidden_input
txtime 3
init 1
putc a 1
putc b 3
putc c 4
putc d 10
@@@ hidden_output
init -> 0 CR=C0000009 BRR=00000001
  TX 'a'
putc 'a' -> 0
putc 'b' -> -1
  TX 'c'
putc 'c' -> 0
  TX 'd'
putc 'd' -> 0

@@@ hidden_input
err 01
err 08
clear 01
err 02
clear 0A
clear 80
@@@ hidden_output
err SR=FFFFFF81
err SR=FFFFFF89
clear -> 0x01 SR=FFFFFF88
err SR=FFFFFF8A
clear -> 0x0A SR=FFFFFF80
clear -> 0x00 SR=FFFFFF80

@@@ hidden_input
init 9
putc Z 1
err 08
clear 08
putc Y 1
putc Y 2
@@@ hidden_output
init -> 0 CR=C0000009 BRR=00000009
  TX 'Z'
putc 'Z' -> 0
err SR=FFFFFF08
clear -> 0x08 SR=FFFFFF00
putc 'Y' -> -1
  TX 'Y'
putc 'Y' -> 0

@@@ hidden_input
cr FFFFFFFF
init 3
putc ! 1
@@@ hidden_output
cr CR=FFFFFFFF
init -> 0 CR=FFFFFFFF BRR=00000003
  TX '!'
putc '!' -> 0

@@@ hidden_input
cr 00000000
init 2
err 0B
clear 02
putc 0 1
@@@ hidden_output
cr CR=00000000
init -> 0 CR=00000009 BRR=00000002
err SR=FFFFFF8B
clear -> 0x02 SR=FFFFFF89
  TX '0'
putc '0' -> 0

@@@ hint
The overlay needs a dummy `uint32_t` member for the reserved word at `0x0C`, so that `BRR` lands at `0x10`. Make the register members `volatile uint32_t`: every read then really goes to the bus, and every write really happens, in program order.
@@@ hint
`CR` is read-modify-write (`UART0->CR |= CR_UE | CR_TE;`) because other bits must survive. `SR` is the opposite: with write-1-to-clear, `UART0->SR |= flag` reads **all** pending flags and writes them back as 1s, which clears all of them. Write only the bits you want to clear: `UART0->SR = pending;`.
@@@ solution_code
#include <stdint.h>

typedef struct {
    volatile uint32_t CR;     /* 0x00 */
    volatile uint32_t SR;     /* 0x04 */
    volatile uint32_t DR;     /* 0x08 */
    uint32_t RESERVED0;       /* 0x0C: keeps BRR at 0x10, never accessed */
    volatile uint32_t BRR;    /* 0x10 */
} uart_regs_t;

#define UART0 ((uart_regs_t *)UART0_BASE)

#define CR_UE   (1u << 0)
#define CR_RE   (1u << 2)
#define CR_TE   (1u << 3)
#define SR_PE   (1u << 0)
#define SR_FE   (1u << 1)
#define SR_ORE  (1u << 3)
#define SR_TXE  (1u << 7)
#define SR_ERR_MASK (SR_PE | SR_FE | SR_ORE)

/* provided by the platform: void hw_delay(void); */

int uart_init(uint32_t divisor)
{
    if (divisor == 0u || divisor > 0xFFFFu)
        return -1;
    UART0->BRR = divisor;                 /* whole register: reserved bits 31:16 written as 0 */
    UART0->CR |= CR_UE | CR_TE;           /* read-modify-write: keep RE and reserved bits */
    return 0;
}

int uart_putc(uint8_t ch, uint32_t max_polls)
{
    if ((UART0->CR & (CR_UE | CR_TE)) != (CR_UE | CR_TE))
        return -2;
    for (uint32_t i = 0; i < max_polls; i++) {
        if (UART0->SR & SR_TXE) {         /* volatile: re-read from the bus every time */
            UART0->DR = ch;
            return 0;
        }
        hw_delay();
    }
    return -1;                            /* bounded wait: never hang the scheduler */
}

uint32_t uart_clear_flags(uint32_t mask)
{
    uint32_t pending = UART0->SR & mask & SR_ERR_MASK;
    if (pending != 0u)
        UART0->SR = pending;              /* W1C: plain write of ONLY the flags to clear */
    return pending;
}
@@@ explanation_md
**Approach.**

*Struct overlay.* Peripheral registers sit at consecutive addresses. A `struct` whose members have the right sizes, plus explicit `RESERVEDn` fillers for gaps, maps a name to each address. This is what every CMSIS device header (`USART_TypeDef`, `GPIO_TypeDef`) does. All members are `uint32_t`, so there is no padding, and the offsets are 0x00, 0x04, 0x08, 0x0C (filler) and 0x10. A `_Static_assert(offsetof(uart_regs_t, BRR) == 0x10, "map")` in production code catches mistakes at compile time.

*volatile.* Without `volatile`, the compiler may keep `SR` in a register and turn the polling loop into `if (!(SR & TXE)) for (;;);`. It may also merge or drop writes to `DR`. `volatile` forces exactly one bus access per source access, in program order. At `-O0` everything "works" without it, which is why the harness checks the type with `_Generic`.

*Three kinds of register write:*

| register | correct access | why |
|---|---|---|
| `CR` (RW, shared bits) | `CR \|= UE \| TE` (read-modify-write) | other drivers and reserved bits must survive |
| `SR` (W1C flags) | `SR = pending` (plain write) | `SR \|= x` writes back every pending flag as 1 and **clears them all** |
| `DR` (write-only, side effect) | `DR = ch` exactly once | each write transmits a byte |

*Bounded polling.* A `while (!(SR & TXE));` loop hangs forever if the clock is gated or the peripheral is in reset. Production code always uses a timeout and reports an error (in AUTOSAR, via the DET/DEM).

**Complexity.** `uart_init` and `uart_clear_flags` are O(1). `uart_putc` is O(max_polls). Space O(1).

**Common mistakes**
- Forgetting the reserved filler, so `BRR` lands at `0x0C` (the harness prints the map mismatch).
- Plain `uint32_t` members: correct at `-O0`, but polling loops are optimised away at `-O2`.
- `UART0->CR = CR_UE | CR_TE;`. This wipes `RE` and the reserved bits (`CR=00000009` instead of `C000000D`).
- `UART0->SR |= flag;` or `UART0->SR &= ~flag;`. With W1C semantics, the first clears every pending error, and the second clears every error **except** the one you wanted. Both lose diagnostic information.
- Polling without `hw_delay()`, or calling it before the first check, which shifts the timeout by one tick.
- Writing `DR` while `TXE` is 0 (TX overrun), or writing it when the transmitter is disabled.

**Interview follow-ups**
- Why is `UART0->CR |= CR_TE;` not atomic, and what can go wrong if an ISR also modifies `CR`? How do bit-banding (Cortex-M3/M4) or separate SET/CLR registers (as in GPIO `BSRR`) solve this?
- What is the difference between `volatile uint32_t *const REG` and `uint32_t *volatile REG`, and which one describes a fixed hardware register?
- Why might the compiler still reorder a `volatile` access against a normal memory access, and when do you need a `__DMB()` / `__DSB()` barrier (for example before starting a DMA transfer)?
- How would you redesign `uart_putc` to be interrupt-driven, with a ring buffer and the `TXE` interrupt?
