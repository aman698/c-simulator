@@@ meta
id: ENM-M-08
topic: Enums
difficulty: Medium
type: FIND_THE_BUG
title: Central Locking Auto-Relock Fires One Tick Late
tags: embedded, state-machine, timer, off-by-one, central-locking
@@@ statement_md
A body controller implements **auto-relock**. If the car is unlocked with the remote key and no door is opened, it locks itself again once **at least 30 000 ms** have passed since the unlock. The controller only sees time when an event arrives.

Intended behaviour. On every event at time `t`, **first** run the relock check: if the relock timer is armed and `t - t_unlock >= 30000`, lock the car, disarm the timer and print `<t>: AUTO_RELOCK`. **Then** process the event:

| event | action |
|---|---|
| `RKE_UNLOCK` | state `UNLOCKED`, (re)arm the timer with `t_unlock = t`, print `<t>: UNLOCKED` |
| `RKE_LOCK` | state `LOCKED`, disarm, print `<t>: LOCKED` |
| `DOOR_OPEN` | if the timer is armed: disarm it and print `<t>: TIMER CANCELLED` |
| `TICK` | nothing (it only lets time pass) |
| other | print `<t>: UNKNOWN <token>` |

At the end print `FINAL LOCKED` or `FINAL UNLOCKED`. The car starts `LOCKED` with the timer disarmed.

A HIL test sends a `TICK` exactly 30 000 ms after the unlock and expects the relock at that tick. The ECU only relocks at the **next** event. Find and fix the bug.

**Input**
- Line 1: `n`. Next `n` lines: `t EVENT` with non-decreasing `t` (ms).

**Example**
```
Input:
3
0 RKE_UNLOCK
29999 TICK
30000 TICK

Output:
0: UNLOCKED
30000: AUTO_RELOCK
FINAL LOCKED
```
@@@ constraints_md
- `0 <= n <= 1000`, `0 <= t <= 2147483647`, `t` non-decreasing.
- The fix is one operator.
@@@ starter_code
#include <stdio.h>
#include <string.h>

#define RELOCK_MS 30000

typedef enum { LOCK_LOCKED, LOCK_UNLOCKED } LockState;
typedef enum { EV_RKE_UNLOCK, EV_RKE_LOCK, EV_DOOR_OPEN, EV_TICK, EV_UNKNOWN } LockEvent;

static LockState state = LOCK_LOCKED;
static int relock_armed = 0;
static int t_unlock = 0;

static LockEvent parse(const char *s)
{
    if (strcmp(s, "RKE_UNLOCK") == 0) return EV_RKE_UNLOCK;
    if (strcmp(s, "RKE_LOCK") == 0) return EV_RKE_LOCK;
    if (strcmp(s, "DOOR_OPEN") == 0) return EV_DOOR_OPEN;
    if (strcmp(s, "TICK") == 0) return EV_TICK;
    return EV_UNKNOWN;
}

static void relock_check(int now)
{
    if (relock_armed && now - t_unlock > RELOCK_MS) {
        state = LOCK_LOCKED;
        relock_armed = 0;
        printf("%d: AUTO_RELOCK\n", now);
    }
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        int t;
        char tok[24];
        if (scanf("%d %23s", &t, tok) != 2) break;

        relock_check(t);

        switch (parse(tok)) {
        case EV_RKE_UNLOCK:
            state = LOCK_UNLOCKED;
            relock_armed = 1;
            t_unlock = t;
            printf("%d: UNLOCKED\n", t);
            break;
        case EV_RKE_LOCK:
            state = LOCK_LOCKED;
            relock_armed = 0;
            printf("%d: LOCKED\n", t);
            break;
        case EV_DOOR_OPEN:
            if (relock_armed) {
                relock_armed = 0;
                printf("%d: TIMER CANCELLED\n", t);
            }
            break;
        case EV_TICK:
            break;
        case EV_UNKNOWN:
            printf("%d: UNKNOWN %s\n", t, tok);
            break;
        }
    }
    printf("FINAL %s\n", state == LOCK_LOCKED ? "LOCKED" : "UNLOCKED");
    return 0;
}
@@@ sample_input
4
0 RKE_UNLOCK
10000 TICK
45000 TICK
46000 RKE_UNLOCK
@@@ sample_output
0: UNLOCKED
45000: AUTO_RELOCK
46000: UNLOCKED
FINAL UNLOCKED

@@@ sample_input
3
0 RKE_UNLOCK
29999 TICK
30000 TICK
@@@ sample_output
0: UNLOCKED
30000: AUTO_RELOCK
FINAL LOCKED

@@@ hidden_input
4
1000 RKE_UNLOCK
5000 DOOR_OPEN
40000 TICK
41000 RKE_LOCK
@@@ hidden_output
1000: UNLOCKED
5000: TIMER CANCELLED
41000: LOCKED
FINAL LOCKED

@@@ hidden_input
2
0 RKE_UNLOCK
30000 DOOR_OPEN
@@@ hidden_output
0: UNLOCKED
30000: AUTO_RELOCK
FINAL LOCKED

@@@ hidden_input
4
0 RKE_UNLOCK
20000 RKE_UNLOCK
45000 TICK
50000 TICK
@@@ hidden_output
0: UNLOCKED
20000: UNLOCKED
50000: AUTO_RELOCK
FINAL LOCKED

@@@ hidden_input
2
5 RKE_UNLOCK
30004 TICK
@@@ hidden_output
5: UNLOCKED
FINAL UNLOCKED

@@@ hidden_input
0
@@@ hidden_output
FINAL LOCKED

@@@ hidden_input
3
0 RKE_UNLOCK
100 RKE_LOCK
90000 TICK
@@@ hidden_output
0: UNLOCKED
100: LOCKED
FINAL LOCKED

@@@ hidden_input
3
2000000000 RKE_UNLOCK
2000029999 TICK
2000030000 RKE_LOCK
@@@ hidden_output
2000000000: UNLOCKED
2000030000: AUTO_RELOCK
2000030000: LOCKED
FINAL LOCKED

@@@ hidden_input
2
0 RKE_UNLOCK
30001 HORN
@@@ hidden_output
0: UNLOCKED
30001: AUTO_RELOCK
30001: UNKNOWN HORN
FINAL LOCKED

@@@ hint
The FSM transitions are all correct. Focus on the one place where time is compared. Evaluate it by hand for `t_unlock = 0` and `now = 30000`.
@@@ hint
The requirement says "at least 30 000 ms", which is `elapsed >= 30000`. Strict `>` only fires at 30 001 ms or later, so with a 10 ms task tick the relock comes one whole tick late.
@@@ solution_code
#include <stdio.h>
#include <string.h>

#define RELOCK_MS 30000

typedef enum { LOCK_LOCKED, LOCK_UNLOCKED } LockState;
typedef enum { EV_RKE_UNLOCK, EV_RKE_LOCK, EV_DOOR_OPEN, EV_TICK, EV_UNKNOWN } LockEvent;

static LockState state = LOCK_LOCKED;
static int relock_armed = 0;
static int t_unlock = 0;

static LockEvent parse(const char *s)
{
    if (strcmp(s, "RKE_UNLOCK") == 0) return EV_RKE_UNLOCK;
    if (strcmp(s, "RKE_LOCK") == 0) return EV_RKE_LOCK;
    if (strcmp(s, "DOOR_OPEN") == 0) return EV_DOOR_OPEN;
    if (strcmp(s, "TICK") == 0) return EV_TICK;
    return EV_UNKNOWN;
}

static void relock_check(int now)
{
    if (relock_armed && now - t_unlock >= RELOCK_MS) {   /* FIX: ">= RELOCK_MS" - "at least 30 s", not "more than" */
        state = LOCK_LOCKED;
        relock_armed = 0;
        printf("%d: AUTO_RELOCK\n", now);
    }
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        int t;
        char tok[24];
        if (scanf("%d %23s", &t, tok) != 2) break;

        relock_check(t);

        switch (parse(tok)) {
        case EV_RKE_UNLOCK:
            state = LOCK_UNLOCKED;
            relock_armed = 1;
            t_unlock = t;
            printf("%d: UNLOCKED\n", t);
            break;
        case EV_RKE_LOCK:
            state = LOCK_LOCKED;
            relock_armed = 0;
            printf("%d: LOCKED\n", t);
            break;
        case EV_DOOR_OPEN:
            if (relock_armed) {
                relock_armed = 0;
                printf("%d: TIMER CANCELLED\n", t);
            }
            break;
        case EV_TICK:
            break;
        case EV_UNKNOWN:
            printf("%d: UNKNOWN %s\n", t, tok);
            break;
        }
    }
    printf("FINAL %s\n", state == LOCK_LOCKED ? "LOCKED" : "UNLOCKED");
    return 0;
}
@@@ explanation_md
**Bug.** `now - t_unlock > RELOCK_MS` means *strictly more than* 30 000 ms. The requirement is *at least* 30 000 ms. At exactly 30 000 ms the comparison is false, so the relock waits for the next event. In the ECU that is the next 10 ms task tick, and if that next event is a `DOOR_OPEN` at the boundary, the relock never happens at all (hidden test: the door opens at exactly 30 000 ms).

**Fix.** Use `>=`. Boundary tests at `deadline - 1`, `deadline` and `deadline + 1` are mandatory for every timer requirement. ISO 26262 calls this boundary-value analysis.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Changing the constant to 29 999 instead of the operator. It makes the tests pass but hides the real intent. The next engineer who changes the timeout re-introduces the bug.
- Comparing absolute times (`now > t_unlock + RELOCK_MS`). With a free-running 32-bit tick counter, `t_unlock + RELOCK_MS` can wrap around. The subtraction form `(uint32_t)(now - t_unlock) >= RELOCK_MS` stays correct across the wrap if you use **unsigned** ticks.
- Running the relock check **after** processing the event. A `DOOR_OPEN` at exactly the deadline would then cancel a relock that should already have fired.

**Interview follow-ups**
- The tick counter is a `uint32_t` in ms and wraps every ~49.7 days. Prove that `(uint32_t)(now - start) >= timeout` still works across the wrap, and say when it fails (timeouts longer than half the range).
- Where should the timer live: a software timer service, an OS alarm (AUTOSAR `SetRelAlarm`), or a counter in the 10 ms runnable? What changes for testability?
- Many OEMs disable auto-relock when the key is detected inside the cabin. How would you add that guard?
