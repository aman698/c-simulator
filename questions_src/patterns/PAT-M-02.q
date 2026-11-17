@@@ meta
id: PAT-M-02
topic: C Patterns
difficulty: Medium
type: CODE
title: Number Butterfly
tags: butterfly, number-pattern, symmetry, asked-in-service-companies
@@@ statement_md
Print a **number butterfly** of size `n`. It has `2n` rows: an upper half with `i = 1, 2, ..., n` and a lower half with `i = n, n-1, ..., 1` (the two middle rows are identical).

Each row for a given `i` consists of:
- the **left wing**: digits `1 2 ... i` (no separators),
- a **gap** of `2 * (n - i)` spaces,
- the **right wing**: digits `i ... 2 1` (counting down).

The gap closes in the middle, so the two middle rows are `1 2 ... n n ... 2 1`.

Only `1 <= n <= 9` is drawn (single-digit numbers). For any other `n`, print exactly `INVALID`.

**Input**
- One integer `n`.

**Output**
- `2n` lines, or `INVALID`.
- The spaces of the gap are significant (they are followed by digits). The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
4

Output:
1      1
12    21
123  321
12344321
12344321
123  321
12    21
1      1
```
@@@ constraints_md
- `-100 <= n <= 100`
- Valid range: `1 <= n <= 9`.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    /* TODO: validate, then print the upper half (i = 1..n)
       and the lower half (i = n..1) */

    return 0;
}
@@@ sample_input
4
@@@ sample_output
1      1
12    21
123  321
12344321
12344321
123  321
12    21
1      1

@@@ sample_input
1
@@@ sample_output
11
11

@@@ hidden_input
2
@@@ hidden_output
1  1
1221
1221
1  1

@@@ hidden_input
0
@@@ hidden_output
INVALID

@@@ hidden_input
10
@@@ hidden_output
INVALID

@@@ hidden_input
-3
@@@ hidden_output
INVALID

@@@ hidden_input
5
@@@ hidden_output
1        1
12      21
123    321
1234  4321
1234554321
1234554321
1234  4321
123    321
12      21
1        1

@@@ hidden_input
9
@@@ hidden_output
1                1
12              21
123            321
1234          4321
12345        54321
123456      654321
1234567    7654321
12345678  87654321
123456789987654321
123456789987654321
12345678  87654321
1234567    7654321
123456      654321
12345        54321
1234          4321
123            321
12              21
1                1

@@@ hint
Every row has the same total width `2n`: `i` digits + `2(n - i)` spaces + `i` digits. Write one helper `print_row(n, i)` and call it for both halves.
@@@ hint
The upper half loops `i = 1..n`, the lower half loops `i = n..1`, so the full-width row appears twice. The right wing is a second digit loop that counts **down** from `i` to 1.
@@@ solution_code
#include <stdio.h>

static void print_row(int n, int i)
{
    for (int d = 1; d <= i; d++)            /* left wing: 1 .. i */
        printf("%d", d);
    for (int s = 0; s < 2 * (n - i); s++)   /* gap closes as i grows */
        putchar(' ');
    for (int d = i; d >= 1; d--)            /* right wing: i .. 1 */
        printf("%d", d);
    putchar('\n');
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    if (n < 1 || n > 9) {
        printf("INVALID\n");
        return 0;
    }
    for (int i = 1; i <= n; i++)    /* upper half */
        print_row(n, i);
    for (int i = n; i >= 1; i--)    /* lower half: middle row repeated */
        print_row(n, i);
    return 0;
}
@@@ explanation_md
**Approach.** Look at the width first: every row is exactly `2n` characters, `i` digits on each side and `2(n - i)` spaces between them. With that invariant, a single `print_row(n, i)` helper draws any row: count up, print the gap, count down. The shape is then just two loops over `i`: up for the top wing pair and down for the bottom pair.

```
n = 4, i = 2:  "12" + "    " (2*(4-2) = 4) + "21"  ->  "12    21"
n = 4, i = 4:  "1234" + "" + "4321"             ->  "12344321"
```

**Complexity.** Time O(n^2), the output has `2n` rows of `2n` characters. Space O(1).

**Common mistakes**
- Using a gap of `n - i` or `2(n - i) - 1` spaces. The wings then do not line up with the middle rows.
- Printing the right wing counting **up** (`12  12`). Read the example: the right wing mirrors the left one.
- Writing the lower half as `i = n-1 .. 1`. That gives `2n - 1` rows. The butterfly here has two identical middle rows; the diamond in another question does not repeat it. Read the spec.
- Skipping the validation. For `n = 10` the number `10` takes two characters, so the wings are no longer `i` characters wide and the butterfly falls apart.

**Interview follow-ups**
- Draw the same butterfly with `*` and make the wings **hollow**.
- Make the middle row appear only once (`2n - 1` rows). Which loop bound changes?
- Allow `n > 9` by giving every number a width `w` (`%*d`) and the gap `2(n - i) * w` spaces.
