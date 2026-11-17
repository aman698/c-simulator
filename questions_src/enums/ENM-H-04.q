@@@ meta
id: ENM-H-04
topic: Enums
difficulty: Hard
type: FUNCTION
title: CAN Fault Confinement - Error-Active, Error-Passive, Bus-Off
tags: embedded, can-bus, iso-11898, fault-confinement, state-machine, asked-in-automotive
@@@ statement_md
Every CAN controller runs the ISO 11898-1 **fault confinement** state machine, driven by a transmit error counter (TEC) and a receive error counter (REC). Model it in software, for example for a simulator or a software CAN stack. The judge defines these types, so do not redefine them:

```c
typedef enum { CAN_ERROR_ACTIVE, CAN_ERROR_PASSIVE, CAN_BUS_OFF } CanErrState;

typedef enum {
    CAN_EV_TX_OK,         /* frame transmitted successfully                     */
    CAN_EV_RX_OK,         /* frame received successfully                        */
    CAN_EV_TX_ERROR,      /* transmitter detected an error                      */
    CAN_EV_TX_ACK_ERROR,  /* transmitter got no ACK                             */
    CAN_EV_RX_ERROR,      /* receiver detected an error                         */
    CAN_EV_RX_ERROR_DOM,  /* receiver saw a dominant bit after its error flag   */
    CAN_EV_IDLE_11,       /* 11 consecutive recessive bits observed on the bus  */
    CAN_EV_COUNT
} CanFcEvent;

typedef struct { int tec; int rec; CanErrState state; int idle_count; } CanNode;
```

Implement `CanErrState can_fc_event(CanNode *n, int ev);`. It applies one event, updates `*n`, and returns the new state.

**While `BUS_OFF`:** only `IDLE_11` has an effect. It increments `idle_count`, and at **128** occurrences the node recovers: `ERROR_ACTIVE`, `tec = rec = 0`, `idle_count = 0`. Every other event, valid or not, is ignored. TEC and REC keep their values while bus-off.

**Otherwise**, update the counters:

| event | effect |
|---|---|
| `TX_OK` | `tec -= 1` if `tec > 0` |
| `RX_OK` | if `rec > 127`: `rec = 119`; else `rec -= 1` if `rec > 0` |
| `TX_ERROR` | `tec += 8` |
| `TX_ACK_ERROR` | `tec += 8`, **except** when the node is `ERROR_PASSIVE` (then no change) |
| `RX_ERROR` | `rec += 1` |
| `RX_ERROR_DOM` | `rec += 8` |
| `IDLE_11` | nothing |

REC saturates at 255. Then derive the state: `BUS_OFF` if `tec > 255`; else `ERROR_PASSIVE` if `tec >= 128` or `rec >= 128`; else `ERROR_ACTIVE`. Entering `BUS_OFF` sets `idle_count = 0`.

An `ev` outside `0 .. CAN_EV_COUNT-1` is ignored in every state.

**How it is tested.** The harness starts from `{0, 0, CAN_ERROR_ACTIVE, 0}` and expands tokens such as `TX_ERR*16` (the event 16 times). Names: `TX_OK RX_OK TX_ERR TX_ACK RX_ERR RX_DOM IDLE`, plus `RAW:<int>` for a raw event value. On every state change it prints `<event#> <OLD> -> <NEW> TEC=<tec> REC=<rec>` (events numbered from 1 after expansion). At the end it prints `final <STATE> TEC=<tec> REC=<rec>`.

**Example**
```
Input:
3
TX_ERR*16 TX_OK RX_ERR*3

Output:
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
17 ERROR_PASSIVE -> ERROR_ACTIVE TEC=127 REC=0
final ERROR_ACTIVE TEC=127 REC=3
```
@@@ constraints_md
- At most 1000 events after expansion. `RAW` values are any 32-bit `int`.
- Thresholds: passive at 128 (either counter), bus-off above 255 (TEC only), recovery after 128 × 11 recessive bits.
@@@ starter_code
/*
 * Provided by the judge (do not redefine): CanErrState, CanFcEvent (CAN_EV_TX_OK .. CAN_EV_COUNT),
 *   typedef struct { int tec; int rec; CanErrState state; int idle_count; } CanNode;
 */
CanErrState can_fc_event(CanNode *n, int ev)
{
    /* TODO */
    (void)ev;
    return n->state;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>

typedef enum { CAN_ERROR_ACTIVE, CAN_ERROR_PASSIVE, CAN_BUS_OFF } CanErrState;

typedef enum {
    CAN_EV_TX_OK,
    CAN_EV_RX_OK,
    CAN_EV_TX_ERROR,
    CAN_EV_TX_ACK_ERROR,
    CAN_EV_RX_ERROR,
    CAN_EV_RX_ERROR_DOM,
    CAN_EV_IDLE_11,
    CAN_EV_COUNT
} CanFcEvent;

typedef struct { int tec; int rec; CanErrState state; int idle_count; } CanNode;

/*USER_CODE*/

static const char *const h_names[CAN_EV_COUNT] = { "TX_OK", "RX_OK", "TX_ERR", "TX_ACK", "RX_ERR", "RX_DOM", "IDLE" };
static const char *const h_state[3] = { "ERROR_ACTIVE", "ERROR_PASSIVE", "BUS_OFF" };

static const char *h_st(CanErrState s)
{
    unsigned u = (unsigned)s;
    return u < 3u ? h_state[u] : "CORRUPT";
}

int main(void)
{
    int m;
    if (scanf("%d", &m) != 1) return 0;
    CanNode node = { 0, 0, CAN_ERROR_ACTIVE, 0 };
    int idx = 0;
    for (int i = 0; i < m; i++) {
        char tok[40];
        if (scanf("%39s", tok) != 1) return 0;
        int count = 1, ev = -1;
        char *star = strchr(tok, '*');
        if (star) {
            *star = '\0';
            if (sscanf(star + 1, "%d", &count) != 1) return 0;
        }
        if (strncmp(tok, "RAW:", 4) == 0) {
            if (sscanf(tok + 4, "%d", &ev) != 1) return 0;
        } else {
            for (int e = 0; e < CAN_EV_COUNT; e++)
                if (strcmp(tok, h_names[e]) == 0) ev = e;
            if (ev < 0) return 0;
        }
        for (int k = 0; k < count; k++) {
            idx++;
            CanErrState before = node.state;
            CanErrState r = can_fc_event(&node, ev);
            if (r != node.state) { printf("%d BAD RETURN VALUE\n", idx); return 0; }
            if (r != before)
                printf("%d %s -> %s TEC=%d REC=%d\n", idx, h_st(before), h_st(r), node.tec, node.rec);
        }
    }
    printf("final %s TEC=%d REC=%d\n", h_st(node.state), node.tec, node.rec);
    return 0;
}
@@@ sample_input
3
TX_ERR*16 TX_OK RX_ERR*3
@@@ sample_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
17 ERROR_PASSIVE -> ERROR_ACTIVE TEC=127 REC=0
final ERROR_ACTIVE TEC=127 REC=3

@@@ sample_input
4
TX_ERR*32 IDLE*127 TX_OK IDLE
@@@ sample_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
32 ERROR_PASSIVE -> BUS_OFF TEC=256 REC=0
161 BUS_OFF -> ERROR_ACTIVE TEC=0 REC=0
final ERROR_ACTIVE TEC=0 REC=0

@@@ hidden_input
4
RX_ERR*127 RX_ERR RX_OK RX_OK
@@@ hidden_output
128 ERROR_ACTIVE -> ERROR_PASSIVE TEC=0 REC=128
129 ERROR_PASSIVE -> ERROR_ACTIVE TEC=0 REC=119
final ERROR_ACTIVE TEC=0 REC=118

@@@ hidden_input
3
TX_ACK*16 TX_ACK*10 TX_ERR
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
final ERROR_PASSIVE TEC=136 REC=0

@@@ hidden_input
4
TX_ERR*31 TX_OK TX_ERR TX_ERR
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
34 ERROR_PASSIVE -> BUS_OFF TEC=263 REC=0
final BUS_OFF TEC=263 REC=0

@@@ hidden_input
6
TX_ERR*32 RX_ERR*5 TX_OK*300 IDLE*127 RAW:99 RAW:-1
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
32 ERROR_PASSIVE -> BUS_OFF TEC=256 REC=0
final BUS_OFF TEC=256 REC=0

@@@ hidden_input
6
TX_OK RAW:7 RAW:-5 RAW:2147483647 TX_ERR RX_OK
@@@ hidden_output
final ERROR_ACTIVE TEC=8 REC=0

@@@ hidden_input
2
RX_DOM*40 RX_OK
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=0 REC=128
41 ERROR_PASSIVE -> ERROR_ACTIVE TEC=0 REC=119
final ERROR_ACTIVE TEC=0 REC=119

@@@ hidden_input
4
TX_ERR*20 RX_DOM*16 TX_OK*40 RX_OK
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
77 ERROR_PASSIVE -> ERROR_ACTIVE TEC=120 REC=119
final ERROR_ACTIVE TEC=120 REC=119

@@@ hidden_input
3
TX_ERR*32 IDLE*128 TX_ERR*32
@@@ hidden_output
16 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
32 ERROR_PASSIVE -> BUS_OFF TEC=256 REC=0
160 BUS_OFF -> ERROR_ACTIVE TEC=0 REC=0
176 ERROR_ACTIVE -> ERROR_PASSIVE TEC=128 REC=0
192 ERROR_PASSIVE -> BUS_OFF TEC=256 REC=0
final BUS_OFF TEC=256 REC=0

@@@ hint
Split the function into three parts: (1) validate `ev`; (2) if bus-off, handle only `IDLE_11`; (3) otherwise update the counters with a `switch (ev)`, then derive the state **from the counters** with one if-chain, instead of tracking transitions event by event.
@@@ hint
Order matters in two places. The ACK-error exception depends on the state **before** this event. The bus-off check (`tec > 255`) must come before the passive check, because a bus-off node also has `tec >= 128`.
@@@ solution_code
#define CAN_PASSIVE_LIMIT 128
#define CAN_BUSOFF_LIMIT  255
#define CAN_REC_MAX       255
#define CAN_RECOVERY_SEQ  128

CanErrState can_fc_event(CanNode *n, int ev)
{
    if (ev < 0 || ev >= CAN_EV_COUNT)
        return n->state;                         /* garbage event: ignored */

    if (n->state == CAN_BUS_OFF) {
        if (ev == CAN_EV_IDLE_11 && ++n->idle_count >= CAN_RECOVERY_SEQ) {
            n->state = CAN_ERROR_ACTIVE;         /* 128 x 11 recessive bits: rejoin the bus */
            n->tec = 0;
            n->rec = 0;
            n->idle_count = 0;
        }
        return n->state;
    }

    switch ((CanFcEvent)ev) {
    case CAN_EV_TX_OK:
        if (n->tec > 0) n->tec--;
        break;
    case CAN_EV_RX_OK:
        if (n->rec > 127) n->rec = 119;
        else if (n->rec > 0) n->rec--;
        break;
    case CAN_EV_TX_ERROR:
        n->tec += 8;
        break;
    case CAN_EV_TX_ACK_ERROR:
        if (n->state != CAN_ERROR_PASSIVE)       /* ISO 11898-1 exception for passive transmitters */
            n->tec += 8;
        break;
    case CAN_EV_RX_ERROR:
        n->rec += 1;
        break;
    case CAN_EV_RX_ERROR_DOM:
        n->rec += 8;
        break;
    case CAN_EV_IDLE_11:
    case CAN_EV_COUNT:
        break;
    }
    if (n->rec > CAN_REC_MAX) n->rec = CAN_REC_MAX;

    if (n->tec > CAN_BUSOFF_LIMIT) {
        n->state = CAN_BUS_OFF;
        n->idle_count = 0;
    } else if (n->tec >= CAN_PASSIVE_LIMIT || n->rec >= CAN_PASSIVE_LIMIT) {
        n->state = CAN_ERROR_PASSIVE;
    } else {
        n->state = CAN_ERROR_ACTIVE;
    }
    return n->state;
}
@@@ explanation_md
**Approach.** In this state machine the states are a **function of the counters**, except for bus-off, which is latched until the recovery sequence. So:
1. Reject invalid events first (an `int` event can be anything).
2. In `BUS_OFF`, only count `IDLE_11` sequences. The node is electrically silent, so TX/RX events cannot occur and are ignored.
3. Otherwise apply the counter rule for the event. The one state-dependent rule (no TEC increment for an ACK error while error-passive) reads the state **before** updating it. Then saturate REC and re-derive the state with the thresholds in the right order: bus-off (`tec > 255`) before passive (`>= 128`).

Deriving the state from the counters makes "passive → active" work automatically when both counters fall back to 127 or below, including the special `rec > 127 → 119` jump on a successful reception.

**Complexity.** Time O(1) per event, space O(1).

**Common mistakes**
- Thresholds off by one: error-passive starts at **128** (not above 128), and bus-off at **256** (TEC *greater than* 255). The hidden tests check 127/128 and 255/256.
- Checking `tec >= 128` before `tec > 255`, so the node never reaches bus-off.
- Letting REC drive the node into bus-off. Only TEC can cause bus-off.
- Processing errors while bus-off, or resetting `idle_count` when it should not be reset (or forgetting to reset it on entering bus-off).
- Forgetting the ACK-error exception. A lone node on a bus with no other node to ACK would otherwise go bus-off, while per the standard it stays error-passive. That is the classic "single ECU on the bench" symptom.

**Interview follow-ups**
- Why does a transmitter's TEC go up by 8 while a receiver's REC goes up by 1? Who is more likely to be the faulty node?
- AUTOSAR CanSM adds a software bus-off recovery with L1/L2 delays (for example 5 × 10 ms, then 1 s). Why not rely only on the controller's automatic 128 × 11-bit recovery?
- How do you detect "bus-off" quickly in the application, and which DTC would you set? (Many OEMs use U-codes such as U0001.)
- What is the difference between an active and a passive error flag on the wire, and why can an error-passive node not destroy other nodes' frames?
