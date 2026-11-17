@@@ meta
id: PAT-E-03
topic: C Patterns
difficulty: Easy
type: CODE
title: Alphabet Palindrome Pyramid
tags: alphabet-pattern, pyramid, char-arithmetic, palindrome
@@@ statement_md
Print an **alphabet pyramid** with `n` rows in which every row is a palindrome.

Row `i` (1-based) consists of:
- `n - i` leading spaces,
- the letters `A`, `B`, ... up to the `i`-th letter of the alphabet,
- then the same letters back down to `A` (the middle letter is **not** repeated).

So row `i` holds `2*i - 1` letters and no spaces between them.

Only `1 <= n <= 26` can be drawn. For any other `n`, print exactly `INVALID`.

**Input**
- One integer `n`.

**Output**
- The pyramid, one row per line, or the single line `INVALID`.
- Leading spaces are significant. The judge ignores trailing spaces at the end of a line and trailing blank lines.

**Example**
```
Input:
4

Output:
   A
  ABA
 ABCBA
ABCDCBA
```
@@@ constraints_md
- `-1000 <= n <= 1000`
- Valid range for drawing: `1 <= n <= 26`; otherwise print `INVALID`.
- Use character arithmetic (`'A' + k`), not a hard-coded alphabet string.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    /* TODO: validate n, then print the palindrome rows */

    return 0;
}
@@@ sample_input
4
@@@ sample_output
   A
  ABA
 ABCBA
ABCDCBA

@@@ sample_input
27
@@@ sample_output
INVALID

@@@ hidden_input
1
@@@ hidden_output
A

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
 A
ABA

@@@ hidden_input
6
@@@ hidden_output
     A
    ABA
   ABCBA
  ABCDCBA
 ABCDEDCBA
ABCDEFEDCBA

@@@ hidden_input
26
@@@ hidden_output
                         A
                        ABA
                       ABCBA
                      ABCDCBA
                     ABCDEDCBA
                    ABCDEFEDCBA
                   ABCDEFGFEDCBA
                  ABCDEFGHGFEDCBA
                 ABCDEFGHIHGFEDCBA
                ABCDEFGHIJIHGFEDCBA
               ABCDEFGHIJKJIHGFEDCBA
              ABCDEFGHIJKLKJIHGFEDCBA
             ABCDEFGHIJKLMLKJIHGFEDCBA
            ABCDEFGHIJKLMNMLKJIHGFEDCBA
           ABCDEFGHIJKLMNONMLKJIHGFEDCBA
          ABCDEFGHIJKLMNOPONMLKJIHGFEDCBA
         ABCDEFGHIJKLMNOPQPONMLKJIHGFEDCBA
        ABCDEFGHIJKLMNOPQRQPONMLKJIHGFEDCBA
       ABCDEFGHIJKLMNOPQRSRQPONMLKJIHGFEDCBA
      ABCDEFGHIJKLMNOPQRSTSRQPONMLKJIHGFEDCBA
     ABCDEFGHIJKLMNOPQRSTUTSRQPONMLKJIHGFEDCBA
    ABCDEFGHIJKLMNOPQRSTUVUTSRQPONMLKJIHGFEDCBA
   ABCDEFGHIJKLMNOPQRSTUVWVUTSRQPONMLKJIHGFEDCBA
  ABCDEFGHIJKLMNOPQRSTUVWXWVUTSRQPONMLKJIHGFEDCBA
 ABCDEFGHIJKLMNOPQRSTUVWXYXWVUTSRQPONMLKJIHGFEDCBA
ABCDEFGHIJKLMNOPQRSTUVWXYZYXWVUTSRQPONMLKJIHGFEDCBA

@@@ hint
A letter is just a small integer: `'A' + 2` is `'C'`. Print the rising half with one loop and the falling half with a second loop that starts one letter lower.
@@@ hint
For row `i`: print `n - i` spaces, then `'A' + k` for `k = 0 .. i-1`, then `'A' + k` for `k = i-2` down to `0`. Validate `n` before the loops.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    if (n < 1 || n > 26) {          /* only 26 letters exist */
        printf("INVALID\n");
        return 0;
    }

    for (int i = 1; i <= n; i++) {
        for (int s = 0; s < n - i; s++)
            putchar(' ');
        for (int k = 0; k < i; k++)         /* A B ... i-th letter */
            putchar('A' + k);
        for (int k = i - 2; k >= 0; k--)    /* back down, middle not repeated */
            putchar('A' + k);
        putchar('\n');
    }
    return 0;
}
@@@ explanation_md
**Approach.** Each row is a palindrome built from two runs: up from `A` to the `i`-th letter, then down again, starting one letter **below** the peak so the middle letter appears once. Letters are produced with character arithmetic: `'A' + k` is the k-th letter (0-based), because `A..Z` are consecutive in ASCII (65..90).

```
i = 3:  spaces = n - 3,  up: A B C,  down: B A   ->  "ABCBA"
```

Validation comes first. With `n = 27`, `'A' + 26` is `'['`, not a letter, so the pyramid would contain garbage.

**Complexity.** Time O(n^2), at most 26 rows of at most 51 letters. Space O(1).

**Common mistakes**
- Starting the falling loop at `i - 1`. The middle letter is printed twice (`ABCCBA`).
- Writing `putchar('A' + i)` with a 1-based `i`. The pattern then starts at `B`.
- Using `%d` with `printf` on `'A' + k`. That prints `65`, not `A`. Use `putchar` or `%c`.
- Forgetting the upper bound check. `'A' + 26` and beyond print `[`, `\`, `]`, ...

**Interview follow-ups**
- Print the same pyramid with **lowercase** letters, or alternate the case per column. How do you convert case with arithmetic (`c - 'A' + 'a'`)?
- Make it a full **diamond**, and then let it wrap around after `Z` (`'A' + k % 26`).
- Is `'A' + k` portable to EBCDIC machines? What does the C standard guarantee about the order of letters, and what does it guarantee for `'0'..'9'`? (Only the digits are guaranteed consecutive.)
