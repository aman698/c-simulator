@@@ meta
id: BIT-E-09
topic: Bit Manipulation
difficulty: Easy
type: FIND_THE_BUG
title: XOR Swap Byte Reverser That Zeroes a Byte
tags: xor-swap, swap-without-temp, aliasing, endianness, in-place
@@@ statement_md
A sensor sends multi-byte fields least-significant byte first. The firmware reverses each field **in place** to get big-endian order. To "save a register" on an old 8-bit MCU, the original author swapped bytes with the XOR trick instead of a temporary variable.

The program reads `n` bytes and prints them in reverse order. QA reports that 2-, 4- and 8-byte fields are fine, but for some field lengths **one byte of the output is `00`** even though no input byte was zero.

Find and fix the bug. Keep the in-place XOR swap; do not change the output format.

**Input**
- Line 1: `n`.
- Line(s) 2+: `n` bytes in hex.

**Output**
- The `n` bytes in reverse order, as two-digit uppercase hex separated by single spaces.

**Example**
```
Input:
3
AA BB CC

Output:
CC BB AA
```
@@@ constraints_md
- `1 <= n <= 256`
- The reversal must stay in place (no second buffer).
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

/* swap two bytes without a temporary */
static void xor_swap(uint8_t *a, uint8_t *b)
{
    *a ^= *b;
    *b ^= *a;
    *a ^= *b;
}

/* reverse buf[0..n-1] in place */
static void reverse_bytes(uint8_t *buf, int n)
{
    int i = 0, j = n - 1;
    while (i <= j) {
        xor_swap(&buf[i], &buf[j]);
        i++;
        j--;
    }
}

int main(void)
{
    static uint8_t buf[256];
    int n;
    if (scanf("%d", &n) != 1 || n < 1 || n > 256) return 0;
    for (int i = 0; i < n; i++) {
        unsigned v;
        if (scanf("%x", &v) != 1) return 0;
        buf[i] = (uint8_t)v;
    }

    reverse_bytes(buf, n);

    for (int i = 0; i < n; i++)
        printf("%02X%c", buf[i], i == n - 1 ? '\n' : ' ');
    return 0;
}
@@@ sample_input
4
11 22 33 44
@@@ sample_output
44 33 22 11

@@@ sample_input
3
AA BB CC
@@@ sample_output
CC BB AA

@@@ hidden_input
1
5A
@@@ hidden_output
5A

@@@ hidden_input
2
FF 00
@@@ hidden_output
00 FF

@@@ hidden_input
5
01 02 00 04 05
@@@ hidden_output
05 04 00 02 01

@@@ hidden_input
8
DE AD BE EF 01 23 45 67
@@@ hidden_output
67 45 23 01 EF BE AD DE

@@@ hidden_input
7
80 7F FF 01 FE 02 10
@@@ hidden_output
10 02 FE 01 FF 7F 80

@@@ hidden_input
255
0B 30 55 7A 9F C4 E9 0E 33 58 7D A2 C7 EC 11 36 5B 80 A5 CA EF 14 39 5E 83 A8 CD F2 17 3C 61 86
AB D0 F5 1A 3F 64 89 AE D3 F8 1D 42 67 8C B1 D6 FB 20 45 6A 8F B4 D9 FE 23 48 6D 92 B7 DC 01 26
4B 70 95 BA DF 04 29 4E 73 98 BD E2 07 2C 51 76 9B C0 E5 0A 2F 54 79 9E C3 E8 0D 32 57 7C A1 C6
EB 10 35 5A 7F A4 C9 EE 13 38 5D 82 A7 CC F1 16 3B 60 85 AA CF F4 19 3E 63 88 AD D2 F7 1C 41 66
8B B0 D5 FA 1F 44 69 8E B3 D8 FD 22 47 6C 91 B6 DB 00 25 4A 6F 94 B9 DE 03 28 4D 72 97 BC E1 06
2B 50 75 9A BF E4 09 2E 53 78 9D C2 E7 0C 31 56 7B A0 C5 EA 0F 34 59 7E A3 C8 ED 12 37 5C 81 A6
CB F0 15 3A 5F 84 A9 CE F3 18 3D 62 87 AC D1 F6 1B 40 65 8A AF D4 F9 1E 43 68 8D B2 D7 FC 21 46
6B 90 B5 DA FF 24 49 6E 93 B8 DD 02 27 4C 71 96 BB E0 05 2A 4F 74 99 BE E3 08 2D 52 77 9C C1
@@@ hidden_output
C1 9C 77 52 2D 08 E3 BE 99 74 4F 2A 05 E0 BB 96 71 4C 27 02 DD B8 93 6E 49 24 FF DA B5 90 6B 46 21 FC D7 B2 8D 68 43 1E F9 D4 AF 8A 65 40 1B F6 D1 AC 87 62 3D 18 F3 CE A9 84 5F 3A 15 F0 CB A6 81 5C 37 12 ED C8 A3 7E 59 34 0F EA C5 A0 7B 56 31 0C E7 C2 9D 78 53 2E 09 E4 BF 9A 75 50 2B 06 E1 BC 97 72 4D 28 03 DE B9 94 6F 4A 25 00 DB B6 91 6C 47 22 FD D8 B3 8E 69 44 1F FA D5 B0 8B 66 41 1C F7 D2 AD 88 63 3E 19 F4 CF AA 85 60 3B 16 F1 CC A7 82 5D 38 13 EE C9 A4 7F 5A 35 10 EB C6 A1 7C 57 32 0D E8 C3 9E 79 54 2F 0A E5 C0 9B 76 51 2C 07 E2 BD 98 73 4E 29 04 DF BA 95 70 4B 26 01 DC B7 92 6D 48 23 FE D9 B4 8F 6A 45 20 FB D6 B1 8C 67 42 1D F8 D3 AE 89 64 3F 1A F5 D0 AB 86 61 3C 17 F2 CD A8 83 5E 39 14 EF CA A5 80 5B 36 11 EC C7 A2 7D 58 33 0E E9 C4 9F 7A 55 30 0B

@@@ hint
Trace `xor_swap` by hand when `a` and `b` point to the **same** byte holding `0x5A`. What is `x ^ x`?
@@@ hint
When does the loop call `xor_swap(&buf[i], &buf[j])` with `i == j`? For an odd `n`, the middle element meets itself. A middle element never needs to move.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

/* swap two bytes without a temporary */
static void xor_swap(uint8_t *a, uint8_t *b)
{
    *a ^= *b;
    *b ^= *a;
    *a ^= *b;
}

/* reverse buf[0..n-1] in place */
static void reverse_bytes(uint8_t *buf, int n)
{
    int i = 0, j = n - 1;
    while (i < j) {             /* FIX: was i <= j; xor_swap on the same byte zeroes it */
        xor_swap(&buf[i], &buf[j]);
        i++;
        j--;
    }
}

int main(void)
{
    static uint8_t buf[256];
    int n;
    if (scanf("%d", &n) != 1 || n < 1 || n > 256) return 0;
    for (int i = 0; i < n; i++) {
        unsigned v;
        if (scanf("%x", &v) != 1) return 0;
        buf[i] = (uint8_t)v;
    }

    reverse_bytes(buf, n);

    for (int i = 0; i < n; i++)
        printf("%02X%c", buf[i], i == n - 1 ? '\n' : ' ');
    return 0;
}
@@@ explanation_md
**Bug.** The XOR swap is only correct for two **different** objects. If `a` and `b` alias the same byte `x`:

```
*a ^= *b;   // x ^ x = 0  -> the byte is now 0
*b ^= *a;   // 0 ^ 0 = 0
*a ^= *b;   // 0 ^ 0 = 0
```

With `while (i <= j)` and an odd `n`, the last iteration has `i == j` (the middle byte), and `xor_swap` wipes it. Even lengths never reach `i == j`, which is why 2-, 4- and 8-byte fields looked fine. The 3-byte, 1-byte and 255-byte tests expose the bug. The 5-byte test passes by luck because its middle byte is already `00`.

**Fix.** Loop while `i < j`. The middle element of an odd-length array is its own mirror image and must not be touched. A defensive alternative is a guard `if (a != b)` inside `xor_swap`.

**Complexity.** O(n) time, O(1) extra space.

**Common mistakes**
- Believing the XOR swap is "free". On any modern core, a temporary register is free, and three dependent XORs are **slower** than two independent moves because they cannot run in parallel. Compilers also turn a plain temp-variable swap into the best code.
- The same aliasing trap with the arithmetic swap `a = a + b; b = a - b; a = a - b;`. It also zeroes aliased operands and can overflow signed types (UB).
- Applying the XOR swap to non-integer types (`float`, pointers). It does not compile without casts that break strict aliasing.

**Interview follow-ups**
- Swap two variables without a temporary in three ways (XOR, add/sub, multiply/divide), and name the failure case of each.
- Why is the XOR swap a classic interview question, but rejected in code review for production code?
- Reverse the byte order of a `uint32_t` *value* (not an array) with shifts and masks. When is that better than reversing a byte array?
