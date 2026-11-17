@@@ meta
id: PAT-M-01
topic: C Patterns
difficulty: Medium
type: CODE
title: Hollow Diamond from Its Width
tags: diamond, hollow-shape, input-validation, symmetry
@@@ statement_md
Print a **hollow diamond** of `*` whose widest row is exactly `W` characters wide. Only the outline is drawn; the inside is spaces.

A diamond of width `W` exists only for **odd** `W >= 1`. For an even or non-positive `W`, print exactly `INVALID`.

Let `n = (W + 1) / 2` (the number of rows in the upper half, including the widest row). The diamond has `2n - 1` rows. For row `r` of the upper half (`r = 1..n`), and mirrored for the lower half (`r = n-1 .. 1`):
- `n - r` leading spaces,
- one `*`,
- if `r > 1`: `2r - 3` spaces and a second `*`.

**Input**
- One integer `W`.

**Output**
- The diamond, or `INVALID`.
- Leading spaces and the spaces **inside** the diamond are significant. The judge ignores trailing spaces at the end of a line and trailing blank lines.

**Example**
```
Input:
7

Output:
   *
  * *
 *   *
*     *
 *   *
  * *
   *
```
@@@ constraints_md
- `-1000 <= W <= 1000`
- Valid diamonds: odd `W` with `1 <= W <= 99`. Inputs `W > 99` do not occur.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int w;
    if (scanf("%d", &w) != 1) return 0;

    /* TODO: validate W (odd, >= 1), then draw the outline */

    return 0;
}
@@@ sample_input
7
@@@ sample_output
   *
  * *
 *   *
*     *
 *   *
  * *
   *

@@@ sample_input
4
@@@ sample_output
INVALID

@@@ hidden_input
1
@@@ hidden_output
*

@@@ hidden_input
3
@@@ hidden_output
 *
* *
 *

@@@ hidden_input
0
@@@ hidden_output
INVALID

@@@ hidden_input
-5
@@@ hidden_output
INVALID

@@@ hidden_input
2
@@@ hidden_output
INVALID

@@@ hidden_input
9
@@@ hidden_output
    *
   * *
  *   *
 *     *
*       *
 *     *
  *   *
   * *
    *

@@@ hidden_input
99
@@@ hidden_output
                                                 *
                                                * *
                                               *   *
                                              *     *
                                             *       *
                                            *         *
                                           *           *
                                          *             *
                                         *               *
                                        *                 *
                                       *                   *
                                      *                     *
                                     *                       *
                                    *                         *
                                   *                           *
                                  *                             *
                                 *                               *
                                *                                 *
                               *                                   *
                              *                                     *
                             *                                       *
                            *                                         *
                           *                                           *
                          *                                             *
                         *                                               *
                        *                                                 *
                       *                                                   *
                      *                                                     *
                     *                                                       *
                    *                                                         *
                   *                                                           *
                  *                                                             *
                 *                                                               *
                *                                                                 *
               *                                                                   *
              *                                                                     *
             *                                                                       *
            *                                                                         *
           *                                                                           *
          *                                                                             *
         *                                                                               *
        *                                                                                 *
       *                                                                                   *
      *                                                                                     *
     *                                                                                       *
    *                                                                                         *
   *                                                                                           *
  *                                                                                             *
 *                                                                                               *
*                                                                                                 *
 *                                                                                               *
  *                                                                                             *
   *                                                                                           *
    *                                                                                         *
     *                                                                                       *
      *                                                                                     *
       *                                                                                   *
        *                                                                                 *
         *                                                                               *
          *                                                                             *
           *                                                                           *
            *                                                                         *
             *                                                                       *
              *                                                                     *
               *                                                                   *
                *                                                                 *
                 *                                                               *
                  *                                                             *
                   *                                                           *
                    *                                                         *
                     *                                                       *
                      *                                                     *
                       *                                                   *
                        *                                                 *
                         *                                               *
                          *                                             *
                           *                                           *
                            *                                         *
                             *                                       *
                              *                                     *
                               *                                   *
                                *                                 *
                                 *                               *
                                  *                             *
                                   *                           *
                                    *                         *
                                     *                       *
                                      *                     *
                                       *                   *
                                        *                 *
                                         *               *
                                          *             *
                                           *           *
                                            *         *
                                             *       *
                                              *     *
                                               *   *
                                                * *
                                                 *

@@@ hint
Write a helper `print_row(n, r)` that draws one row of the upper half. Then the diamond is `r = 1..n` followed by `r = n-1 .. 1`, so the widest row is printed only once.
@@@ hint
Row `r` spans `2r - 1` columns. Its first and last characters are stars, which leaves `2r - 3` spaces between them. For `r = 1` there is only one star. Also check odd/even with `W % 2 == 0`, which is true for negative even numbers too (`-4 % 2 == 0`).
@@@ solution_code
#include <stdio.h>

static void print_row(int n, int r)
{
    for (int s = 0; s < n - r; s++)     /* outer indentation */
        putchar(' ');
    putchar('*');
    if (r > 1) {                        /* the tip row has a single star */
        for (int s = 0; s < 2 * r - 3; s++)
            putchar(' ');
        putchar('*');
    }
    putchar('\n');
}

int main(void)
{
    int w;
    if (scanf("%d", &w) != 1) return 0;

    if (w < 1 || w % 2 == 0) {          /* only odd widths have a center column */
        printf("INVALID\n");
        return 0;
    }
    int n = (w + 1) / 2;
    for (int r = 1; r <= n; r++)        /* upper half including the widest row */
        print_row(n, r);
    for (int r = n - 1; r >= 1; r--)    /* lower half, mirrored */
        print_row(n, r);
    return 0;
}
@@@ explanation_md
**Approach.** A diamond is a pyramid followed by its mirror image, without repeating the widest row. Each row of the upper half spans `2r - 1` columns starting at column `n - r`. A hollow row prints only the two end points, so the gap between them is `(2r - 1) - 2 = 2r - 3`. The tip (`r = 1`) is a single star. One `print_row` helper serves both halves.

```
W = 7, n = 4
r=1  "   *"         3 spaces, 1 star
r=2  "  * *"        2 spaces, *, 1 gap, *
r=3  " *   *"       1 space,  *, 3 gap, *
r=4  "*     *"      0 spaces, *, 5 gap, *
r=3, r=2, r=1      mirrored
```

**Validation.** An even width has no single center column, so the two halves cannot be symmetric. `W % 2 == 0` identifies even numbers of either sign. The opposite test `W % 2 == 1` is a classic trap: in C the remainder takes the sign of the dividend, so `-5 % 2` is `-1` and a negative odd number is not recognized as odd. Non-positive widths are rejected separately with `W < 1`.

**Complexity.** Time O(W^2) characters in the worst case (interior spaces included). Space O(1).

**Common mistakes**
- Printing the widest row twice (`for r = n .. 1` in the lower half), which gives `2n` rows.
- Printing two stars on the tip row (`r = 1`), because `2r - 3 = -1` gaps look harmless but the second `*` is still printed.
- Computing `n = W / 2`. For `W = 7` that gives 3 and the diamond is too small.
- Testing oddness with `W % 2 == 1`. That fails for negative odd numbers. Here they are invalid anyway, but the habit causes bugs elsewhere.

**Interview follow-ups**
- Print a **filled** diamond and a diamond whose border is made of letters `A, B, C, ...` (one letter per row).
- Print the hollow diamond inside a rectangular frame of `*` (the frame is `W + 2` wide).
- Can you generate each row in O(1) decisions per character, using `abs(r - center) + abs(c - center) == radius`? (Manhattan distance.)
