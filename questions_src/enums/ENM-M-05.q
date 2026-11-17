@@@ meta
id: ENM-M-05
topic: Enums
difficulty: Medium
type: FUNCTION
title: Debounced Push-Button State Machine
tags: embedded, debounce, state-machine, gpio, defensive-programming
@@@ statement_md
A steering-wheel button is sampled every 5 ms from a GPIO. Mechanical contacts bounce, so a press or release is only accepted after the new level has been seen on `n` **consecutive** samples. The judge defines these types, so do not redefine them:

```c
typedef enum { BTN_RELEASED, BTN_MAYBE_PRESSED, BTN_PRESSED, BTN_MAYBE_RELEASED } BtnState;
typedef enum { BTN_EVT_NONE, BTN_EVT_PRESS, BTN_EVT_RELEASE } BtnEvent;

typedef struct {
    BtnState state;
    int      count;   /* yours to use: consecutive samples in a MAYBE state */
    int      n;       /* samples needed to confirm a change, n >= 1 */
} Debouncer;
```

Implement

```c
BtnEvent deb_sample(Debouncer *d, int raw);
```

It is called once per sample. Any non-zero `raw` means "pressed level". It updates `*d` and returns the event that this sample confirmed:

| state | sample | action |
|---|---|---|
| `RELEASED` | pressed | `MAYBE_PRESSED` with count 1, or straight to `PRESSED` + return `PRESS` if `n == 1` |
| `RELEASED` | released | stay |
| `MAYBE_PRESSED` | pressed | count += 1; when count reaches `n`: `PRESSED`, return `PRESS` |
| `MAYBE_PRESSED` | released | back to `RELEASED` (a bounce, no event) |
| `PRESSED` | released | `MAYBE_RELEASED` with count 1, or straight to `RELEASED` + return `RELEASE` if `n == 1` |
| `PRESSED` | pressed | stay |
| `MAYBE_RELEASED` | released | count += 1; when count reaches `n`: `RELEASED`, return `RELEASE` |
| `MAYBE_RELEASED` | pressed | back to `PRESSED` (a bounce, no event) |

**Robustness:** if `d->state` holds a value that is not a `BtnState` enumerator (RAM corruption), set the state to `RELEASED` and the count to 0, and return `BTN_EVT_NONE`. That sample is **discarded** and is not evaluated.

All other calls return `BTN_EVT_NONE`.

**How it is tested.** The harness initializes `{ BTN_RELEASED, 0, n }` and feeds the sample string one character at a time. A digit is a sample. An `X` is not a sample: it corrupts `d->state` to 7 before the next sample. The harness prints `<sample#> PRESS` / `<sample#> RELEASE` for every event (samples numbered from 1), and `final <STATE>` at the end.

**Example**
```
Input:
3
0111100011000

Output:
4 PRESS
8 RELEASE
final RELEASED
```
@@@ constraints_md
- `1 <= n <= 10`
- 1 to 200 characters, each a digit `0`..`9` or `X`. Digits other than `0` mean "pressed".
- The sample string never ends with `X`.
@@@ starter_code
/*
 * Provided by the judge (do not redefine):
 *   typedef enum { BTN_RELEASED, BTN_MAYBE_PRESSED, BTN_PRESSED, BTN_MAYBE_RELEASED } BtnState;
 *   typedef enum { BTN_EVT_NONE, BTN_EVT_PRESS, BTN_EVT_RELEASE } BtnEvent;
 *   typedef struct { BtnState state; int count; int n; } Debouncer;
 */
BtnEvent deb_sample(Debouncer *d, int raw)
{
    /* TODO: switch on d->state */
    (void)d;
    (void)raw;
    return BTN_EVT_NONE;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>

typedef enum { BTN_RELEASED, BTN_MAYBE_PRESSED, BTN_PRESSED, BTN_MAYBE_RELEASED } BtnState;
typedef enum { BTN_EVT_NONE, BTN_EVT_PRESS, BTN_EVT_RELEASE } BtnEvent;

typedef struct {
    BtnState state;
    int      count;
    int      n;
} Debouncer;

/*USER_CODE*/

static const char *const h_state[4] = { "RELEASED", "MAYBE_PRESSED", "PRESSED", "MAYBE_RELEASED" };

int main(void)
{
    int n;
    char s[256];
    if (scanf("%d %255s", &n, s) != 2) return 0;
    Debouncer d = { BTN_RELEASED, 0, n };
    int idx = 0;
    for (size_t i = 0; i < strlen(s); i++) {
        if (s[i] == 'X') { d.state = (BtnState)7; continue; }
        idx++;
        BtnEvent e = deb_sample(&d, s[i] - '0');
        if (e == BTN_EVT_PRESS) printf("%d PRESS\n", idx);
        else if (e == BTN_EVT_RELEASE) printf("%d RELEASE\n", idx);
        else if (e != BTN_EVT_NONE) printf("%d BAD_EVENT\n", idx);
    }
    unsigned st = (unsigned)d.state;
    printf("final %s\n", st < 4u ? h_state[st] : "CORRUPT");
    return 0;
}
@@@ sample_input
3
0111100011000
@@@ sample_output
4 PRESS
8 RELEASE
final RELEASED

@@@ sample_input
1
0101
@@@ sample_output
2 PRESS
3 RELEASE
4 PRESS
final PRESSED

@@@ hidden_input
3
1101101110
@@@ hidden_output
9 PRESS
final MAYBE_RELEASED

@@@ hidden_input
2
11X1100
@@@ hidden_output
2 PRESS
final RELEASED

@@@ hidden_input
2
0290
@@@ hidden_output
3 PRESS
final MAYBE_RELEASED

@@@ hidden_input
4
0000
@@@ hidden_output
final RELEASED

@@@ hidden_input
5
11111111110000011
@@@ hidden_output
5 PRESS
15 RELEASE
final MAYBE_PRESSED

@@@ hidden_input
3
1110110001
@@@ hidden_output
3 PRESS
9 RELEASE
final MAYBE_PRESSED

@@@ hidden_input
1
1X0
@@@ hidden_output
1 PRESS
final RELEASED

@@@ hint
Write a `switch (d->state)` with one `case` per state and a `default:` for the corrupted case. In each case, branch on `raw != 0`. The `n == 1` rule falls out naturally if you increment `count` and compare it with `n` right after entering a MAYBE state.
@@@ hint
A neat trick: on the first differing sample, set `count = 1` and immediately check `count >= n`. If it is true, jump straight to the confirmed state. Reset `count` to 0 whenever you return to a stable state.
@@@ solution_code
BtnEvent deb_sample(Debouncer *d, int raw)
{
    const int pressed = (raw != 0);

    switch (d->state) {
    case BTN_RELEASED:
        if (pressed) {
            d->count = 1;
            if (d->count >= d->n) { d->state = BTN_PRESSED; d->count = 0; return BTN_EVT_PRESS; }
            d->state = BTN_MAYBE_PRESSED;
        }
        return BTN_EVT_NONE;

    case BTN_MAYBE_PRESSED:
        if (!pressed) {                       /* bounce: level went back */
            d->state = BTN_RELEASED;
            d->count = 0;
            return BTN_EVT_NONE;
        }
        if (++d->count >= d->n) { d->state = BTN_PRESSED; d->count = 0; return BTN_EVT_PRESS; }
        return BTN_EVT_NONE;

    case BTN_PRESSED:
        if (!pressed) {
            d->count = 1;
            if (d->count >= d->n) { d->state = BTN_RELEASED; d->count = 0; return BTN_EVT_RELEASE; }
            d->state = BTN_MAYBE_RELEASED;
        }
        return BTN_EVT_NONE;

    case BTN_MAYBE_RELEASED:
        if (pressed) {                        /* bounce: still held */
            d->state = BTN_PRESSED;
            d->count = 0;
            return BTN_EVT_NONE;
        }
        if (++d->count >= d->n) { d->state = BTN_RELEASED; d->count = 0; return BTN_EVT_RELEASE; }
        return BTN_EVT_NONE;

    default:                                  /* corrupted state: recover to a safe state */
        d->state = BTN_RELEASED;
        d->count = 0;
        return BTN_EVT_NONE;
    }
}
@@@ explanation_md
**Approach.** A four-state debouncer: two stable states (`RELEASED`, `PRESSED`) and two "candidate" states (`MAYBE_*`) that count consecutive samples of the new level. Any contradicting sample during counting means the contact bounced, and the machine goes straight back to the stable state it came from. Events are emitted only on the transition **into** a stable state, so the application gets exactly one `PRESS` and one `RELEASE` per physical actuation, however much the contacts chatter.

Setting `count = 1` and then checking `count >= n` handles `n == 1` (no debouncing) without a special case. The `default:` branch is the robustness requirement: `d->state` is an enum variable, and nothing stops it from holding 7 after a stray pointer write or a RAM bit flip. Without `default`, the switch silently does nothing on every later call, and the button is dead until the next reset.

**Complexity.** Time O(1) per sample, space O(1) per button.

**Common mistakes**
- Emitting `PRESS` on the first pressed sample, which reacts to bounce and gives multiple presses per actuation.
- Forgetting to reset `count` when leaving a `MAYBE` state. The next debounce then starts from a stale count and confirms too early.
- Comparing `raw == 1` instead of `raw != 0`. Some GPIO reads return the pin mask (for example `0x20`), not 1.
- No `default:` case. The corrupted-state tests leave the FSM stuck in state 7.
- Mixing up the event and the state. The application usually wants the *edge* (event) for actions and the *state* for hold functions.

**Interview follow-ups**
- Replace the FSM with an integrator / shift-register debouncer (`hist = (hist << 1) | raw; if (hist == 0xFF) ...`). What are the trade-offs?
- Add long-press detection: emit `LONG_PRESS` after the button has been held for 1 s, with `RELEASE` still emitted afterwards.
- This runs in a 5 ms task, but the button also wakes the MCU from sleep through an EXTI interrupt. How do you combine the interrupt with the sampled debouncer?
