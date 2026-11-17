@@@ meta
id: BIT-H-06
topic: Bit Manipulation
difficulty: Hard
type: CODE
title: CAN Bit Stuffing and Destuffing on a Packed Bit Stream
tags: embedded, can, bit-stuffing, bit-stream, physical-layer, asked-in-automotive
@@@ statement_md
On the CAN bus, edges are needed for resynchronisation, so the transmitter applies **bit stuffing** from SOF to the end of the CRC sequence: after **5 consecutive bits of the same level**, it inserts one bit of the **opposite** level. The receiver removes those stuff bits again. If it sees a 6th identical bit where a stuff bit was expected, it raises a **stuff error**.

Write a tool that stuffs and destuffs a bit stream that is stored **packed in bytes**.

**Bit stream format.** A stream of `n` bits is given as `ceil(n/8)` hex bytes. Bit `i` (in transmission order) is bit `7 - i%8` of byte `i/8`, so the **MSB of byte 0 is sent first**. Unused low bits of the last byte are ignored on input and must be **0** on output.

**Stuffing rules (exactly these):**
- Count runs of equal bits in the **output** stream. A stuff bit counts as the first bit of the next run.
- Right after the 5th equal bit, insert the complement. This also applies if the run of 5 ends with the very last input bit, so a stuff bit is appended.
- Destuffing: after 5 equal bits (stuff bits included), the next bit is a stuff bit and is removed. If it has the **same** level, report `STUFF ERROR at bit i` (`i` = its 0-based index in the stuffed stream). If the stream ends right after 5 equal bits, the stuff bit is missing: report `STUFF ERROR at bit n`.

```
input   : 0 0 0 0 0 1 1 1 1            (9 bits, bytes 07 80)
stuffed : 0 0 0 0 0 [1] 1 1 1 1 [0]    (11 bits, bytes 07 C0, 2 stuff bits)
```
The first stuff bit `1` starts the run of ones, which reaches 5 after only four input ones.

**Input**
- Line 1: `q`.
- Next `q` lines: `S n bytes...` (stuff `n` bits) or `D n bytes...` (destuff `n` bits).

**Output**
- `S`: `len=M stuff=K data=HH HH ...`, where `M` is the stuffed length, `K` the number of stuff bits, and `data` the stuffed stream (`ceil(M/8)` bytes).
- `D`: `len=M data=HH HH ...` with the destuffed stream, or `STUFF ERROR at bit i`.

**Example**
```
Input:
2
S 8 00
D 9 04 00

Output:
len=9 stuff=1 data=04 00
len=8 data=00
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= n <= 512`
- Bytes are uppercase or lowercase hex. Output uses uppercase `%02X`.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

static uint8_t in_buf[64];
static uint8_t out_buf[96];

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        int n;
        if (scanf(" %c %d", &op, &n) != 2) return 0;
        int nbytes = (n + 7) / 8;
        for (int i = 0; i < nbytes; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            in_buf[i] = (uint8_t)b;
        }
        memset(out_buf, 0, sizeof out_buf);

        /* TODO: op == 'S' -> stuff, op == 'D' -> destuff; print the result */
    }
    return 0;
}
@@@ sample_input
2
S 8 00
D 9 04 00
@@@ sample_output
len=9 stuff=1 data=04 00
len=8 data=00

@@@ sample_input
3
S 9 07 80
D 11 07 C0
D 6 FC
@@@ sample_output
len=11 stuff=2 data=07 C0
len=9 data=07 80
STUFF ERROR at bit 5

@@@ hidden_input
5
S 16 FF 00
S 5 F8
S 8 55
S 1 80
S 6 FC
@@@ hidden_output
len=18 stuff=2 data=FB 82 00
len=6 stuff=1 data=F8
len=8 stuff=0 data=55
len=1 stuff=0 data=80
len=7 stuff=1 data=FA

@@@ hidden_input
4
D 5 00
D 6 F8
D 1 00
S 24 00 00 00
@@@ hidden_output
STUFF ERROR at bit 5
len=5 data=F8
len=1 data=00
len=28 stuff=4 data=04 10 41 00

@@@ hidden_input
2
S 19 E4 6C 00
S 40 FF FF FF FF FF
@@@ hidden_output
len=20 stuff=1 data=E4 6C 10
len=48 stuff=8 data=FB EF BE FB EF BE

@@@ hidden_input
1
S 397 00 89 00 5C 00 00 EB 00 FF FF FF 00 F4 00 FF 63 F0 FF EA A2 D0 3E FA 00 FF FF FF FF 00 C3 FF 00 FF B5 00 F0 FF 70 00 9D 05 FF 00 0C 94 FF 98 FF FF 6F
@@@ hidden_output
len=441 stuff=44 data=04 44 82 17 04 10 47 58 23 EF BE FB C1 1E 82 0F BD 8F A1 F7 D5 51 68 2F 9F 20 87 DF 7D F7 DF 60 8C 3E F8 21 F7 B5 04 78 7D DC 10 49 D0 6F BC 10 4C 94 FB CC 7D F7 D6 80

@@@ hidden_input
1
D 441 04 44 82 17 04 10 47 58 23 EF BE FB C1 1E 82 0F BD 8F A1 F7 D5 51 68 2F 9F 20 87 DF 7D F7 DF 60 8C 3E F8 21 F7 B5 04 78 7D DC 10 49 D0 6F BC 10 4C 94 FB CC 7D F7 D6 80
@@@ hidden_output
len=397 data=00 89 00 5C 00 00 EB 00 FF FF FF 00 F4 00 FF 63 F0 FF EA A2 D0 3E FA 00 FF FF FF FF 00 C3 FF 00 FF B5 00 F0 FF 70 00 9D 05 FF 00 0C 94 FF 98 FF FF 68

@@@ hidden_input
1
D 441 04 44 82 17 04 10 47 58 23 EF BE FB C1 1E 82 0F BD 8F A1 F7 D5 51 68 2F 9F 20 87 DF 7D F7 DF 60 0C 3E F8 21 F7 B5 04 78 7D DC 10 49 D0 6F BC 10 4C 94 FB CC 7D F7 D6 80
@@@ hidden_output
STUFF ERROR at bit 256

@@@ hidden_input
2
S 200 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
D 239 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 40
@@@ hidden_output
len=240 stuff=40 data=04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41 04 10 41
STUFF ERROR at bit 239

@@@ hint
Write two tiny helpers first: `get_bit(buf, i)` = `(buf[i >> 3] >> (7 - (i & 7))) & 1` and `put_bit(buf, i, b)`, which ORs `b << (7 - (i & 7))` into a zeroed buffer. Then the problem is a simple run-length state machine over bits.
@@@ hint
Keep `run_bit` and `run_len` for the **output** (stuffed) stream. When stuffing: emit the bit, update the run, and if `run_len == 5`, emit `!bit` and reset the run to (`!bit`, 1). When destuffing: if `run_len == 5`, the current bit must differ (skip it and restart the run with it) or it is an error. After the loop, `run_len == 5` means the final stuff bit is missing.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

static uint8_t in_buf[64];
static uint8_t out_buf[96];

static int get_bit(const uint8_t *buf, int i)
{
    return (buf[i >> 3] >> (7 - (i & 7))) & 1;          /* MSB of byte 0 first */
}

static void put_bit(uint8_t *buf, int i, int b)
{
    if (b) buf[i >> 3] |= (uint8_t)(0x80u >> (i & 7));  /* buffer is pre-zeroed */
}

static void print_bytes(int nbits)
{
    int nbytes = (nbits + 7) / 8;
    printf(" data=");
    for (int i = 0; i < nbytes; i++)
        printf("%02X%s", out_buf[i], i + 1 < nbytes ? " " : "\n");
}

static void do_stuff(int n)
{
    int m = 0, stuffed = 0, run_bit = -1, run_len = 0;
    for (int i = 0; i < n; i++) {
        int b = get_bit(in_buf, i);
        put_bit(out_buf, m++, b);
        if (b == run_bit) run_len++;
        else { run_bit = b; run_len = 1; }
        if (run_len == 5) {                              /* insert complement */
            put_bit(out_buf, m++, !b);
            stuffed++;
            run_bit = !b;                                /* stuff bit starts the next run */
            run_len = 1;
        }
    }
    printf("len=%d stuff=%d", m, stuffed);
    print_bytes(m);
}

static void do_destuff(int n)
{
    int m = 0, run_bit = -1, run_len = 0;
    for (int i = 0; i < n; i++) {
        int b = get_bit(in_buf, i);
        if (run_len == 5) {                              /* this must be a stuff bit */
            if (b == run_bit) {
                printf("STUFF ERROR at bit %d\n", i);
                return;
            }
            run_bit = b;                                 /* dropped, but starts a run */
            run_len = 1;
            continue;
        }
        put_bit(out_buf, m++, b);
        if (b == run_bit) run_len++;
        else { run_bit = b; run_len = 1; }
    }
    if (run_len == 5) {                                  /* stream ended where a stuff bit was due */
        printf("STUFF ERROR at bit %d\n", n);
        return;
    }
    printf("len=%d", m);
    print_bytes(m);
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        int n;
        if (scanf(" %c %d", &op, &n) != 2 || n < 1 || n > 512) return 0;
        int nbytes = (n + 7) / 8;
        for (int i = 0; i < nbytes; i++) {
            unsigned b;
            if (scanf("%x", &b) != 1) return 0;
            in_buf[i] = (uint8_t)b;
        }
        memset(out_buf, 0, sizeof out_buf);
        if (op == 'S')
            do_stuff(n);
        else
            do_destuff(n);
    }
    return 0;
}
@@@ explanation_md
**Approach.** Two layers:

1. **Bit I/O on packed bytes.** Bit `i` lives in byte `i >> 3` at mask `0x80 >> (i & 7)` (MSB first, the order CAN transmits). Reading is shift-and-mask. Writing ORs into a zeroed output buffer, which also leaves the padding bits of the last byte at 0.
2. **A run-length state machine** over the *output* stream (stuffing) or the *input* stream (destuffing), with `run_bit` and `run_len`.

```
input   0 0 0 0 0 | 1 1 1 1
emit    0 0 0 0 0 [1]            run(0)=5 -> stuff 1, run = (1, 1)
        1 1 1 1 [0]              run(1)=2,3,4,5 -> stuff 0
```

The subtle rule is that a **stuff bit belongs to the next run**. Because of it, `00000 1111` needs two stuff bits even though the input has no run of five ones. The destuffer mirrors the rule exactly: after five equal bits it *expects* a complement, drops it, and restarts the run with it.

**Complexity.** O(n) time for both directions. O(n) space for the packed output (at most `n + n/4 + 1` bits).

**Common mistakes**
- Resetting the run to length 0 after a stuff bit instead of counting the stuff bit as length 1. Streams like `00000 1111` then come out wrong.
- Counting runs in the **input** instead of the output while stuffing.
- Not appending a stuff bit when the 5-bit run ends at the last bit, or not detecting the missing stuff bit at the end when destuffing.
- Leaving garbage in the padding bits of the last output byte (`memset` the buffer, or mask the last byte).
- Using LSB-first bit order inside a byte. CAN sends the MSB of each field first.

**Interview follow-ups**
- What is the worst-case length of a stuffed classic CAN frame with 8 data bytes, and why does that matter for bus-load and latency calculations?
- Which CAN fields are **not** stuffed (CRC delimiter, ACK, EOF), and why are 6 dominant bits used deliberately for an error flag?
- CAN FD uses **fixed stuff bits** in the CRC field and a stuff-bit counter. What problem with classic CAN's dynamic stuffing did that fix?
- Implement the bit reader as a streaming "get next bit" function over a ring buffer of received bytes, as in a bit-banged software CAN/UART.
