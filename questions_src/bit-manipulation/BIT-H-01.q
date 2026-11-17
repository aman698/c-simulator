@@@ meta
id: BIT-H-01
topic: Bit Manipulation
difficulty: Hard
type: FUNCTION
title: Unpack a CAN Signal (Intel and Motorola Byte Order)
tags: embedded, can, dbc, signal-unpacking, endianness, sign-extension, asked-in-automotive
@@@ statement_md
A CAN database (DBC) describes every signal in an 8-byte payload by a **start bit**, a **length** and a **byte order**. Implement the decoder that a generated COM stack would call:

```c
uint64_t can_get_raw(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola);
int64_t  can_get_signed(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola);
```

`can_get_raw` returns the unsigned raw value. `can_get_signed` interprets the same `length` bits as two's complement.

**Bit numbering (both byte orders).** Payload bit `k` is bit `k % 8` of byte `k / 8`:

```
            bit7 bit6 bit5 bit4 bit3 bit2 bit1 bit0
byte 0:       7    6    5    4    3    2    1    0
byte 1:      15   14   13   12   11   10    9    8
byte 2:      23   22   21   20   19   18   17   16
 ...
byte 7:      63   62   61   60   59   58   57   56
```

**Intel (little-endian, DBC `@1`).** `start_bit` is the position of the signal's **LSB**. Signal bit `i` is payload bit `start_bit + i`, so the signal grows toward higher bit numbers and into the **next** byte's bit 0.
*Example:* start 12, length 8 → bits 12..15 (byte 1, upper nibble) are the low nibble, bits 16..19 (byte 2, lower nibble) are the high nibble.

**Motorola (big-endian, DBC `@0`, "sawtooth").** `start_bit` is the position of the signal's **MSB**. Moving toward the LSB, go down within the byte (`k-1`). After bit 0 of a byte, continue at bit 7 of the **next** byte (`k+15`).
*Example:* start 4, length 10 → MSB-first bits `4 3 2 1 0 | 15 14 13 12 11`.

With payload `12 34 56 78 9A BC DE F0`:

| order | start | length | bits used (MSB → LSB) | raw |
|---|---|---|---|---|
| Intel | 0 | 16 | 15..8, 7..0 | `0x3412` |
| Intel | 12 | 8 | 19..16, 15..12 | `0x63` |
| Motorola | 7 | 16 | 7..0, 15..8 | `0x1234` |
| Motorola | 4 | 10 | 4..0, 15..11 | `0x246` (signed: -442) |

**Input (read by the hidden harness)**
- Line 1: the 8 payload bytes in hex.
- Line 2: `q`.
- Next `q` lines: `I start length` (Intel) or `M start length` (Motorola).

**Output**
- Per query: `raw=0x<hex> signed=<decimal>`, printed with `%llX` / `%lld`.

**Example**
```
Input:
12 34 56 78 9A BC DE F0
4
I 0 16
I 12 8
M 7 16
M 4 10

Output:
raw=0x3412 signed=13330
raw=0x63 signed=99
raw=0x1234 signed=4660
raw=0x246 signed=-442
```
@@@ constraints_md
- `1 <= length <= 64`, `0 <= start_bit <= 63`, `1 <= q <= 20`
- Every queried signal fits inside the 8-byte payload (no bit outside 0..63 is touched).
- No undefined behavior: shifting a 64-bit value by 64 is UB, just like shifting a 32-bit value by 32.
@@@ starter_code
#include <stdint.h>

uint64_t can_get_raw(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola)
{
    /* TODO */
    return 0;
}

int64_t can_get_signed(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola)
{
    /* TODO: sign-extend the `length`-bit raw value */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/*USER_CODE*/

int main(void)
{
    uint8_t payload[8], copy[8];
    for (int i = 0; i < 8; i++) {
        unsigned b;
        if (scanf("%x", &b) != 1) return 0;
        payload[i] = (uint8_t)b;
    }
    memcpy(copy, payload, sizeof copy);
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int k = 0; k < q; k++) {
        char op;
        unsigned start, len;
        if (scanf(" %c %u %u", &op, &start, &len) != 3) return 0;
        int mot = (op == 'M');
        uint64_t raw = can_get_raw(payload, start, len, mot);
        int64_t sv = can_get_signed(payload, start, len, mot);
        printf("raw=0x%llX signed=%lld\n", (unsigned long long)raw, (long long)sv);
        if (memcmp(copy, payload, sizeof copy) != 0) {
            printf("PAYLOAD MODIFIED\n");
            return 0;
        }
    }
    return 0;
}
@@@ sample_input
12 34 56 78 9A BC DE F0
4
I 0 16
I 12 8
M 7 16
M 4 10
@@@ sample_output
raw=0x3412 signed=13330
raw=0x63 signed=99
raw=0x1234 signed=4660
raw=0x246 signed=-442

@@@ sample_input
FF 00 00 00 00 00 00 80
5
I 63 1
I 0 8
M 7 8
M 15 8
M 0 1
@@@ sample_output
raw=0x1 signed=-1
raw=0xFF signed=-1
raw=0xFF signed=-1
raw=0x0 signed=0
raw=0x1 signed=-1

@@@ hidden_input
FF FF FF FF FF FF FF FF
4
I 0 64
M 7 64
I 5 3
M 58 3
@@@ hidden_output
raw=0xFFFFFFFFFFFFFFFF signed=-1
raw=0xFFFFFFFFFFFFFFFF signed=-1
raw=0x7 signed=-1
raw=0x7 signed=-1

@@@ hidden_input
01 23 45 67 89 AB CD EF
2
I 0 64
M 7 64
@@@ hidden_output
raw=0xEFCDAB8967452301 signed=-1167088121787636991
raw=0x123456789ABCDEF signed=81985529216486895

@@@ hidden_input
01 23 45 67 89 AB CD EF
4
I 3 33
M 16 9
M 39 32
I 60 4
@@@ hidden_output
raw=0x12CE8A460 signed=-3541523360
raw=0x167 signed=-153
raw=0x89ABCDEF signed=-1985229329
raw=0xE signed=-2

@@@ hidden_input
00 38 0F 00 00 00 00 00
4
I 8 12
M 23 12
M 11 12
I 15 2
@@@ hidden_output
raw=0xF38 signed=-200
raw=0xF0 signed=240
raw=0x80F signed=-2033
raw=0x2 signed=-2

@@@ hidden_input
A5 5A F0 0F 81 18 7E E7
6
M 0 1
M 63 1
I 4 20
M 3 20
M 55 16
I 30 31
@@@ hidden_output
raw=0x1 signed=-1
raw=0x1 signed=-1
raw=0xF05AA signed=-64086
raw=0x55AF0 signed=350960
raw=0x7EE7 signed=32487
raw=0x1DF86204 signed=502817284

@@@ hint
Load all 8 bytes into one `uint64_t` twice. As a **little-endian** word (byte 0 = bits 0..7), an Intel signal is just `(word >> start) & mask`. As a **big-endian** word (byte 0 = bits 56..63), the Motorola sawtooth becomes a contiguous run of bits. Where does payload bit `k` land in that word?
@@@ hint
In the big-endian word, payload bit `k` sits at position `(7 - k/8) * 8 + k % 8`. That is the signal's MSB, so its LSB is `msb - length + 1`. Build the mask without shifting by 64 (`length == 64 ? ~0ull : (1ull << length) - 1`), and sign-extend with the sign bit `1ull << (length - 1)`.
@@@ solution_code
#include <stdint.h>

static uint64_t mask_of(unsigned length)
{
    return length >= 64u ? ~(uint64_t)0 : (((uint64_t)1 << length) - 1u);
}

uint64_t can_get_raw(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola)
{
    uint64_t word = 0;
    if (!motorola) {
        /* little-endian word: payload bit k is word bit k */
        for (int i = 7; i >= 0; i--)
            word = (word << 8) | payload[i];
        return (word >> start_bit) & mask_of(length);
    }
    /* big-endian word: byte 0 is the most significant byte.
       payload bit k lands at (7 - k/8)*8 + k%8, and the sawtooth is contiguous here */
    for (int i = 0; i < 8; i++)
        word = (word << 8) | payload[i];
    unsigned msb = (7u - start_bit / 8u) * 8u + start_bit % 8u;
    unsigned lsb = msb + 1u - length;                 /* valid layouts guarantee msb >= length - 1 */
    return (word >> lsb) & mask_of(length);
}

int64_t can_get_signed(const uint8_t payload[8], unsigned start_bit, unsigned length, int motorola)
{
    uint64_t raw = can_get_raw(payload, start_bit, length, motorola);
    uint64_t m = mask_of(length);
    if (((raw >> (length - 1u)) & 1u) == 0u)
        return (int64_t)raw;                          /* non-negative: fits */
    return -(int64_t)(~raw & m) - 1;                  /* -(magnitude) without overflow */
}
@@@ explanation_md
**Approach: turn the payload into one 64-bit word, then shift and mask.**

- **Intel.** Assemble the bytes little-endian (`payload[0]` in bits 0..7). DBC Intel numbering then matches the word's bit numbering exactly: `raw = (word >> start) & mask(length)`.
- **Motorola.** Assemble the bytes big-endian (`payload[0]` in bits 56..63). In that word the sawtooth disappears: bit 0 of byte `n` is immediately followed (toward the LSB) by bit 7 of byte `n+1`, so a Motorola signal is a **contiguous** run. Payload bit `k` is word bit `(7 - k/8)*8 + k%8`. That gives the MSB position, so `lsb = msb - length + 1` and `raw = (word >> lsb) & mask`.

```
Motorola start 4, length 10, payload 12 34 ...
big-endian word = 0x1234...;  msb = 7*8 + 4 = 60, lsb = 51
(word >> 51) & 0x3FF = 0x246 = 10 0100 0110
sign bit (bit 9) = 1 -> 0x246 - 0x400 = -442
```

- **Signed.** Check bit `length - 1`. If it is set, return `-((~raw & mask) + 1)`, written as `-(int64_t)(~raw & mask) - 1`. This never overflows, even for a 64-bit signal equal to `INT64_MIN`. There is no implementation-defined conversion either.
- **Full width.** `1ull << 64` is UB (C11 6.5.7p3), so the mask function special-cases `length == 64`.

**Complexity.** O(1): 8 byte loads plus a few shifts per signal, O(1) space. A bit-by-bit walk (follow `k+1` for Intel, and `k-1` or `k+15` for Motorola) is O(length) and is a good way to cross-check.

**Common mistakes**
- Treating the Motorola start bit as the **LSB**. Some tools (for example, the CANdb++ GUI in "Motorola LSB" mode) display it that way, but the DBC file stores the MSB in sawtooth numbering.
- Walking Motorola bits as `k-1` across byte boundaries (bit 8 → bit 7). The next bit after a byte's bit 0 is bit 7 of the **next** byte, `k+15`.
- Assembling the word with `payload[i] << 56` without a cast. That is an `int` shift by 56, which is UB.
- Using `uint32_t` intermediates. Signals longer than 32 bits, or Intel signals that start above bit 31, lose bits (the `I 3 33` and `I 60 4` tests).
- Sign-extending with `(int64_t)(raw << (64 - length)) >> (64 - length)`, which is a shift by 64 for `length == 64` and implementation-defined otherwise.

**Interview follow-ups**
- Add the physical conversion `phys = raw * factor + offset` from the DBC. How do you avoid floating point on an MCU without an FPU (fixed-point scaling)?
- How would you validate a DBC layout (signal fits, no overlapping signals) at generation time instead of at run time?
- What changes for CAN FD payloads of up to 64 bytes? Can you still use a single 64-bit word?
- AUTOSAR COM uses "signal groups" and update bits. How would you extract a whole signal group atomically while the CAN RX ISR may overwrite the buffer?
