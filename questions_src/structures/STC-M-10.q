@@@ meta
id: STC-M-10
topic: Structures
difficulty: Medium
type: FIND_THE_BUG
title: Gateway Block List Never Matches (memcmp on Padded Frames)
tags: embedded, struct-padding, memcmp, can-bus, struct-comparison, asked-in-automotive
@@@ statement_md
A CAN gateway must **drop** frames that exactly match an entry of a constant block list (same ID, same DLC, same first `dlc` data bytes) and **forward** everything else. Frames arrive in a receive buffer that the driver allocates once and reuses for every frame. The driver writes `id`, `dlc` and only the first `dlc` data bytes.

```c
struct CanFrame {
    uint32_t id;
    uint8_t  dlc;
    uint8_t  data[8];
};
```

**Symptom.** The block list was reviewed and is correct, yet frames that match an entry byte-for-byte are **forwarded** anyway. Only frames that are not in the list are handled correctly.

Find and fix the bug. The output format must not change.

**Input**
- Line 1: `n`.
- Next `n` lines: `id dlc b0 .. b(dlc-1)` (id and bytes in hex, `dlc` decimal).

**Output**
- Per frame: `DROP 0x%03X`, or `FWD 0x%03X [dlc]` followed by the data bytes as ` %02X`.
- Last line: `forwarded=<f> dropped=<d>`.

**Block list** (in the code): `7DF [2] 3E 00`, `100 [8] 01 02 03 04 05 06 07 08`, `7E0 [3] 22 F1 90`, `7FF [0]`.

**Example**
```
Input:
4
7DF 2 3E 00
123 1 55
100 8 01 02 03 04 05 06 07 08
7E0 3 22 F1 90

Output:
DROP 0x7DF
FWD 0x123 [1] 55
DROP 0x100
DROP 0x7E0
forwarded=1 dropped=3
```
@@@ constraints_md
- `0 <= n <= 500`, `0 <= dlc <= 8`, IDs `0x000 .. 0x7FF`.
- Data bytes beyond `dlc` are **not** part of the frame and must not influence the result.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct CanFrame {
    uint32_t id;
    uint8_t  dlc;
    uint8_t  data[8];
};

static const struct CanFrame blocklist[] = {
    { 0x7DF, 2, { 0x3E, 0x00 } },                                     /* functional TesterPresent */
    { 0x100, 8, { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 } }, /* test pattern            */
    { 0x7E0, 3, { 0x22, 0xF1, 0x90 } },                               /* read VIN                */
    { 0x7FF, 0, { 0 } },                                              /* empty frame on 0x7FF    */
};
#define NBLOCK (sizeof blocklist / sizeof blocklist[0])

static int is_blocked(const struct CanFrame *f)
{
    for (size_t i = 0; i < NBLOCK; i++)
        if (memcmp(f, &blocklist[i], sizeof *f) == 0)
            return 1;
    return 0;
}

int main(void)
{
    int n, fwd = 0, drop = 0;
    if (scanf("%d", &n) != 1) return 0;

    struct CanFrame *rx = malloc(sizeof *rx);    /* driver mailbox, reused for every frame */
    if (rx == NULL) return 1;

    for (int k = 0; k < n; k++) {
        unsigned id;
        int dlc;
        if (scanf("%x %d", &id, &dlc) != 2 || dlc < 0 || dlc > 8) break;
        rx->id = id;
        rx->dlc = (uint8_t)dlc;
        for (int i = 0; i < dlc; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) b = 0;
            rx->data[i] = (uint8_t)b;
        }

        if (is_blocked(rx)) {
            printf("DROP 0x%03X\n", (unsigned)rx->id);
            drop++;
        } else {
            printf("FWD 0x%03X [%d]", (unsigned)rx->id, rx->dlc);
            for (int i = 0; i < rx->dlc; i++) printf(" %02X", (unsigned)rx->data[i]);
            printf("\n");
            fwd++;
        }
    }
    printf("forwarded=%d dropped=%d\n", fwd, drop);
    free(rx);
    return 0;
}
@@@ sample_input
4
7DF 2 3E 00
123 1 55
100 8 01 02 03 04 05 06 07 08
7E0 3 22 F1 90
@@@ sample_output
DROP 0x7DF
FWD 0x123 [1] 55
DROP 0x100
DROP 0x7E0
forwarded=1 dropped=3

@@@ sample_input
0
@@@ sample_output
forwarded=0 dropped=0

@@@ hidden_input
3
7DF 2 3E 80
7DF 3 3E 00 00
7DE 2 3E 00
@@@ hidden_output
FWD 0x7DF [2] 3E 80
FWD 0x7DF [3] 3E 00 00
FWD 0x7DE [2] 3E 00
forwarded=3 dropped=0

@@@ hidden_input
2
100 8 01 02 03 04 05 06 07 08
7DF 2 3E 00
@@@ hidden_output
DROP 0x100
DROP 0x7DF
forwarded=0 dropped=2

@@@ hidden_input
3
7FF 0
7FF 1 00
000 0
@@@ hidden_output
DROP 0x7FF
FWD 0x7FF [1] 00
FWD 0x000 [0]
forwarded=2 dropped=1

@@@ hidden_input
4
100 8 01 02 03 04 05 06 07 09
100 7 01 02 03 04 05 06 07
7E0 3 22 F1 90
7E0 3 22 F1 91
@@@ hidden_output
FWD 0x100 [8] 01 02 03 04 05 06 07 09
FWD 0x100 [7] 01 02 03 04 05 06 07
DROP 0x7E0
FWD 0x7E0 [3] 22 F1 91
forwarded=3 dropped=1

@@@ hidden_input
1
7E0 3 22 F1 90
@@@ hidden_output
DROP 0x7E0
forwarded=0 dropped=1

@@@ hidden_input
200
7DF 2 3E 00
61 5 1F 30 41 52 63
C2 1 3E
100 8 01 02 03 04 05 06 07 08
184 2 7C 8D
1E5 7 9B AC BD CE DF F0 01
7E0 3 22 F1 90
2A7 8 D9 EA FB 0C 1D 2E 3F 50
308 4 F8 09 1A 2B
7FF 0
3CA 5 36 47 58 69 7A
42B 1 55
7DF 2 3E 00
4ED 2 93 A4
54E 7 B2 C3 D4 E5 F6 07 18
100 8 01 02 03 04 05 06 07 08
610 8 F0 01 12 23 34 45 56 67
671 4 0F 20 31 42
7E0 3 22 F1 90
733 5 4D 5E 6F 80 91
794 1 6C
7FF 0
56 2 AA BB
B7 7 C9 DA EB FC 0D 1E 2F
7DF 2 3E 00
179 8 07 18 29 3A 4B 5C 6D 7E
1DA 4 26 37 48 59
100 8 01 02 03 04 05 06 07 08
29C 5 64 75 86 97 A8
2FD 1 83
7E0 3 22 F1 90
3BF 2 C1 D2
420 7 E0 F1 02 13 24 35 46
7FF 0
4E2 8 1E 2F 40 51 62 73 84 95
543 4 3D 4E 5F 70
7DF 2 3E 00
605 5 7B 8C 9D AE BF
666 1 9A
100 8 01 02 03 04 05 06 07 08
728 2 D8 E9
789 7 F7 08 19 2A 3B 4C 5D
7E0 3 22 F1 90
4B 8 35 46 57 68 79 8A 9B AC
AC 4 54 65 76 87
7FF 0
16E 5 92 A3 B4 C5 D6
1CF 1 B1
7DF 2 3E 00
291 2 EF 00
2F2 7 0E 1F 30 41 52 63 74
100 8 01 02 03 04 05 06 07 08
3B4 8 4C 5D 6E 7F 90 A1 B2 C3
415 4 6B 7C 8D 9E
7E0 3 22 F1 90
4D7 5 A9 BA CB DC ED
538 1 C8
7FF 0
5FA 2 06 17
65B 7 25 36 47 58 69 7A 8B
7DF 2 3E 00
71D 8 63 74 85 96 A7 B8 C9 DA
77E 4 82 93 A4 B5
100 8 01 02 03 04 05 06 07 08
40 5 C0 D1 E2 F3 04
A1 1 DF
7E0 3 22 F1 90
163 2 1D 2E
1C4 7 3C 4D 5E 6F 80 91 A2
7FF 0
286 8 7A 8B 9C AD BE CF E0 F1
2E7 4 99 AA BB CC
7DF 2 3E 00
3A9 5 D7 E8 F9 0A 1B
40A 1 F6
100 8 01 02 03 04 05 06 07 08
4CC 2 34 45
52D 7 53 64 75 86 97 A8 B9
7E0 3 22 F1 90
5EF 8 91 A2 B3 C4 D5 E6 F7 08
650 4 B0 C1 D2 E3
7FF 0
712 5 EE FF 10 21 32
773 1 0D
7DF 2 3E 00
35 2 4B 5C
96 7 6A 7B 8C 9D AE BF D0
100 8 01 02 03 04 05 06 07 08
158 8 A8 B9 CA DB EC FD 0E 1F
1B9 4 C7 D8 E9 FA
7E0 3 22 F1 90
27B 5 05 16 27 38 49
2DC 1 24
7FF 0
39E 2 62 73
3FF 7 81 92 A3 B4 C5 D6 E7
7DF 2 3E 00
4C1 8 BF D0 E1 F2 03 14 25 36
522 4 DE EF 00 11
100 8 01 02 03 04 05 06 07 08
5E4 5 1C 2D 3E 4F 60
645 1 3B
7E0 3 22 F1 90
707 2 79 8A
768 7 98 A9 BA CB DC ED FE
7FF 0
2A 8 D6 E7 F8 09 1A 2B 3C 4D
8B 4 F5 06 17 28
7DF 2 3E 00
14D 5 33 44 55 66 77
1AE 1 52
100 8 01 02 03 04 05 06 07 08
270 2 90 A1
2D1 7 AF C0 D1 E2 F3 04 15
7E0 3 22 F1 90
393 8 ED FE 0F 20 31 42 53 64
3F4 4 0C 1D 2E 3F
7FF 0
4B6 5 4A 5B 6C 7D 8E
517 1 69
7DF 2 3E 00
5D9 2 A7 B8
63A 7 C6 D7 E8 F9 0A 1B 2C
100 8 01 02 03 04 05 06 07 08
6FC 8 04 15 26 37 48 59 6A 7B
75D 4 23 34 45 56
7E0 3 22 F1 90
1F 5 61 72 83 94 A5
80 1 80
7FF 0
142 2 BE CF
1A3 7 DD EE FF 10 21 32 43
7DF 2 3E 00
265 8 1B 2C 3D 4E 5F 70 81 92
2C6 4 3A 4B 5C 6D
100 8 01 02 03 04 05 06 07 08
388 5 78 89 9A AB BC
3E9 1 97
7E0 3 22 F1 90
4AB 2 D5 E6
50C 7 F4 05 16 27 38 49 5A
7FF 0
5CE 8 32 43 54 65 76 87 98 A9
62F 4 51 62 73 84
7DF 2 3E 00
6F1 5 8F A0 B1 C2 D3
752 1 AE
100 8 01 02 03 04 05 06 07 08
14 2 EC FD
75 7 0B 1C 2D 3E 4F 60 71
7E0 3 22 F1 90
137 8 49 5A 6B 7C 8D 9E AF C0
198 4 68 79 8A 9B
7FF 0
25A 5 A6 B7 C8 D9 EA
2BB 1 C5
7DF 2 3E 00
37D 2 03 14
3DE 7 22 33 44 55 66 77 88
100 8 01 02 03 04 05 06 07 08
4A0 8 60 71 82 93 A4 B5 C6 D7
501 4 7F 90 A1 B2
7E0 3 22 F1 90
5C3 5 BD CE DF F0 01
624 1 DC
7FF 0
6E6 2 1A 2B
747 7 39 4A 5B 6C 7D 8E 9F
7DF 2 3E 00
9 8 77 88 99 AA BB CC DD EE
6A 4 96 A7 B8 C9
100 8 01 02 03 04 05 06 07 08
12C 5 D4 E5 F6 07 18
18D 1 F3
7E0 3 22 F1 90
24F 2 31 42
2B0 7 50 61 72 83 94 A5 B6
7FF 0
372 8 8E 9F B0 C1 D2 E3 F4 05
3D3 4 AD BE CF E0
7DF 2 3E 00
495 5 EB FC 0D 1E 2F
4F6 1 0A
100 8 01 02 03 04 05 06 07 08
5B8 2 48 59
619 7 67 78 89 9A AB BC CD
7E0 3 22 F1 90
6DB 8 A5 B6 C7 D8 E9 FA 0B 1C
73C 4 C4 D5 E6 F7
7FF 0
7FE 5 02 13 24 35 46
5F 1 21
7DF 2 3E 00
121 2 5F 70
182 7 7E 8F A0 B1 C2 D3 E4
100 8 01 02 03 04 05 06 07 08
244 8 BC CD DE EF 00 11 22 33
2A5 4 DB EC FD 0E
7E0 3 22 F1 90
367 5 19 2A 3B 4C 5D
@@@ hidden_output
DROP 0x7DF
FWD 0x061 [5] 1F 30 41 52 63
FWD 0x0C2 [1] 3E
DROP 0x100
FWD 0x184 [2] 7C 8D
FWD 0x1E5 [7] 9B AC BD CE DF F0 01
DROP 0x7E0
FWD 0x2A7 [8] D9 EA FB 0C 1D 2E 3F 50
FWD 0x308 [4] F8 09 1A 2B
DROP 0x7FF
FWD 0x3CA [5] 36 47 58 69 7A
FWD 0x42B [1] 55
DROP 0x7DF
FWD 0x4ED [2] 93 A4
FWD 0x54E [7] B2 C3 D4 E5 F6 07 18
DROP 0x100
FWD 0x610 [8] F0 01 12 23 34 45 56 67
FWD 0x671 [4] 0F 20 31 42
DROP 0x7E0
FWD 0x733 [5] 4D 5E 6F 80 91
FWD 0x794 [1] 6C
DROP 0x7FF
FWD 0x056 [2] AA BB
FWD 0x0B7 [7] C9 DA EB FC 0D 1E 2F
DROP 0x7DF
FWD 0x179 [8] 07 18 29 3A 4B 5C 6D 7E
FWD 0x1DA [4] 26 37 48 59
DROP 0x100
FWD 0x29C [5] 64 75 86 97 A8
FWD 0x2FD [1] 83
DROP 0x7E0
FWD 0x3BF [2] C1 D2
FWD 0x420 [7] E0 F1 02 13 24 35 46
DROP 0x7FF
FWD 0x4E2 [8] 1E 2F 40 51 62 73 84 95
FWD 0x543 [4] 3D 4E 5F 70
DROP 0x7DF
FWD 0x605 [5] 7B 8C 9D AE BF
FWD 0x666 [1] 9A
DROP 0x100
FWD 0x728 [2] D8 E9
FWD 0x789 [7] F7 08 19 2A 3B 4C 5D
DROP 0x7E0
FWD 0x04B [8] 35 46 57 68 79 8A 9B AC
FWD 0x0AC [4] 54 65 76 87
DROP 0x7FF
FWD 0x16E [5] 92 A3 B4 C5 D6
FWD 0x1CF [1] B1
DROP 0x7DF
FWD 0x291 [2] EF 00
FWD 0x2F2 [7] 0E 1F 30 41 52 63 74
DROP 0x100
FWD 0x3B4 [8] 4C 5D 6E 7F 90 A1 B2 C3
FWD 0x415 [4] 6B 7C 8D 9E
DROP 0x7E0
FWD 0x4D7 [5] A9 BA CB DC ED
FWD 0x538 [1] C8
DROP 0x7FF
FWD 0x5FA [2] 06 17
FWD 0x65B [7] 25 36 47 58 69 7A 8B
DROP 0x7DF
FWD 0x71D [8] 63 74 85 96 A7 B8 C9 DA
FWD 0x77E [4] 82 93 A4 B5
DROP 0x100
FWD 0x040 [5] C0 D1 E2 F3 04
FWD 0x0A1 [1] DF
DROP 0x7E0
FWD 0x163 [2] 1D 2E
FWD 0x1C4 [7] 3C 4D 5E 6F 80 91 A2
DROP 0x7FF
FWD 0x286 [8] 7A 8B 9C AD BE CF E0 F1
FWD 0x2E7 [4] 99 AA BB CC
DROP 0x7DF
FWD 0x3A9 [5] D7 E8 F9 0A 1B
FWD 0x40A [1] F6
DROP 0x100
FWD 0x4CC [2] 34 45
FWD 0x52D [7] 53 64 75 86 97 A8 B9
DROP 0x7E0
FWD 0x5EF [8] 91 A2 B3 C4 D5 E6 F7 08
FWD 0x650 [4] B0 C1 D2 E3
DROP 0x7FF
FWD 0x712 [5] EE FF 10 21 32
FWD 0x773 [1] 0D
DROP 0x7DF
FWD 0x035 [2] 4B 5C
FWD 0x096 [7] 6A 7B 8C 9D AE BF D0
DROP 0x100
FWD 0x158 [8] A8 B9 CA DB EC FD 0E 1F
FWD 0x1B9 [4] C7 D8 E9 FA
DROP 0x7E0
FWD 0x27B [5] 05 16 27 38 49
FWD 0x2DC [1] 24
DROP 0x7FF
FWD 0x39E [2] 62 73
FWD 0x3FF [7] 81 92 A3 B4 C5 D6 E7
DROP 0x7DF
FWD 0x4C1 [8] BF D0 E1 F2 03 14 25 36
FWD 0x522 [4] DE EF 00 11
DROP 0x100
FWD 0x5E4 [5] 1C 2D 3E 4F 60
FWD 0x645 [1] 3B
DROP 0x7E0
FWD 0x707 [2] 79 8A
FWD 0x768 [7] 98 A9 BA CB DC ED FE
DROP 0x7FF
FWD 0x02A [8] D6 E7 F8 09 1A 2B 3C 4D
FWD 0x08B [4] F5 06 17 28
DROP 0x7DF
FWD 0x14D [5] 33 44 55 66 77
FWD 0x1AE [1] 52
DROP 0x100
FWD 0x270 [2] 90 A1
FWD 0x2D1 [7] AF C0 D1 E2 F3 04 15
DROP 0x7E0
FWD 0x393 [8] ED FE 0F 20 31 42 53 64
FWD 0x3F4 [4] 0C 1D 2E 3F
DROP 0x7FF
FWD 0x4B6 [5] 4A 5B 6C 7D 8E
FWD 0x517 [1] 69
DROP 0x7DF
FWD 0x5D9 [2] A7 B8
FWD 0x63A [7] C6 D7 E8 F9 0A 1B 2C
DROP 0x100
FWD 0x6FC [8] 04 15 26 37 48 59 6A 7B
FWD 0x75D [4] 23 34 45 56
DROP 0x7E0
FWD 0x01F [5] 61 72 83 94 A5
FWD 0x080 [1] 80
DROP 0x7FF
FWD 0x142 [2] BE CF
FWD 0x1A3 [7] DD EE FF 10 21 32 43
DROP 0x7DF
FWD 0x265 [8] 1B 2C 3D 4E 5F 70 81 92
FWD 0x2C6 [4] 3A 4B 5C 6D
DROP 0x100
FWD 0x388 [5] 78 89 9A AB BC
FWD 0x3E9 [1] 97
DROP 0x7E0
FWD 0x4AB [2] D5 E6
FWD 0x50C [7] F4 05 16 27 38 49 5A
DROP 0x7FF
FWD 0x5CE [8] 32 43 54 65 76 87 98 A9
FWD 0x62F [4] 51 62 73 84
DROP 0x7DF
FWD 0x6F1 [5] 8F A0 B1 C2 D3
FWD 0x752 [1] AE
DROP 0x100
FWD 0x014 [2] EC FD
FWD 0x075 [7] 0B 1C 2D 3E 4F 60 71
DROP 0x7E0
FWD 0x137 [8] 49 5A 6B 7C 8D 9E AF C0
FWD 0x198 [4] 68 79 8A 9B
DROP 0x7FF
FWD 0x25A [5] A6 B7 C8 D9 EA
FWD 0x2BB [1] C5
DROP 0x7DF
FWD 0x37D [2] 03 14
FWD 0x3DE [7] 22 33 44 55 66 77 88
DROP 0x100
FWD 0x4A0 [8] 60 71 82 93 A4 B5 C6 D7
FWD 0x501 [4] 7F 90 A1 B2
DROP 0x7E0
FWD 0x5C3 [5] BD CE DF F0 01
FWD 0x624 [1] DC
DROP 0x7FF
FWD 0x6E6 [2] 1A 2B
FWD 0x747 [7] 39 4A 5B 6C 7D 8E 9F
DROP 0x7DF
FWD 0x009 [8] 77 88 99 AA BB CC DD EE
FWD 0x06A [4] 96 A7 B8 C9
DROP 0x100
FWD 0x12C [5] D4 E5 F6 07 18
FWD 0x18D [1] F3
DROP 0x7E0
FWD 0x24F [2] 31 42
FWD 0x2B0 [7] 50 61 72 83 94 A5 B6
DROP 0x7FF
FWD 0x372 [8] 8E 9F B0 C1 D2 E3 F4 05
FWD 0x3D3 [4] AD BE CF E0
DROP 0x7DF
FWD 0x495 [5] EB FC 0D 1E 2F
FWD 0x4F6 [1] 0A
DROP 0x100
FWD 0x5B8 [2] 48 59
FWD 0x619 [7] 67 78 89 9A AB BC CD
DROP 0x7E0
FWD 0x6DB [8] A5 B6 C7 D8 E9 FA 0B 1C
FWD 0x73C [4] C4 D5 E6 F7
DROP 0x7FF
FWD 0x7FE [5] 02 13 24 35 46
FWD 0x05F [1] 21
DROP 0x7DF
FWD 0x121 [2] 5F 70
FWD 0x182 [7] 7E 8F A0 B1 C2 D3 E4
DROP 0x100
FWD 0x244 [8] BC CD DE EF 00 11 22 33
FWD 0x2A5 [4] DB EC FD 0E
DROP 0x7E0
FWD 0x367 [5] 19 2A 3B 4C 5D
forwarded=133 dropped=67

@@@ hint
`sizeof(struct CanFrame)` is 16, but its members cover only 13 bytes. What is in the other 3 bytes of a `malloc`ed buffer, and what is in them in a `static const` table?
@@@ hint
`memcmp` also compares the padding **and** the data bytes beyond `dlc`, which still hold whatever the previous frame left there. Compare the frame member by member: `id`, `dlc`, then only `dlc` data bytes.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct CanFrame {
    uint32_t id;
    uint8_t  dlc;
    uint8_t  data[8];
};

static const struct CanFrame blocklist[] = {
    { 0x7DF, 2, { 0x3E, 0x00 } },                                     /* functional TesterPresent */
    { 0x100, 8, { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 } }, /* test pattern            */
    { 0x7E0, 3, { 0x22, 0xF1, 0x90 } },                               /* read VIN                */
    { 0x7FF, 0, { 0 } },                                              /* empty frame on 0x7FF    */
};
#define NBLOCK (sizeof blocklist / sizeof blocklist[0])

/* FIX: compare the meaningful members only - never padding, never data beyond dlc */
static int frame_equal(const struct CanFrame *a, const struct CanFrame *b)
{
    return a->id == b->id && a->dlc == b->dlc && memcmp(a->data, b->data, a->dlc) == 0;
}

static int is_blocked(const struct CanFrame *f)
{
    for (size_t i = 0; i < NBLOCK; i++)
        if (frame_equal(f, &blocklist[i]))          /* FIX: was memcmp(f, &blocklist[i], sizeof *f) */
            return 1;
    return 0;
}

int main(void)
{
    int n, fwd = 0, drop = 0;
    if (scanf("%d", &n) != 1) return 0;

    struct CanFrame *rx = malloc(sizeof *rx);    /* driver mailbox, reused for every frame */
    if (rx == NULL) return 1;

    for (int k = 0; k < n; k++) {
        unsigned id;
        int dlc;
        if (scanf("%x %d", &id, &dlc) != 2 || dlc < 0 || dlc > 8) break;
        rx->id = id;
        rx->dlc = (uint8_t)dlc;
        for (int i = 0; i < dlc; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) b = 0;
            rx->data[i] = (uint8_t)b;
        }

        if (is_blocked(rx)) {
            printf("DROP 0x%03X\n", (unsigned)rx->id);
            drop++;
        } else {
            printf("FWD 0x%03X [%d]", (unsigned)rx->id, rx->dlc);
            for (int i = 0; i < rx->dlc; i++) printf(" %02X", (unsigned)rx->data[i]);
            printf("\n");
            fwd++;
        }
    }
    printf("forwarded=%d dropped=%d\n", fwd, drop);
    free(rx);
    return 0;
}
@@@ explanation_md
**Bug.** `memcmp(f, &blocklist[i], sizeof *f)` compares all **16** bytes of the object representation:

| offset | content | rx buffer (malloc, reused) | block-list entry (static) |
|---|---|---|---|
| 0-3 | `id` | set | set |
| 4 | `dlc` | set | set |
| 5..5+dlc-1 | used data | set | set |
| rest of `data` | unused data | **stale bytes from the previous frame / heap fill** | 0 |
| 13-15 | tail padding | **indeterminate (heap fill 0xBE)** | 0 (static objects have zeroed padding) |

Two independent causes make "equal" frames compare unequal:
1. **Padding.** C gives padding bytes unspecified values (C11 6.2.6.1p6). Only objects with static storage duration are guaranteed zero padding. A `malloc`ed buffer, a stack variable or a struct copied member by member can hold anything there.
2. **Bytes beyond `dlc`.** They are not part of the frame, but the reused mailbox still holds the previous frame's payload (test: `100 [8] ...` followed by `7DF [2] 3E 00`).

**Fix.** Compare semantically: `id`, `dlc`, and `memcmp` of exactly `dlc` data bytes.

**Complexity.** O(B * 8) per frame for B block-list entries. Space O(1).

**Common mistakes**
- "Fixing" it with `memset(rx, 0, sizeof *rx)` once after `malloc`. Padding is now zero, but stale data bytes still break the second test, and padding may become non-zero again after any struct assignment.
- Using `calloc` for the same reason. It fixes only the first frame.
- Comparing all 8 data bytes even for shorter frames.
- Using `__attribute__((packed))` to "remove the padding". It hides one cause, does not fix the stale bytes, and makes every access unaligned.

**Interview follow-ups**
- Why does C not provide `==` for structs, while C++20 lets you write `operator== = default`?
- When is `memcmp` on structs safe? (No padding, verified with `_Static_assert(sizeof(T) == sum of members)`, and no floating-point members, where `-0.0 == 0.0` but the bits differ, or `NaN != NaN` while the bytes match.)
- The same padding problem appears when you compute a CRC over a struct or write it to EEPROM. How do you serialize instead?
- Can the padding leak data? (Yes: copying a stack struct to the bus or to user space can expose old stack contents, the classic kernel info-leak.)
