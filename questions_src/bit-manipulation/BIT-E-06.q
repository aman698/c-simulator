@@@ meta
id: BIT-E-06
topic: Bit Manipulation
difficulty: Easy
type: FUNCTION
title: Gray Code Encode and Decode for an Absolute Encoder
tags: embedded, gray-code, xor, rotary-encoder, sensors
@@@ statement_md
An absolute rotary encoder on a steering column outputs its position in **Gray code**: consecutive positions differ in exactly **one** bit. This means a reading taken while the shaft moves is never off by more than one step. The ECU must convert the Gray reading to a binary position. The end-of-line tester needs the opposite conversion.

Implement both directions for 32-bit values:

```c
uint32_t bin_to_gray(uint32_t b);   /* reflected binary Gray code: g = b ^ (b >> 1) */
uint32_t gray_to_bin(uint32_t g);   /* inverse: gray_to_bin(bin_to_gray(b)) == b    */
```

| binary | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Gray | 000 | 001 | 011 | 010 | 110 | 111 | 101 | 100 |

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines, one of:
  - `G v`: print `bin_to_gray(v)` as `%08X`.
  - `B g`: print `gray_to_bin(g)` as `%08X`.
  - `R start count`: for `count` consecutive values `v = start, start+1, ...` (wrapping modulo 2^32), check that `gray_to_bin(bin_to_gray(v)) == v` and that `bin_to_gray(v)` and `bin_to_gray(v+1)` differ in exactly one bit. Prints `range ok` or `FAIL at XXXXXXXX`.

All numbers are hex except `count` (decimal).

**Example**
```
Input:
3
G 00000002
B 00000004
R 00000000 16

Output:
00000003
00000007
range ok
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= count <= 100000`
- All values are 32-bit unsigned.
@@@ starter_code
#include <stdint.h>

uint32_t bin_to_gray(uint32_t b)
{
    /* TODO */
    return b;
}

uint32_t gray_to_bin(uint32_t g)
{
    /* TODO */
    return g;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

/*USER_CODE*/

static int one_bit(uint32_t x)
{
    return x != 0u && (x & (x - 1u)) == 0u;
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        unsigned v;
        if (scanf(" %c %x", &op, &v) != 2) return 0;
        if (op == 'G') {
            printf("%08X\n", (unsigned)bin_to_gray(v));
        } else if (op == 'B') {
            printf("%08X\n", (unsigned)gray_to_bin(v));
        } else {
            int count;
            if (scanf("%d", &count) != 1) return 0;
            uint32_t x = v;
            int ok = 1;
            for (int k = 0; k < count && ok; k++, x++) {
                uint32_t g0 = bin_to_gray(x), g1 = bin_to_gray(x + 1u);
                if (gray_to_bin(g0) != x || !one_bit(g0 ^ g1)) {
                    printf("FAIL at %08X\n", (unsigned)x);
                    ok = 0;
                }
            }
            if (ok) printf("range ok\n");
        }
    }
    return 0;
}
@@@ sample_input
3
G 00000002
B 00000004
R 00000000 16
@@@ sample_output
00000003
00000007
range ok

@@@ sample_input
4
G 00000007
G 00000008
B 0000000C
B 00000003
@@@ sample_output
00000004
0000000C
00000008
00000002

@@@ hidden_input
4
G 00000000
B 00000000
G 00000001
B 00000001
@@@ hidden_output
00000000
00000000
00000001
00000001

@@@ hidden_input
4
G FFFFFFFF
G 80000000
B 80000000
B C0000000
@@@ hidden_output
80000000
C0000000
FFFFFFFF
80000000

@@@ hidden_input
4
B 00000200
G 000003FF
B 000002A5
G 000002D5
@@@ hidden_output
000003FF
00000200
00000339
000003BF

@@@ hidden_input
4
G 12345678
B 12345678
G DEADBEEF
B FFFFFFFF
@@@ hidden_output
1B2E7D44
1C279BAF
B1FB6198
AAAAAAAA

@@@ hidden_input
2
R FFFFFF00 300
R 7FFFFF80 256
@@@ hidden_output
range ok
range ok

@@@ hidden_input
3
R 12340000 100000
B 0000001E
B 5555AAAA
@@@ hidden_output
range ok
00000014
6666CCCC

@@@ hint
Encoding is one line: each Gray bit is the XOR of a binary bit and its left neighbour, `b ^ (b >> 1)`. Decoding goes the other way: binary bit `i` is the XOR of **all** Gray bits from the MSB down to bit `i`.
@@@ hint
A loop works: `b = g; while (g >>= 1) b ^= g;`. In O(log 32) steps you can do the same prefix-XOR: `g ^= g >> 16; g ^= g >> 8; g ^= g >> 4; g ^= g >> 2; g ^= g >> 1;`.
@@@ solution_code
#include <stdint.h>

uint32_t bin_to_gray(uint32_t b)
{
    return b ^ (b >> 1);
}

uint32_t gray_to_bin(uint32_t g)
{
    /* prefix XOR from the MSB downwards, in 5 doubling steps */
    g ^= g >> 16;
    g ^= g >> 8;
    g ^= g >> 4;
    g ^= g >> 2;
    g ^= g >> 1;
    return g;
}
@@@ explanation_md
**Approach.**
- **Encode:** `g = b ^ (b >> 1)`. Incrementing `b` flips a block of trailing bits `0111 -> 1000`. In Gray code, all but one of those flips cancel against the neighbouring bit, so exactly one Gray bit changes per step.
- **Decode:** inverting the XOR means `b[i] = g[31] ^ g[30] ^ ... ^ g[i]`, a prefix XOR from the MSB. You can loop over the bits, or do it in 5 steps: after `g ^= g >> 16`, each bit holds the XOR of itself and the bit 16 above. After `>> 8, 4, 2, 1`, each bit holds the XOR of everything above it.

```
g = 0x1E = 11110
b4 = 1
b3 = 1^1 = 0
b2 = 0^1 = 1
b1 = 1^1 = 0
b0 = 0^0 = 0      -> b = 10100 = 0x14
```

**Complexity.** Encode is O(1). Decode is O(log w) with doubling shifts (5 steps for 32 bits), or O(w) with a simple loop. Space is O(1).

**Common mistakes**
- Decoding with the encode formula (`g ^ (g >> 1)`). Gray-to-binary is **not** self-inverse.
- Decoding by XOR-ing only adjacent bits instead of the full prefix. Bit `i` depends on **all** higher Gray bits.
- Using a signed `int`: `>>` on a negative value is arithmetic in gcc, so the sign bit smears into the result. Keep everything `uint32_t`.
- Forgetting the wrap-around property. Gray code is cyclic, so `0xFFFFFFFF -> 0x80000000` and `0 -> 0` also differ in one bit (the harness checks it).

**Interview follow-ups**
- Why does a mechanical encoder that outputs plain binary produce glitches like `0111 -> 1111 -> 1000` at a transition, and how does Gray code fix this?
- Your encoder has **10** bits. What changes in decode? (Nothing, if the upper bits are 0. Mask with `0x3FF` if they are not.)
- How is Gray code used for **asynchronous FIFO** pointers crossing clock domains in an FPGA or SoC?
- Decode a **quadrature** (incremental A/B) encoder with a 4x4 state table indexed by `(old << 2) | new`.
