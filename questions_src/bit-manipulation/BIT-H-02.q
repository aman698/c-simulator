@@@ meta
id: BIT-H-02
topic: Bit Manipulation
difficulty: Hard
type: FUNCTION
title: Pack a CAN Signal Into a Payload (Intel and Motorola)
tags: embedded, can, dbc, signal-packing, read-modify-write, endianness, asked-in-automotive
@@@ statement_md
The transmit side of a COM stack writes each signal into the 8-byte CAN payload **without disturbing the other signals** already packed there. Implement:

```c
void can_set_raw(uint8_t payload[8], unsigned start_bit, unsigned length, int motorola, uint64_t value);
```

It writes the **low `length` bits** of `value` into the signal's bit positions and leaves every other payload bit unchanged. Bits of `value` above `length` are ignored. Signed signals arrive as two's complement, so `-442` in a 10-bit signal is written as `0x246`.

**Bit numbering (DBC).** Payload bit `k` is bit `k % 8` of byte `k / 8` (byte 0 holds bits 7..0, byte 1 holds bits 15..8, ..., byte 7 holds bits 63..56).

- **Intel (`@1`, little-endian):** `start_bit` = position of the **LSB**. Signal bit `i` goes to payload bit `start_bit + i` (upward, into the next byte's bit 0).
- **Motorola (`@0`, big-endian, sawtooth):** `start_bit` = position of the **MSB**. Going toward the LSB, the next position is `k - 1`, except after bit 0 of a byte, where it continues at bit 7 of the **next** byte (`k + 15`).

```
Motorola, start 4, length 10, value 0x246 (= -442):
MSB-first positions:  4  3  2  1  0 | 15 14 13 12 11
value bits:           1  0  0  1  0 |  0  0  1  1  0
payload FF FF ...  -> F2 37 FF FF FF FF FF FF
```

**Input (read by the hidden harness)**
- Line 1: the initial 8 payload bytes (hex).
- Line 2: `q`.
- Next `q` lines: `I start length value` or `M start length value`, where `value` is a signed decimal (`long long`). The harness passes `(uint64_t)value`.

**Output**
- After each command, the 8 payload bytes as `%02X`, separated by spaces. The harness also checks that you never write outside `payload[0..7]`.

**Example**
```
Input:
FF FF FF FF FF FF FF FF
2
M 4 10 -442
I 63 1 0

Output:
F2 37 FF FF FF FF FF FF
F2 37 FF FF FF FF FF 7F
```
@@@ constraints_md
- `1 <= length <= 64`, `0 <= start_bit <= 63`, `1 <= q <= 20`
- Every signal fits inside the 8 bytes.
- No undefined behavior (no shift by 64, no signed overflow).
@@@ starter_code
#include <stdint.h>

void can_set_raw(uint8_t payload[8], unsigned start_bit, unsigned length, int motorola, uint64_t value)
{
    /* TODO: write the low `length` bits of value; keep all other bits */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

#define GUARD 8
#define CANARY 0x5Au

int main(void)
{
    uint8_t arena[GUARD + 8 + GUARD];
    for (int i = 0; i < (int)sizeof arena; i++) arena[i] = CANARY;
    uint8_t *payload = arena + GUARD;
    for (int i = 0; i < 8; i++) {
        unsigned b;
        if (scanf("%x", &b) != 1) return 0;
        payload[i] = (uint8_t)b;
    }
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        unsigned start, len;
        long long v;
        if (scanf(" %c %u %u %lld", &op, &start, &len, &v) != 4) return 0;
        can_set_raw(payload, start, len, op == 'M', (uint64_t)v);
        for (int i = 0; i < GUARD; i++) {
            if (arena[i] != CANARY || payload[8 + i] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        for (int i = 0; i < 8; i++) printf("%02X%c", payload[i], i == 7 ? '\n' : ' ');
    }
    return 0;
}
@@@ sample_input
FF FF FF FF FF FF FF FF
2
M 4 10 -442
I 63 1 0
@@@ sample_output
F2 37 FF FF FF FF FF FF
F2 37 FF FF FF FF FF 7F

@@@ sample_input
00 00 00 00 00 00 00 00
3
I 0 16 4660
M 23 16 4660
I 36 8 -1
@@@ sample_output
34 12 00 00 00 00 00 00
34 12 12 34 00 00 00 00
34 12 12 34 F0 0F 00 00

@@@ hidden_input
00 00 00 00 00 00 00 00
3
I 4 4 255
M 11 2 7
I 62 2 -2
@@@ hidden_output
F0 00 00 00 00 00 00 00
F0 0C 00 00 00 00 00 00
F0 0C 00 00 00 00 00 80

@@@ hidden_input
00 00 00 00 00 00 00 00
3
I 0 64 -1
M 7 64 81985529216486895
I 0 64 81985529216486895
@@@ hidden_output
FF FF FF FF FF FF FF FF
01 23 45 67 89 AB CD EF
EF CD AB 89 67 45 23 01

@@@ hidden_input
A5 5A F0 0F 81 18 7E E7
3
M 3 20 0
I 30 31 305419896
M 0 1 0
@@@ hidden_output
A0 00 00 0F 81 18 7E E7
A0 00 00 0F 9E 15 8D E4
A0 00 00 0F 9E 15 8D E4

@@@ hidden_input
11 22 33 44 55 66 77 88
3
M 39 32 -1985229329
I 8 12 -200
M 16 9 -153
@@@ hidden_output
11 22 33 44 89 AB CD EF
11 38 3F 44 89 AB CD EF
11 38 3F 67 89 AB CD EF

@@@ hidden_input
00 00 00 00 00 00 00 00
3
I 3 33 -3541523360
M 55 16 32487
I 13 6 -32
@@@ hidden_output
00 23 45 67 09 00 00 00
00 23 45 67 09 00 7E E7
00 03 44 67 09 00 7E E7

@@@ hint
A pack is a read-modify-write on a 64-bit word: load the payload into a `uint64_t`, clear the signal's bits with `& ~(mask << shift)`, OR in `(value & mask) << shift`, and store the word back **in the same byte order** you loaded it.
@@@ hint
For Intel, load little-endian and use `shift = start_bit`. For Motorola, load big-endian (byte 0 = most significant byte): the sawtooth becomes contiguous, the MSB sits at `msb = (7 - start/8)*8 + start%8`, and `shift = msb - length + 1`. The mask for `length == 64` is `~0ull`, not `(1ull << 64) - 1`.
@@@ solution_code
#include <stdint.h>

static uint64_t mask_of(unsigned length)
{
    return length >= 64u ? ~(uint64_t)0 : (((uint64_t)1 << length) - 1u);
}

void can_set_raw(uint8_t payload[8], unsigned start_bit, unsigned length, int motorola, uint64_t value)
{
    uint64_t m = mask_of(length);
    uint64_t word = 0;
    unsigned shift;

    if (!motorola) {
        for (int i = 7; i >= 0; i--) word = (word << 8) | payload[i];   /* little-endian */
        shift = start_bit;
    } else {
        for (int i = 0; i < 8; i++) word = (word << 8) | payload[i];    /* big-endian */
        unsigned msb = (7u - start_bit / 8u) * 8u + start_bit % 8u;
        shift = msb + 1u - length;
    }

    /* read-modify-write: clear the field, insert the truncated value */
    word = (word & ~(m << shift)) | ((value & m) << shift);

    if (!motorola) {
        for (int i = 0; i < 8; i++) { payload[i] = (uint8_t)word; word >>= 8; }
    } else {
        for (int i = 7; i >= 0; i--) { payload[i] = (uint8_t)word; word >>= 8; }
    }
}
@@@ explanation_md
**Approach.** Packing is the mirror image of unpacking, plus a read-modify-write:

1. Load the payload into a 64-bit word: **little-endian** for Intel, **big-endian** for Motorola. In the big-endian view, the Motorola sawtooth is a contiguous bit run whose MSB is at `(7 - start/8)*8 + start%8`.
2. `shift` = position of the signal's LSB in that word (`start` for Intel, `msb - length + 1` for Motorola).
3. `word = (word & ~(mask << shift)) | ((value & mask) << shift)`. The `& mask` truncates the value (and so turns a negative number into its two's complement field). Clearing first keeps every neighbouring signal intact.
4. Store the word back in the same byte order.

```
Intel start 8, length 12, value -200
-200 & 0xFFF = 0xF38;  payload 11 22 33 ... ->  11 38 3F ...
(byte 1 = 0x38, byte 2 low nibble = 0xF, byte 2 high nibble 0x3 is kept)
```

A bit-by-bit walk is an equally valid solution, and it is how the expected outputs were cross-checked. It writes `value` bit `i` to position `start + i` (Intel), or walks from the MSB with `k-1` / `k+15` (Motorola).

**Complexity.** O(1): 8 loads, a few ALU operations and 8 stores per signal, O(1) space. The bit walk is O(length).

**Common mistakes**
- OR-ing the value in without clearing the field first. The old bits survive (see `M 3 20 0`, which must **clear** 20 bits).
- Not masking `value`. A negative `int64_t` has ones in all 64 bits and would overwrite every signal above the field.
- Storing the word back in the wrong byte order, or writing all 8 bytes when only some changed while another task updates the same frame buffer (a race in the COM layer).
- `mask << shift` computed in 32 bits (`0xFFFu << 40` is UB). Keep everything in `uint64_t`.
- For Motorola, computing the LSB by "counting down" `start - length + 1` in payload numbering. That ignores the sawtooth jump at byte boundaries.

**Interview follow-ups**
- How would a code generator (AUTOSAR COM, or a DBC-to-C tool) emit **constant** shifts and masks per signal instead of calling a generic function?
- The TX buffer is shared with the CAN driver ISR. How do you make the update of a multi-signal frame consistent (shadow buffer, signal groups, disabling the TX mailbox)?
- Add range checking: reject (or saturate) a physical value that does not fit in the signal after `raw = (phys - offset) / factor`.
- What is a **multiplexed** signal in a DBC (`m` / `M` multiplexor indicator), and how does it change packing?
