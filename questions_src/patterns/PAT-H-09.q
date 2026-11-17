@@@ meta
id: PAT-H-09
topic: C Patterns
difficulty: Hard
type: FIND_THE_BUG
title: CAN Payload Dump with Wrong Decimals and Checksum
tags: embedded, can-bus, signed-char, integer-promotion, hex-dump, asked-in-automotive
@@@ statement_md
A bench tool prints received **CAN frames** as a byte grid: for each payload byte its hex value, its decimal value and its 8 bits as LEDs (MSB left, `*` = 1, `.` = 0). The last line of each frame is the **sum of all payload bytes** (as unsigned values `0..255`), which the team compares with the checksum the ECU computes.

**Format of one frame**
```
ID 0x<id, 3 hex digits> DLC <dlc>
  B<i> 0x<HH> <decimal, width 3> <8 bits>      (one line per byte)
  SUM <sum>
```

**Expected for the frame `18F 3 12 A5 FF`**
```
ID 0x18F DLC 3
  B0 0x12  18 ...*..*.
  B1 0xA5 165 *.*..*.*
  B2 0xFF 255 ********
  SUM 438
```

**Symptom.** The hex column and the LED bits are always correct. But for many frames the decimal column shows **negative** numbers and the `SUM` line is wrong. Frames whose bytes are all below `0x80` are printed correctly. Find and fix the bug (assume x86-64, where plain `char` is signed).

**Input**
- Line 1: the number of frames `f`.
- Next `f` lines: `id dlc` followed by `dlc` payload bytes, all in hex except `dlc` (decimal).

**Output**
- The frames in the format above. The judge ignores trailing spaces and trailing blank lines.
@@@ constraints_md
- `1 <= f <= 10`
- `0 <= id <= 0x7FF` (11-bit identifier), `0 <= dlc <= 8`, bytes `00..FF`.
@@@ starter_code
#include <stdio.h>

static const char HEX[] = "0123456789ABCDEF";

int main(void)
{
    int frames;
    if (scanf("%d", &frames) != 1) return 0;

    for (int f = 0; f < frames; f++) {
        unsigned int id;
        int dlc;
        char data[8];

        if (scanf("%x %d", &id, &dlc) != 2 || dlc < 0 || dlc > 8) return 0;
        for (int i = 0; i < dlc; i++) {
            unsigned int tmp;
            if (scanf("%x", &tmp) != 1) return 0;
            data[i] = tmp;
        }

        printf("ID 0x%03X DLC %d\n", id, dlc);
        int sum = 0;
        for (int i = 0; i < dlc; i++) {
            printf("  B%d 0x%c%c %3d ", i,
                   HEX[(data[i] >> 4) & 0x0F], HEX[data[i] & 0x0F], data[i]);
            for (int b = 7; b >= 0; b--)
                putchar(((data[i] >> b) & 1) ? '*' : '.');
            putchar('\n');
            sum += data[i];
        }
        printf("  SUM %d\n", sum);
    }
    return 0;
}
@@@ sample_input
1
18F 3 12 A5 FF
@@@ sample_output
ID 0x18F DLC 3
  B0 0x12  18 ...*..*.
  B1 0xA5 165 *.*..*.*
  B2 0xFF 255 ********
  SUM 438

@@@ sample_input
1
7DF 2 02 01
@@@ sample_output
ID 0x7DF DLC 2
  B0 0x02   2 ......*.
  B1 0x01   1 .......*
  SUM 3

@@@ hidden_input
1
100 0
@@@ hidden_output
ID 0x100 DLC 0
  SUM 0

@@@ hidden_input
1
7FF 1 7F
@@@ hidden_output
ID 0x7FF DLC 1
  B0 0x7F 127 .*******
  SUM 127

@@@ hidden_input
1
000 8 80 80 80 80 80 80 80 80
@@@ hidden_output
ID 0x000 DLC 8
  B0 0x80 128 *.......
  B1 0x80 128 *.......
  B2 0x80 128 *.......
  B3 0x80 128 *.......
  B4 0x80 128 *.......
  B5 0x80 128 *.......
  B6 0x80 128 *.......
  B7 0x80 128 *.......
  SUM 1024

@@@ hidden_input
1
2A5 8 FF FF FF FF FF FF FF FF
@@@ hidden_output
ID 0x2A5 DLC 8
  B0 0xFF 255 ********
  B1 0xFF 255 ********
  B2 0xFF 255 ********
  B3 0xFF 255 ********
  B4 0xFF 255 ********
  B5 0xFF 255 ********
  B6 0xFF 255 ********
  B7 0xFF 255 ********
  SUM 2040

@@@ hidden_input
3
123 4 00 10 20 30
456 2 C0 3F
7E8 8 06 41 0C 1A F8 00 00 00
@@@ hidden_output
ID 0x123 DLC 4
  B0 0x00   0 ........
  B1 0x10  16 ...*....
  B2 0x20  32 ..*.....
  B3 0x30  48 ..**....
  SUM 96
ID 0x456 DLC 2
  B0 0xC0 192 **......
  B1 0x3F  63 ..******
  SUM 255
ID 0x7E8 DLC 8
  B0 0x06   6 .....**.
  B1 0x41  65 .*.....*
  B2 0x0C  12 ....**..
  B3 0x1A  26 ...**.*.
  B4 0xF8 248 *****...
  B5 0x00   0 ........
  B6 0x00   0 ........
  B7 0x00   0 ........
  SUM 357

@@@ hidden_input
2
0F0 5 81 7E 99 66 E7
00A 1 00
@@@ hidden_output
ID 0x0F0 DLC 5
  B0 0x81 129 *......*
  B1 0x7E 126 .******.
  B2 0x99 153 *..**..*
  B3 0x66 102 .**..**.
  B4 0xE7 231 ***..***
  SUM 741
ID 0x00A DLC 1
  B0 0x00   0 ........
  SUM 0

@@@ hint
Compare the bytes that print correctly with the ones that do not. What do `0x80`, `0xA5` and `0xFF` have in common, and what is the range of a plain `char` on x86-64?
@@@ hint
`data` is an array of plain (signed) `char`, so `0xA5` is stored as `-91`. The hex digits and bits look right only because of the `& 0x0F` / `& 1` masks; `%d` and the `sum` use the negative value. Store the payload in `uint8_t` (`<stdint.h>`) or `unsigned char`.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

static const char HEX[] = "0123456789ABCDEF";

int main(void)
{
    int frames;
    if (scanf("%d", &frames) != 1) return 0;

    for (int f = 0; f < frames; f++) {
        unsigned int id;
        int dlc;
        uint8_t data[8];                    /* FIX: was plain char (signed on x86): 0xA5 became -91 */

        if (scanf("%x %d", &id, &dlc) != 2 || dlc < 0 || dlc > 8) return 0;
        for (int i = 0; i < dlc; i++) {
            unsigned int tmp;
            if (scanf("%x", &tmp) != 1) return 0;
            data[i] = tmp;
        }

        printf("ID 0x%03X DLC %d\n", id, dlc);
        int sum = 0;
        for (int i = 0; i < dlc; i++) {
            printf("  B%d 0x%c%c %3d ", i,
                   HEX[(data[i] >> 4) & 0x0F], HEX[data[i] & 0x0F], data[i]);
            for (int b = 7; b >= 0; b--)
                putchar(((data[i] >> b) & 1) ? '*' : '.');
            putchar('\n');
            sum += data[i];
        }
        printf("  SUM %d\n", sum);
    }
    return 0;
}
@@@ explanation_md
**Bug.** The payload buffer is `char data[8]`. On x86-64 plain `char` is **signed**, range `-128..127` (on ARM it is usually unsigned, so the same code "works" on the target and fails on the PC tool). Assigning `0xA5` (165) stores the implementation-defined result `-91`. Every later use promotes `data[i]` to `int` with sign extension:
- `%d` prints `-91`;
- `sum += data[i]` subtracts instead of adding;
- the hex digits survive only because `(x >> 4) & 0x0F` and `x & 0x0F` mask away the sign-extension bits, and the LED loop only looks at bits 0..7. That is why the bug looked like a "decimal formatting" problem.

**Fix.** Declare the buffer as `uint8_t data[8]` (or `unsigned char`). Raw bus data is a sequence of **octets**, never characters. With an unsigned type the promotion to `int` yields `0..255`.

**Complexity.** Time O(total bytes * 8), space O(8).

**Common mistakes**
- Patching the symptom with `data[i] & 0xFF` in the `printf` and forgetting the `sum`, or the next place that uses `data`.
- Casting at the point of use (`(unsigned)data[i]`): that yields `4294967205`, not 165, because the sign extension happens before the conversion.
- Assuming `char` is unsigned everywhere. Its signedness is implementation-defined: gcc for ARM Linux makes it unsigned, x86 makes it signed, and `-funsigned-char` changes it.
- Using `%hhx` with a `char *` argument to read the bytes. The conversion expects `unsigned char *`.

**Interview follow-ups**
- What does `(data[i] >> 4)` evaluate to for `-91`, and why is right-shifting a negative value implementation-defined?
- MISRA C:2012 distinguishes plain `char` (character data) from `signed`/`unsigned char` (numeric data) in its essential type model. Which rule would flag `sum += data[i]` here?
- Real CAN checksums (e.g. AUTOSAR E2E profiles) use CRC-8 or CRC-16 instead of a sum. Why is a plain sum a weak check?
