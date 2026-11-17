@@@ meta
id: PAT-E-06
topic: C Patterns
difficulty: Easy
type: FUNCTION
title: Battery Gauge Icon for a Cluster Display
tags: embedded, hollow-shape, clamping, rounding, hmi
@@@ statement_md
The instrument cluster of an e-scooter draws the battery state of charge (SoC) as a 3-line ASCII icon with `segments` cells. Implement

```c
void draw_battery(int percent, int segments);
```

**Rules**
1. If `segments < 1` or `segments > 40`, print the single line `ERR` and return.
2. Clamp `percent` to `0..100`, because the fuel-gauge IC sometimes reports glitches such as `-3` or `104`.
3. The number of lit cells is `lit = ceil(percent * segments / 100)`. A cell stays lit while **any** charge is left in its range, so 1 % still shows one cell and only 0 % is empty.
4. Print three lines (with `S = segments`):
   - line 1: `+`, then `S` times `-`, then `+`
   - line 2: `|`, `lit` times `#`, `S - lit` spaces, `|`, then `=` (the battery terminal), a space, the clamped percent and `%`. If the clamped percent is `<= 10`, append ` LOW`.
   - line 3: the same as line 1.

**How it is tested.** A hidden `main()` reads `q` queries `percent segments`. For each one it prints a line `# battery(<percent>, <segments>)` and then calls your function.

**Input (read by the hidden harness)**
- Line 1: `q`. Next `q` lines: `percent segments`.

**Output**
- For each query, the harness line followed by your lines. Spaces **inside** the icon are significant. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
2
57 10
5 10

Output:
# battery(57, 10)
+----------+
|######    |= 57%
+----------+
# battery(5, 10)
+----------+
|#         |= 5% LOW
+----------+
```
`ceil(57 * 10 / 100) = ceil(5.7) = 6` lit cells; `ceil(0.5) = 1`.
@@@ constraints_md
- `1 <= q <= 20`
- `-1000 <= percent <= 1000`, `-10 <= segments <= 100`
- Integer arithmetic only (no `<math.h>`).
@@@ starter_code
#include <stdio.h>

void draw_battery(int percent, int segments)
{
    /* TODO: validate, clamp, compute lit cells, print 3 lines */
}
@@@ harness_code
#include <stdio.h>
#include <math.h>

#define ceil(x) ceil_is_not_needed_use_integer_math
#define round(x) round_is_not_needed_use_integer_math

/*USER_CODE*/

#undef ceil
#undef round

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        int p, s;
        if (scanf("%d %d", &p, &s) != 2) return 0;
        printf("# battery(%d, %d)\n", p, s);
        draw_battery(p, s);
    }
    return 0;
}
@@@ sample_input
2
57 10
5 10
@@@ sample_output
# battery(57, 10)
+----------+
|######    |= 57%
+----------+
# battery(5, 10)
+----------+
|#         |= 5% LOW
+----------+

@@@ sample_input
2
100 4
0 4
@@@ sample_output
# battery(100, 4)
+----+
|####|= 100%
+----+
# battery(0, 4)
+----+
|    |= 0% LOW
+----+

@@@ hidden_input
3
150 4
-20 4
104 1
@@@ hidden_output
# battery(150, 4)
+----+
|####|= 100%
+----+
# battery(-20, 4)
+----+
|    |= 0% LOW
+----+
# battery(104, 1)
+-+
|#|= 100%
+-+

@@@ hidden_input
3
50 0
50 41
50 -1
@@@ hidden_output
# battery(50, 0)
ERR
# battery(50, 41)
ERR
# battery(50, -1)
ERR

@@@ hidden_input
4
10 3
11 3
34 3
67 3
@@@ hidden_output
# battery(10, 3)
+---+
|#  |= 10% LOW
+---+
# battery(11, 3)
+---+
|#  |= 11%
+---+
# battery(34, 3)
+---+
|## |= 34%
+---+
# battery(67, 3)
+---+
|###|= 67%
+---+

@@@ hidden_input
3
1 40
99 40
50 40
@@@ hidden_output
# battery(1, 40)
+----------------------------------------+
|#                                       |= 1% LOW
+----------------------------------------+
# battery(99, 40)
+----------------------------------------+
|########################################|= 99%
+----------------------------------------+
# battery(50, 40)
+----------------------------------------+
|####################                    |= 50%
+----------------------------------------+

@@@ hidden_input
2
1 1
0 1
@@@ hidden_output
# battery(1, 1)
+-+
|#|= 1% LOW
+-+
# battery(0, 1)
+-+
| |= 0% LOW
+-+

@@@ hint
Clamp first (`if (p < 0) p = 0; if (p > 100) p = 100;`), then everything else works on a value in `0..100`.
@@@ hint
Integer ceiling division: `ceil(a / b) == (a + b - 1) / b` for `a >= 0, b > 0`. Here `lit = (p * segments + 99) / 100`.
@@@ solution_code
#include <stdio.h>

static void border(int segments)
{
    putchar('+');
    for (int i = 0; i < segments; i++)
        putchar('-');
    printf("+\n");
}

void draw_battery(int percent, int segments)
{
    if (segments < 1 || segments > 40) {
        printf("ERR\n");
        return;
    }
    if (percent < 0) percent = 0;           /* clamp sensor glitches */
    if (percent > 100) percent = 100;

    int lit = (percent * segments + 99) / 100;  /* integer ceil(p*S/100) */

    border(segments);
    putchar('|');
    for (int i = 0; i < segments; i++)
        putchar(i < lit ? '#' : ' ');
    printf("|= %d%%%s\n", percent, percent <= 10 ? " LOW" : "");
    border(segments);
}
@@@ explanation_md
**Approach.** Validate, clamp, then compute the number of lit cells with an **integer ceiling division**: `ceil(a/b) = (a + b - 1) / b` for non-negative `a` and positive `b`. With `a = p * S` and `b = 100` this is `(p*S + 99) / 100`. The icon is a hollow rectangle: two identical border lines and one content line whose interior has exactly `S` characters (`lit` hashes plus `S - lit` spaces).

```
p = 57, S = 10:  57*10 = 570,  (570 + 99) / 100 = 6
|######    |= 57%
```

**Complexity.** Time O(S) per icon, space O(1).

**Common mistakes**
- Using `p * S / 100` (floor). Then 5 % on 10 cells shows an **empty** battery while the scooter still runs. That is why the spec asks for a ceiling.
- Computing the ceiling with floating point (`ceil(p * S / 100)`). The division inside is still an integer division, so `ceil` receives an already truncated value.
- Clamping after computing `lit`. With `p = 150` you would draw 15 hashes in a 10-cell icon.
- Printing `%` with a single `%` in the format string. A literal percent sign is `%%`.
- Not padding the interior with spaces. The right border then moves left as the battery drains.

**Interview follow-ups**
- Add **hysteresis**: the LOW warning turns on at 10 % but only turns off again above 15 %, so it does not flicker around the threshold. What extra state do you need?
- The SoC comes from a 12-bit ADC (0..4095) instead of a percent. Convert with correct rounding without floating point.
- How would you draw this icon into a 128x64 monochrome frame buffer instead of a text console?
