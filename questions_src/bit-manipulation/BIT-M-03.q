@@@ meta
id: BIT-M-03
topic: Bit Manipulation
difficulty: Medium
type: FUNCTION
title: Parity by XOR Folding and the LIN Protected Identifier
tags: embedded, parity, xor-folding, lin-bus, uint64, asked-in-automotive
@@@ statement_md
Parity bits protect UART bytes, memory words and bus identifiers. A word has **odd parity** if it has an odd number of 1-bits.

Implement:

```c
int     parity32(uint32_t x);   /* 1 if x has an odd number of 1-bits, else 0 */
int     parity64(uint64_t x);   /* same for 64 bits                            */
uint8_t lin_pid(uint8_t id);    /* LIN protected identifier of a 6-bit frame ID */
```

`parity32`/`parity64` must run in **O(log w)** steps by XOR folding, without looping over every bit. `__builtin_parity*` and `__builtin_popcount*` are not allowed.

**LIN protected identifier (LIN 2.x).** A LIN header carries a 6-bit frame ID (`ID0..ID5`, bits 0..5) plus two parity bits:
- `P0` (bit 6) = `ID0 ^ ID1 ^ ID2 ^ ID4` (even parity over those bits)
- `P1` (bit 7) = `!(ID1 ^ ID3 ^ ID4 ^ ID5)` (odd parity, so that the PID is never `0x00`)

For example, `lin_pid(0x3C)` = `0x3C` (the master-request diagnostic frame) and `lin_pid(0x00)` = `0x80`.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines:
  - `P x` (32-bit hex): print `parity32(x)`.
  - `Q x` (64-bit hex): print `parity64(x)`.
  - `I id` (decimal, `0..63`): print `lin_pid(id)` as `%02X`.
  - `R seed n`: the harness draws `n` pairs `a, b` from the LCG `s = s * 1103515245u + 12345u` and prints `odd32=X odd64=Y`, where X counts `parity32(a) == 1` and Y counts `parity64(((uint64_t)a << 32) | b) == 1`.

**Example**
```
Input:
4
P 00000003
P 80000000
Q 8000000000000000
I 61

Output:
0
1
1
7D
```
@@@ constraints_md
- `1 <= q <= 20`, `1 <= n <= 100000`, `0 <= id <= 63`
- No `__builtin_parity`, `__builtin_parityll`, `__builtin_popcount`, `__builtin_popcountll`.
@@@ starter_code
#include <stdint.h>

int parity32(uint32_t x)
{
    /* TODO: XOR folding */
    return 0;
}

int parity64(uint64_t x)
{
    /* TODO */
    return 0;
}

uint8_t lin_pid(uint8_t id)
{
    /* TODO: P0 = ID0^ID1^ID2^ID4 (bit 6), P1 = !(ID1^ID3^ID4^ID5) (bit 7) */
    return id;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

#define __builtin_parity(x) builtin_parity_is_not_allowed
#define __builtin_parityll(x) builtin_parity_is_not_allowed
#define __builtin_popcount(x) builtin_popcount_is_not_allowed
#define __builtin_popcountll(x) builtin_popcount_is_not_allowed

/*USER_CODE*/

#undef __builtin_parity
#undef __builtin_parityll
#undef __builtin_popcount
#undef __builtin_popcountll

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'P') {
            unsigned x;
            if (scanf("%x", &x) != 1) return 0;
            printf("%d\n", parity32(x));
        } else if (op == 'Q') {
            unsigned long long x;
            if (scanf("%llx", &x) != 1) return 0;
            printf("%d\n", parity64((uint64_t)x));
        } else if (op == 'I') {
            unsigned id;
            if (scanf("%u", &id) != 1 || id > 63u) return 0;
            printf("%02X\n", (unsigned)lin_pid((uint8_t)id));
        } else {
            unsigned seed;
            int n;
            if (scanf("%u %d", &seed, &n) != 2) return 0;
            uint32_t s = seed;
            int odd32 = 0, odd64 = 0;
            for (int k = 0; k < n; k++) {
                s = s * 1103515245u + 12345u;
                uint32_t a = s;
                s = s * 1103515245u + 12345u;
                uint32_t b = s;
                odd32 += parity32(a) == 1;
                odd64 += parity64(((uint64_t)a << 32) | b) == 1;
            }
            printf("odd32=%d odd64=%d\n", odd32, odd64);
        }
    }
    return 0;
}
@@@ sample_input
4
P 00000003
P 80000000
Q 8000000000000000
I 61
@@@ sample_output
0
1
1
7D

@@@ sample_input
3
P 00000000
I 60
I 0
@@@ sample_output
0
3C
80

@@@ hidden_input
5
P FFFFFFFF
P 7FFFFFFF
P 12345678
P DEADBEEF
P 80000001
@@@ hidden_output
0
1
1
0
0

@@@ hidden_input
5
Q 0
Q FFFFFFFFFFFFFFFF
Q 7FFFFFFFFFFFFFFF
Q 0000000100000000
Q 8000000000000001
@@@ hidden_output
0
0
1
1
0

@@@ hidden_input
4
Q 123456789ABCDEF0
Q FFFFFFFF00000001
Q DEADBEEFCAFEBABE
P 00010000
@@@ hidden_output
0
1
0
1

@@@ hidden_input
7
I 1
I 63
I 16
I 34
I 42
I 21
I 49
@@@ hidden_output
C1
BF
50
E2
6A
55
B1

@@@ hidden_input
2
R 1 1000
R 0 3
@@@ hidden_output
odd32=488 odd64=511
odd32=2 odd64=2

@@@ hidden_input
1
R 99 50000
@@@ hidden_output
odd32=24906 odd64=24921

@@@ hint
XOR-ing the upper half of a word onto the lower half preserves the parity of the whole word in the lower half. Repeat with 16, 8, 4, 2 and 1: bit 0 then holds the parity of all 32 bits.
@@@ hint
For 64 bits, start with `x ^= x >> 32`. For the LIN PID, mask the ID bits that each parity covers and reuse `parity32`: P0 covers bits 0,1,2,4 (mask `0x17`), P1 covers bits 1,3,4,5 (mask `0x3A`), and P1 is inverted.
@@@ solution_code
#include <stdint.h>

int parity32(uint32_t x)
{
    x ^= x >> 16;      /* fold: parity of 32 bits -> parity of low 16 */
    x ^= x >> 8;
    x ^= x >> 4;
    x &= 0xFu;
    return (int)((0x6996u >> x) & 1u);   /* 16-entry parity table packed in a constant */
}

int parity64(uint64_t x)
{
    return parity32((uint32_t)(x ^ (x >> 32)));
}

uint8_t lin_pid(uint8_t id)
{
    id &= 0x3Fu;
    unsigned p0 = (unsigned)parity32(id & 0x17u);         /* ID0 ^ ID1 ^ ID2 ^ ID4   */
    unsigned p1 = (unsigned)parity32(id & 0x3Au) ^ 1u;    /* !(ID1 ^ ID3 ^ ID4 ^ ID5) */
    return (uint8_t)(id | (p0 << 6) | (p1 << 7));
}
@@@ explanation_md
**Approach: XOR folding.** Parity is the XOR of all bits. XOR is associative, so you can combine bits in any grouping:
- `x ^= x >> 16` puts `bit[i] ^ bit[i+16]` into the low half. The parity of the low 16 bits now equals the parity of all 32.
- Repeat with 8 and 4. Bits 0..3 then carry the parity of the whole word, folded into a nibble.
- Finish with a 16-bit lookup constant: `0x6996` = `0110 1001 1001 0110` has bit `n` set exactly when the nibble `n` has odd parity. (`>> 2` and `>> 1` steps instead also work.)

For 64 bits, fold the top half onto the bottom half first, then reuse the 32-bit version.

**LIN PID.** Each parity bit covers a subset of the ID bits. Mask that subset (`0x17` = bits 0,1,2,4 and `0x3A` = bits 1,3,4,5) and take its parity. P1 is inverted (odd parity), so a PID can never be all zeros, which would look like a dominant bus fault.

```
id = 0x3D = 11 1101
P0 = parity(0x3D & 0x17 = 0x15) = parity(1 0101) = 1
P1 = !parity(0x3D & 0x3A = 0x38) = !parity(11 1000) = !1 = 0
PID = 0 1 111101 = 0x7D
```

**Complexity.** O(log w) time: 3 fold steps plus a constant look-up for 32 bits, one more step for 64. O(1) space.

**Common mistakes**
- Folding with signed `int`/`int64_t`. Arithmetic right shifts drag the sign bit in and break the parity of the upper half.
- Forgetting `x &= 0xF` before `0x6996 >> x`, which shifts by up to 2^32 - 1 (UB).
- `parity64` written as `parity32((uint32_t)x)`, which ignores the upper 32 bits entirely. The `0000000100000000` test catches that.
- In the LIN PID, forgetting to **invert** P1, or putting P0/P1 in the wrong bit position (P0 = bit 6, P1 = bit 7).

**Interview follow-ups**
- How does a LIN slave use the PID to reject a corrupted header, and why is parity enough here when the data field needs a checksum (classic vs enhanced)?
- What can parity detect and what can it not? (All odd-weight errors; no even-weight errors; it cannot correct anything.) Compare with SECDED ECC in automotive SRAM.
- On an 8051 or other MCU with a hardware parity flag (`P` in PSW), how would you compute parity of a 32-bit word in a few instructions?
- How would you compute the parity of a 1 KB block as fast as possible on a 32-bit core?
