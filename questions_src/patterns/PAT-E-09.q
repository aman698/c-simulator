@@@ meta
id: PAT-E-09
topic: C Patterns
difficulty: Easy
type: FIND_THE_BUG
title: Right-Aligned Number Staircase Off by One
tags: off-by-one, number-pattern, loop-bounds, zero-based-index
@@@ statement_md
The program below should print a **right-aligned number staircase** with `n` rows. Row `i` (1-based) is
- `n - i` leading spaces, followed by
- the digits `1 2 ... i` written without separators.

So the last row starts in column 0, and all rows end in the same column.

Only `1 <= n <= 9` is drawn (one digit per number). For any other `n` the program prints `INVALID`.

**Expected for `n = 5`**
```
    1
   12
  123
 1234
12345
```

**Symptom.** The `INVALID` cases pass, but the judge reports **Wrong Answer** for every valid `n`, including `n = 1`. Find and fix the bug with a minimal change.

**Input**
- One integer `n`.

**Output**
- The staircase or `INVALID`. Leading spaces are significant; the judge ignores trailing spaces and trailing blank lines.
@@@ constraints_md
- `-100 <= n <= 100`
- Valid drawing range: `1 <= n <= 9`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    if (n < 1 || n > 9) {
        printf("INVALID\n");
        return 0;
    }

    for (int r = 0; r < n; r++) {           /* r = 0 is the top row */
        for (int s = 0; s < n - r; s++)     /* leading spaces */
            putchar(' ');
        for (int d = 1; d <= r + 1; d++)    /* digits 1 .. r+1 */
            printf("%d", d);
        putchar('\n');
    }
    return 0;
}
@@@ sample_input
5
@@@ sample_output
    1
   12
  123
 1234
12345

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
 1
12

@@@ hidden_input
9
@@@ hidden_output
        1
       12
      123
     1234
    12345
   123456
  1234567
 12345678
123456789

@@@ hidden_input
10
@@@ hidden_output
INVALID

@@@ hidden_input
-4
@@@ hidden_output
INVALID

@@@ hidden_input
3
@@@ hidden_output
  1
 12
123

@@@ hint
Check the formulas at the boundaries. With the 0-based row index `r`, how many spaces must the **last** row (`r = n - 1`) have, and how many does the loop print?
@@@ hint
The statement's formula `n - i` uses a 1-based row `i = r + 1`. Translated to `r`, the space count is `n - r - 1`, not `n - r`.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    if (n < 1 || n > 9) {
        printf("INVALID\n");
        return 0;
    }

    for (int r = 0; r < n; r++) {               /* r = 0 is the top row */
        for (int s = 0; s < n - r - 1; s++)     /* FIX: row i = r + 1 needs n - i = n - r - 1 spaces */
            putchar(' ');
        for (int d = 1; d <= r + 1; d++)        /* digits 1 .. r+1 */
            printf("%d", d);
        putchar('\n');
    }
    return 0;
}
@@@ explanation_md
**Bug.** The specification counts rows from 1 (`n - i` spaces in row `i`), but the code counts rows from 0 (`r = i - 1`). The space loop used the 1-based formula with the 0-based index, so every row gets `n - r = n - i + 1` spaces, which is **one too many**. The whole staircase is shifted one column to the right. Even `n = 1` prints ` 1` instead of `1`.

**Fix.** `s < n - r - 1`. Alternatively, switch to a 1-based loop `for (int i = 1; i <= n; i++)` and use `n - i` and `d <= i`. Do not mix the two conventions.

**Complexity.** Time O(n^2), space O(1).

**Common mistakes**
- "Fixing" it by starting `s` at 1. That has the same effect, but hides the real reason, and the next pattern built on that loop is wrong again.
- Changing the digit loop as well. The digit loop `d <= r + 1` is already correct for a 0-based `r`.
- Testing only by eye. A one-column shift is easy to miss on screen; check the last row, which must start in column 0.

**Interview follow-ups**
- How would you test the edges systematically? (Write down the counts for the first and last row and compare them with the formula before running the code.)
- Extend it to `n > 9` by printing `d % 10` (a digit wheel), or by giving every number the same width with `%*d`.
- Print the mirror image (left-aligned digits counting down) using only one `printf` per row with `%*s`.
