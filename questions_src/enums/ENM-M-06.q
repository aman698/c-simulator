@@@ meta
id: ENM-M-06
topic: Enums
difficulty: Medium
type: FUNCTION
title: ECU Power-Mode Transitions Gated by Enum Bit Masks
tags: embedded, mode-mask, bitmask, power-management, enum-as-bit-index
@@@ statement_md
An ECU's power manager switches between six power modes. Which transitions are allowed, and which software features may run in each mode, are both stored as **mode masks**: bit `m` of a mask stands for `PowerMode m`. The judge defines the enums and tables, so do not redefine them:

```c
typedef enum { PM_OFF, PM_SLEEP, PM_STANDBY, PM_NORMAL, PM_DIAG, PM_FLASH, PM_COUNT } PowerMode;
#define PM_BIT(m) (1u << (m))

typedef enum { F_CAN_RX, F_CAN_TX, F_NVM_WRITE, F_HEATER, F_DIAG, F_REPROG, F_LIN_WAKE, F_COUNT } Feature;

/* pm_allowed_from[target]: modes from which `target` may be entered */
static const uint32_t pm_allowed_from[PM_COUNT] = {
    [PM_OFF]     = PM_BIT(PM_SLEEP) | PM_BIT(PM_STANDBY),
    [PM_SLEEP]   = PM_BIT(PM_STANDBY),
    [PM_STANDBY] = PM_BIT(PM_OFF) | PM_BIT(PM_SLEEP) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG),
    [PM_NORMAL]  = PM_BIT(PM_STANDBY) | PM_BIT(PM_DIAG),
    [PM_DIAG]    = PM_BIT(PM_NORMAL) | PM_BIT(PM_FLASH),
    [PM_FLASH]   = PM_BIT(PM_DIAG),
};

/* feature_modes[f]: modes in which feature f may run */
static const uint32_t feature_modes[F_COUNT] = {
    [F_CAN_RX]    = PM_BIT(PM_STANDBY) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_CAN_TX]    = PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_NVM_WRITE] = PM_BIT(PM_STANDBY) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG),
    [F_HEATER]    = PM_BIT(PM_NORMAL),
    [F_DIAG]      = PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_REPROG]    = PM_BIT(PM_FLASH),
    [F_LIN_WAKE]  = PM_BIT(PM_SLEEP) | PM_BIT(PM_STANDBY),
};
```

Implement

```c
int pm_request(PowerMode *cur, int target, uint32_t *enabled, uint32_t *disabled);
```

`target` is a raw value from a CAN mode request, so it can be anything.
1. If `target` is not a valid `PowerMode` (`0 .. PM_COUNT-1`), **reject**.
2. If `target == *cur`, **accept** with no change (`*enabled = *disabled = 0`).
3. If `*cur` is not in `pm_allowed_from[target]`, **reject**.
4. Otherwise **accept**. Set `*enabled` to the features that may run in the new mode but not in the old one, and `*disabled` to the features that may run in the old mode but not in the new one. Both are **feature masks**, where bit `f` stands for `Feature f`. Then set `*cur = target`.

Return 1 when accepted. On reject, return 0, leave `*cur` unchanged and set both masks to 0.

**How it is tested.** The harness starts in `PM_OFF` and sends raw targets. For each one it prints `FROM -> TO: +FEAT ... -FEAT ...` (in `Feature` order), `FROM -> TO: no change`, or `FROM -> TO: REJECTED`. An invalid target prints as `#<value>`.

**Example**
```
Input:
4
2 3 4 5

Output:
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE
NORMAL -> DIAG: +DIAG -HEATER
DIAG -> FLASH: +REPROG -NVM_WRITE
```
@@@ constraints_md
- `1 <= n <= 50` requests. Targets are any 32-bit `int`.
- Never shift by an unvalidated amount: `1u << 32` and `1u << -1` are undefined behavior.
@@@ starter_code
/*
 * Provided by the judge (do not redefine): PowerMode, PM_BIT(m), Feature,
 * pm_allowed_from[PM_COUNT], feature_modes[F_COUNT]  (see the statement).
 */
#include <stdint.h>

int pm_request(PowerMode *cur, int target, uint32_t *enabled, uint32_t *disabled)
{
    /* TODO */
    (void)cur;
    (void)target;
    *enabled = 0;
    *disabled = 0;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

typedef enum { PM_OFF, PM_SLEEP, PM_STANDBY, PM_NORMAL, PM_DIAG, PM_FLASH, PM_COUNT } PowerMode;
#define PM_BIT(m) (1u << (m))

typedef enum { F_CAN_RX, F_CAN_TX, F_NVM_WRITE, F_HEATER, F_DIAG, F_REPROG, F_LIN_WAKE, F_COUNT } Feature;

static const uint32_t pm_allowed_from[PM_COUNT] = {
    [PM_OFF]     = PM_BIT(PM_SLEEP) | PM_BIT(PM_STANDBY),
    [PM_SLEEP]   = PM_BIT(PM_STANDBY),
    [PM_STANDBY] = PM_BIT(PM_OFF) | PM_BIT(PM_SLEEP) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG),
    [PM_NORMAL]  = PM_BIT(PM_STANDBY) | PM_BIT(PM_DIAG),
    [PM_DIAG]    = PM_BIT(PM_NORMAL) | PM_BIT(PM_FLASH),
    [PM_FLASH]   = PM_BIT(PM_DIAG),
};

static const uint32_t feature_modes[F_COUNT] = {
    [F_CAN_RX]    = PM_BIT(PM_STANDBY) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_CAN_TX]    = PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_NVM_WRITE] = PM_BIT(PM_STANDBY) | PM_BIT(PM_NORMAL) | PM_BIT(PM_DIAG),
    [F_HEATER]    = PM_BIT(PM_NORMAL),
    [F_DIAG]      = PM_BIT(PM_DIAG) | PM_BIT(PM_FLASH),
    [F_REPROG]    = PM_BIT(PM_FLASH),
    [F_LIN_WAKE]  = PM_BIT(PM_SLEEP) | PM_BIT(PM_STANDBY),
};

/*USER_CODE*/

static const char *const h_mode[PM_COUNT] = { "OFF", "SLEEP", "STANDBY", "NORMAL", "DIAG", "FLASH" };
static const char *const h_feat[F_COUNT] = { "CAN_RX", "CAN_TX", "NVM_WRITE", "HEATER", "DIAG", "REPROG", "LIN_WAKE" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    PowerMode cur = PM_OFF;
    for (int i = 0; i < n; i++) {
        int t;
        if (scanf("%d", &t) != 1) return 0;
        PowerMode before = cur;
        uint32_t en = 0xDEADBEEFu, dis = 0xDEADBEEFu;
        int ok = pm_request(&cur, t, &en, &dis);
        printf("%s -> ", h_mode[before]);
        if (t >= 0 && t < PM_COUNT) printf("%s:", h_mode[t]);
        else printf("#%d:", t);
        if (!ok) {
            printf(" REJECTED%s\n", (cur != before || en != 0 || dis != 0) ? " (BAD OUTPUTS)" : "");
            continue;
        }
        if ((int)cur != t) { printf(" BAD STATE\n"); return 0; }
        if ((en | dis) >> F_COUNT) { printf(" BAD MASK\n"); return 0; }
        if (en == 0 && dis == 0) { printf(" no change\n"); continue; }
        for (int f = 0; f < F_COUNT; f++) if (en & (1u << f)) printf(" +%s", h_feat[f]);
        for (int f = 0; f < F_COUNT; f++) if (dis & (1u << f)) printf(" -%s", h_feat[f]);
        printf("\n");
    }
    return 0;
}
@@@ sample_input
4
2 3 4 5
@@@ sample_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE
NORMAL -> DIAG: +DIAG -HEATER
DIAG -> FLASH: +REPROG -NVM_WRITE

@@@ sample_input
3
5 6 -1
@@@ sample_output
OFF -> FLASH: REJECTED
OFF -> #6: REJECTED
OFF -> #-1: REJECTED

@@@ hidden_input
2
0 2
@@@ hidden_output
OFF -> OFF: no change
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE

@@@ hidden_input
4
2 1 0 1
@@@ hidden_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> SLEEP: -CAN_RX -NVM_WRITE
SLEEP -> OFF: -LIN_WAKE
OFF -> SLEEP: REJECTED

@@@ hidden_input
6
2 3 4 5 3 4
@@@ hidden_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE
NORMAL -> DIAG: +DIAG -HEATER
DIAG -> FLASH: +REPROG -NVM_WRITE
FLASH -> NORMAL: REJECTED
FLASH -> DIAG: +NVM_WRITE -REPROG

@@@ hidden_input
3
2147483647 -2147483648 32
@@@ hidden_output
OFF -> #2147483647: REJECTED
OFF -> #-2147483648: REJECTED
OFF -> #32: REJECTED

@@@ hidden_input
5
2 3 4 2 3
@@@ hidden_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE
NORMAL -> DIAG: +DIAG -HEATER
DIAG -> STANDBY: +LIN_WAKE -CAN_TX -DIAG
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE

@@@ hidden_input
3
2 0 4
@@@ hidden_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> OFF: -CAN_RX -NVM_WRITE -LIN_WAKE
OFF -> DIAG: REJECTED

@@@ hidden_input
4
2 3 3 1
@@@ hidden_output
OFF -> STANDBY: +CAN_RX +NVM_WRITE +LIN_WAKE
STANDBY -> NORMAL: +CAN_TX +HEATER -LIN_WAKE
NORMAL -> NORMAL: no change
NORMAL -> SLEEP: REJECTED

@@@ hint
Write a helper `uint32_t features_in(PowerMode m)` that loops over `f < F_COUNT` and sets bit `f` when `feature_modes[f] & PM_BIT(m)`. The transition check is one AND: `pm_allowed_from[target] & PM_BIT(*cur)`.
@@@ hint
Validate `target` **before** using it as an array index or a shift count. The set differences are `new & ~old` (enabled) and `old & ~new` (disabled).
@@@ solution_code
#include <stdint.h>

static uint32_t features_in(PowerMode m)
{
    uint32_t set = 0;
    for (int f = 0; f < F_COUNT; f++)
        if (feature_modes[f] & PM_BIT(m))
            set |= 1u << f;
    return set;
}

int pm_request(PowerMode *cur, int target, uint32_t *enabled, uint32_t *disabled)
{
    *enabled = 0;
    *disabled = 0;

    if (target < 0 || target >= PM_COUNT)           /* raw CAN value: validate first */
        return 0;
    if (target == (int)*cur)                        /* already there: accepted, nothing to do */
        return 1;
    if ((pm_allowed_from[target] & PM_BIT(*cur)) == 0u)
        return 0;                                   /* transition not allowed from here */

    uint32_t old_f = features_in(*cur);
    uint32_t new_f = features_in((PowerMode)target);
    *enabled  = new_f & ~old_f;
    *disabled = old_f & ~new_f;
    *cur = (PowerMode)target;
    return 1;
}
@@@ explanation_md
**Approach.** Contiguous enumerators starting at 0 make perfect **bit indices**. `PM_BIT(m)` turns one mode into a one-bit mask, and a whole set of modes is the OR of such bits. Two different kinds of mask are in play:
- **mode masks** (bit = `PowerMode`): `pm_allowed_from[target]` and `feature_modes[f]`;
- **feature masks** (bit = `Feature`): the result values.

"Is the transition allowed?" is one AND. To get the feature set of a mode, *transpose* the table: feature `f` is in mode `m`'s set when `feature_modes[f]` contains `PM_BIT(m)`. The diff between two sets is plain set algebra: `new & ~old` were switched on, `old & ~new` were switched off. Validation comes first, because `target` indexes an array **and** is used as a shift count. `1u << 32` and `1u << -1` are undefined behavior, and UBSan flags them.

**Complexity.** Time O(F) per request (F = number of features), space O(1).

**Common mistakes**
- Using a mode index where a mode mask is expected: `pm_allowed_from[target] & *cur` instead of `& PM_BIT(*cur)`. It passes for some modes by accident (`PM_SLEEP == 1 == PM_BIT(PM_OFF)`).
- Range-checking only the upper bound. `target = -1` then reads `pm_allowed_from[-1]`.
- Computing `disabled` as `~new_f`. That also sets all the bits above `F_COUNT`.
- Leaving `*enabled`/`*disabled` unset on reject. The caller would act on garbage, which the harness catches by pre-filling `0xDEADBEEF`.
- Rejecting a same-mode request. A repeated CAN request for the current mode is normal and must be harmless.

**Interview follow-ups**
- How would you check at compile time that no feature is allowed in `PM_OFF`? (`_Static_assert` cannot see array contents in C, so use a unit test, or build the masks from X-macros with constant expressions.)
- What changes if there are more than 32 modes or features?
- The feature enable and disable actions have side effects (switching CAN transceivers, heater relays). In which order should you execute them during a transition, and why?
