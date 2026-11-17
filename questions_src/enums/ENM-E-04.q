@@@ meta
id: ENM-E-04
topic: Enums
difficulty: Easy
type: CODE
title: Per-Channel Sensor Statistics With a COUNT Sentinel
tags: embedded, enum-as-index, count-sentinel, input-validation, adc
@@@ statement_md
An engine ECU logs temperature samples from four sensor channels. Each channel is identified by an enum:

```c
enum Channel { CH_COOLANT, CH_OIL, CH_INTAKE, CH_EXHAUST, CH_COUNT };
```

`CH_COUNT` is not a channel. It is a **sentinel** equal to the number of channels, and you should use it to size your per-channel arrays and to bound your loops.

Read `n` samples. Each sample is a raw channel number and a value in degrees Celsius. For every **valid** channel, track how many samples it got, the minimum, the maximum and the average. A sample whose channel number is not a valid `enum Channel` value (negative, `CH_COUNT` or larger) is **rejected** and counted.

**Input**
- Line 1: `n`.
- Next `n` lines: `ch value` (two integers).

**Output**
- One line per channel, in enum order (`COOLANT`, `OIL`, `INTAKE`, `EXHAUST`):
  - `NAME n=<count> min=<min> max=<max> avg=<avg>` if the channel has at least one sample, where `avg = sum / count` using C integer division (truncated toward zero);
  - `NAME n=0` otherwise.
- A last line `rejected=<k>`.

**Example**
```
Input:
6
0 88
1 95
0 92
3 640
7 100
0 90

Output:
COOLANT n=3 min=88 max=92 avg=90
OIL n=1 min=95 max=95 avg=95
INTAKE n=0
EXHAUST n=1 min=640 max=640 avg=640
rejected=1
```
@@@ constraints_md
- `0 <= n <= 1000`
- `ch` is any 32-bit `int` (`INT_MIN` and `INT_MAX` may appear).
- `-40 <= value <= 1200`
- Size all per-channel storage with `CH_COUNT`, not a magic number.
@@@ starter_code
#include <stdio.h>

enum Channel { CH_COOLANT, CH_OIL, CH_INTAKE, CH_EXHAUST, CH_COUNT };

static const char *const ch_name[CH_COUNT] = { "COOLANT", "OIL", "INTAKE", "EXHAUST" };

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    /* TODO: per-channel statistics, sized with CH_COUNT */
    int rejected = 0;

    for (int i = 0; i < n; i++) {
        int ch, value;
        if (scanf("%d %d", &ch, &value) != 2) break;
        /* TODO: validate ch, then update that channel's statistics */
    }

    /* TODO: one line per channel, in enum order */
    printf("rejected=%d\n", rejected);
    return 0;
}
@@@ sample_input
6
0 88
1 95
0 92
3 640
7 100
0 90
@@@ sample_output
COOLANT n=3 min=88 max=92 avg=90
OIL n=1 min=95 max=95 avg=95
INTAKE n=0
EXHAUST n=1 min=640 max=640 avg=640
rejected=1

@@@ sample_input
0
@@@ sample_output
COOLANT n=0
OIL n=0
INTAKE n=0
EXHAUST n=0
rejected=0

@@@ hidden_input
3
2 -40
2 -15
2 -10
@@@ hidden_output
COOLANT n=0
OIL n=0
INTAKE n=3 min=-40 max=-10 avg=-21
EXHAUST n=0
rejected=0

@@@ hidden_input
4
4 100
-1 50
3 700
3 701
@@@ hidden_output
COOLANT n=0
OIL n=0
INTAKE n=0
EXHAUST n=2 min=700 max=701 avg=700
rejected=2

@@@ hidden_input
4
3 1200
2 25
1 130
0 105
@@@ hidden_output
COOLANT n=1 min=105 max=105 avg=105
OIL n=1 min=130 max=130 avg=130
INTAKE n=1 min=25 max=25 avg=25
EXHAUST n=1 min=1200 max=1200 avg=1200
rejected=0

@@@ hidden_input
3
2147483647 5
-2147483648 6
1 7
@@@ hidden_output
COOLANT n=0
OIL n=1 min=7 max=7 avg=7
INTAKE n=0
EXHAUST n=0
rejected=2

@@@ hidden_input
2
5 10
100 20
@@@ hidden_output
COOLANT n=0
OIL n=0
INTAKE n=0
EXHAUST n=0
rejected=2

@@@ hidden_input
5
1 -40
1 -40
1 -40
1 -40
1 -40
@@@ hidden_output
COOLANT n=0
OIL n=5 min=-40 max=-40 avg=-40
INTAKE n=0
EXHAUST n=0
rejected=0

@@@ hidden_input
4
0 1
0 2
3 -1
3 2
@@@ hidden_output
COOLANT n=2 min=1 max=2 avg=1
OIL n=0
INTAKE n=0
EXHAUST n=2 min=-1 max=2 avg=0
rejected=0

@@@ hint
Declare `int count[CH_COUNT], sum[CH_COUNT], ...` (or one array of structs) and loop `for (int c = 0; c < CH_COUNT; c++)`. Adding a fifth channel then only means adding one enumerator and one name.
@@@ hint
Validate before indexing: `if (ch < 0 || ch >= CH_COUNT) { rejected++; continue; }`. Keep `ch` as a plain `int` until it has passed the check. Initialize min and max from the **first** sample of each channel, not from 0.
@@@ solution_code
#include <stdio.h>

enum Channel { CH_COOLANT, CH_OIL, CH_INTAKE, CH_EXHAUST, CH_COUNT };

static const char *const ch_name[CH_COUNT] = { "COOLANT", "OIL", "INTAKE", "EXHAUST" };

struct ChStats {
    int count;
    int sum;
    int min;
    int max;
};

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    struct ChStats st[CH_COUNT] = { { 0, 0, 0, 0 } };   /* sized by the sentinel */
    int rejected = 0;

    for (int i = 0; i < n; i++) {
        int ch, value;
        if (scanf("%d %d", &ch, &value) != 2) break;
        if (ch < 0 || ch >= CH_COUNT) {          /* never index with an unchecked value */
            rejected++;
            continue;
        }
        struct ChStats *s = &st[ch];
        if (s->count == 0 || value < s->min) s->min = value;
        if (s->count == 0 || value > s->max) s->max = value;
        s->sum += value;
        s->count++;
    }

    for (int c = 0; c < CH_COUNT; c++) {
        const struct ChStats *s = &st[c];
        if (s->count == 0)
            printf("%s n=0\n", ch_name[c]);
        else
            printf("%s n=%d min=%d max=%d avg=%d\n", ch_name[c], s->count, s->min, s->max,
                   s->sum / s->count);
    }
    printf("rejected=%d\n", rejected);
    return 0;
}
@@@ explanation_md
**Approach.** The enum doubles as an array index. `CH_COUNT` (the last enumerator) automatically equals the number of real channels, so `struct ChStats st[CH_COUNT]` and `for (c = 0; c < CH_COUNT; c++)` grow with the enum. Each raw channel number from the input is range-checked **before** it is used as an index. Invalid samples are counted and skipped. Min and max are seeded from the first sample of each channel (`count == 0`), so negative temperatures work.

**Complexity.** Time O(n + CH_COUNT), space O(CH_COUNT).

**Common mistakes**
- Using the sentinel as a channel: `if (ch > CH_COUNT)` lets `ch == CH_COUNT` write one element past the end of every array.
- Forgetting negative channel numbers. `st[-1]` is an out-of-bounds write that corrupts whatever sits before the array on the stack.
- Initializing `max = 0`. A channel whose readings are all below zero (intake air at -40 °C) then reports `max=0`.
- Hard-coding `4` in the loops and arrays. The next engineer adds `CH_TRANS_OIL` before `CH_COUNT`, and the arrays silently become too small.
- Printing `avg` for an empty channel, which divides by zero.

**Interview follow-ups**
- How do you guarantee at compile time that `ch_name` has exactly `CH_COUNT` entries? (`_Static_assert(sizeof ch_name / sizeof ch_name[0] == CH_COUNT, ...)`, or generate both with an X-macro.)
- The sum could overflow with long logging periods. Which type would you use, and how would you compute a running average without storing the sum? (`int64_t`, or an exponential moving average.)
- On a Cortex-M ADC driver, would you index a DMA result buffer directly by this enum? What has to stay in sync with the ADC sequencer configuration?
