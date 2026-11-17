@@@ meta
id: PAT-H-06
topic: C Patterns
difficulty: Hard
type: CODE
title: Multi-Channel PWM Waveform with Phase Shift
tags: embedded, pwm, waveform, modulo-wraparound, rounding, motor-control
@@@ statement_md
A motor-control engineer wants a quick ASCII preview of the PWM outputs of a timer before flashing the board. The timer counts ticks `t = 0 .. T-1` in every period.

Each channel has a **mode**, a **duty** in percent and a **phase** in ticks:
- The pulse length is `h = round(duty * T / 100)` ticks, rounded **half up** (`2.5 -> 3`).
- Mode `E` (edge-aligned): the pulse **starts** at tick `phase`, so `start = phase`.
- Mode `C` (center-aligned): the pulse is centered in the period that starts at `phase`, so `start = (phase + (T - h) / 2) % T` (integer division).
- Tick `t` is **high** if `(t - start + T) % T < h`. A pulse may wrap past the end of the period into its beginning.

**Output.** For channel `i` (1-based) print `CH<i> |` followed, for each of the `k` periods, by `T` characters (`#` for high, `_` for low) and a `|`. Then print `SUM |` in the same layout, where each character is the **number of channels that are high** at that tick (a digit). Finally print `PEAK=<p>`, the maximum of that sum.

**Validation.** Print only `INVALID` if any value is out of range: `1 <= T <= 50`, `1 <= k <= 5`, `1 <= m <= 6`, `0 <= duty <= 100`, `0 <= phase <= T - 1`, mode `E` or `C`.

**Input**
- Line 1: `T k m`.
- Next `m` lines: `mode duty phase` (if `m` is out of range, these lines may be missing).

**Output**
- `m + 2` lines, or `INVALID`. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
10 2 2
E 40 0
E 30 8

Output:
CH1 |####______|####______|
CH2 |#_______##|#_______##|
SUM |2111000011|2111000011|
PEAK=2
```
Channel 2 has `h = 3` and starts at tick 8, so it is high at ticks 8, 9 and (wrapping) 0.
@@@ constraints_md
- `-10 <= T, k, m <= 100`; `-10 <= duty <= 200`; `-10 <= phase <= 100`.
- When `1 <= m <= 6`, exactly `m` channel lines follow; mode is a single character.
- Integer arithmetic only.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int T, k, m;
    if (scanf("%d %d %d", &T, &k, &m) != 3) return 0;

    /* TODO: read and validate the channels, compute each pulse,
       print the channel lines, the SUM line and PEAK */

    return 0;
}
@@@ sample_input
10 2 2
E 40 0
E 30 8
@@@ sample_output
CH1 |####______|####______|
CH2 |#_______##|#_______##|
SUM |2111000011|2111000011|
PEAK=2

@@@ sample_input
8 1 2
C 50 0
E 50 0
@@@ sample_output
CH1 |__####__|
CH2 |####____|
SUM |11221100|
PEAK=2

@@@ hidden_input
0 1 1
E 50 0
@@@ hidden_output
INVALID

@@@ hidden_input
10 6 1
E 50 0
@@@ hidden_output
INVALID

@@@ hidden_input
10 1 0
@@@ hidden_output
INVALID

@@@ hidden_input
10 1 2
E 50 0
E 101 0
@@@ hidden_output
INVALID

@@@ hidden_input
10 1 2
E 50 0
C 50 10
@@@ hidden_output
INVALID

@@@ hidden_input
10 1 1
X 50 0
@@@ hidden_output
INVALID

@@@ hidden_input
10 1 3
E 25 0
E 24 0
E 26 9
@@@ hidden_output
CH1 |###_______|
CH2 |##________|
CH3 |##_______#|
SUM |3310000001|
PEAK=3

@@@ hidden_input
5 2 2
E 0 3
C 100 4
@@@ hidden_output
CH1 |_____|_____|
CH2 |#####|#####|
SUM |11111|11111|
PEAK=1

@@@ hidden_input
1 3 2
E 50 0
E 49 0
@@@ hidden_output
CH1 |#|#|#|
CH2 |_|_|_|
SUM |1|1|1|
PEAK=1

@@@ hidden_input
7 2 1
C 40 3
@@@ hidden_output
CH1 |#____##|#____##|
SUM |1000011|1000011|
PEAK=1

@@@ hidden_input
30 2 6
E 50 0
E 50 10
E 50 20
C 33 0
C 33 15
E 17 29
@@@ hidden_output
CH1 |###############_______________|###############_______________|
CH2 |__________###############_____|__________###############_____|
CH3 |#####_______________##########|#####_______________##########|
CH4 |__________##########__________|__________##########__________|
CH5 |#####____________________#####|#####____________________#####|
CH6 |####_________________________#|####_________________________#|
SUM |444431111133333222222222222223|444431111133333222222222222223|
PEAK=4

@@@ hidden_input
50 5 6
E 100 49
C 1 0
C 99 25
E 51 49
C 0 7
E 13 40
@@@ hidden_output
CH1 |##################################################|##################################################|##################################################|##################################################|##################################################|
CH2 |________________________#_________________________|________________________#_________________________|________________________#_________________________|________________________#_________________________|________________________#_________________________|
CH3 |##################################################|##################################################|##################################################|##################################################|##################################################|
CH4 |#########################________________________#|#########################________________________#|#########################________________________#|#########################________________________#|#########################________________________#|
CH5 |__________________________________________________|__________________________________________________|__________________________________________________|__________________________________________________|__________________________________________________|
CH6 |________________________________________#######___|________________________________________#######___|________________________________________#######___|________________________________________#######___|________________________________________#######___|
SUM |33333333333333333333333342222222222222223333333223|33333333333333333333333342222222222222223333333223|33333333333333333333333342222222222222223333333223|33333333333333333333333342222222222222223333333223|33333333333333333333333342222222222222223333333223|
PEAK=4

@@@ hint
Round half up with integers: `h = (2 * duty * T + 100) / 200`. Compute `start` once per channel; the picture of one period is the same for every period.
@@@ hint
`t - start` can be negative, and in C `-3 % 10` is `-3`, not `7`. Add `T` before taking the remainder: `(t - start + T) % T < h`. Validate every channel before printing anything, because `INVALID` must be the only output.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int T, k, m;
    if (scanf("%d %d %d", &T, &k, &m) != 3) return 0;

    if (T < 1 || T > 50 || k < 1 || k > 5 || m < 1 || m > 6) {
        printf("INVALID\n");
        return 0;
    }

    int start[6], h[6];
    for (int i = 0; i < m; i++) {
        char mode;
        int duty, phase;
        if (scanf(" %c %d %d", &mode, &duty, &phase) != 3) return 0;
        if ((mode != 'E' && mode != 'C') || duty < 0 || duty > 100 || phase < 0 || phase >= T) {
            printf("INVALID\n");                    /* nothing printed before this */
            return 0;
        }
        h[i] = (2 * duty * T + 100) / 200;          /* round(duty * T / 100), half up */
        start[i] = (mode == 'E') ? phase : (phase + (T - h[i]) / 2) % T;
    }

    char wave[6][50];
    int sum[50] = {0};
    int peak = 0;
    for (int t = 0; t < T; t++) {
        for (int i = 0; i < m; i++) {
            int high = (t - start[i] + T) % T < h[i];   /* +T: no negative remainder */
            wave[i][t] = high ? '#' : '_';
            sum[t] += high;
        }
        if (sum[t] > peak)
            peak = sum[t];
    }

    for (int i = 0; i < m; i++) {
        printf("CH%d |", i + 1);
        for (int p = 0; p < k; p++)
            printf("%.*s|", T, wave[i]);            /* one period, not NUL-terminated */
        putchar('\n');
    }
    printf("SUM |");
    for (int p = 0; p < k; p++) {
        for (int t = 0; t < T; t++)
            putchar('0' + sum[t]);
        putchar('|');
    }
    printf("\nPEAK=%d\n", peak);
    return 0;
}
@@@ explanation_md
**Approach.** A PWM output is periodic, so compute **one period** per channel and print it `k` times. For each channel:
1. `h = round(duty * T / 100)`, half up, as `(2*duty*T + 100) / 200`.
2. The start tick: `phase` for edge-aligned; for center-aligned the pulse is shifted by half the low time, `(T - h) / 2`, and wrapped with `% T`.
3. Tick `t` is high if its distance after `start`, taken modulo `T`, is less than `h`: `(t - start + T) % T < h`. This one comparison handles pulses that wrap around the period boundary.

```
T = 10, E 30 8:  h = 3, start = 8
t           0 1 2 3 4 5 6 7 8 9
(t-8+10)%10 2 3 4 5 6 7 8 9 0 1   -> high where < 3: t = 8, 9, 0
```

The `SUM` row shows how many phases conduct at the same time. Interleaving phases (as in a multi-phase buck converter or a 3-phase inverter) lowers the `PEAK`, and with it the input current ripple.

**Complexity.** Time O(m * T) to compute, O((m + 1) * k * T) to print. Space O(m * T).

**Common mistakes**
- `(t - start) % T` without `+ T`: in C the remainder has the sign of the dividend, so ticks before `start` are never high and wrapped pulses disappear.
- Truncating `duty * T / 100`: 25 % of 10 ticks gives 2 instead of 3.
- Printing the channels while still reading them. Then an invalid later channel leaves partial output before `INVALID`.
- Forgetting the duty = 0 and duty = 100 edge cases (no edges at all), or the center-aligned shift with an odd `T - h`.
- Printing `wave[i]` with `%s`. The row is not NUL-terminated; `%.*s` with the length prints exactly `T` characters.

**Interview follow-ups**
- On an STM32 timer, which registers implement period, duty and center-aligned mode (`ARR`, `CCRx`, `CMS` bits)? Why does center-aligned mode halve the effective PWM frequency for the same `ARR`?
- Add **dead time**: complementary outputs `CHx` and `CHxN` must never be high together. How do you insert `dt` low ticks around each edge?
- Why should a new duty value be written to a **preload (shadow) register** and only take effect at the update event?
