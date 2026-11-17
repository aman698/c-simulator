@@@ meta
id: ENM-H-06
topic: Enums
difficulty: Hard
type: CODE
title: Turn-Signal Controller With Hazard Priority and Comfort Blink
tags: embedded, state-machine, timer, turn-signal, body-control-module, asked-in-automotive
@@@ statement_md
Implement the flasher logic of a body control module. It is driven by events, and time advances only through `TICK` events (1 tick = 100 ms).

```c
typedef enum { TS_OFF, TS_LEFT, TS_RIGHT, TS_HAZARD } TsMode;
typedef enum { LEVER_CENTER, LEVER_LEFT, LEVER_RIGHT } Lever;
```

**Flash generator.** When an indication *starts* (mode `LEFT`, `RIGHT` or `HAZARD` is entered), `phase = 0`, `flashes = 0`, and the lamp(s) switch ON immediately. Each `TICK` sets `phase = (phase + 1) % 8`. Lamps are ON while `phase < 4` and OFF otherwise. When `phase` becomes 4, one flash is complete (`flashes += 1`). `LEFT` drives the left lamp, `RIGHT` the right lamp, `HAZARD` both. In `OFF`, both lamps are off and `TICK` does not touch `phase`.

**Events**
- `TICK`: if the lever is not in the center, `lever_ticks += 1`. Then run the flash generator. In **comfort** mode, the indication stops (mode `OFF`) as soon as the 3rd flash is complete.
- `LEFT` / `RIGHT` (lever pushed): ignored if the lever is already in that position. Otherwise the lever moves there and `lever_ticks = 0`. If hazard is active, nothing else happens. Else, if the mode already is that side (for example during comfort blink), comfort is cancelled and flashing continues without restarting. Otherwise that side's indication **starts** (comfort off).
- `CENTER` (lever released): ignored if the lever is already centered. Otherwise `held = lever_ticks`, and the lever returns to the center. If hazard is active, nothing else happens. If the mode is the side the lever came from: when `held < 5`, the driver only tapped the lever and **comfort** mode turns on (the indication continues until 3 flashes in total are complete). Otherwise the mode becomes `OFF` immediately.
- `HAZARD` (button): toggles hazard. Hazard on: the `HAZARD` indication **starts**. Hazard off: if the lever is held left or right, that side's indication **starts**. Otherwise the mode becomes `OFF`.
- Any other token: print `<time> ignored <token>`.

**Output.** After each event, if the left or right lamp output changed, print `<time> L=<0|1> R=<0|1>`, where `time = ticks so far × 100`. At the end print `final mode=<OFF|LEFT|RIGHT|HAZARD> L=<l> R=<r>`. Comfort mode is reported as its side.

**Input**
- Line 1: `n`. Then `n` event tokens.

**Example**
```
Input:
11
LEFT TICK TICK TICK TICK TICK TICK TICK TICK TICK CENTER

Output:
0 L=1 R=0
400 L=0 R=0
800 L=1 R=0
900 L=0 R=0
final mode=OFF L=0 R=0
```
@@@ constraints_md
- `0 <= n <= 2000`. Tokens are at most 15 characters.
- Initial state: mode `OFF`, lever `CENTER`, hazard off, lamps off.
@@@ starter_code
#include <stdio.h>
#include <string.h>

typedef enum { TS_OFF, TS_LEFT, TS_RIGHT, TS_HAZARD } TsMode;
typedef enum { LEVER_CENTER, LEVER_LEFT, LEVER_RIGHT } Lever;

static const char *const mode_name[] = { "OFF", "LEFT", "RIGHT", "HAZARD" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    TsMode mode = TS_OFF;
    Lever lever = LEVER_CENTER;
    int ticks = 0, lamp_l = 0, lamp_r = 0;

    for (int i = 0; i < n; i++) {
        char tok[16];
        if (scanf("%15s", tok) != 1) break;
        /* TODO: handle the event, then print lamp changes */
    }
    printf("final mode=%s L=%d R=%d\n", mode_name[mode], lamp_l, lamp_r);
    (void)lever;
    (void)ticks;
    return 0;
}
@@@ sample_input
11
LEFT TICK TICK TICK TICK TICK TICK TICK TICK TICK CENTER
@@@ sample_output
0 L=1 R=0
400 L=0 R=0
800 L=1 R=0
900 L=0 R=0
final mode=OFF L=0 R=0

@@@ sample_input
24
RIGHT TICK TICK CENTER TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK
@@@ sample_output
0 L=0 R=1
400 L=0 R=0
800 L=0 R=1
1200 L=0 R=0
1600 L=0 R=1
2000 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
12
LEFT TICK TICK HAZARD TICK TICK TICK TICK TICK HAZARD TICK CENTER
@@@ hidden_output
0 L=1 R=0
200 L=1 R=1
600 L=0 R=0
700 L=1 R=0
800 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
5
HAZARD TICK TICK HAZARD TICK
@@@ hidden_output
0 L=1 R=1
200 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
15
LEFT TICK CENTER TICK TICK TICK TICK RIGHT TICK TICK TICK TICK TICK TICK CENTER
@@@ hidden_output
0 L=1 R=0
400 L=0 R=0
500 L=0 R=1
900 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
10
LEFT TICK TICK TICK TICK TICK CENTER TICK TICK TICK
@@@ hidden_output
0 L=1 R=0
400 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
23
LEFT TICK TICK TICK TICK CENTER TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK TICK
@@@ hidden_output
0 L=1 R=0
400 L=0 R=0
800 L=1 R=0
1200 L=0 R=0
1600 L=1 R=0
2000 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
6
LEFT LEFT TICK FOO CENTER CENTER
@@@ hidden_output
0 L=1 R=0
100 ignored FOO
final mode=LEFT L=1 R=0

@@@ hidden_input
0
@@@ hidden_output
final mode=OFF L=0 R=0

@@@ hidden_input
11
RIGHT TICK CENTER TICK HAZARD TICK TICK TICK TICK HAZARD TICK
@@@ hidden_output
0 L=0 R=1
200 L=1 R=1
600 L=0 R=0
final mode=OFF L=0 R=0

@@@ hidden_input
12
HAZARD RIGHT TICK TICK CENTER LEFT TICK HAZARD TICK TICK TICK TICK
@@@ hidden_output
0 L=1 R=1
300 L=1 R=0
700 L=0 R=0
final mode=LEFT L=0 R=0

@@@ hint
Separate **inputs** (`lever`, `hazard`, `lever_ticks`) from the **output state machine** (`mode`, `phase`, `flashes`, `comfort`). Write two helpers: `start(mode)` (phase = 0, flashes = 0, comfort off) and `stop()`. Compute the lamps from `mode` and `phase` after every event, and compare them with the previous lamp values to decide what to print.
@@@ hint
Comfort blink is a flag on top of `LEFT`/`RIGHT`, not a separate output pattern. On `TICK`, when the phase becomes 4 and `++flashes >= 3` while comfort is on, call `stop()`. A tap held 4 ticks has already completed one flash, so only two more follow.
@@@ solution_code
#include <stdio.h>
#include <string.h>

typedef enum { TS_OFF, TS_LEFT, TS_RIGHT, TS_HAZARD } TsMode;
typedef enum { LEVER_CENTER, LEVER_LEFT, LEVER_RIGHT } Lever;
typedef enum { EV_TICK, EV_LEFT, EV_RIGHT, EV_CENTER, EV_HAZARD, EV_UNKNOWN } TsEvent;

static const char *const mode_name[] = { "OFF", "LEFT", "RIGHT", "HAZARD" };

#define FLASH_PERIOD     8     /* ticks: 4 on + 4 off = 800 ms */
#define FLASH_ON         4
#define COMFORT_MAX_HOLD 5     /* a tap is shorter than 500 ms */
#define COMFORT_FLASHES  3

static TsMode mode = TS_OFF;
static Lever lever = LEVER_CENTER;
static int hazard, comfort, phase, flashes, lever_ticks;

static void start(TsMode m)
{
    mode = m;
    phase = 0;
    flashes = 0;
    comfort = 0;
}

static void stop(void)
{
    mode = TS_OFF;
    comfort = 0;
}

static TsMode side_mode(Lever l)
{
    return l == LEVER_LEFT ? TS_LEFT : l == LEVER_RIGHT ? TS_RIGHT : TS_OFF;
}

static TsEvent parse(const char *s)
{
    if (strcmp(s, "TICK") == 0) return EV_TICK;
    if (strcmp(s, "LEFT") == 0) return EV_LEFT;
    if (strcmp(s, "RIGHT") == 0) return EV_RIGHT;
    if (strcmp(s, "CENTER") == 0) return EV_CENTER;
    if (strcmp(s, "HAZARD") == 0) return EV_HAZARD;
    return EV_UNKNOWN;
}

static void lever_to(Lever pos)
{
    if (lever == pos) return;                       /* repeated position: ignored */
    lever = pos;
    lever_ticks = 0;
    if (hazard) return;                             /* hazard has priority */
    if (mode == side_mode(pos)) comfort = 0;        /* already flashing this side */
    else start(side_mode(pos));
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    int ticks = 0, lamp_l = 0, lamp_r = 0;

    for (int i = 0; i < n; i++) {
        char tok[16];
        if (scanf("%15s", tok) != 1) break;

        switch (parse(tok)) {
        case EV_TICK:
            ticks++;
            if (lever != LEVER_CENTER) lever_ticks++;
            if (mode != TS_OFF) {
                phase = (phase + 1) % FLASH_PERIOD;
                if (phase == FLASH_ON && ++flashes >= COMFORT_FLASHES && comfort)
                    stop();                         /* comfort blink finished */
            }
            break;
        case EV_LEFT:
            lever_to(LEVER_LEFT);
            break;
        case EV_RIGHT:
            lever_to(LEVER_RIGHT);
            break;
        case EV_CENTER:
            if (lever != LEVER_CENTER) {
                int held = lever_ticks;
                TsMode from = side_mode(lever);
                lever = LEVER_CENTER;
                lever_ticks = 0;
                if (!hazard && mode == from) {
                    if (held < COMFORT_MAX_HOLD) comfort = 1;
                    else stop();
                }
            }
            break;
        case EV_HAZARD:
            hazard = !hazard;
            if (hazard) start(TS_HAZARD);
            else if (lever != LEVER_CENTER) start(side_mode(lever));
            else stop();
            break;
        case EV_UNKNOWN:
            printf("%d ignored %s\n", ticks * 100, tok);
            break;
        }

        int on = mode != TS_OFF && phase < FLASH_ON;
        int l = on && (mode == TS_LEFT || mode == TS_HAZARD);
        int r = on && (mode == TS_RIGHT || mode == TS_HAZARD);
        if (l != lamp_l || r != lamp_r) {
            lamp_l = l;
            lamp_r = r;
            printf("%d L=%d R=%d\n", ticks * 100, lamp_l, lamp_r);
        }
    }
    printf("final mode=%s L=%d R=%d\n", mode_name[mode], lamp_l, lamp_r);
    return 0;
}
@@@ explanation_md
**Approach.** The difficulty is keeping three concerns apart:
1. **Inputs**: lever position, how long it has been held, and the hazard toggle. These change only on their own events.
2. **Mode FSM** (`OFF / LEFT / RIGHT / HAZARD`, plus a comfort flag): decides *what* should flash. Hazard has priority. While it is active, lever events only update the input variables, so turning hazard off can return to whatever the lever is doing *now*.
3. **Flash generator** (`phase`, `flashes`): decides *when* the lamps are lit. Every start resets it, so the first flash is always a full 400 ms. That is a legal requirement (UN ECE R48 regulates flash frequency and the first flash).

The lamp outputs are derived from `mode` and `phase` after **every** event and compared with the previous values. That gives "print only edges" without scattering `printf`s through the FSM. Comfort blink is a flag rather than a new mode: the light pattern is identical, and only the stop condition differs.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Restarting the phase when the lever is pushed again to the side that is already flashing (comfort cancel), which causes a visible "double flash".
- Letting lever events change the mode while hazard is on, or forgetting to resume the held side when hazard is switched off.
- Counting `held` in events instead of ticks, or using `<=` for the tap threshold (exactly 5 ticks = 500 ms is **not** a tap).
- Counting a flash when the lamp turns **on** instead of when it turns off, so comfort stops in the middle of the 3rd flash.
- Updating `phase` in `OFF`, so the next indication starts mid-period with a short first flash.

**Interview follow-ups**
- A bulb fails (open-load detected by the high-side driver). Regulations require the flash rate to double. Where does that go in this design?
- The lever and hazard signals come over LIN from a switch module that can drop out. What should the flasher do on signal timeout?
- How would you synchronize this flasher with the trailer module's flasher on another ECU, so all lamps blink in phase?
- Why is it common to run this logic in a 10 ms task with a 100 ms divider, rather than with a hardware timer per lamp?
