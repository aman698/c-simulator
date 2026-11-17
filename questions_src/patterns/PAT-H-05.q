@@@ meta
id: PAT-H-05
topic: C Patterns
difficulty: Hard
type: CODE
title: UART Frame Timing Diagram
tags: embedded, uart, timing-diagram, parity, lsb-first, asked-in-automotive
@@@ statement_md
Draw the **logic-analyzer view** of a UART transmission as ASCII art.

**Frame format.** The configuration is a 3-character string such as `8N1`: number of data bits `5..8`, parity `N` (none), `E` (even) or `O` (odd), and stop bits `1` or `2`. Each byte is sent as:
- one **start** bit (`0`),
- the low `d` data bits, **LSB first** (bits above `d` are ignored),
- a **parity** bit if parity is `E` or `O`: for `E` the number of 1s in data + parity is even, for `O` it is odd,
- `1` or `2` **stop** bits (`1`).

Frames follow each other back-to-back. The line idles high: draw **one idle cell (`1`) before the first frame and one after the last**.

**Rendering.** Every bit is a cell 3 characters wide. Let `v` be the cell's level and `p` the level of the previous cell (for the first idle cell, `p = 1`). Print 4 rows:
1. **High row:** column 0 is a space if `v != p`, otherwise `_` if `v == 1` and a space if `v == 0`; columns 1-2 are `__` if `v == 1`, else spaces.
2. **Low row:** column 0 is `|` if `v != p` (an edge), otherwise `_` if `v == 0` and a space if `v == 1`; columns 1-2 are `__` if `v == 0`, else spaces.
3. **Label row:** a space followed by `ST` (start), `D0`..`D7` (data bit index), `PA` (parity) or `SP` (stop); idle cells are 3 spaces.
4. **Bit row:** two spaces and the bit value `0`/`1`; idle cells are 3 spaces.

Finally print `frames=<k> bits/frame=<n>` where `n = 1 + d + (parity ? 1 : 0) + stop`.

**Validation.** If the configuration is not exactly 3 characters of the form above (uppercase parity letter), print only `BAD CONFIG`. Otherwise, if the byte count `k` is not in `1..4`, print only `BAD LENGTH`.

**Input**
- Line 1: the configuration string.
- Line 2: `k`, followed by `k` bytes in hex (`00`..`FF`).

**Output**
- The 4 diagram rows and the summary line, or one error line. Leading spaces are significant; the judge ignores trailing spaces and trailing blank lines.

**Example** (`0x41` = `0100 0001`, sent LSB first as `1 0 0 0 0 0 1 0`)
```
Input:
8N1
1 41

Output:
___    __                __    _____
   |__|  |______________|  |__|
    ST D0 D1 D2 D3 D4 D5 D6 D7 SP
     0  1  0  0  0  0  0  1  0  1
frames=1 bits/frame=10
```
@@@ constraints_md
- The configuration string has 1..15 characters and no spaces.
- `-5 <= k <= 10`; when `1 <= k <= 4`, exactly `k` hex bytes follow.
- At most `1 + 4 * 12 + 1 = 50` cells.
@@@ starter_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    char cfg[16];
    if (scanf("%15s", cfg) != 1) return 0;

    /* TODO: validate cfg, read k and the bytes,
       build the list of cell levels and labels, render 4 rows + summary */

    return 0;
}
@@@ sample_input
8N1
1 41
@@@ sample_output
___    __                __    _____
   |__|  |______________|  |__|
    ST D0 D1 D2 D3 D4 D5 D6 D7 SP
     0  1  0  0  0  0  0  1  0  1
frames=1 bits/frame=10

@@@ sample_input
7E2
2 C1 03
@@@ sample_output
___    __                __    _____    _____                   ________
   |__|  |______________|  |__|     |__|     |_________________|
    ST D0 D1 D2 D3 D4 D5 D6 PA SP SP ST D0 D1 D2 D3 D4 D5 D6 PA SP SP
     0  1  0  0  0  0  0  1  0  1  1  0  1  1  0  0  0  0  0  0  1  1
frames=2 bits/frame=11

@@@ hidden_input
9N1
1 41
@@@ hidden_output
BAD CONFIG

@@@ hidden_input
8N3
1 41
@@@ hidden_output
BAD CONFIG

@@@ hidden_input
8n1
1 41
@@@ hidden_output
BAD CONFIG

@@@ hidden_input
8N1X
1 41
@@@ hidden_output
BAD CONFIG

@@@ hidden_input
8N1
0
@@@ hidden_output
BAD LENGTH

@@@ hidden_input
8E1
5 01 02 03 04 05
@@@ hidden_output
BAD LENGTH

@@@ hidden_input
5O1
1 FF
@@@ hidden_output
___    ______________    _____
   |__|              |__|
    ST D0 D1 D2 D3 D4 PA SP
     0  1  1  1  1  1  0  1
frames=1 bits/frame=8

@@@ hidden_input
8O2
4 00 FF 55 AA
@@@ hidden_output
___                            ________    ________________________________    __    __    __    __    ________       __    __    __    ______________
   |__________________________|        |__|                                |__|  |__|  |__|  |__|  |__|        |_____|  |__|  |__|  |__|
    ST D0 D1 D2 D3 D4 D5 D6 D7 PA SP SP ST D0 D1 D2 D3 D4 D5 D6 D7 PA SP SP ST D0 D1 D2 D3 D4 D5 D6 D7 PA SP SP ST D0 D1 D2 D3 D4 D5 D6 D7 PA SP SP
     0  0  0  0  0  0  0  0  0  1  1  1  0  1  1  1  1  1  1  1  1  1  1  1  0  1  0  1  0  1  0  1  0  1  1  1  0  0  1  0  1  0  1  0  1  1  1  1
frames=4 bits/frame=12

@@@ hidden_input
6E1
3 3F 40 2A
@@@ hidden_output
___    _________________    __                         __       __    __    ___________
   |__|                 |__|  |_______________________|  |_____|  |__|  |__|
    ST D0 D1 D2 D3 D4 D5 PA SP ST D0 D1 D2 D3 D4 D5 PA SP ST D0 D1 D2 D3 D4 D5 PA SP
     0  1  1  1  1  1  1  0  1  0  0  0  0  0  0  0  0  1  0  0  1  0  1  0  1  1  1
frames=3 bits/frame=9

@@@ hidden_input
8N1
2 00 FF
@@@ hidden_output
___                            __    _____________________________
   |__________________________|  |__|
    ST D0 D1 D2 D3 D4 D5 D6 D7 SP ST D0 D1 D2 D3 D4 D5 D6 D7 SP
     0  0  0  0  0  0  0  0  0  1  0  1  1  1  1  1  1  1  1  1
frames=2 bits/frame=10

@@@ hint
Separate the two problems. First build two arrays: the level of every cell (idle, start, data LSB first, parity, stop(s), ..., idle) and its 2-character label. Then render the 4 rows by walking those arrays, comparing each level with the previous one to find the edges.
@@@ hint
Data bit `i` of byte `b` is `(b >> i) & 1` for `i = 0..d-1`; count the 1s while you emit them. Even parity bit = `ones % 2`; odd parity bit = `1 - ones % 2`. In the high row an edge column is always a space; in the low row it is `|`.
@@@ solution_code
#include <stdio.h>
#include <string.h>

#define MAXCELLS 64

static int level[MAXCELLS];
static char label[MAXCELLS][3];     /* "" for idle cells */
static int ncells;

static void add(int v, const char *lab, int idx)
{
    level[ncells] = v;
    if (idx >= 0) {                 /* data bit label D0..D7 */
        label[ncells][0] = 'D';
        label[ncells][1] = (char)('0' + idx);
        label[ncells][2] = '\0';
    } else {
        strcpy(label[ncells], lab);
    }
    ncells++;
}

int main(void)
{
    char cfg[16];
    int k;
    if (scanf("%15s", cfg) != 1) return 0;

    if (strlen(cfg) != 3 || cfg[0] < '5' || cfg[0] > '8' ||
        (cfg[1] != 'N' && cfg[1] != 'E' && cfg[1] != 'O') ||
        (cfg[2] != '1' && cfg[2] != '2')) {
        printf("BAD CONFIG\n");
        return 0;
    }
    int d = cfg[0] - '0';
    char par = cfg[1];
    int stop = cfg[2] - '0';

    if (scanf("%d", &k) != 1) return 0;
    if (k < 1 || k > 4) {
        printf("BAD LENGTH\n");
        return 0;
    }

    add(1, "", -1);                                 /* idle before */
    for (int f = 0; f < k; f++) {
        unsigned int b;
        if (scanf("%x", &b) != 1) return 0;
        int ones = 0;
        add(0, "ST", -1);                           /* start bit */
        for (int i = 0; i < d; i++) {               /* LSB first */
            int bit = (int)((b >> i) & 1u);
            ones += bit;
            add(bit, "", i);
        }
        if (par == 'E')
            add(ones % 2, "PA", -1);                /* makes the count even */
        else if (par == 'O')
            add(1 - ones % 2, "PA", -1);            /* makes the count odd */
        for (int s = 0; s < stop; s++)
            add(1, "SP", -1);
    }
    add(1, "", -1);                                 /* idle after */

    for (int row = 0; row < 4; row++) {
        int prev = 1;                               /* line was idle (high) */
        for (int c = 0; c < ncells; c++) {
            int v = level[c];
            int edge = (v != prev);
            if (row == 0) {
                putchar(edge ? ' ' : (v ? '_' : ' '));
                printf(v ? "__" : "  ");
            } else if (row == 1) {
                putchar(edge ? '|' : (v ? ' ' : '_'));
                printf(v ? "  " : "__");
            } else if (row == 2) {
                printf(label[c][0] ? " %s" : "   ", label[c]);
            } else {
                if (label[c][0])
                    printf("  %d", v);
                else
                    printf("   ");
            }
            prev = v;
        }
        putchar('\n');
    }
    printf("frames=%d bits/frame=%d\n", k, 1 + d + (par != 'N') + stop);
    return 0;
}
@@@ explanation_md
**Approach.** Model first, render second. Building the frame is a small serializer: start bit, `d` data bits taken **LSB first** with `(b >> i) & 1`, an optional parity bit computed from the running count of ones, then the stop bits. Wrap all frames in one idle cell on each side. Rendering then walks the cell list once per row. The only state is the previous level, because an **edge** (`v != prev`) changes the first column of a cell: a gap in the high row and `|` in the low row.

```
8N1, 0x41:   idle ST D0 D1 D2 D3 D4 D5 D6 D7 SP idle
level:         1   0  1  0  0  0  0  0  1  0  1   1
```

**Parity.** Even parity sets the parity bit so that data + parity contains an even number of ones: `p = ones % 2`. Odd parity is the complement. For `5O1` with `0xFF`, only the low 5 bits are sent (5 ones), so the odd-parity bit is 0.

**Complexity.** O(k * (d + 4)) cells and O(1) work per cell and row. Space O(cells), at most 50.

**Common mistakes**
- Sending the data **MSB first**. UART is LSB first (SPI usually MSB first). The example `0x41` shows the difference immediately.
- Using all 8 bits of the byte in 5/6/7-bit modes, both for the data cells and for the parity count.
- Inverting the parity rule (even parity does **not** mean "parity bit = 0").
- Treating the first cell as having an edge, or resetting `prev` between frames. Frames are back-to-back, so the stop bit of one frame is followed directly by the start edge of the next.
- `strchr("NEO", c)` as the parity check: it also matches `c == '\0'`. Here the length check prevents that, but it is a known trap.

**Interview follow-ups**
- At 115200 baud, how long is one `8N1` frame, and what is the maximum payload throughput in bytes per second? (10 bits per byte: 86.8 us, 11520 B/s.)
- How does a UART receiver find the middle of each bit (16x oversampling, start-bit validation)? What baud-rate mismatch can `8N1` tolerate?
- Implement this framing as a **bit-banged TX** driven by a timer interrupt: what state machine and which variables do you need, and which of them must be `volatile`?
- LIN uses a UART frame too. What is a LIN *break field*, and why can a normal UART frame never look like one?
