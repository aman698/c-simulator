@@@ meta
id: BIT-E-10
topic: Bit Manipulation
difficulty: Easy
type: FIND_THE_BUG
title: GPIO Driver Mode Field Read-Modify-Write Bug
tags: embedded, read-modify-write, registers, gpio, stm32, masks, bsp
@@@ statement_md
Below is part of a GPIO driver for an STM32-style port. The register block is defined in the vendor header (part of the hidden harness):

```c
typedef struct {
    volatile uint32_t MODER;   /* 2 bits per pin: 00 input, 01 output, 10 alternate fn, 11 analog */
    volatile uint32_t OTYPER;  /* 1 bit  per pin: 0 push-pull, 1 open-drain                        */
    volatile uint32_t AFRL;    /* 4 bits per pin for pins 0..7  (alternate function number)        */
    volatile uint32_t AFRH;    /* 4 bits per pin for pins 8..15                                    */
} GPIO_TypeDef;
```

Pin `p` occupies `MODER` bits `2p+1 : 2p`. Every driver function must change **only** the field of the given pin, and leave that field holding exactly the requested value.

The driver passed its bench tests on an older chip whose GPIO ports reset to `0x00000000` (all inputs). On the new chip, ports reset to **analog mode** (`MODER = 0xFFFFFFFF`, or `0xABFFFFFF` on port A because of the debug pins), and now **pins never become outputs**. Find and fix the bug.

**Input (read by the hidden harness)**
- Line 1: the reset value of `MODER` (hex) and `q`. `OTYPER`, `AFRL` and `AFRH` reset to 0.
- Next `q` lines: `M pin mode` → `gpio_set_mode`, `O pin od` → `gpio_set_otype`, `A pin af` → `gpio_set_af` (decimal).

**Output**
- After each command: `MODER=%08X OTYPER=%08X AFRL=%08X AFRH=%08X`.

**Example**
```
Input:
FFFFFFFF 1
M 5 1

Output:
MODER=FFFFF7FF OTYPER=00000000 AFRL=00000000 AFRH=00000000
```
@@@ constraints_md
- `0 <= pin <= 15`, `mode` uses only its low 2 bits, `af` only its low 4 bits.
- Keep the function signatures. The harness supplies `GPIO_TypeDef` and `main()`.
@@@ starter_code
#include <stdint.h>

/* GPIO_TypeDef comes from the vendor header (see statement). */

void gpio_set_mode(GPIO_TypeDef *port, unsigned pin, uint32_t mode)
{
    port->MODER |= (mode & 0x3u) << (pin * 2u);
}

void gpio_set_otype(GPIO_TypeDef *port, unsigned pin, uint32_t open_drain)
{
    if (open_drain)
        port->OTYPER |= 1u << pin;
    else
        port->OTYPER &= ~(1u << pin);
}

void gpio_set_af(GPIO_TypeDef *port, unsigned pin, uint32_t af)
{
    volatile uint32_t *afr = (pin < 8u) ? &port->AFRL : &port->AFRH;
    unsigned shift = (pin & 7u) * 4u;
    *afr = (*afr & ~(0xFu << shift)) | ((af & 0xFu) << shift);
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t AFRL;
    volatile uint32_t AFRH;
} GPIO_TypeDef;

/*USER_CODE*/

int main(void)
{
    static GPIO_TypeDef port;
    unsigned reset;
    int q;
    if (scanf("%x %d", &reset, &q) != 2) return 0;
    port.MODER = reset;
    port.OTYPER = 0u;
    port.AFRL = 0u;
    port.AFRH = 0u;
    for (int i = 0; i < q; i++) {
        char op;
        unsigned pin, val;
        if (scanf(" %c %u %u", &op, &pin, &val) != 3 || pin > 15u) return 0;
        if (op == 'M')
            gpio_set_mode(&port, pin, val);
        else if (op == 'O')
            gpio_set_otype(&port, pin, val);
        else
            gpio_set_af(&port, pin, val);
        printf("MODER=%08X OTYPER=%08X AFRL=%08X AFRH=%08X\n", (unsigned)port.MODER,
               (unsigned)port.OTYPER, (unsigned)port.AFRL, (unsigned)port.AFRH);
    }
    return 0;
}
@@@ sample_input
00000000 3
M 5 1
O 5 1
A 5 7
@@@ sample_output
MODER=00000400 OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=00000400 OTYPER=00000020 AFRL=00000000 AFRH=00000000
MODER=00000400 OTYPER=00000020 AFRL=00700000 AFRH=00000000

@@@ sample_input
FFFFFFFF 1
M 5 1
@@@ sample_output
MODER=FFFFF7FF OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hidden_input
ABFFFFFF 3
M 13 2
M 0 1
M 15 0
@@@ hidden_output
MODER=ABFFFFFF OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=ABFFFFFD OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=2BFFFFFD OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hidden_input
00000000 2
M 15 3
M 15 1
@@@ hidden_output
MODER=C0000000 OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=40000000 OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hidden_input
00000000 5
A 9 7
A 10 7
A 9 4
M 9 2
M 10 2
@@@ hidden_output
MODER=00000000 OTYPER=00000000 AFRL=00000000 AFRH=00000070
MODER=00000000 OTYPER=00000000 AFRL=00000000 AFRH=00000770
MODER=00000000 OTYPER=00000000 AFRL=00000000 AFRH=00000740
MODER=00080000 OTYPER=00000000 AFRL=00000000 AFRH=00000740
MODER=00280000 OTYPER=00000000 AFRL=00000000 AFRH=00000740

@@@ hidden_input
00000000 3
M 3 1
M 3 2
M 3 0
@@@ hidden_output
MODER=00000040 OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=00000080 OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=00000000 OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hidden_input
55555555 2
M 7 3
M 7 0
@@@ hidden_output
MODER=5555D555 OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=55551555 OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hidden_input
FFFFFFFF 4
M 2 5
O 2 1
O 2 0
M 14 0
@@@ hidden_output
MODER=FFFFFFDF OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=FFFFFFDF OTYPER=00000004 AFRL=00000000 AFRH=00000000
MODER=FFFFFFDF OTYPER=00000000 AFRL=00000000 AFRH=00000000
MODER=CFFFFFDF OTYPER=00000000 AFRL=00000000 AFRH=00000000

@@@ hint
OR (`|=`) can only turn bits **on**. What happens to a 2-bit field that currently holds `11` (analog) when you OR `01` (output) into it?
@@@ hint
A multi-bit field update is a read-modify-write in two steps: first **clear** the whole field with `& ~(mask << shift)`, then OR in the new value. Compare with `gpio_set_af`, which does it right.
@@@ solution_code
#include <stdint.h>

/* GPIO_TypeDef comes from the vendor header (see statement). */

void gpio_set_mode(GPIO_TypeDef *port, unsigned pin, uint32_t mode)
{
    unsigned shift = pin * 2u;
    /* FIX: clear the 2-bit field before OR-ing the new mode in */
    port->MODER = (port->MODER & ~(0x3u << shift)) | ((mode & 0x3u) << shift);
}

void gpio_set_otype(GPIO_TypeDef *port, unsigned pin, uint32_t open_drain)
{
    if (open_drain)
        port->OTYPER |= 1u << pin;
    else
        port->OTYPER &= ~(1u << pin);
}

void gpio_set_af(GPIO_TypeDef *port, unsigned pin, uint32_t af)
{
    volatile uint32_t *afr = (pin < 8u) ? &port->AFRL : &port->AFRH;
    unsigned shift = (pin & 7u) * 4u;
    *afr = (*afr & ~(0xFu << shift)) | ((af & 0xFu) << shift);
}
@@@ explanation_md
**Bug.** `gpio_set_mode` only ORs the new value into `MODER`. OR can set bits but never clear them, so the result is `old_field | new_mode`. On a chip that resets to `00`, the field starts empty and the bug is invisible. On a chip that resets to analog `11`, `11 | 01 = 11`, so the pin stays analog and never drives.

```
MODER (pin 5) = ...11 11 11...   reset: analog
|= 01 << 10   = ...11 11 11...   still analog  (bug)
clear, then OR = ...11 01 11...  output        (fix)
```

**Fix.** The standard read-modify-write: `reg = (reg & ~(FIELD_MASK << shift)) | ((value & FIELD_MASK) << shift);`. Read once, clear the field, insert the masked value, write once. The other two functions already follow this rule: single bits use `|=`/`&= ~`, and `gpio_set_af` clears before setting.

**Complexity.** O(1) time and space per call.

**Common mistakes**
- Fixing it with two separate statements (`MODER &= ~mask; MODER |= val;`). It works, but it performs two volatile writes, and for a moment the pin is briefly configured as **input** (00). That is a glitch on a pin that is driving a relay or a CAN transceiver's standby line.
- Not masking `mode` (`mode << shift`). A bad value such as 5 then overwrites the neighbouring pin's field. The hidden test `M 2 5` checks this.
- Forgetting that a read-modify-write on a register shared with an ISR is **not atomic**. Disable interrupts around it, or use the port's atomic set/reset register (`BSRR`) for output levels.

**Interview follow-ups**
- Why did ST change the reset value of `MODER` to analog on newer families (power consumption, Schmitt-trigger leakage)? What breaks in drivers ported from the STM32F1/F4?
- Write a generic `WRITE_FIELD(reg, mask, shift, val)` macro that evaluates `reg` only once.
- Which STM32 registers must **not** be written with read-modify-write at all? (Write-1-to-clear status registers such as `EXTI_PR`, and the `BSRR` set/reset register.)
- How would you make `gpio_set_mode` safe to call from both the main loop and an ISR?
