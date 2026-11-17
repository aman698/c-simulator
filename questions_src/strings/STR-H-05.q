@@@ meta
id: STR-H-05
topic: Strings
difficulty: Hard
type: CODE
title: Validate a VIN with the ISO 3779 Check Digit
tags: embedded, vin, check-digit, lookup-table, input-validation, automotive, uds
@@@ statement_md
An end-of-line tester reads the **Vehicle Identification Number** from the ECU (UDS DID `0xF190`) and must reject corrupted or mistyped VINs before writing them to other modules. Validate each VIN using the North-American check digit (ISO 3779 / 49 CFR 565).

**Rules, checked in this order**
1. **Length.** A VIN has exactly 17 characters. Otherwise print `INVALID LENGTH`.
2. **Characters.** Allowed are the digits `0-9` and the **uppercase** letters `A-Z` **except `I`, `O` and `Q`** (too easy to confuse with 1 and 0). At the first bad character, print `INVALID CHAR <pos>` (1-based position).
3. **Check digit.** Transliterate every character to a number:
   - digits: their own value;
   - `A=1 B=2 C=3 D=4 E=5 F=6 G=7 H=8 J=1 K=2 L=3 M=4 N=5 P=7 R=9 S=2 T=3 U=4 V=5 W=6 X=7 Y=8 Z=9`.

   Multiply each value by the weight of its position:

   | pos | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
   | weight | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 10 | 0 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 |

   The expected check digit is `sum % 11`, written as `X` when the remainder is 10. It must equal the character at **position 9**. If it does, print `VALID`; otherwise print `INVALID CHECK expected <e> got <c>`.

**Worked example:** `1M8GDM9AXKP042788`. The weighted sum is 351, and 351 % 11 = 10, so the expected check digit is `X`. Position 9 is `X`, so the VIN is `VALID`.

**Input**
- Line 1: `n`.
- Next `n` lines: one VIN candidate per line (may be empty or contain spaces).

**Output**
- One result line per candidate.

**Example**
```
Input:
3
1M8GDM9AXKP042788
1M8GDM9A1KP042788
1m8gdm9axkp042788

Output:
VALID
INVALID CHECK expected X got 1
INVALID CHAR 2
```
@@@ constraints_md
- `1 <= n <= 100`, each line has at most 40 characters.
- Use lookup tables, not a 23-way `if` chain. O(1) work per VIN (17 characters).
@@@ starter_code
#include <stdio.h>
#include <string.h>

static void check_vin(const char *vin)
{
    /* TODO: length -> characters -> check digit */
    (void)vin;
    puts("VALID");
}

int main(void)
{
    char line[64];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        check_vin(line);
    }
    return 0;
}
@@@ sample_input
3
1M8GDM9AXKP042788
1M8GDM9A1KP042788
1m8gdm9axkp042788
@@@ sample_output
VALID
INVALID CHECK expected X got 1
INVALID CHAR 2

@@@ sample_input
3
11111111111111111
1HGCM82633A004352
<<BLANK>>
@@@ sample_output
VALID
VALID
INVALID LENGTH

@@@ hidden_input
4
JHMCM56557C404453
WVWZZZ1J0XW000001
SALVA2BGXCH000000
WBA3A5C53CF256985
@@@ hidden_output
VALID
VALID
VALID
VALID

@@@ hidden_input
4
1M8GDM9AXKP042789
WBA3A5C50CF256985
MA3EWDE1S00123456
5YJ3E1EA7KF317000
@@@ hidden_output
INVALID CHECK expected 1 got X
INVALID CHECK expected 3 got 0
INVALID CHECK expected 6 got S
INVALID CHECK expected 2 got 7

@@@ hidden_input
4
1M8GDM9AXKP04278
1M8GDM9AXKP0427888
 1M8GDM9AXKP042788
12345
@@@ hidden_output
INVALID LENGTH
INVALID LENGTH
INVALID LENGTH
INVALID LENGTH

@@@ hidden_input
5
1M8GOM9AXKP042788
I1111111111111111
1M8GDM9AXKP04278Q
1M8GDM9AX P042788
1M8GDM9AXKP04278-
@@@ hidden_output
INVALID CHAR 5
INVALID CHAR 1
INVALID CHAR 17
INVALID CHAR 10
INVALID CHAR 17

@@@ hidden_input
3
5YJ3E1EA2KF317000
MA3EWDE1600123456
1M8GDM9AXKP0427I8
@@@ hidden_output
VALID
VALID
INVALID CHAR 16

@@@ hint
Build two tables: `static const int weight[17] = {8,7,6,5,4,3,2,10,0,9,8,7,6,5,4,3,2};` and a 26-entry table for the letters `A..Z`, with `-1` for `I`, `O` and `Q`. One function `value(c)` returning 0..9 or -1 then covers both the character check and the transliteration.
@@@ hint
Check `strlen(vin) != 17` first. Then loop once, returning `INVALID CHAR i+1` as soon as `value(vin[i]) < 0`, and accumulate `sum += value(vin[i]) * weight[i]`. Map `sum % 11 == 10` to `'X'`, everything else to `'0' + r`, and compare with `vin[8]` (index 8 is position 9).
@@@ solution_code
#include <stdio.h>
#include <string.h>

static const int weight[17] = { 8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2 };

/*                                  A  B  C  D  E  F  G  H  I  J  K  L  M  N  O  P  Q  R  S  T  U  V  W  X  Y  Z */
static const signed char letter[26] = { 1, 2, 3, 4, 5, 6, 7, 8,-1, 1, 2, 3, 4, 5,-1, 7,-1, 9, 2, 3, 4, 5, 6, 7, 8, 9 };

/* transliterated value 0..9, or -1 if c is not a legal VIN character */
static int value(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'A' && c <= 'Z')
        return letter[c - 'A'];
    return -1;                          /* lowercase, punctuation, space, ... */
}

static void check_vin(const char *vin)
{
    int sum = 0;

    if (strlen(vin) != 17) {
        puts("INVALID LENGTH");
        return;
    }
    for (int i = 0; i < 17; i++) {
        int v = value(vin[i]);
        if (v < 0) {
            printf("INVALID CHAR %d\n", i + 1);
            return;
        }
        sum += v * weight[i];           /* weight[8] == 0: the check digit itself */
    }
    int r = sum % 11;
    char expected = (r == 10) ? 'X' : (char)('0' + r);
    if (vin[8] == expected)
        puts("VALID");
    else
        printf("INVALID CHECK expected %c got %c\n", expected, vin[8]);
}

int main(void)
{
    char line[64];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        check_vin(line);
    }
    return 0;
}
@@@ explanation_md
**Approach: two lookup tables and one pass.**
- `value(c)` handles both validation and transliteration. Digits map to themselves, letters go through a 26-entry table in which `I`, `O`, `Q` are `-1`, and everything else (lowercase, spaces, punctuation) is `-1`.
- One loop over the 17 characters rejects the first illegal character and accumulates `value * weight`. Position 9 has weight 0, so the check digit does not influence its own computation.
- `sum % 11` gives 0..10, and 10 is written as `X`.

Worked example, `1M8GDM9AXKP042788`: values `1 4 8 7 4 4 9 1 7 2 7 0 4 2 7 8 8`. The weighted sum is 8+28+48+35+16+12+18+10+0+18+56+0+24+10+28+24+16 = 351, and 351 % 11 = 10, which gives `X`.

**Complexity.** O(1) per VIN: a fixed 17 iterations plus `strlen`. Space O(1): two small constant tables, which belong in flash (`static const`).

**Common mistakes**
- Accepting lowercase letters, or `I`/`O`/`Q`. They are not legal VIN characters and must be rejected **before** the checksum.
- Off-by-one between "position 9" and index 8, or between 1-based error positions and 0-based indexes.
- Transliterating with `c - 'A' + 1`. The table is not linear: it skips `I`, `O`, `Q` and restarts (`J=1`, `S=2`).
- Comparing the check digit as a number and forgetting the `X` case.
- Not stripping `'\n'` from `fgets`, so every VIN has length 18. Conversely, stripping spaces, which would hide a corrupted VIN with a trailing space.

**Interview follow-ups**
- European VINs often carry no valid check digit (position 9 is filler). How should a tester for a global platform decide whether to enforce it? (Region from the WMI, the first 3 characters.)
- UDS DID `0xF190` returns 17 raw bytes **without** a terminator. How do you validate and print it safely? (`memcpy` into `char[18]`, or `printf("%.17s")`.)
- The VIN is stored redundantly in several ECUs. Design a consistency check at ignition-on, and decide what to do on a mismatch (immobiliser, component protection).
- Extract the model year (position 10) and the manufacturer (WMI). Why does the model-year code repeat every 30 years?
