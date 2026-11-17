@@@ meta
id: PAT-M-03
topic: C Patterns
difficulty: Medium
type: CODE
title: Zig-Zag Rail Pattern of a String
tags: zig-zag, rail-fence, modulo-arithmetic, string-pattern
@@@ statement_md
Write the characters of a string `s` in a **zig-zag** over `k` rows ("rails") and print the picture.

Character `s[t]` goes into **column `t`**. Its row follows a zig-zag: `0, 1, 2, ..., k-1, k-2, ..., 1, 0, 1, ...` (down to the last rail, then back up, and so on). All other cells are spaces. With `k = 1` every character is in row 0.

The classic interview "zig-zag star pattern" is the case `k = 3` with a string of `*`s:
```
*   *   *   *
 * * * * * *
  *   *   *
```

After the `k` rows, print one more line `CIPHER: ` followed by the characters read **row by row**, left to right (this is the rail-fence cipher).

If `k < 1`, print exactly `INVALID`.

**Input**
- Line 1: `k`.
- Line 2: the string `s` (no spaces).

**Output**
- `k` picture rows, then the `CIPHER:` line; or `INVALID`.
- A rail that receives no character is an empty line. Leading spaces are significant. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
3
WEAREDISCOVERED

Output:
W   E   C   R
 E R D S O E E
  A   I   V   D
CIPHER: WECRERDSOEEAIVD
```
@@@ constraints_md
- `-10 <= k <= 20`
- `1 <= strlen(s) <= 100`; `s` consists of printable ASCII characters without spaces.
- `k` may be larger than `strlen(s)`.
@@@ starter_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    int k;
    char s[101];
    if (scanf("%d", &k) != 1 || scanf("%100s", s) != 1) return 0;

    /* TODO: print the k rails, then "CIPHER: ..." */

    return 0;
}
@@@ sample_input
3
WEAREDISCOVERED
@@@ sample_output
W   E   C   R
 E R D S O E E
  A   I   V   D
CIPHER: WECRERDSOEEAIVD

@@@ sample_input
1
HELLO
@@@ sample_output
HELLO
CIPHER: HELLO

@@@ hidden_input
2
ABCDEF
@@@ hidden_output
A C E
 B D F
CIPHER: ACEBDF

@@@ hidden_input
4
ZIGZAGPATTERN
@@@ hidden_output
Z     P     N
 I   G A   R
  G A   T E
   Z     T
CIPHER: ZPNIGARGATEZT

@@@ hidden_input
5
ABC
@@@ hidden_output
A
 B
  C


CIPHER: ABC

@@@ hidden_input
0
X
@@@ hidden_output
INVALID

@@@ hidden_input
-2
ABC
@@@ hidden_output
INVALID

@@@ hidden_input
3
*************
@@@ hidden_output
*   *   *   *
 * * * * * *
  *   *   *
CIPHER: *************

@@@ hidden_input
1
Q
@@@ hidden_output
Q
CIPHER: Q

@@@ hidden_input
7
The_quick_brown_fox_jumps_over_the_lazy_dog_while_the_ECU_logs_CAN_frames_at_500kbit/s_on_bus_012345
@@@ hidden_output
T           o           s           a           e           g           s           /           2
 h         r w         p _         l z         l _         o s         e _         t s         1 3
  e       b   n       m   o       _   y       i   t       l   _       m   a       i   _       0   4
   _     _     _     u     v     e     _     h     h     _     C     a     t     b     o     _     5
    q   k       f   j       e   h       d   w       e   U       A   r       _   k       n   s
     u c         o _         r t         o _         _ C         N f         5 0         _ u
      i           x           _           g           E           _           0           b
CIPHER: Tosaegs/2hrwp_lzl_ose_ts13ebnmo_yitl_mai_04___uve_hh_Catbo_5qkfjehdweUAr_knsuco_rto__CNf50_uix_gE_0b

@@@ hint
The zig-zag repeats every `p = 2 * (k - 1)` columns. Inside one period, `m = t % p` gives the row directly for `m < k`; on the way back up the row is `p - m`.
@@@ hint
`k = 1` makes `p = 0`, and `t % 0` is undefined behavior (a crash on most CPUs), so handle it separately. Then print row by row: for each row `r`, walk all columns `t` and print `s[t]` if `rail(t) == r`, else a space.
@@@ solution_code
#include <stdio.h>
#include <string.h>

/* row of column t for k rails */
static int rail(int t, int k)
{
    if (k == 1)
        return 0;                   /* avoid t % 0 */
    int p = 2 * (k - 1);            /* period of the zig-zag */
    int m = t % p;
    return m < k ? m : p - m;       /* going down, then coming back up */
}

int main(void)
{
    int k;
    char s[101];
    if (scanf("%d", &k) != 1 || scanf("%100s", s) != 1) return 0;

    if (k < 1) {
        printf("INVALID\n");
        return 0;
    }
    int len = (int)strlen(s);

    for (int r = 0; r < k; r++) {
        int last = -1;                          /* last column used in this row */
        for (int t = 0; t < len; t++)
            if (rail(t, k) == r)
                last = t;
        for (int t = 0; t <= last; t++)         /* no trailing spaces */
            putchar(rail(t, k) == r ? s[t] : ' ');
        putchar('\n');
    }

    printf("CIPHER: ");
    for (int r = 0; r < k; r++)
        for (int t = 0; t < len; t++)
            if (rail(t, k) == r)
                putchar(s[t]);
    putchar('\n');
    return 0;
}
@@@ explanation_md
**Approach.** The row of column `t` is a **triangle wave** with period `p = 2(k - 1)`: `m = t % p` climbs `0..k-1`, and for `m >= k` the row is `p - m` (coming back up). Because every row is a full line of output, iterate **row by row**. For row `r`, walk all columns and print the character where `rail(t) == r` and a space elsewhere. The cipher line reads the same cells in the same order, without the spaces.

```
k = 3, p = 4
t     : 0 1 2 3 4 5 6 7 ...
t % p : 0 1 2 3 0 1 2 3
row   : 0 1 2 1 0 1 2 1
```

Stopping each row at its last used column avoids trailing spaces. The judge would ignore them anyway, but a real terminal or log file would keep them.

**Complexity.** Time O(k * n) for `n = strlen(s)`: each of the `k` rows scans all columns. Space O(1) besides the input. An O(n) version first collects each row's characters into its own buffer.

**Common mistakes**
- `k = 1`: the period is 0 and `t % 0` is undefined behavior, typically a divide-error exception. The special case is part of the solution.
- Using period `2k` or `2k - 1`. The turning rows (`0` and `k - 1`) are visited once per period, not twice.
- Filling a 2D grid `char grid[k][n]` without terminating or initializing it, and then printing garbage or uninitialized bytes.
- Printing nothing for a rail that receives no character. The spec wants an empty line, so the line count is always `k + 1`.

**Interview follow-ups**
- **Decode** the rail-fence cipher: given the ciphertext and `k`, recover the plaintext. (Compute how many characters each rail holds, then walk the zig-zag again.)
- LeetCode 6 ("Zigzag Conversion") asks only for the cipher line. Can you produce it in O(n) without scanning all columns for every row? (Jump directly with steps `p - 2r` and `2r`.)
- Plot a sampled **triangle wave** from a DAC test signal the same way: column = sample index, row = quantized amplitude.
