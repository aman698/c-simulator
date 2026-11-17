@@@ meta
id: PAT-H-02
topic: C Patterns
difficulty: Hard
type: FUNCTION
title: Seven-Segment Display Driver with Overflow Indicator
tags: embedded, seven-segment, lookup-table, int-min, bitmask, asked-in-automotive
@@@ statement_md
A trip computer shows numbers on a row of **7-segment digits**. Implement the text-mode preview of its driver:

```c
void render_7seg(int32_t value, int digits);
```

**Segments.** Each digit position has segments `a..g`, stored in a byte as `a = bit 0, b = bit 1, ..., g = bit 6`. A position is drawn as **3 rows of 3 characters**:

```
 a          row 0:  ' '  a?'_'  ' '
f g b       row 1:  f?'|'  g?'_'  b?'|'
e d c       row 2:  e?'|'  d?'_'  c?'|'
```

(a lit segment prints the character shown, an unlit one prints a space). The standard digit codes are `0:3F 1:06 2:5B 3:4F 4:66 5:6D 6:7D 7:07 8:7F 9:6F` (hex). The minus sign is segment `g` only (`40`).

**Layout rules**
1. If `digits < 3` or `digits > 12`, print the single line `BAD DIGITS` and return.
2. The display has `digits` positions; in each of the 3 rows, positions are separated by **one space**.
3. The number is **right-aligned**: decimal digits without leading zeros (`0` shows one `0`), and for a negative value a minus sign in the position directly left of the most significant digit. Unused positions on the left are blank (all segments off).
4. If the number needs more positions than `digits` (minus sign included), show `Err` in the three rightmost positions instead: `E = 79`, `r = 50`, `r = 50`. Everything to the left is blank.
5. The full `int32_t` range must work, including `INT32_MIN`.

**How it is tested.** A hidden `main()` reads `q` lines `value digits`. For each one it prints a header `> <value> @<digits>` and then calls your function.

**Output.** Leading spaces are significant. The judge ignores trailing spaces and trailing blank lines, so a row that ends in unlit segments may be printed with or without its trailing spaces.

**Example**
```
Input:
2
-42 4
1234567890 10

Output:
> -42 @4
             _
     _  |_|  _|
          | |_
> 1234567890 @10
     _   _       _   _   _   _   _   _
  |  _|  _| |_| |_  |_    | |_| |_| | |
  | |_   _|   |  _| |_|   | |_|  _| |_|
```
@@@ constraints_md
- `1 <= q <= 20`
- `value` is any `int32_t` (`-2147483648 .. 2147483647`); `-100 <= digits <= 100`.
- Use a segment lookup table; do not hard-code the 3x3 picture of every digit.
- Do not use `long` (its size differs between Linux and Windows).
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

/* segment bits: a=0, b=1, c=2, d=3, e=4, f=5, g=6 */
static const uint8_t SEG_DIGIT[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

void render_7seg(int32_t value, int digits)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        int v, d;
        if (scanf("%d %d", &v, &d) != 2) return 0;
        printf("> %d @%d\n", v, d);
        render_7seg((int32_t)v, d);
    }
    return 0;
}
@@@ sample_input
2
-42 4
1234567890 10
@@@ sample_output
> -42 @4
             _
     _  |_|  _|
          | |_
> 1234567890 @10
     _   _       _   _   _   _   _   _
  |  _|  _| |_| |_  |_    | |_| |_| | |
  | |_   _|   |  _| |_|   | |_|  _| |_|

@@@ sample_input
2
8 3
0 3
@@@ sample_output
> 8 @3
         _
        |_|
        |_|
> 0 @3
         _
        | |
        |_|

@@@ hidden_input
3
-2147483648 11
-2147483648 12
2147483647 10
@@@ hidden_output
> -2147483648 @11
     _           _       _   _   _       _
 _   _|   | |_|   | |_| |_|  _| |_  |_| |_|
    |_    |   |   |   | |_|  _| |_|   | |_|
> -2147483648 @12
         _           _       _   _   _       _
     _   _|   | |_|   | |_| |_|  _| |_  |_| |_|
        |_    |   |   |   | |_|  _| |_|   | |_|
> 2147483647 @10
 _           _       _   _   _       _
 _|   | |_|   | |_| |_|  _| |_  |_|   |
|_    |   |   |   | |_|  _| |_|   |   |

@@@ hidden_input
4
1000 3
-100 3
-99 3
999 3
@@@ hidden_output
> 1000 @3
 _
|_   _   _
|_  |   |
> -100 @3
 _
|_   _   _
|_  |   |
> -99 @3
     _   _
 _  |_| |_|
     _|  _|
> 999 @3
 _   _   _
|_| |_| |_|
 _|  _|  _|

@@@ hidden_input
3
5 2
5 13
5 -1
@@@ hidden_output
> 5 @2
BAD DIGITS
> 5 @13
BAD DIGITS
> 5 @-1
BAD DIGITS

@@@ hidden_input
2
-2147483648 10
2147483647 9
@@@ hidden_output
> -2147483648 @10
                             _
                            |_   _   _
                            |_  |   |
> 2147483647 @9
                         _
                        |_   _   _
                        |_  |   |

@@@ hidden_input
4
-1 3
-7 4
65535 8
0 12
@@@ hidden_output
> -1 @3

     _    |
          |
> -7 @4
             _
         _    |
              |
> 65535 @8
             _   _   _   _   _
            |_  |_  |_   _| |_
            |_|  _|  _|  _|  _|
> 0 @12
                                             _
                                            | |
                                            |_|

@@@ hidden_input
2
-1234567890 12
-500 4
@@@ hidden_output
> -1234567890 @12
             _   _       _   _   _   _   _   _
     _    |  _|  _| |_| |_  |_    | |_| |_| | |
          | |_   _|   |  _| |_|   | |_|  _| |_|
> -500 @4
     _   _   _
 _  |_  | | | |
     _| |_| |_|

@@@ hint
Build an array `pos[digits]` of segment bytes first (0 = blank), filling it **from the right**: `value % 10` gives the last digit. Rendering is then three passes over `pos`, one per text row.
@@@ hint
`-value` overflows for `INT32_MIN`. Work with the magnitude as `uint32_t mag = value < 0 ? 0u - (uint32_t)value : (uint32_t)value;`, which is well-defined. Count the needed positions (digits plus one for `-`) before deciding between the number and `Err`. Use `do { ... } while (mag)` so that `0` still produces one digit.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

/* segment bits: a=0, b=1, c=2, d=3, e=4, f=5, g=6 */
static const uint8_t SEG_DIGIT[10] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};

#define SEG_A 0x01u
#define SEG_B 0x02u
#define SEG_C 0x04u
#define SEG_D 0x08u
#define SEG_E 0x10u
#define SEG_F 0x20u
#define SEG_G 0x40u
#define CODE_MINUS 0x40u
#define CODE_E     0x79u
#define CODE_R     0x50u

static char on(uint8_t s, unsigned mask, char c) { return (s & mask) ? c : ' '; }

void render_7seg(int32_t value, int digits)
{
    if (digits < 3 || digits > 12) {
        printf("BAD DIGITS\n");
        return;
    }

    uint8_t pos[12] = {0};      /* segment code per position, 0 = blank */
    uint8_t tmp[11];            /* number from the right: at most 10 digits + '-' */
    int n = 0;

    /* magnitude without overflow: works for INT32_MIN too */
    uint32_t mag = value < 0 ? 0u - (uint32_t)value : (uint32_t)value;
    do {
        tmp[n++] = SEG_DIGIT[mag % 10u];
        mag /= 10u;
    } while (mag != 0u);        /* do-while: 0 still yields one digit */
    if (value < 0)
        tmp[n++] = CODE_MINUS;

    if (n > digits) {           /* does not fit: overflow indicator */
        pos[digits - 3] = CODE_E;
        pos[digits - 2] = CODE_R;
        pos[digits - 1] = CODE_R;
    } else {
        for (int i = 0; i < n; i++)
            pos[digits - 1 - i] = tmp[i];   /* right-aligned */
    }

    for (int row = 0; row < 3; row++) {
        for (int p = 0; p < digits; p++) {
            uint8_t s = pos[p];
            if (p > 0)
                putchar(' ');
            if (row == 0) {
                putchar(' '); putchar(on(s, SEG_A, '_')); putchar(' ');
            } else if (row == 1) {
                putchar(on(s, SEG_F, '|')); putchar(on(s, SEG_G, '_')); putchar(on(s, SEG_B, '|'));
            } else {
                putchar(on(s, SEG_E, '|')); putchar(on(s, SEG_D, '_')); putchar(on(s, SEG_C, '|'));
            }
        }
        putchar('\n');
    }
}
@@@ explanation_md
**Approach.** Split the job like a real display driver does: first compute a **segment buffer** (one byte per position, exactly what you would write to a MAX7219 or a multiplexed GPIO port), then render it. Filling the buffer from the right is natural because `% 10` yields the least significant digit first. Rendering then needs no knowledge of digits at all; each row only tests three segment bits per position.

```
-42 on 4 positions:   pos = [ 00, 40('-'), 66('4'), 5B('2') ]
row 0: "   " "   " "   " " _ "
row 1: "   " " _ " "|_|" " _|"
row 2: "   " "   " "  |" "|_ "
```

**Edge cases**
- `INT32_MIN`: `-value` is signed overflow (undefined behavior). Converting to `uint32_t` first and computing `0u - (uint32_t)value` gives `2147483648` with well-defined modular arithmetic.
- `0`: a `while (mag)` loop produces no digit at all. `do ... while` produces one.
- The overflow test counts the minus sign: `-100` needs 4 positions, so on a 3-digit display it shows `Err`, while `-99` fits.

**Complexity.** Time O(digits) per call (at most 12 positions x 3 rows). Space O(digits).

**Common mistakes**
- `abs(value)` or `-value` for negative numbers. Both are undefined for `INT32_MIN`.
- Forgetting the minus sign when checking whether the number fits.
- Printing the separator after every position (including the last one). That only adds trailing spaces here, but the same habit breaks fixed-width LCD lines.
- Drawing `b` and `f` swapped. `f` is the **upper-left** segment, `b` the upper-right.
- Hard-coding a 3x3 string table per character. That works for the preview, but the real hardware takes segment bytes, and this spec requires them.

**Interview follow-ups**
- On the real board, 4 digits share segment lines and are **multiplexed**. How would a 1 ms timer ISR refresh them, and why must the ISR read a double-buffered segment array?
- Add a decimal point (bit 7 = `dp`) to show `12.5` from the fixed-point value `125` with one decimal.
- Some displays are **common-anode**: the GPIO must drive a segment low to light it. Where does that change go in this design? (Invert the byte at output time, never in the table.)
- How would you show hexadecimal (`A b C d E F`) for a diagnostic trouble code?
