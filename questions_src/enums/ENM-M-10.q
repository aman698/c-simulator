@@@ meta
id: ENM-M-10
topic: Enums
difficulty: Medium
type: FUNCTION
title: Instrument Cluster Chime Arbitration by Priority Enum
tags: embedded, priority, arbitration, enum-indexed-table, instrument-cluster
@@@ statement_md
The instrument cluster has one speaker but many warnings. An arbiter decides which chime plays. The judge defines these enums, so do not redefine them:

```c
/* Lower value = MORE urgent (like CAN arbitration: the lowest ID wins). */
typedef enum { PRIO_CRITICAL, PRIO_HIGH, PRIO_MEDIUM, PRIO_LOW } ChimePrio;

typedef enum {
    W_SEATBELT, W_DOOR_OPEN, W_LOW_FUEL, W_OVERSPEED,
    W_BRAKE_FAIL, W_LIGHTS_ON, W_KEY_IN, W_TPMS, W_COUNT
} Warning;
```

Priorities (put them in an enum-indexed table in your code):

| warning | priority | warning | priority |
|---|---|---|---|
| `W_SEATBELT` | `HIGH` | `W_BRAKE_FAIL` | `CRITICAL` |
| `W_DOOR_OPEN` | `MEDIUM` | `W_LIGHTS_ON` | `LOW` |
| `W_LOW_FUEL` | `LOW` | `W_KEY_IN` | `MEDIUM` |
| `W_OVERSPEED` | `HIGH` | `W_TPMS` | `MEDIUM` |

Implement

```c
int chime_arbitrate(uint32_t active_mask, int playing);
```

- Bit `w` of `active_mask` means warning `w` is active. Bits at position `W_COUNT` and above are noise and must be ignored.
- The **best** active warning is the one with the most urgent priority. Ties go to the lowest `Warning` value.
- `playing` is the warning that is currently playing, or any other value (for example -1) if none is. If `playing` is a valid warning **and still active**, it keeps playing, **unless** the best warning is **strictly** more urgent. In that case the best one preempts it. Equal priority never preempts.
- Otherwise return the best active warning, or `-1` if none is active.

**How it is tested.** The harness keeps the mask and `playing` (starting at -1). After each `ON <name>`, `OFF <name>` or `MASK <hex>` event it calls your function, prints the result (`NAME` or `NONE`) and stores it as the new `playing`. `PLAY <int>` overwrites `playing` with a raw value (corruption) and prints nothing.

**Example**
```
Input:
5
ON DOOR_OPEN
ON SEATBELT
ON KEY_IN
OFF SEATBELT
ON BRAKE_FAIL

Output:
DOOR_OPEN
SEATBELT
SEATBELT
DOOR_OPEN
BRAKE_FAIL
```
@@@ constraints_md
- `1 <= events <= 100`
- `playing` is any `int`. Never index or shift with it before validating it.
@@@ starter_code
/*
 * Provided by the judge (do not redefine):
 *   typedef enum { PRIO_CRITICAL, PRIO_HIGH, PRIO_MEDIUM, PRIO_LOW } ChimePrio;
 *   typedef enum { W_SEATBELT, W_DOOR_OPEN, W_LOW_FUEL, W_OVERSPEED,
 *                  W_BRAKE_FAIL, W_LIGHTS_ON, W_KEY_IN, W_TPMS, W_COUNT } Warning;
 */
#include <stdint.h>

/* TODO: priority table indexed by Warning */

int chime_arbitrate(uint32_t active_mask, int playing)
{
    /* TODO */
    (void)active_mask;
    (void)playing;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef enum { PRIO_CRITICAL, PRIO_HIGH, PRIO_MEDIUM, PRIO_LOW } ChimePrio;

typedef enum {
    W_SEATBELT, W_DOOR_OPEN, W_LOW_FUEL, W_OVERSPEED,
    W_BRAKE_FAIL, W_LIGHTS_ON, W_KEY_IN, W_TPMS, W_COUNT
} Warning;

/*USER_CODE*/

static const char *const h_warn[W_COUNT] = {
    "SEATBELT", "DOOR_OPEN", "LOW_FUEL", "OVERSPEED", "BRAKE_FAIL", "LIGHTS_ON", "KEY_IN", "TPMS"
};

static int h_find(const char *s)
{
    for (int w = 0; w < W_COUNT; w++)
        if (strcmp(s, h_warn[w]) == 0) return w;
    return -1;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    uint32_t mask = 0;
    int playing = -1;
    for (int i = 0; i < n; i++) {
        char cmd[8], arg[24];
        if (scanf("%7s %23s", cmd, arg) != 2) return 0;
        if (strcmp(cmd, "PLAY") == 0) {
            if (sscanf(arg, "%d", &playing) != 1) return 0;
            continue;
        }
        if (strcmp(cmd, "MASK") == 0) {
            unsigned v;
            if (sscanf(arg, "%x", &v) != 1) return 0;
            mask = v;
        } else {
            int w = h_find(arg);
            if (w < 0) return 0;
            if (strcmp(cmd, "ON") == 0) mask |= 1u << w;
            else mask &= ~(1u << w);
        }
        int r = chime_arbitrate(mask, playing);
        if (r == -1) printf("NONE\n");
        else if (r >= 0 && r < W_COUNT) printf("%s\n", h_warn[r]);
        else printf("BAD RESULT %d\n", r);
        playing = r;
    }
    return 0;
}
@@@ sample_input
5
ON DOOR_OPEN
ON SEATBELT
ON KEY_IN
OFF SEATBELT
ON BRAKE_FAIL
@@@ sample_output
DOOR_OPEN
SEATBELT
SEATBELT
DOOR_OPEN
BRAKE_FAIL

@@@ sample_input
4
ON TPMS
ON DOOR_OPEN
OFF TPMS
OFF DOOR_OPEN
@@@ sample_output
TPMS
TPMS
DOOR_OPEN
NONE

@@@ hidden_input
2
MASK FFFFFF00
MASK 1FF
@@@ hidden_output
NONE
BRAKE_FAIL

@@@ hidden_input
4
ON LOW_FUEL
ON LIGHTS_ON
PLAY 99
OFF LOW_FUEL
@@@ hidden_output
LOW_FUEL
LOW_FUEL
LIGHTS_ON

@@@ hidden_input
5
ON OVERSPEED
PLAY 3
ON SEATBELT
PLAY -7
ON DOOR_OPEN
@@@ hidden_output
OVERSPEED
OVERSPEED
SEATBELT

@@@ hidden_input
3
ON KEY_IN
PLAY 4
OFF LOW_FUEL
@@@ hidden_output
KEY_IN
KEY_IN

@@@ hidden_input
1
OFF SEATBELT
@@@ hidden_output
NONE

@@@ hidden_input
3
ON LIGHTS_ON
ON BRAKE_FAIL
ON LOW_FUEL
@@@ hidden_output
LIGHTS_ON
BRAKE_FAIL
BRAKE_FAIL

@@@ hidden_input
6
MASK FF
OFF BRAKE_FAIL
OFF SEATBELT
OFF OVERSPEED
OFF DOOR_OPEN
OFF KEY_IN
@@@ hidden_output
BRAKE_FAIL
SEATBELT
OVERSPEED
DOOR_OPEN
KEY_IN
TPMS

@@@ hint
Use `static const ChimePrio warn_prio[W_COUNT] = { [W_SEATBELT] = PRIO_HIGH, ... };`. Then scan `w = 0 .. W_COUNT-1` and keep the active one with the **smallest** priority value. Using strict `<` automatically keeps the lowest index on ties.
@@@ hint
Check `playing` last. It wins only if `0 <= playing < W_COUNT`, its bit is set in the mask, and `!(warn_prio[best] < warn_prio[playing])`.
@@@ solution_code
#include <stdint.h>

static const ChimePrio warn_prio[W_COUNT] = {
    [W_SEATBELT]   = PRIO_HIGH,
    [W_DOOR_OPEN]  = PRIO_MEDIUM,
    [W_LOW_FUEL]   = PRIO_LOW,
    [W_OVERSPEED]  = PRIO_HIGH,
    [W_BRAKE_FAIL] = PRIO_CRITICAL,
    [W_LIGHTS_ON]  = PRIO_LOW,
    [W_KEY_IN]     = PRIO_MEDIUM,
    [W_TPMS]       = PRIO_MEDIUM,
};
_Static_assert(sizeof warn_prio / sizeof warn_prio[0] == W_COUNT, "priority table size");

int chime_arbitrate(uint32_t active_mask, int playing)
{
    int best = -1;
    for (int w = 0; w < W_COUNT; w++) {          /* bits >= W_COUNT are never looked at */
        if (!(active_mask & (1u << w)))
            continue;
        if (best < 0 || warn_prio[w] < warn_prio[best])   /* smaller value = more urgent */
            best = w;
    }
    if (best < 0)
        return -1;

    if (playing >= 0 && playing < W_COUNT && (active_mask & (1u << playing))
        && !(warn_prio[best] < warn_prio[playing]))
        return playing;                          /* no preemption by equal or lower priority */
    return best;
}
@@@ explanation_md
**Approach.**
1. **Enum-indexed table.** `warn_prio[W_COUNT]` with designated initializers maps every warning to its priority. The `_Static_assert` together with the `[W_COUNT]` size documents that every warning has an entry.
2. **Scan for the best.** Loop over `w < W_COUNT`, which also ignores noise bits automatically, and keep the active warning with the smallest priority value. A strict `<` keeps the first, lowest-index candidate on ties.
3. **Hysteresis / no preemption.** The currently playing chime is kept unless a *strictly* more urgent one is active. Without this rule, two `MEDIUM` warnings that toggle in turn would restart the chime every cycle (chime "ping-pong").
4. **Validation.** `playing` comes from outside the function and may be corrupted, so it is range-checked before it is used as an index or a shift count.

**Complexity.** Time O(W) per call (W = 8), space O(W) for the table.

**Common mistakes**
- **Priority direction.** `PRIO_CRITICAL` is 0. Picking the *largest* value selects `LOW` warnings over a brake failure.
- `<=` instead of `<` in the scan, which picks the *highest* index on ties.
- Preempting on equal priority, which fails the `TPMS`/`DOOR_OPEN` sample.
- Shifting by an unvalidated `playing` (`1u << 99` is undefined behavior) or indexing `warn_prio[-7]`.
- Looping over all 32 bits of the mask and indexing `warn_prio[w]` for `w >= W_COUNT`, an out-of-bounds read triggered by noise bits.

**Interview follow-ups**
- Add a minimum on-time: a playing chime cannot be preempted during its first 500 ms unless the new warning is `CRITICAL`. What state does the arbiter need?
- Why does CAN use "lower identifier = higher priority", and how does bitwise arbitration on the bus achieve it?
- With 200 warnings, how would you make arbitration O(1) per event? (A priority-indexed bitmap and "find first set", as in RTOS ready queues.)
