@@@ meta
id: PTR-H-03
topic: Pointers
difficulty: Hard
type: FUNCTION
title: Simulated Interrupt Vector Table with Priorities and Tail-Chaining
tags: embedded, function-pointer, vector-table, isr, interrupt-controller, asked-in-automotive
@@@ statement_md
On a Cortex-M, the **vector table** is an array of function pointers: entry *n* is the address of the handler for interrupt *n*. Unused entries point to a weak `Default_Handler`. Implement a small software model of an interrupt controller with 16 IRQs:

```c
typedef void (*isr_t)(void);
#define NUM_IRQ 16

void  nvic_init(void);
isr_t nvic_set_handler(int irq, isr_t handler);
int   nvic_set_priority(int irq, int prio);
void  nvic_set_pending(int irq);
int   nvic_active(void);
int   nvic_dispatch(void);
```

`void default_isr(void);` is provided by the platform (declared before your code).

- **`nvic_init`**: every vector is set to `default_isr`, every priority to 0, nothing is pending, and no IRQ is active.
- **`nvic_set_handler(irq, h)`**:
  - Install `h` for `irq` and return the handler that was installed **before** (like `signal()`).
  - `h == NULL` restores `default_isr`.
  - If `irq` is outside `0..15`, change nothing and return `NULL`.
- **`nvic_set_priority(irq, prio)`**: `prio` is in `0..7`, and a **lower number means higher priority**. Return `0`, or `-1` (and change nothing) for an invalid `irq` or `prio`.
- **`nvic_set_pending(irq)`**: mark `irq` as pending. Invalid numbers are ignored. Handlers may call it (an interrupt can trigger another one).
- **`nvic_active()`**: the IRQ whose handler is currently running inside `nvic_dispatch`, or `-1` outside of any handler.
- **`nvic_dispatch()`**: while something is pending:
  1. Select the pending IRQ with the **highest priority** (lowest number). Ties go to the **lower IRQ number**.
  2. Clear its pending bit **before** calling its vector (so the handler can re-trigger it).
  3. Make it active, call the vector, then make no IRQ active again.

  There is no preemption: newly pending IRQs are served after the current handler returns (tail-chaining). Return the number of handlers executed. If **64** handlers have run and an IRQ is still pending, stop and return `-1` (interrupt storm); the remaining pending bits stay set.

**How it is tested.** The harness calls `nvic_init()` once, then runs commands. Handlers print their name, prefixed by two spaces:
- `tick`, `uart`
- `can` (also pends IRQ 3)
- `adc` (also pends IRQ 0)
- `storm` (re-pends `nvic_active()` and prints nothing; `stormcount` prints how often it ran)
- `default_isr` prints `default(irq=N)` using `nvic_active()`.

**Commands**
- `vec IRQ NAME` (`NAME` is one of the handlers or `none` for `NULL`): prints `vec IRQ -> prev=<name of returned handler>`, where `NULL` is printed as `NULL`.
- `prio IRQ P`: prints `prio IRQ -> R`.
- `pend IRQ`: prints nothing.
- `run`: prints the handler output, then `run -> R`.
- `active`: prints `active -> R`.
- `stormcount`: prints `stormcount -> N`.

**Example**
```
Input:
vec 2 tick
vec 5 uart
prio 5 1
prio 2 3
pend 2
pend 5
pend 7
run

Output:
vec 2 -> prev=default
vec 5 -> prev=default
prio 5 -> 0
prio 2 -> 0
  default(irq=7)
  uart
  tick
run -> 3
```
IRQ 7 still has the default priority 0, so it runs first.
@@@ constraints_md
- 16 IRQs (`0..15`), priorities `0..7`, at most 60 commands.
- No dynamic memory.
- `nvic_dispatch` must stop after 64 handler executions if IRQs are still pending.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

typedef void (*isr_t)(void);
#define NUM_IRQ 16

/* provided by the platform: void default_isr(void); */

void nvic_init(void)
{
    /* TODO */
}

isr_t nvic_set_handler(int irq, isr_t handler)
{
    /* TODO: return the previously installed handler */
    (void)irq;
    (void)handler;
    return NULL;
}

int nvic_set_priority(int irq, int prio)
{
    /* TODO */
    (void)irq;
    (void)prio;
    return -1;
}

void nvic_set_pending(int irq)
{
    /* TODO */
    (void)irq;
}

int nvic_active(void)
{
    /* TODO */
    return -1;
}

int nvic_dispatch(void)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

void default_isr(void);

/*USER_CODE*/

static int storm_count;

void default_isr(void) { printf("  default(irq=%d)\n", nvic_active()); }
static void isr_tick(void) { printf("  tick\n"); }
static void isr_uart(void) { printf("  uart\n"); }
static void isr_can(void) { printf("  can\n"); nvic_set_pending(3); }
static void isr_adc(void) { printf("  adc\n"); nvic_set_pending(0); }
static void isr_storm(void) { storm_count++; nvic_set_pending(nvic_active()); }

static const struct { const char *name; isr_t fn; } known[] = {
    {"default", default_isr}, {"tick", isr_tick}, {"uart", isr_uart},
    {"can", isr_can}, {"adc", isr_adc}, {"storm", isr_storm},
};
#define NKNOWN (sizeof known / sizeof known[0])

static const char *name_of(isr_t f)
{
    if (f == NULL) return "NULL";
    for (size_t i = 0; i < NKNOWN; i++)
        if (known[i].fn == f) return known[i].name;
    return "UNKNOWN";
}

static isr_t fn_of(const char *s)
{
    for (size_t i = 0; i < NKNOWN; i++)
        if (strcmp(known[i].name, s) == 0) return known[i].fn;
    return NULL;
}

int main(void)
{
    char cmd[16];
    nvic_init();
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "vec") == 0) {
            int irq;
            char nm[16];
            if (scanf("%d %15s", &irq, nm) != 2) return 0;
            printf("vec %d -> prev=%s\n", irq, name_of(nvic_set_handler(irq, fn_of(nm))));
        } else if (strcmp(cmd, "prio") == 0) {
            int irq, p;
            if (scanf("%d %d", &irq, &p) != 2) return 0;
            printf("prio %d -> %d\n", irq, nvic_set_priority(irq, p));
        } else if (strcmp(cmd, "pend") == 0) {
            int irq;
            if (scanf("%d", &irq) != 1) return 0;
            nvic_set_pending(irq);
        } else if (strcmp(cmd, "run") == 0) {
            int r = nvic_dispatch();
            printf("run -> %d\n", r);
        } else if (strcmp(cmd, "active") == 0) {
            printf("active -> %d\n", nvic_active());
        } else if (strcmp(cmd, "stormcount") == 0) {
            printf("stormcount -> %d\n", storm_count);
        }
    }
    return 0;
}
@@@ sample_input
vec 2 tick
vec 5 uart
prio 5 1
prio 2 3
pend 2
pend 5
pend 7
run
@@@ sample_output
vec 2 -> prev=default
vec 5 -> prev=default
prio 5 -> 0
prio 2 -> 0
  default(irq=7)
  uart
  tick
run -> 3

@@@ sample_input
vec 4 can
vec 4 tick
vec 4 none
vec 16 tick
vec -1 tick
prio 3 8
prio 16 0
active
@@@ sample_output
vec 4 -> prev=default
vec 4 -> prev=can
vec 4 -> prev=tick
vec 16 -> prev=NULL
vec -1 -> prev=NULL
prio 3 -> -1
prio 16 -> -1
active -> -1

@@@ hidden_input
vec 4 can
vec 3 uart
prio 3 5
prio 4 2
pend 4
run
pend 3
pend 4
run
@@@ hidden_output
vec 4 -> prev=default
vec 3 -> prev=default
prio 3 -> 0
prio 4 -> 0
  can
  uart
run -> 2
  can
  uart
run -> 2

@@@ hidden_input
vec 9 storm
pend 9
run
stormcount
active
run
stormcount
@@@ hidden_output
vec 9 -> prev=default
run -> -1
stormcount -> 64
active -> -1
run -> -1
stormcount -> 128

@@@ hidden_input
pend 15
pend 0
pend 8
run
run
active
@@@ hidden_output
  default(irq=0)
  default(irq=8)
  default(irq=15)
run -> 3
run -> 0
active -> -1

@@@ hidden_input
vec 1 adc
vec 0 tick
pend 1
pend 6
run
@@@ hidden_output
vec 1 -> prev=default
vec 0 -> prev=default
  adc
  tick
  default(irq=6)
run -> 3

@@@ hidden_input
vec 12 uart
prio 12 0
prio 0 7
pend 0
pend 12
pend 16
pend -3
run
vec 12 none
pend 12
run
@@@ hidden_output
vec 12 -> prev=default
prio 12 -> 0
prio 0 -> 0
  uart
  default(irq=0)
run -> 2
vec 12 -> prev=uart
  default(irq=12)
run -> 1

@@@ hint
Keep three static arrays/values: `isr_t vectors[NUM_IRQ]`, `uint8_t prio[NUM_IRQ]`, a `uint32_t pending` bitmask, and `int active`. `nvic_set_handler` saves `vectors[irq]` in a local, stores the new handler (or `default_isr` for `NULL`), and returns the saved value.
@@@ hint
In `nvic_dispatch`, scan IRQs 0..15 and keep the best candidate using a strict `<` on priority (ties then keep the lower IRQ number). Clear its pending bit, set `active`, call `vectors[best]()`, reset `active = -1`, and count. Before selecting the next one, check whether you have already run 64 handlers.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

typedef void (*isr_t)(void);
#define NUM_IRQ 16
#define MAX_PRIO 7
#define STORM_LIMIT 64

/* provided by the platform: void default_isr(void); */

static isr_t vectors[NUM_IRQ];        /* the "vector table": array of function pointers */
static uint8_t prio[NUM_IRQ];
static uint32_t pending;              /* bit n = IRQ n pending */
static int active = -1;

void nvic_init(void)
{
    for (int i = 0; i < NUM_IRQ; i++) {
        vectors[i] = default_isr;
        prio[i] = 0;
    }
    pending = 0;
    active = -1;
}

isr_t nvic_set_handler(int irq, isr_t handler)
{
    if (irq < 0 || irq >= NUM_IRQ)
        return NULL;
    isr_t old = vectors[irq];
    vectors[irq] = handler != NULL ? handler : default_isr;
    return old;
}

int nvic_set_priority(int irq, int p)
{
    if (irq < 0 || irq >= NUM_IRQ || p < 0 || p > MAX_PRIO)
        return -1;
    prio[irq] = (uint8_t)p;
    return 0;
}

void nvic_set_pending(int irq)
{
    if (irq >= 0 && irq < NUM_IRQ)
        pending |= 1u << irq;
}

int nvic_active(void)
{
    return active;
}

int nvic_dispatch(void)
{
    int executed = 0;

    while (pending != 0u) {
        if (executed == STORM_LIMIT)
            return -1;                          /* interrupt storm: give up */
        int best = -1;
        for (int i = 0; i < NUM_IRQ; i++)
            if ((pending & (1u << i)) && (best < 0 || prio[i] < prio[best]))
                best = i;                       /* strict <: ties keep the lower IRQ */
        pending &= ~(1u << best);               /* clear BEFORE the call: handler may re-pend */
        active = best;
        vectors[best]();                        /* indirect call through the table */
        active = -1;
        executed++;
    }
    return executed;
}
@@@ explanation_md
**Approach.** The vector table is just `isr_t vectors[16]`, where `isr_t` is `void (*)(void)`. Dispatching interrupt *n* is the indirect call `vectors[n]()`. That is what the Cortex-M hardware does when it loads the handler address from `VTOR + 4 * (16 + n)`.

- *Default handler:* every slot always holds a valid function, so an unexpected IRQ lands in `default_isr` instead of jumping to address 0. On real MCUs, `Default_Handler` is a **weak** symbol that each driver overrides by defining a function with the same name.
- *Function returning a function pointer:* `nvic_set_handler` returns the old handler, so a caller can chain to it or restore it later. Without the typedef the prototype reads `void (*nvic_set_handler(int irq, void (*h)(void)))(void);`.
- *Arbitration:* pick the lowest priority value among the pending bits, with ties broken by the lowest IRQ number (as the NVIC does). Clearing the pending bit *before* calling the handler lets a handler legitimately re-trigger itself or others. Those requests are served afterwards (*tail-chaining*), not recursively.
- *Storm protection:* a handler that keeps re-pending itself would hang the system. A bound turns that into an error the caller can report.

**Complexity.** Each dispatched handler costs an O(NUM_IRQ) scan, so `nvic_dispatch` is O(k * 16) for k handlers (k <= 64). The other functions are O(1). Space O(NUM_IRQ).

**Common mistakes**
- Clearing the pending bit **after** the handler returns. A handler that re-pends its own IRQ is then lost, and the storm limit never triggers.
- Using `<=` in the selection, which breaks the tie rule (the higher IRQ number wins).
- Storing `NULL` for "no handler" and calling it, which is a jump to address 0. On Cortex-M, address 0 holds the initial stack pointer: an immediate HardFault.
- Returning the **new** handler from `nvic_set_handler`, or returning `default_isr` for an invalid IRQ.
- Not resetting `active` to -1 after the handler, so code outside any ISR thinks it is still in interrupt context.

**Interview follow-ups**
- How does a real Cortex-M find the vector table, and why would a bootloader change `SCB->VTOR` before jumping to the application?
- What does `__attribute__((weak, alias("Default_Handler")))` do in a startup file?
- Add preemption: a higher-priority IRQ pended inside a handler runs **immediately** (nested). How does the call stack change, and what is the worst-case stack depth?
- Why must data shared between an ISR and the main loop be `volatile`, and why is that still not enough for a read-modify-write of a 64-bit counter on a 32-bit MCU?
