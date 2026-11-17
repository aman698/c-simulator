@@@ meta
id: BIT-E-02
topic: Bit Manipulation
difficulty: Easy
type: FUNCTION
title: Count Set Bits Two Ways (Kernighan and Lookup Table)
tags: popcount, kernighan, lookup-table, hamming-weight, diagnostics
@@@ statement_md
A diagnostic task keeps a 32-bit **fault status word**: every bit is one active fault (DTC). To report how many faults are active, you need the number of 1-bits in the word (its *population count*, or Hamming weight).

Implement it in two ways:

```c
int  popcount_kernighan(uint32_t x);   /* loop that runs once per SET bit */
void popcount_table_init(void);        /* fill your own 256-entry table   */
int  popcount_table(uint32_t x);       /* 4 table look-ups, one per byte  */
```

- `popcount_kernighan` must use Brian Kernighan's trick: `x & (x - 1)` clears the lowest set bit, so the loop runs exactly `popcount(x)` times instead of 32.
- `popcount_table` uses a `static uint8_t` table of 256 entries (the bit count of every byte value). The harness calls `popcount_table_init()` **once** before any `popcount_table()` call.
- `__builtin_popcount` is not allowed.

**Input (read by the hidden harness)**
- Line 1: `q`, the number of commands.
- Next `q` lines, one of:
  - `V x`: `x` in hex. The harness prints `XXXXXXXX -> k t`, where `k` = `popcount_kernighan(x)` and `t` = `popcount_table(x)`.
  - `R seed n`: the harness generates `n` pseudo-random words (LCG `s = s * 1103515245u + 12345u`, starting from `seed`) and prints `sum -> K T`, the sums of both functions over all words.

**Example**
```
Input:
3
V 0000000B
V 80000000
V FFFFFFFF

Output:
0000000B -> 3 3
80000000 -> 1 1
FFFFFFFF -> 32 32
```
@@@ constraints_md
- `1 <= q <= 20`, `0 <= x <= 0xFFFFFFFF`
- `1 <= n <= 200000` for `R` commands
- Do not use `__builtin_popcount` or any compiler intrinsic.
@@@ starter_code
#include <stdint.h>

/* Kernighan: loop once per set bit using x & (x - 1). */
int popcount_kernighan(uint32_t x)
{
    /* TODO */
    return 0;
}

/* static uint8_t table[256]; */

void popcount_table_init(void)
{
    /* TODO: table[i] = number of 1-bits in i, for i = 0..255 */
}

int popcount_table(uint32_t x)
{
    /* TODO: sum the table entries of the 4 bytes of x */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>

#define __builtin_popcount(x) builtin_popcount_is_not_allowed
#define __builtin_popcountll(x) builtin_popcount_is_not_allowed

/*USER_CODE*/

#undef __builtin_popcount
#undef __builtin_popcountll

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    popcount_table_init();
    for (int k = 0; k < q; k++) {
        char op;
        if (scanf(" %c", &op) != 1) return 0;
        if (op == 'V') {
            unsigned x;
            if (scanf("%x", &x) != 1) return 0;
            printf("%08X -> %d %d\n", x, popcount_kernighan(x), popcount_table(x));
        } else {
            unsigned seed;
            int n;
            if (scanf("%u %d", &seed, &n) != 2) return 0;
            uint32_t s = seed;
            long long sk = 0, st = 0;
            for (int i = 0; i < n; i++) {
                s = s * 1103515245u + 12345u;
                sk += popcount_kernighan(s);
                st += popcount_table(s);
            }
            printf("sum -> %lld %lld\n", sk, st);
        }
    }
    return 0;
}
@@@ sample_input
3
V 0000000B
V 80000000
V FFFFFFFF
@@@ sample_output
0000000B -> 3 3
80000000 -> 1 1
FFFFFFFF -> 32 32

@@@ sample_input
2
V 00000000
V 12345678
@@@ sample_output
00000000 -> 0 0
12345678 -> 13 13

@@@ hidden_input
4
V 00000001
V 7FFFFFFF
V AAAAAAAA
V 0F0F0F0F
@@@ hidden_output
00000001 -> 1 1
7FFFFFFF -> 31 31
AAAAAAAA -> 16 16
0F0F0F0F -> 16 16

@@@ hidden_input
5
V DEADBEEF
V 000000FF
V 0000FF00
V 00000100
V FFFF0000
@@@ hidden_output
DEADBEEF -> 24 24
000000FF -> 8 8
0000FF00 -> 8 8
00000100 -> 1 1
FFFF0000 -> 16 16

@@@ hidden_input
1
V 01010101
@@@ hidden_output
01010101 -> 4 4

@@@ hidden_input
2
R 1 1000
R 0 5
@@@ hidden_output
sum -> 16020 16020
sum -> 74 74

@@@ hidden_input
1
R 12345 100000
@@@ hidden_output
sum -> 1599796 1599796

@@@ hidden_input
1
R 42 200000
@@@ hidden_output
sum -> 3200187 3200187

@@@ hint
`x - 1` flips the lowest set bit to 0 and every 0 below it to 1. ANDing with `x` therefore removes exactly that lowest 1-bit. Count how many times you can do this before `x` becomes 0.
@@@ hint
Build the table with the recurrence `table[i] = table[i >> 1] + (i & 1)`: the count of `i` is the count of `i` without its last bit, plus that bit. Then `popcount_table(x)` = `table[x & 0xFF] + table[(x >> 8) & 0xFF] + table[(x >> 16) & 0xFF] + table[x >> 24]`.
@@@ solution_code
#include <stdint.h>

int popcount_kernighan(uint32_t x)
{
    int count = 0;
    while (x != 0u) {
        x &= x - 1u;        /* clear the lowest set bit */
        count++;
    }
    return count;
}

static uint8_t table[256];

void popcount_table_init(void)
{
    table[0] = 0;
    for (unsigned i = 1; i < 256u; i++)
        table[i] = (uint8_t)(table[i >> 1] + (i & 1u));
}

int popcount_table(uint32_t x)
{
    return table[x & 0xFFu] +
           table[(x >> 8) & 0xFFu] +
           table[(x >> 16) & 0xFFu] +
           table[x >> 24];
}
@@@ explanation_md
**Approach 1: Kernighan.** In `x - 1` the lowest 1-bit becomes 0 and every bit below it becomes 1. Bits above it are unchanged. So `x & (x - 1)` is `x` with its lowest set bit cleared:

```
x       = 1011 0100
x - 1   = 1011 0011
x&(x-1) = 1011 0000   <- one bit gone
```

The loop runs once per set bit. A fault word with 2 active faults costs 2 iterations, not 32.

**Approach 2: lookup table.** Precompute the count of every byte value once (256 bytes of flash or RAM). Then a 32-bit word takes 4 loads and 3 additions, with no data-dependent loop. The timing is constant, which matters for WCET analysis. The recurrence `table[i] = table[i/2] + (i & 1)` fills the table in one pass.

**Complexity.**
- Kernighan: O(k) time, where k = number of set bits (worst case 32). O(1) space.
- Table: O(1) time (4 look-ups) after an O(256) one-time init. O(256) bytes of space.

**Common mistakes**
- Loop `while (x) { c += x & 1; x >>= 1; }` on a **signed** `int`. For negative values, `>>` is arithmetic in gcc, so the sign bit is copied in forever and the loop never ends. Use `uint32_t`.
- Forgetting `& 0xFF` on the middle bytes. `table[x >> 8]` indexes far outside the 256-entry table.
- Initialising the table inside `popcount_table` on every call. That defeats the purpose.
- Indexing the table with a plain `char` byte (for example, from a `char` receive buffer). `char` is signed on x86-64, so bytes `0x80..0xFF` become negative indices.

**Interview follow-ups**
- Write the branch-free **SWAR** version: `x = x - ((x >> 1) & 0x55555555); x = (x & 0x33333333) + ((x >> 2) & 0x33333333); ...`. Why is it popular on cores without a `POPCNT` instruction?
- Trade-offs on a Cortex-M0 with 32 KB flash: table in flash vs RAM, and a 16-entry nibble table vs a 256-entry byte table.
- How would you compute the **parity** (odd/even number of 1s) faster than a full popcount?
- How would you count set bits across a 1 KB bitmap (for example, free blocks in a flash allocator) efficiently?
