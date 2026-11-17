@@@ meta
id: PAT-M-06
topic: C Patterns
difficulty: Medium
type: FUNCTION
title: Render a 5x7 Dot-Matrix Glyph from a Font Table
tags: embedded, dot-matrix, font-bitmap, bit-extraction, transpose
@@@ statement_md
Small LCD and LED-matrix drivers store each character of a **5x7 font** as 5 bytes, one byte per **column** (left to right). In each column byte, **bit 0 is the top pixel** and bit 6 the bottom pixel; bit 7 is unused and must be **ignored**. The letter `A`, for example, is `7C 12 11 12 7C`.

Implement

```c
void render_glyph(const uint8_t col[5], int scale);
```

It prints the glyph as text, **row by row** (top row first): `#` for a pixel that is on, `.` for a pixel that is off. Each pixel is drawn as a `scale x scale` block, so the output has `7*scale` lines of `5*scale` characters.

If `scale < 1` or `scale > 4`, print the single line `ERR`.

**How it is tested.** A hidden `main()` reads `q` glyphs. For each one it prints a header line `-- glyph <k> x<scale> --` and then calls your function.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: five column bytes in hex, then `scale`.

**Output**
- The headers and your rendered glyphs. The judge ignores trailing spaces and trailing blank lines.

**Example**
```
Input:
1
7C 12 11 12 7C 1

Output:
-- glyph 1 x1 --
..#..
.#.#.
#...#
#...#
#####
#...#
#...#
```
Column 0 is `0x7C = 0111 1100`: bits 2..6 are set, so the left edge is lit from row 2 to row 6.
@@@ constraints_md
- `1 <= q <= 10`
- Column bytes are `00..FF`; bit 7 may be set and must not be drawn.
- `-5 <= scale <= 10`; only `1..4` is valid.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

/* col[c], bit r (r = 0 is the top row) = pixel at row r, column c */
void render_glyph(const uint8_t col[5], int scale)
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
    for (int k = 1; k <= q; k++) {
        unsigned int b[5];
        int scale;
        if (scanf("%x %x %x %x %x %d", &b[0], &b[1], &b[2], &b[3], &b[4], &scale) != 6) return 0;
        uint8_t glyph[5];
        for (int i = 0; i < 5; i++)
            glyph[i] = (uint8_t)b[i];
        printf("-- glyph %d x%d --\n", k, scale);
        render_glyph(glyph, scale);
    }
    return 0;
}
@@@ sample_input
1
7C 12 11 12 7C 1
@@@ sample_output
-- glyph 1 x1 --
..#..
.#.#.
#...#
#...#
#####
#...#
#...#

@@@ sample_input
2
00 42 7F 40 00 2
3E 51 49 45 3E 1
@@@ sample_output
-- glyph 1 x2 --
....##....
....##....
..####....
..####....
....##....
....##....
....##....
....##....
....##....
....##....
....##....
....##....
..######..
..######..
-- glyph 2 x1 --
.###.
#...#
#..##
#.#.#
##..#
#...#
.###.

@@@ hidden_input
3
7C 12 11 12 7C 0
7C 12 11 12 7C 5
7C 12 11 12 7C -1
@@@ hidden_output
-- glyph 1 x0 --
ERR
-- glyph 2 x5 --
ERR
-- glyph 3 x-1 --
ERR

@@@ hidden_input
2
FF FF FF FF FF 1
80 80 80 80 80 1
@@@ hidden_output
-- glyph 1 x1 --
#####
#####
#####
#####
#####
#####
#####
-- glyph 2 x1 --
.....
.....
.....
.....
.....
.....
.....

@@@ hidden_input
1
7F 49 49 49 41 1
@@@ hidden_output
-- glyph 1 x1 --
#####
#....
#....
####.
#....
#....
#####

@@@ hidden_input
1
00 00 00 00 00 3
@@@ hidden_output
-- glyph 1 x3 --
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............
...............

@@@ hidden_input
2
7C 12 11 12 7C 4
C1 A2 94 88 F7 2
@@@ hidden_output
-- glyph 1 x4 --
........####........
........####........
........####........
........####........
....####....####....
....####....####....
....####....####....
....####....####....
####............####
####............####
####............####
####............####
####............####
####............####
####............####
####............####
####################
####################
####################
####################
####............####
####............####
####............####
####............####
####............####
####............####
####............####
####............####
-- glyph 2 x2 --
##......##
##......##
..##....##
..##....##
....##..##
....##..##
......##..
......##..
....##..##
....##..##
..##....##
..##....##
##......##
##......##

@@@ hidden_input
3
01 02 04 08 10 1
40 20 10 08 04 1
1C 22 41 00 00 1
@@@ hidden_output
-- glyph 1 x1 --
#....
.#...
..#..
...#.
....#
.....
.....
-- glyph 2 x1 --
.....
.....
....#
...#.
..#..
.#...
#....
-- glyph 3 x1 --
..#..
.#...
#....
#....
#....
.#...
..#..

@@@ hint
The font is stored by **columns**, but you print by **rows**. For output row `r` and column `c`, the pixel is bit `r` of `col[c]`: `(col[c] >> r) & 1`.
@@@ hint
Scaling is two extra loops: repeat every output row `scale` times, and inside a row print every pixel `scale` times. Loop `r` only over `0..6`, so bit 7 is never drawn.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

void render_glyph(const uint8_t col[5], int scale)
{
    if (scale < 1 || scale > 4) {
        printf("ERR\n");
        return;
    }
    for (int r = 0; r < 7; r++) {                   /* rows 0..6 only: bit 7 ignored */
        for (int sy = 0; sy < scale; sy++) {        /* vertical scaling */
            for (int c = 0; c < 5; c++) {
                char px = ((col[c] >> r) & 1u) ? '#' : '.';   /* transpose */
                for (int sx = 0; sx < scale; sx++)  /* horizontal scaling */
                    putchar(px);
            }
            putchar('\n');
        }
    }
}
@@@ explanation_md
**Approach.** The font is column-major (one byte per column), which suits LCD controllers such as the KS0108 or SSD1306 that write 8 vertical pixels per byte. A text console prints row by row, so the code must **transpose** while reading: output row `r`, column `c` is bit `r` of `col[c]`. Scaling to `scale x scale` blocks needs two more loops: repeat each output row `scale` times, and each pixel `scale` times within the row.

```
'A' = 7C 12 11 12 7C       row 0: bit 0 of each column -> 0 0 1 0 0 -> ..#..
                           row 4: bit 4 of each column -> 1 1 1 1 1 -> #####
```

**Complexity.** Time O(35 * scale^2), proportional to the output size. Space O(1); no frame buffer is needed.

**Common mistakes**
- Treating the bytes as rows (`col[r] >> c`). The glyph comes out transposed (mirrored along the diagonal) and only 5 rows tall.
- Looping `r < 8`. That draws the unused bit 7 as an eighth row, which shows up for bytes such as `0xFF` or `0x80`.
- Reading bit `6 - r` (bottom-up). Some fonts are stored that way, but this one is not, and the glyph appears upside-down. Always check the font's bit order in its documentation.
- Scaling only horizontally (one loop) so the glyph is squashed.

**Interview follow-ups**
- Render a whole string with one blank column between characters, given `font[96][5]` for ASCII 32..127. How do you compute the table index for a character?
- The SSD1306 OLED has 8-pixel "pages". How would you write this glyph into a page-organized frame buffer at an arbitrary y position that is not a multiple of 8?
- Store the font in flash on an AVR (`PROGMEM` / `pgm_read_byte`) or as `static const` on ARM. Why does `const` matter for RAM usage?
