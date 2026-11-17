@@@ meta
id: PAT-H-03
topic: C Patterns
difficulty: Hard
type: FUNCTION
title: Vertical Bargraph of ADC Channels
tags: embedded, bargraph, adc, fixed-point-rounding, clamping, vertical-rendering
@@@ statement_md
A service tool shows the raw readings of several ADC channels (battery voltage, NTC temperatures, pedal sensors, ...) as a **vertical bar chart** on a text console. Implement

```c
void print_bargraph(const int *adc, int nch, int full_scale, int height);
```

**Rules**
1. If `nch < 1`, `nch > 16`, `full_scale < 1`, `height < 1` or `height > 20`, print the single line `ERR` and return. In that case `adc` may be `NULL`.
2. Clamp every reading to `0..full_scale` (offset calibration can make a reading negative, and a shorted input can exceed full scale).
3. The bar height of channel `c` is `round(v * height / full_scale)`, where `v` is the clamped reading. **Round half up**: `2.5 -> 3`, `0.49 -> 0`.
4. Print `height` rows, from level `L = height` down to `L = 1`. Each row is the label `round(L * 100 / height)` (round half up) printed with `"%3d%%|"`, followed by, for every channel, a space and then `#` if the bar height of that channel is `>= L`, otherwise a space.
5. Then the axis line: `  0%+` followed by `--` for every channel.
6. Then the index line: 5 spaces, then for every channel a space and the digit `c % 10`.

`full_scale` can be as large as `2^30 - 1`, so `v * height` does not fit in an `int`. Use integer arithmetic only.

**How it is tested.** A hidden `main()` reads `q` charts. For each one it reads `nch full_scale height` and `nch` readings, prints `== chart <k> ==` and calls your function. For `nch <= 0` it passes `adc = NULL`.

**Output.** Leading spaces are significant. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
1
4 4095 4
4095 2048 1000 0

Output:
== chart 1 ==
100%| #
 75%| #
 50%| # #
 25%| # # #
  0%+--------
      0 1 2 3
```
Bar heights: `4095*4/4095 = 4`, `2048*4/4095 = 2.0005 -> 2`, `1000*4/4095 = 0.977 -> 1`, `0`.
@@@ constraints_md
- `1 <= q <= 10`
- `-5 <= nch <= 20` (the input always contains `max(nch, 0)` readings)
- `-10 <= full_scale <= 2^30 - 1`, `-5 <= height <= 30`
- Each reading fits in an `int`.
- No floating point; do not use `long` (use `long long` or `int64_t`).
@@@ starter_code
#include <stdio.h>

void print_bargraph(const int *adc, int nch, int full_scale, int height)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define round(x) round_is_not_allowed_use_integer_math
#define lround(x) lround_is_not_allowed_use_integer_math

/*USER_CODE*/

#undef round
#undef lround

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 1; k <= q; k++) {
        int nch, fs, h;
        if (scanf("%d %d %d", &nch, &fs, &h) != 3) return 0;
        int *adc = NULL;
        if (nch > 0) {
            adc = malloc((size_t)nch * sizeof *adc);   /* exact size: over-reads are caught */
            if (!adc) return 1;
            for (int i = 0; i < nch; i++)
                if (scanf("%d", &adc[i]) != 1) { free(adc); return 0; }
        }
        printf("== chart %d ==\n", k);
        print_bargraph(adc, nch, fs, h);
        free(adc);
    }
    return 0;
}
@@@ sample_input
1
4 4095 4
4095 2048 1000 0
@@@ sample_output
== chart 1 ==
100%| #
 75%| #
 50%| # #
 25%| # # #
  0%+--------
      0 1 2 3

@@@ sample_input
1
5 100 3
100 50 16 17 0
@@@ sample_output
== chart 1 ==
100%| #
 67%| # #
 33%| # #   #
  0%+----------
      0 1 2 3 4

@@@ hidden_input
5
0 100 3
17 100 3
1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
2 100 0
1 2
2 100 21
1 2
2 0 3
1 2
@@@ hidden_output
== chart 1 ==
ERR
== chart 2 ==
ERR
== chart 3 ==
ERR
== chart 4 ==
ERR
== chart 5 ==
ERR

@@@ hidden_input
1
6 1000 5
-50 1500 1000 999 100 99
@@@ hidden_output
== chart 1 ==
100%|   # # #
 80%|   # # #
 60%|   # # #
 40%|   # # #
 20%|   # # # #
  0%+------------
      0 1 2 3 4 5

@@@ hidden_input
2
4 10 1
4 5 6 10
1 1 2
1
@@@ hidden_output
== chart 1 ==
100%|   # # #
  0%+--------
      0 1 2 3
== chart 2 ==
100%| #
 50%| #
  0%+--
      0

@@@ hidden_input
1
3 1073741823 20
1073741823 536870912 1
@@@ hidden_output
== chart 1 ==
100%| #
 95%| #
 90%| #
 85%| #
 80%| #
 75%| #
 70%| #
 65%| #
 60%| #
 55%| #
 50%| # #
 45%| # #
 40%| # #
 35%| # #
 30%| # #
 25%| # #
 20%| # #
 15%| # #
 10%| # #
  5%| # #
  0%+------
      0 1 2

@@@ hidden_input
1
8 255 8
0 32 64 96 128 160 192 255
@@@ hidden_output
== chart 1 ==
100%|               #
 88%|               #
 75%|             # #
 63%|           # # #
 50%|         # # # #
 38%|       # # # # #
 25%|     # # # # # #
 13%|   # # # # # # #
  0%+----------------
      0 1 2 3 4 5 6 7

@@@ hidden_input
1
16 65535 7
65535 -1 32767 32768 4681 4682 9362 70000 0 13107 26214 39321 52428 58981 2340 2341
@@@ hidden_output
== chart 1 ==
100%| #             #
 86%| #             #         # #
 71%| #             #         # #
 57%| #     #       #       # # #
 43%| #   # #       #     # # # #
 29%| #   # #       #     # # # #
 14%| #   # #   # # #   # # # # #
  0%+--------------------------------
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5

@@@ hint
Round half up in integer arithmetic: `round(a / b) = (2*a + b) / (2*b)` for `a >= 0, b > 0`. Do it in `long long`, because `2 * v * height` can reach about `4 * 10^10`.
@@@ hint
Compute all bar heights first (at most 16), then print row by row from the top. A channel shows `#` in row `L` exactly when its bar height is `>= L`. Validate before you touch `adc`, since it may be `NULL`.
@@@ solution_code
#include <stdio.h>

/* round(a / b), half up, for a >= 0 and b > 0 */
static int div_round(long long a, long long b)
{
    return (int)((2 * a + b) / (2 * b));
}

void print_bargraph(const int *adc, int nch, int full_scale, int height)
{
    if (nch < 1 || nch > 16 || full_scale < 1 || height < 1 || height > 20) {
        printf("ERR\n");                    /* adc may be NULL here: never touch it */
        return;
    }

    int bar[16];
    for (int c = 0; c < nch; c++) {
        long long v = adc[c];
        if (v < 0) v = 0;                   /* clamp to 0..full_scale */
        if (v > full_scale) v = full_scale;
        bar[c] = div_round(v * height, full_scale);   /* 64-bit product */
    }

    for (int level = height; level >= 1; level--) {
        printf("%3d%%|", div_round(100LL * level, height));
        for (int c = 0; c < nch; c++) {
            putchar(' ');
            putchar(bar[c] >= level ? '#' : ' ');
        }
        putchar('\n');
    }

    printf("  0%%+");
    for (int c = 0; c < nch; c++)
        printf("--");
    putchar('\n');

    printf("     ");
    for (int c = 0; c < nch; c++)
        printf(" %d", c % 10);
    putchar('\n');
}
@@@ explanation_md
**Approach.** A vertical chart must be printed **row by row from the top**, but the data is per channel. So compute all bar heights first, then for each level `L` (top to bottom) print `#` for every channel whose bar reaches that level. The level labels and the bar heights use the same rounding helper:

```
round_half_up(a / b) = floor((2a + b) / (2b))        a >= 0, b > 0
bar  = round_half_up(v * height / full_scale)
label = round_half_up(L * 100 / height)
```

Example: `height = 8`, level 1 is `12.5 %` and is labelled `13`; level 3 is `37.5 %` and is labelled `38`.

**Overflow.** With `full_scale` up to `2^30 - 1` and `height` up to 20, `2 * v * height` is about `4.3 * 10^10`, far beyond `INT_MAX`. Converting `v` to `long long` **before** the multiplication is essential. Writing `(long long)(v * height)` is too late, because the `int` product has already overflowed.

**Complexity.** Time O(nch * height). Space O(nch) for the bar heights.

**Common mistakes**
- Truncating instead of rounding (`v * height / full_scale`): a channel at 49 % of a 2-row chart then shows nothing at all, and labels such as 66.67 % become 66.
- Rounding with `+ 0.5` on doubles. That uses floating point (often not available or slow on small MCUs) and still needs care with large integers.
- Clamping after scaling, or not at all: a reading of `70000` on a 16-bit scale would draw a bar taller than the chart.
- Reading `adc[c]` before validating. For invalid charts the harness passes `NULL`.
- Printing a literal `%` with `printf("%")`. It must be `%%`.

**Interview follow-ups**
- Add **peak-hold** markers (`-` at the highest level each channel has reached in the last N updates). What state must be kept between calls?
- The ADC is 12-bit but the chart should show physical units (mV) using a calibration `mV = raw * 3300 / 4095`. How do you keep the rounding exact?
- On an LCD you would redraw only the cells that changed. How would you diff two frames cheaply?
