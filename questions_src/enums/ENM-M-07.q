@@@ meta
id: ENM-M-07
topic: Enums
difficulty: Medium
type: FIND_THE_BUG
title: HV State Log Decoder With a Stale Name Table
tags: embedded, enum-to-string, string-table, out-of-bounds, ev-powertrain
@@@ statement_md
An electric vehicle's inverter logs its high-voltage (HV) state machine as `timestamp state` records. A PC-side tool decodes the log. In software release 2.1 a new `HV_PRECHARGE` state was added between `STANDBY` and `READY`, and since then the decoded logs "look wrong", and some logs crash the tool.

Intended behaviour:
- For each record print `<t>: <NAME>`, where `NAME` is the state's name (`INIT`, `STANDBY`, `PRECHARGE`, `READY`, `DRIVE`, `FAULT`). If the raw state value is not a valid `HvState`, print `<t>: INVALID(<raw>)`.
- Then, for every state in **enum order** that accumulated time, print `time <NAME> <ms>`. The time between record `i` and record `i+1` belongs to the state of record `i` (if that state is valid). The last record has no duration.

Find and fix the bug.

**Input**
- Line 1: `n`. Next `n` lines: `t state` with non-decreasing `t` in ms.

**Output**
- As described above (nothing at all when `n = 0`).

**Example**
```
Input:
4
0 0
100 1
250 3
900 4

Output:
0: INIT
100: STANDBY
250: READY
900: DRIVE
time INIT 100
time STANDBY 150
time READY 650
```
@@@ constraints_md
- `0 <= n <= 1000`, `0 <= t <= 10^9`
- `state` is any 32-bit `int`.
- The fix is one line.
@@@ starter_code
#include <stdio.h>

typedef enum {
    HV_INIT,
    HV_STANDBY,
    HV_PRECHARGE,       /* new in SW 2.1 */
    HV_READY,
    HV_DRIVE,
    HV_FAULT,
    HV_STATE_COUNT
} HvState;

static const char *const hv_state_name[] = {
    "INIT",
    "STANDBY",
    "READY",
    "DRIVE",
    "FAULT",
};

static int is_valid_state(int s)
{
    return s >= 0 && s < HV_STATE_COUNT;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    long long time_in[HV_STATE_COUNT] = { 0 };
    int prev_t = 0, prev_s = -1;

    for (int i = 0; i < n; i++) {
        int t, s;
        if (scanf("%d %d", &t, &s) != 2) break;

        if (i > 0 && is_valid_state(prev_s))
            time_in[prev_s] += t - prev_t;

        if (is_valid_state(s))
            printf("%d: %s\n", t, hv_state_name[s]);
        else
            printf("%d: INVALID(%d)\n", t, s);

        prev_t = t;
        prev_s = s;
    }

    for (int s = 0; s < HV_STATE_COUNT; s++)
        if (time_in[s] > 0)
            printf("time %s %lld\n", hv_state_name[s], time_in[s]);
    return 0;
}
@@@ sample_input
4
0 0
100 1
250 3
900 4
@@@ sample_output
0: INIT
100: STANDBY
250: READY
900: DRIVE
time INIT 100
time STANDBY 150
time READY 650

@@@ sample_input
3
0 1
40 7
90 0
@@@ sample_output
0: STANDBY
40: INVALID(7)
90: INIT
time STANDBY 40

@@@ hidden_input
3
0 2
500 5
600 0
@@@ hidden_output
0: PRECHARGE
500: FAULT
600: INIT
time PRECHARGE 500
time FAULT 100

@@@ hidden_input
2
0 0
10 1
@@@ hidden_output
0: INIT
10: STANDBY
time INIT 10

@@@ hidden_input
1
5 3
@@@ hidden_output
5: READY

@@@ hidden_input
4
0 -1
10 6
20 2
30 2
@@@ hidden_output
0: INVALID(-1)
10: INVALID(6)
20: PRECHARGE
30: PRECHARGE
time PRECHARGE 10

@@@ hidden_input
6
0 0
50 1
120 2
400 3
1000 4
5000 1
@@@ hidden_output
0: INIT
50: STANDBY
120: PRECHARGE
400: READY
1000: DRIVE
5000: STANDBY
time INIT 50
time STANDBY 70
time PRECHARGE 280
time READY 600
time DRIVE 4000

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
4
0 4
100 3
300 4
400 3
@@@ hidden_output
0: DRIVE
100: READY
300: DRIVE
400: READY
time READY 200
time DRIVE 200

@@@ hint
The range check is correct, and so is the time bookkeeping. Compare the **enum** with the **name table** line by line. How many entries does each have, and what is at index 2?
@@@ hint
An unsized array `[] = { ... }` silently takes as many elements as you list. Since `PRECHARGE` was added, every later state prints the next state's name, and `hv_state_name[HV_FAULT]` reads past the end of the array.
@@@ solution_code
#include <stdio.h>

typedef enum {
    HV_INIT,
    HV_STANDBY,
    HV_PRECHARGE,       /* new in SW 2.1 */
    HV_READY,
    HV_DRIVE,
    HV_FAULT,
    HV_STATE_COUNT
} HvState;

static const char *const hv_state_name[] = {
    "INIT",
    "STANDBY",
    "PRECHARGE",        /* FIX: name for the new enumerator, in the same position as in the enum */
    "READY",
    "DRIVE",
    "FAULT",
};

static int is_valid_state(int s)
{
    return s >= 0 && s < HV_STATE_COUNT;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    long long time_in[HV_STATE_COUNT] = { 0 };
    int prev_t = 0, prev_s = -1;

    for (int i = 0; i < n; i++) {
        int t, s;
        if (scanf("%d %d", &t, &s) != 2) break;

        if (i > 0 && is_valid_state(prev_s))
            time_in[prev_s] += t - prev_t;

        if (is_valid_state(s))
            printf("%d: %s\n", t, hv_state_name[s]);
        else
            printf("%d: INVALID(%d)\n", t, s);

        prev_t = t;
        prev_s = s;
    }

    for (int s = 0; s < HV_STATE_COUNT; s++)
        if (time_in[s] > 0)
            printf("time %s %lld\n", hv_state_name[s], time_in[s]);
    return 0;
}
@@@ explanation_md
**Bug.** `HV_PRECHARGE` was inserted into the enum, but nobody updated the parallel string table. The table is declared **unsized** (`[]`), so the compiler quietly sizes it to 5 elements while `HV_STATE_COUNT` is 6. Two symptoms follow:
1. Every state after `STANDBY` is printed with the *next* state's name (`PRECHARGE` shows as `READY`, `READY` as `DRIVE`, ...).
2. `hv_state_name[HV_FAULT]` (index 5) is past the end of the array. That is undefined behavior, and AddressSanitizer reports a *global-buffer-overflow*. In the field this prints garbage or crashes the tool.

**Fix.** Insert `"PRECHARGE"` at index 2. To make this impossible to repeat, also make the table self-checking:

```c
static const char *const hv_state_name[HV_STATE_COUNT] = {
    [HV_INIT] = "INIT", [HV_STANDBY] = "STANDBY", [HV_PRECHARGE] = "PRECHARGE", /* ... */
};
_Static_assert(sizeof hv_state_name / sizeof hv_state_name[0] == HV_STATE_COUNT, "names out of sync");
```

Designated initializers make the order irrelevant. The `_Static_assert` only fails when the table is **unsized** and too short (a sized array is always `HV_STATE_COUNT` long, and a missing entry becomes `NULL`), so a fully robust version also checks for `NULL` names in a unit test, or generates both lists from an X-macro.

**Complexity.** Time O(n + HV_STATE_COUNT), space O(HV_STATE_COUNT).

**Common mistakes**
- Fixing the symptom by changing the range check to `s < HV_STATE_COUNT - 1`. This hides `FAULT`, the most important state in an HV log.
- Adding `"PRECHARGE"` at the **end** of the table. The sizes then match, but the names are still shifted.
- Sizing the array `[HV_STATE_COUNT]` without designated initializers. The last entry becomes `NULL`, and `printf("%s", NULL)` is undefined behavior.

**Interview follow-ups**
- Rewrite the enum and the table as a single X-macro list. What exactly does that prevent?
- The inverter firmware and the PC tool are released separately. How do you version the state encoding in the log format so that an old tool does not mis-decode a new log?
- Why is appending new enumerators **at the end** (just before `COUNT`) a common rule for enums that are stored in NVM or sent over the bus?
