@@@ meta
id: PAT-M-10
topic: C Patterns
difficulty: Medium
type: FIND_THE_BUG
title: Column Ruler That Hangs on Wide Displays
tags: embedded, uint8-overflow, infinite-loop, loop-counter, asked-in-automotive
@@@ statement_md
An end-of-line tester for character displays prints a **column ruler** so that operators can check text alignment. For a display that is `L` columns wide, it prints two lines:

- **Line 1 (ticks):** for every column `c = 0..L-1`: `|` if `c % 10 == 0`, otherwise `+` if `c % 5 == 0`, otherwise `-`.
- **Line 2 (labels):** for every column `c`: the digit `(c / 10) % 10` if `c % 10 == 0`, otherwise a space.

If `L < 1` or `L > 1000`, the program prints `INVALID`.

**Expected for `L = 23`**
```
|----+----|----+----|--
0         1         2
```

**Symptom.** The tool worked on every display the team had used so far (all 240 columns wide or less). On a new 320-column panel, the tester **hangs**; the judge reports **Time Limit Exceeded**. There is no crash and no sanitizer message. Find and fix the bug.

**Input**
- One integer `L`.

**Output**
- The two ruler lines, or `INVALID`. The judge ignores trailing spaces and trailing blank lines.
@@@ constraints_md
- `-1000 <= L <= 5000`
- Valid widths: `1 <= L <= 1000`.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

static char ticks[1001];
static char labels[1001];

int main(void)
{
    int len;
    uint8_t col;                    /* current display column */

    if (scanf("%d", &len) != 1) return 0;
    if (len < 1 || len > 1000) {
        printf("INVALID\n");
        return 0;
    }

    for (col = 0; col < len; col++) {
        if (col % 10 == 0)
            ticks[col] = '|';
        else if (col % 5 == 0)
            ticks[col] = '+';
        else
            ticks[col] = '-';
        labels[col] = (col % 10 == 0) ? (char)('0' + col / 10 % 10) : ' ';
    }
    ticks[len] = '\0';
    labels[len] = '\0';

    printf("%s\n%s\n", ticks, labels);
    return 0;
}
@@@ sample_input
23
@@@ sample_output
|----+----|----+----|--
0         1         2

@@@ sample_input
1
@@@ sample_output
|
0

@@@ hidden_input
0
@@@ hidden_output
INVALID

@@@ hidden_input
1001
@@@ hidden_output
INVALID

@@@ hidden_input
255
@@@ hidden_output
|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----
0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5

@@@ hidden_input
256
@@@ hidden_output
|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+
0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5

@@@ hidden_input
320
@@@ hidden_output
|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----
0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1

@@@ hidden_input
1000
@@@ hidden_output
|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----|----+----
0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9         0         1         2         3         4         5         6         7         8         9

@@@ hint
The program hangs only when `L` is large, and nothing is printed before the hang. Which loop could fail to terminate, and what is the largest value its counter can ever hold?
@@@ hint
A `uint8_t` holds 0..255. After 255, `col++` wraps to 0, so `col < len` is always true for `len >= 256`. Use a counter type that can reach `len` (`int`, or at least `uint16_t`).
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

static char ticks[1001];
static char labels[1001];

int main(void)
{
    int len;
    int col;                        /* FIX: was uint8_t, which wraps 255 -> 0 and never reaches len >= 256 */

    if (scanf("%d", &len) != 1) return 0;
    if (len < 1 || len > 1000) {
        printf("INVALID\n");
        return 0;
    }

    for (col = 0; col < len; col++) {
        if (col % 10 == 0)
            ticks[col] = '|';
        else if (col % 5 == 0)
            ticks[col] = '+';
        else
            ticks[col] = '-';
        labels[col] = (col % 10 == 0) ? (char)('0' + col / 10 % 10) : ' ';
    }
    ticks[len] = '\0';
    labels[len] = '\0';

    printf("%s\n%s\n", ticks, labels);
    return 0;
}
@@@ explanation_md
**Bug.** The loop counter is a `uint8_t`, so it can hold only 0..255. In `col < len`, `col` is promoted to `int` and compared with `len`. When `len >= 256`, the comparison is still true at `col = 255`. Then `col++` stores 256 into a `uint8_t`, which is reduced modulo 256 to **0**, and the loop starts over, forever. The writes stay inside `ticks[0..255]`, so there is no crash and no sanitizer report, only a hang. That is a TLE here and a watchdog reset on a real ECU.

**Fix.** Give the counter a type that can represent every value up to `len`: `int col` (or `uint16_t`, `size_t`). On 32-bit MCUs an `int` counter is also *faster*. An 8-bit counter forces the compiler to insert extra masking instructions to emulate the wrap-around.

**Complexity.** Time O(L), space O(L) for the two line buffers.

**Common mistakes**
- Adding a cast `(int)col < len`. The counter still wraps; the type of the variable is the problem.
- Clamping `len` to 255. That hides the bug and breaks the 320-column display.
- "Optimizing" loop counters to `uint8_t` to save RAM. A counter normally lives in a register anyway, so nothing is saved.
- Thinking unsigned overflow is undefined behavior. It is well-defined wrap-around, which is why no sanitizer complains.

**Interview follow-ups**
- Why does `for (uint8_t i = 0; i < 256; i++)` make gcc warn ("comparison is always true due to limited range of data type") while this code produces no warning?
- A watchdog would have reset the tester instead of hanging forever. Where would you kick the watchdog, and why never inside such a loop?
- MISRA C Rule 14.2 requires a well-formed `for` loop. Which property of the loop counter does it demand, and would it catch this bug?
