@@@ meta
id: PAT-M-04
topic: C Patterns
difficulty: Medium
type: CODE
title: Number Hourglass with Multi-Digit Alignment
tags: hourglass, number-pattern, printf-width, centering
@@@ statement_md
Print a **number hourglass** (sand-glass) of size `n` that stays centered even when the numbers have two digits.

Let `w` be the number of decimal digits of `n`. Every number is printed **right-aligned in width `w`**, numbers in a row are separated by **`w` spaces**, and each level is indented by **`w` more spaces** than the previous one.

Level `i` (`i = 0, 1, ..., n-1`) is the row
- `i * w` spaces of indentation,
- the numbers `i+1, i+2, ..., n` in the format above.

Print levels `0, 1, ..., n-1` (narrowing to the neck, which holds only `n`), then levels `n-2, ..., 1, 0` (widening again). That is `2n - 1` rows in total, and the neck is printed once.

Only `1 <= n <= 40` fits the 160-column console. For any other `n` print exactly `INVALID`.

**Input**
- One integer `n`.

**Output**
- The hourglass, or `INVALID`.
- Leading spaces are significant. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
5

Output:
1 2 3 4 5
 2 3 4 5
  3 4 5
   4 5
    5
   4 5
  3 4 5
 2 3 4 5
1 2 3 4 5
```

For `n = 10` (`w = 2`) the first rows are
```
 1   2   3   4   5   6   7   8   9  10
   2   3   4   5   6   7   8   9  10
     3   4   5   6   7   8   9  10
```
where `1` is printed as ` 1`. Level 1 begins with 2 spaces of indentation followed by ` 2`, so the line starts with 3 spaces.
@@@ constraints_md
- `-1000 <= n <= 1000`
- Valid range: `1 <= n <= 40`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    /* TODO: validate n, compute w = digits(n),
       print levels 0..n-1 and then n-2..0 */

    return 0;
}
@@@ sample_input
5
@@@ sample_output
1 2 3 4 5
 2 3 4 5
  3 4 5
   4 5
    5
   4 5
  3 4 5
 2 3 4 5
1 2 3 4 5

@@@ sample_input
0
@@@ sample_output
INVALID

@@@ hidden_input
1
@@@ hidden_output
1

@@@ hidden_input
2
@@@ hidden_output
1 2
 2
1 2

@@@ hidden_input
41
@@@ hidden_output
INVALID

@@@ hidden_input
-1
@@@ hidden_output
INVALID

@@@ hidden_input
9
@@@ hidden_output
1 2 3 4 5 6 7 8 9
 2 3 4 5 6 7 8 9
  3 4 5 6 7 8 9
   4 5 6 7 8 9
    5 6 7 8 9
     6 7 8 9
      7 8 9
       8 9
        9
       8 9
      7 8 9
     6 7 8 9
    5 6 7 8 9
   4 5 6 7 8 9
  3 4 5 6 7 8 9
 2 3 4 5 6 7 8 9
1 2 3 4 5 6 7 8 9

@@@ hidden_input
10
@@@ hidden_output
 1   2   3   4   5   6   7   8   9  10
   2   3   4   5   6   7   8   9  10
     3   4   5   6   7   8   9  10
       4   5   6   7   8   9  10
         5   6   7   8   9  10
           6   7   8   9  10
             7   8   9  10
               8   9  10
                 9  10
                  10
                 9  10
               8   9  10
             7   8   9  10
           6   7   8   9  10
         5   6   7   8   9  10
       4   5   6   7   8   9  10
     3   4   5   6   7   8   9  10
   2   3   4   5   6   7   8   9  10
 1   2   3   4   5   6   7   8   9  10

@@@ hidden_input
40
@@@ hidden_output
 1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
     3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
       4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
         5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
           6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
             7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
               8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                 9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                    11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                      12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                        13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                          14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                            15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                              16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                    19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                      20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                        21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                          22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                            23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                              24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                    27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                      28  29  30  31  32  33  34  35  36  37  38  39  40
                                                        29  30  31  32  33  34  35  36  37  38  39  40
                                                          30  31  32  33  34  35  36  37  38  39  40
                                                            31  32  33  34  35  36  37  38  39  40
                                                              32  33  34  35  36  37  38  39  40
                                                                33  34  35  36  37  38  39  40
                                                                  34  35  36  37  38  39  40
                                                                    35  36  37  38  39  40
                                                                      36  37  38  39  40
                                                                        37  38  39  40
                                                                          38  39  40
                                                                            39  40
                                                                              40
                                                                            39  40
                                                                          38  39  40
                                                                        37  38  39  40
                                                                      36  37  38  39  40
                                                                    35  36  37  38  39  40
                                                                  34  35  36  37  38  39  40
                                                                33  34  35  36  37  38  39  40
                                                              32  33  34  35  36  37  38  39  40
                                                            31  32  33  34  35  36  37  38  39  40
                                                          30  31  32  33  34  35  36  37  38  39  40
                                                        29  30  31  32  33  34  35  36  37  38  39  40
                                                      28  29  30  31  32  33  34  35  36  37  38  39  40
                                                    27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                                25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                              24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                            23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                          22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                        21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                      20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                    19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                                17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                              16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                            15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                          14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                        13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                      12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                    11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
                 9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
               8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
             7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
           6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
         5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
       4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
     3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
 1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40

@@@ hint
Treat each number as a cell `w` characters wide, followed by a `w`-space gap. Shifting a row by one cell is `2w` columns, so indenting by `w` (half a cell) keeps every row centered on the same column.
@@@ hint
Write `print_level(n, w, i)`: `printf("%*s", i * w, "")` for the indentation, then for each `k = i+1..n` print the separator (`w` spaces) **before** every number except the first, and the number with `printf("%*d", w, k)`. Call it for `i = 0..n-1`, then for `i = n-2..0`.
@@@ solution_code
#include <stdio.h>

static void print_level(int n, int w, int i)
{
    printf("%*s", i * w, "");               /* indentation: i half-cells */
    for (int k = i + 1; k <= n; k++) {
        if (k > i + 1)
            printf("%*s", w, "");           /* gap of w spaces */
        printf("%*d", w, k);                /* number right-aligned in w */
    }
    putchar('\n');
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    if (n < 1 || n > 40) {
        printf("INVALID\n");
        return 0;
    }
    int w = 0;
    for (int v = n; v > 0; v /= 10)
        w++;                                /* digits of the largest number */

    for (int i = 0; i < n; i++)             /* top half down to the neck */
        print_level(n, w, i);
    for (int i = n - 2; i >= 0; i--)        /* bottom half, neck not repeated */
        print_level(n, w, i);
    return 0;
}
@@@ explanation_md
**Approach.** With single digits, the hourglass is "indent by `i`, print `i+1..n` separated by spaces". To keep that shape with wider numbers, scale everything by `w`: each number is a cell of width `w`, the gap is `w`, so moving to the next number advances `2w` columns. Indenting a level by `w` columns is half a step, which is exactly what a centered shape needs. Then the center of every row is the same column:

```
row i starts at i*w and has (n - i) cells and (n - i - 1) gaps:
center = i*w + ((n - i)*w + (n - i - 1)*w) / 2 = n*w - w/2   (independent of i)
```

`printf("%*s", k, "")` prints `k` spaces (including zero), and `printf("%*d", w, x)` right-aligns `x` in `w` columns.

**Complexity.** Time O(n^2 * w) characters. Space O(1).

**Common mistakes**
- Indenting by one space per level when `w = 2`. The hourglass then leans to one side.
- Printing the neck twice (second loop starting at `n - 1`).
- Separating numbers with one space when `w = 2` (`" 1  2"` vs `" 1   2"`). The spec says `w` spaces.
- Computing `w` from the row count `2n - 1` or from `n - 1`. The widest number is `n`.

**Interview follow-ups**
- Print the hourglass with stars (`* * *`) and make it **hollow**: only the first and last element of each row, plus the full top and bottom rows.
- Why does the formula break when cells and gaps have different widths (e.g. width 2 and gap 1)? What indentation would you need then, and when is exact centering impossible?
- Generate any row in a single `printf` call using a preformatted buffer and `%.*s`.
