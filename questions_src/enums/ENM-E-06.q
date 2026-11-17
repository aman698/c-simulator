@@@ meta
id: ENM-E-06
topic: Enums
difficulty: Easy
type: CODE
title: Traffic Light Controller FSM With a Fault Mode
tags: embedded, state-machine, switch, traffic-light, timer
@@@ statement_md
Implement the controller of a traffic light as a finite state machine. Use an enum for the state and a `switch` for the logic.

**States:** `RED`, `GREEN`, `YELLOW`, `FLASHING` (fault mode, blinking yellow). The controller starts in `RED` with a time-in-state of 0.

**Events** (one token each):

| event | behaviour |
|---|---|
| `TICK` | In `RED`/`GREEN`/`YELLOW`: time-in-state += 1. When it **reaches** the state's duration, go to the next state (`RED -> GREEN -> YELLOW -> RED`) and reset time-in-state to 0. In `FLASHING`: nothing happens. |
| `FAULT` | From `RED`/`GREEN`/`YELLOW`: go to `FLASHING`. In `FLASHING`: nothing happens (no output). |
| `RESET` | From `FLASHING`: go to `RED` with time-in-state 0. In any other state the event is ignored and reported. |
| anything else | unknown event, reported, state unchanged |

Durations: `RED` = 3 ticks, `GREEN` = 2 ticks, `YELLOW` = 1 tick.

**Input**
- Line 1: `n`, the number of events.
- Then `n` whitespace-separated event tokens (each at most 15 characters).

**Output** (events are numbered from 1)
- On every state change: `<i>: <FROM> -> <TO>`
- On a `RESET` that is ignored: `<i>: RESET ignored in <STATE>`
- On an unknown token: `<i>: unknown event <token>`
- After all events: `final: <STATE>`

**Example**
```
Input:
6
TICK FAULT TICK RESET RESET TICK

Output:
2: RED -> FLASHING
4: FLASHING -> RED
5: RESET ignored in RED
final: RED
```
@@@ constraints_md
- `0 <= n <= 1000`
- Tokens are case-sensitive (`tick` is unknown).
- An ignored `RESET` does not change the time-in-state.
@@@ starter_code
#include <stdio.h>
#include <string.h>

typedef enum { TL_RED, TL_GREEN, TL_YELLOW, TL_FLASHING, TL_COUNT } TlState;

static const char *const tl_name[TL_COUNT] = { "RED", "GREEN", "YELLOW", "FLASHING" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    TlState state = TL_RED;
    int time_in_state = 0;

    for (int i = 1; i <= n; i++) {
        char ev[16];
        if (scanf("%15s", ev) != 1) break;
        /* TODO: handle TICK / FAULT / RESET / unknown with a switch on state */
    }
    printf("final: %s\n", tl_name[state]);
    (void)time_in_state;
    return 0;
}
@@@ sample_input
6
TICK FAULT TICK RESET RESET TICK
@@@ sample_output
2: RED -> FLASHING
4: FLASHING -> RED
5: RESET ignored in RED
final: RED

@@@ sample_input
6
TICK TICK TICK TICK TICK TICK
@@@ sample_output
3: RED -> GREEN
5: GREEN -> YELLOW
6: YELLOW -> RED
final: RED

@@@ hidden_input
0
@@@ hidden_output
final: RED

@@@ hidden_input
3
TICK BLINK TICK
@@@ hidden_output
2: unknown event BLINK
final: RED

@@@ hidden_input
4
FAULT FAULT TICK TICK
@@@ hidden_output
1: RED -> FLASHING
final: FLASHING

@@@ hidden_input
12
TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK
@@@ hidden_output
3: RED -> GREEN
5: GREEN -> YELLOW
6: YELLOW -> RED
9: RED -> GREEN
11: GREEN -> YELLOW
12: YELLOW -> RED
final: RED

@@@ hidden_input
8
TICK TICK TICK TICK FAULT RESET TICK TICK
@@@ hidden_output
3: RED -> GREEN
5: GREEN -> FLASHING
6: FLASHING -> RED
final: RED

@@@ hidden_input
7
TICK TICK TICK TICK TICK RESET tick
@@@ hidden_output
3: RED -> GREEN
5: GREEN -> YELLOW
6: RESET ignored in YELLOW
7: unknown event tick
final: YELLOW

@@@ hidden_input
4
TICK TICK RESET TICK
@@@ hidden_output
3: RESET ignored in RED
4: RED -> GREEN
final: GREEN

@@@ hint
Keep two variables: `TlState state` and `int time_in_state`. Turn the token into an event first, then `switch (state)` inside each event and end every `case` with `break` or `return`.
@@@ hint
Put the durations in a table indexed by state (`{3, 2, 1, 0}`) and the successor in another (`{GREEN, YELLOW, RED, FLASHING}`). Write a small `go(i, to)` helper that prints the transition line and resets the timer.
@@@ solution_code
#include <stdio.h>
#include <string.h>

typedef enum { TL_RED, TL_GREEN, TL_YELLOW, TL_FLASHING, TL_COUNT } TlState;
typedef enum { EV_TICK, EV_FAULT, EV_RESET, EV_UNKNOWN } TlEvent;

static const char *const tl_name[TL_COUNT] = { "RED", "GREEN", "YELLOW", "FLASHING" };

static TlState state = TL_RED;
static int time_in_state = 0;

static void go(int i, TlState to)
{
    printf("%d: %s -> %s\n", i, tl_name[state], tl_name[to]);
    state = to;
    time_in_state = 0;
}

static TlEvent parse_event(const char *s)
{
    if (strcmp(s, "TICK") == 0) return EV_TICK;
    if (strcmp(s, "FAULT") == 0) return EV_FAULT;
    if (strcmp(s, "RESET") == 0) return EV_RESET;
    return EV_UNKNOWN;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int i = 1; i <= n; i++) {
        char tok[16];
        if (scanf("%15s", tok) != 1) break;

        switch (parse_event(tok)) {
        case EV_TICK:
            switch (state) {
            case TL_RED:
                if (++time_in_state == 3) go(i, TL_GREEN);
                break;
            case TL_GREEN:
                if (++time_in_state == 2) go(i, TL_YELLOW);
                break;
            case TL_YELLOW:
                if (++time_in_state == 1) go(i, TL_RED);
                break;
            case TL_FLASHING:
            case TL_COUNT:          /* not a real state; listed to keep -Wswitch quiet */
                break;
            }
            break;
        case EV_FAULT:
            if (state != TL_FLASHING) go(i, TL_FLASHING);
            break;
        case EV_RESET:
            if (state == TL_FLASHING) go(i, TL_RED);
            else printf("%d: RESET ignored in %s\n", i, tl_name[state]);
            break;
        case EV_UNKNOWN:
            printf("%d: unknown event %s\n", i, tok);
            break;
        }
    }
    printf("final: %s\n", tl_name[state]);
    return 0;
}
@@@ explanation_md
**Approach.** The whole controller state is one enum value plus one counter. Parse each token into an event enum first, so the FSM logic never compares strings. Then switch on the event, and inside `TICK` switch on the state. Every transition goes through `go()`, which prints, changes state and resets the timer in one place, so no path forgets the reset. The fault and reset rules are global ("from any normal state"), so they are written as a guard (`if (state != TL_FLASHING)`) instead of being repeated in three `case`s.

`TICK` uses "time-in-state **reaches** the duration": `RED` lasts exactly 3 ticks and changes on the 3rd one.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- A missing `break` between `case TL_RED:` and `case TL_GREEN:`. One tick then runs two transitions. `-Wextra` (`-Wimplicit-fallthrough`) warns about it.
- Forgetting to reset `time_in_state` on `FAULT` or `RESET`, so the first `RED` after a reset is too short.
- Off-by-one on the duration: checking `>` instead of reaching (`==` after the increment) makes every phase one tick too long.
- Leaving out a `case` for an enumerator without a `default:`. `-Wall` (`-Wswitch`) then warns "enumeration value not handled in switch". That warning is the reason to list every enumerator instead of hiding them behind `default`.

**Interview follow-ups**
- Add a pedestrian button that shortens the current `GREEN` phase to at most 1 more tick. Where does that logic live?
- Move the durations and successor states into a `const` table indexed by state. When is a table-driven FSM better than nested `switch` statements?
- What should the controller do if `state` is ever corrupted to a value outside the enum (an SEU in RAM)? (A defensive `default:` that goes to `FLASHING`, the safe state.)
