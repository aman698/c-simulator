@@@ meta
id: ARR-H-03
topic: Arrays
difficulty: Hard
type: FUNCTION
title: NTC Calibration Lookup Table With Linear Interpolation
tags: embedded, lookup-table, interpolation, binary-search, fixed-point, sensor-calibration
@@@ statement_md
An NTC thermistor's resistance is not linear in temperature, so the ECU converts the raw ADC value with a **calibration table** stored in flash. The table has breakpoints `x[i]` (ADC counts, **strictly increasing**) and values `y[i]` (temperature in 0.1 degC). `y` may rise or fall; for an NTC it falls.

```c
typedef struct {
    const uint16_t *x;   /* breakpoints, strictly increasing */
    const int16_t  *y;   /* output at each breakpoint        */
    uint16_t        n;   /* number of breakpoints, 1..4096   */
} lut_t;

int16_t lut_interp(const lut_t *t, uint16_t adc);
```

Rules:
- `adc <= x[0]` returns `y[0]`, and `adc >= x[n-1]` returns `y[n-1]` (**clamp**, never extrapolate).
- Otherwise find the segment `x[i] <= adc < x[i+1]` and return
  `y[i] + round( (y[i+1] - y[i]) * (adc - x[i]) / (x[i+1] - x[i]) )`,
  where `round` goes to the **nearest integer, with exact halves rounded away from zero** (`2.5 -> 3`, `-2.5 -> -3`).
- **Integer arithmetic only.** The target MCU has no FPU.
- Find the segment in **O(log n)**: the harness makes up to 10^6 lookups in a 4096-entry table.
- `y` spans the full `int16_t` range and `x` the full `uint16_t` range, so `(y[i+1]-y[i]) * (adc-x[i])` can reach about 4.3 * 10^9. The judge runs with UBSan.

**How it is tested.** A hidden `main()` builds the table at the very **end** of a buffer (reading past `x[n-1]` or `y[n-1]` is out of bounds) and prints one result per query. Generated tests compare against a reference and print `OK checksum=...`.

**Input (read by the hidden harness)**
- Either: `n`, then `n` lines `x y`, then `q`, then `q` lines `adc`,
- or: one line `GEN n q seed`.

**Example**
```
Input:
6
200 1250
500 800
1000 450
2000 250
3000 50
3800 -300
4
100
350
505
4095

Output:
1250
1025
796
-300
```
`505`: `800 + round(-350 * 5 / 500) = 800 + round(-3.5) = 800 - 4 = 796`.
@@@ constraints_md
- `1 <= n <= 4096`, `x` strictly increasing in `0..65535`, `y` in `-32768..32767`
- `1 <= q <= 1000000`, `0 <= adc <= 65535`
- O(log n) per lookup, integer arithmetic only, no writes to the table
@@@ starter_code
#include <stdint.h>

/* lut_t is provided by the system (see the statement). */

int16_t lut_interp(const lut_t *t, uint16_t adc)
{
    /* TODO: clamp, binary search the segment, interpolate with rounding */
    return t->y[0];
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

typedef struct {
    const uint16_t *x;
    const int16_t  *y;
    uint16_t        n;
} lut_t;

/*USER_CODE*/

#define MAXN 4096

static uint16_t xs[MAXN];
static int16_t ys[MAXN];

static int16_t ref_interp(const uint16_t *x, const int16_t *y, int n, uint16_t adc)
{
    if (adc <= x[0]) return y[0];
    if (adc >= x[n - 1]) return y[n - 1];
    int lo = 0, hi = n - 1;
    while (hi - lo > 1) {
        int mid = lo + (hi - lo) / 2;
        if (x[mid] <= adc) lo = mid; else hi = mid;
    }
    int64_t num = ((int64_t)y[hi] - y[lo]) * ((int64_t)adc - x[lo]);
    int64_t den = (int64_t)x[hi] - x[lo];
    int64_t q = num >= 0 ? (2 * num + den) / (2 * den) : -((-2 * num + den) / (2 * den));
    return (int16_t)(y[lo] + q);
}

int main(void)
{
    char tok[16];
    int n, q;
    int gen = 0;
    uint32_t s = 0;
    if (scanf("%15s", tok) != 1) return 0;
    if (strcmp(tok, "GEN") == 0) {
        unsigned int seed;
        if (scanf("%d %d %u", &n, &q, &seed) != 3 || n < 1 || n > MAXN || q < 1) return 0;
        gen = 1;
        s = seed;
    } else if (sscanf(tok, "%d", &n) != 1 || n < 1 || n > MAXN) {
        return 0;
    }
    /* the table occupies the LAST n slots, so x[n] / y[n] would be past the arrays */
    uint16_t *x = xs + (MAXN - n);
    int16_t *y = ys + (MAXN - n);
    if (gen) {
        int step_max = n > 1 ? (65535 - 100) / (n - 1) : 1;
        for (int i = 0; i < n; i++) {
            s = s * 1103515245u + 12345u;
            x[i] = (uint16_t)(i == 0 ? (int)((s >> 16) % 100u) : x[i - 1] + 1 + (int)((s >> 16) % (uint32_t)step_max));
            s = s * 1103515245u + 12345u;
            y[i] = (int16_t)((int32_t)((s >> 16) & 0xFFFFu) - 32768);
        }
    } else {
        for (int i = 0; i < n; i++) {
            int xv, yv;
            if (scanf("%d %d", &xv, &yv) != 2) return 0;
            x[i] = (uint16_t)xv;
            y[i] = (int16_t)yv;
        }
        if (scanf("%d", &q) != 1) return 0;
    }
    const lut_t t = { x, y, (uint16_t)n };
    uint64_t checksum = 0;
    for (int k = 0; k < q; k++) {
        uint16_t adc;
        if (gen) {
            s = s * 1103515245u + 12345u;
            uint32_t r = s >> 8;
            if ((r & 7u) == 0) adc = x[(r >> 3) % (uint32_t)n];             /* exact breakpoint */
            else if ((r & 15u) == 1) adc = (r & 16u) ? 65535u : 0u;         /* extremes */
            else adc = (uint16_t)(r >> 4);
        } else {
            unsigned v;
            if (scanf("%u", &v) != 1) return 0;
            adc = (uint16_t)v;
        }
        int16_t got = lut_interp(&t, adc);
        if (gen) {
            int16_t want = ref_interp(x, y, n, adc);
            if (got != want) {
                printf("WRONG for adc=%u: got %d, expected %d\n", (unsigned)adc, got, want);
                return 0;
            }
            checksum = checksum * 1000003u + (uint16_t)got;
        } else {
            printf("%d\n", got);
        }
    }
    if (gen) printf("OK checksum=%llu\n", (unsigned long long)checksum);
    return 0;
}
@@@ sample_input
6
200 1250
500 800
1000 450
2000 250
3000 50
3800 -300
4
100
350
505
4095
@@@ sample_output
1250
1025
796
-300

@@@ sample_input
2
0 -32768
65535 32767
5
0
65535
1
32768
40000
@@@ sample_output
-32768
32767
-32767
0
7232

@@@ hidden_input
6
200 1250
500 800
1000 450
2000 250
3000 50
3800 -300
9
200
501
750
1999
2000
3400
3799
3800
65535
@@@ hidden_output
1250
799
625
250
250
-125
-300
-300
-300

@@@ hidden_input
1
1000 255
3
0
1000
65535
@@@ hidden_output
255
255
255

@@@ hidden_input
3
0 0
2 1
4 0
4
1
3
2
4
@@@ hidden_output
1
0
1
0

@@@ hidden_input
2
0 32767
65535 -32768
4
40000
65534
1
32767
@@@ hidden_output
-7233
-32767
32766
0

@@@ hidden_input
GEN 4096 1000000 1
@@@ hidden_output
OK checksum=16127378941131960028

@@@ hidden_input
GEN 2 200000 2
@@@ hidden_output
OK checksum=12599118440761074106

@@@ hidden_input
GEN 64 300000 3
@@@ hidden_output
OK checksum=2535991890091230034

@@@ hint
Clamp first. Then binary-search the segment with the invariant `x[lo] <= adc < x[hi]`, starting from `lo = 0`, `hi = n - 1`. Loop while `hi - lo > 1`, so `mid` is always strictly inside and `lo = mid` cannot stall.
@@@ hint
Do the interpolation in `int64_t`: `num = (int64_t)(y1 - y0) * (adc - x0)`, `den = x1 - x0 > 0`. Round half away from zero without floating point: `num >= 0 ? (2*num + den) / (2*den) : -((-2*num + den) / (2*den))`. Plain `/` truncates toward zero, so a separate case for negative values is needed.
@@@ solution_code
#include <stdint.h>

/* divide num by den > 0, rounding to nearest, halves away from zero */
static int64_t div_round(int64_t num, int64_t den)
{
    return num >= 0 ? (2 * num + den) / (2 * den)
                    : -((-2 * num + den) / (2 * den));
}

int16_t lut_interp(const lut_t *t, uint16_t adc)
{
    const uint16_t *x = t->x;
    const int16_t *y = t->y;
    uint16_t n = t->n;

    if (adc <= x[0])
        return y[0];                       /* clamp low (also covers n == 1) */
    if (adc >= x[n - 1])
        return y[n - 1];                   /* clamp high */

    /* invariant: x[lo] <= adc < x[hi] */
    uint16_t lo = 0, hi = (uint16_t)(n - 1);
    while (hi - lo > 1) {
        uint16_t mid = (uint16_t)(lo + (hi - lo) / 2);
        if (x[mid] <= adc)
            lo = mid;
        else
            hi = mid;
    }

    int64_t num = ((int64_t)y[hi] - y[lo]) * ((int64_t)adc - x[lo]);   /* up to ~4.3e9 */
    int64_t den = (int64_t)x[hi] - x[lo];
    return (int16_t)(y[lo] + div_round(num, den));                   /* stays between y[lo] and y[hi] */
}
@@@ explanation_md
**Approach.**
1. **Clamp** outside the table. Extrapolating an NTC curve beyond its last breakpoint gives absurd temperatures, and an open or shorted sensor would then look like a plausible value.
2. **Binary search** for the segment with the invariant `x[lo] <= adc < x[hi]`. Because the loop runs only while `hi - lo > 1`, `mid` is strictly between them, so both `lo = mid` and `hi = mid` make progress. O(log n): 12 steps for 4096 breakpoints instead of up to 4096.
3. **Interpolate in 64 bits.** `dy` can be ±65 535 and `dx` up to 65 535, so the product reaches 4.29 * 10^9, more than `INT32_MAX`. On a 32-bit MCU an `int32_t` multiply silently wraps (it is formally UB); the result is a wrong temperature only in certain segments.
4. **Round correctly.** C's `/` truncates toward zero, so `-3.5` becomes `-3` and `3.5` becomes `3`. Rounding half away from zero needs the sign split shown above (`2*num + den` over `2*den`).

```
adc = 505 in [500, 1000]: dy = -350, dx = 5, den = 500
num = -1750 -> -((3500 + 500) / 1000) = -4 -> 800 - 4 = 796
```

**Complexity.** O(log n) per lookup, O(1) extra memory. The table is read-only and can stay `const` in flash.

**Common mistakes**
- `int32_t` (or `int`) product: overflows for steep, wide segments (sample 2 with `adc = 40000`).
- `(dy * dx + den / 2) / den` for all signs: rounds negative values the wrong way (`-3.5 -> -3`).
- Linear search: correct, but 4096 * 10^6 comparisons is too slow here and wastes CPU in a 1 ms task.
- Binary search off-by-one: returning `hi` as the segment start, or reading `x[i+1]` when `adc == x[n-1]`, which is one past the table (the harness places the table at the end of its buffer, so ASan reports it).
- Extrapolating instead of clamping.
- Dividing first (`dy / dx * (adc - x0)`): precision is lost; for `|dy| < dx` the slope truncates to 0.

**Interview follow-ups**
- Uniformly spaced breakpoints (`x[i] = x0 + i * 2^s`): the segment index is `(adc - x0) >> s` and the division becomes a shift. Why do most calibration tables in production use this layout?
- Make the table **monotonic-safe**: what should happen if a calibration engineer flashes a table whose `x` is not strictly increasing? (Check at start-up and report a DTC; `den == 0` would otherwise divide by zero.)
- Inverse lookup: given a temperature, find the ADC threshold for a fan-on comparator. (Binary search on `y`, which is monotonic decreasing for an NTC.)
- 2D maps (e.g. ignition timing over RPM x load): bilinear interpolation with two binary searches.
