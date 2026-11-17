@@@ meta
id: ARR-H-04
topic: Arrays
difficulty: Hard
type: FUNCTION
title: De-interleave a DMA Audio Buffer In Place (Cycle-Leader Transpose)
tags: embedded, in-place-transpose, permutation-cycles, dma, matrix, modular-arithmetic
@@@ statement_md
A multi-channel ADC (e.g. a microphone array for in-cabin noise cancellation) writes samples by DMA in **interleaved** order: frame 0 of every channel, then frame 1 of every channel, and so on. The DSP library needs **planar** order: all frames of channel 0, then all frames of channel 1, ...

```
interleaved (F = 3 frames, C = 2 channels):  L0 R0 L1 R1 L2 R2
planar:                                       L0 L1 L2 R0 R1 R2
```

This is an in-place **transpose** of an `F x C` row-major matrix into a `C x F` one. The buffer fills most of the SRAM, so there is **no room for a copy**, and not even for a "visited" bitmap: only O(1) extra memory (a few scalar variables).

Implement

```c
void deinterleave(int16_t *buf, int frames, int channels);
```

After the call, `buf[c * frames + f]` must hold the sample that was at `buf[f * channels + c]`.

**How it is tested.** A hidden `main()` calls your function once. Guard words around the buffer detect out-of-bounds writes. Small tests print the planar result one channel per line. Large generated tests (up to 2^20 samples) are compared with the original and print `OK` or `WRONG`.

**Input (read by the hidden harness)**
- Either: line 1 `F C`, then `F` lines of `C` samples (one frame per line),
- or: one line `GEN F C seed`.

**Output**
- `chK: s0 s1 ...` for each channel, or `OK` / `WRONG at channel c frame f`.

**Example**
```
Input:
3 2
1 10
2 20
3 30

Output:
ch0: 1 2 3
ch1: 10 20 30
```
@@@ constraints_md
- `1 <= F, C` and `F * C <= 1048576`
- Samples are `int16_t`
- O(1) extra memory. Expected time about O(N log N) for `N = F * C` (the cycle-leader method); it must finish in the time limit for every shape.
@@@ starter_code
#include <stdint.h>

/* In place: buf[c * frames + f] <- old buf[f * channels + c]. O(1) extra memory. */
void deinterleave(int16_t *buf, int frames, int channels)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/*USER_CODE*/

#define MAXN (1 << 20)
#define GUARD 16
#define CANARY ((int16_t)0x5A5A)

static int16_t arena[GUARD + MAXN + GUARD];
static int16_t orig[MAXN];

int main(void)
{
    char tok[16];
    int F, C;
    int gen = 0;
    if (scanf("%15s", tok) != 1) return 0;
    int16_t *buf = arena + GUARD;
    if (strcmp(tok, "GEN") == 0) {
        unsigned int seed;
        if (scanf("%d %d %u", &F, &C, &seed) != 3) return 0;
        if (F < 1 || C < 1 || (long long)F * C > MAXN) return 0;
        gen = 1;
        uint32_t x = seed;
        for (int i = 0; i < F * C; i++) {
            x = x * 1103515245u + 12345u;
            buf[i] = (int16_t)((int32_t)(x >> 16) - 32768);
        }
    } else {
        if (sscanf(tok, "%d", &F) != 1 || scanf("%d", &C) != 1) return 0;
        if (F < 1 || C < 1 || (long long)F * C > MAXN) return 0;
        for (int i = 0; i < F * C; i++) {
            int v;
            if (scanf("%d", &v) != 1) return 0;
            buf[i] = (int16_t)v;
        }
    }
    int n = F * C;
    memcpy(orig, buf, (size_t)n * sizeof buf[0]);
    for (int i = 0; i < GUARD; i++) {
        arena[i] = CANARY;
        arena[GUARD + n + i] = CANARY;
    }

    deinterleave(buf, F, C);

    for (int i = 0; i < GUARD; i++) {
        if (arena[i] != CANARY || arena[GUARD + n + i] != CANARY) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    if (gen) {
        for (int c = 0; c < C; c++) {
            for (int f = 0; f < F; f++) {
                if (buf[c * F + f] != orig[f * C + c]) {
                    printf("WRONG at channel %d frame %d\n", c, f);
                    return 0;
                }
            }
        }
        printf("OK\n");
    } else {
        for (int c = 0; c < C; c++) {
            printf("ch%d:", c);
            for (int f = 0; f < F; f++) printf(" %d", buf[c * F + f]);
            printf("\n");
        }
    }
    return 0;
}
@@@ sample_input
3 2
1 10
2 20
3 30
@@@ sample_output
ch0: 1 2 3
ch1: 10 20 30

@@@ sample_input
2 4
1 2 3 4
5 6 7 8
@@@ sample_output
ch0: 1 5
ch1: 2 6
ch2: 3 7
ch3: 4 8

@@@ hidden_input
1 1
-32768
@@@ hidden_output
ch0: -32768

@@@ hidden_input
1 5
9 8 7 6 5
@@@ hidden_output
ch0: 9
ch1: 8
ch2: 7
ch3: 6
ch4: 5

@@@ hidden_input
4 1
11
12
13
14
@@@ hidden_output
ch0: 11 12 13 14

@@@ hidden_input
4 3
1 2 3
4 5 6
7 8 9
10 11 12
@@@ hidden_output
ch0: 1 4 7 10
ch1: 2 5 8 11
ch2: 3 6 9 12

@@@ hidden_input
3 3
32767 -1 0
-32768 5 5
7 7 -7
@@@ hidden_output
ch0: 32767 -32768 7
ch1: -1 5 7
ch2: 0 5 -7

@@@ hidden_input
GEN 524288 2 1
@@@ hidden_output
OK

@@@ hidden_input
GEN 131072 8 2
@@@ hidden_output
OK

@@@ hidden_input
GEN 1000 1000 3
@@@ hidden_output
OK

@@@ hidden_input
GEN 349525 3 4
@@@ hidden_output
OK

@@@ hidden_input
GEN 7 149796 5
@@@ hidden_output
OK

@@@ hint
Index the buffer linearly with `N = F * C`. The sample at position `i = f*C + c` must move to `j = c*F + f`. Positions `0` and `N-1` never move. For every other `i` you can show that `j = (i * F) mod (N - 1)`. So the transpose is a **permutation** made of disjoint cycles.
@@@ hint
Rotate each cycle exactly once, carrying one sample along it with a single temporary. Without a visited bitmap, decide whether `s` should start (lead) a cycle by walking `next(s), next(next(s)), ...`. If you meet an index smaller than `s` first, that cycle was already rotated from its smallest member, so skip `s`. If you come back to `s`, rotate the cycle now. Use 64-bit arithmetic for `i * F`.
@@@ solution_code
#include <stdint.h>

void deinterleave(int16_t *buf, int frames, int channels)
{
    uint64_t n = (uint64_t)frames * (uint64_t)channels;
    if (n < 3)
        return;                              /* positions 0 and n-1 never move */
    uint64_t m = n - 1;
    uint64_t F = (uint64_t)frames;

    for (uint64_t start = 1; start < m; start++) {
        /* leader test: is 'start' the smallest index on its cycle? */
        uint64_t j = (start * F) % m;
        while (j > start)
            j = (j * F) % m;
        if (j < start)
            continue;                        /* cycle already done from a smaller leader */

        /* rotate the cycle: the sample at i moves to (i * F) mod m */
        int16_t carry = buf[start];
        uint64_t i = start;
        do {
            uint64_t next = (i * F) % m;
            int16_t t = buf[next];
            buf[next] = carry;
            carry = t;
            i = next;
        } while (i != start);
    }
}
@@@ explanation_md
**Approach: follow the permutation's cycles.** In the flat buffer the sample at `i = f*C + c` must go to `j = c*F + f`. Since `N = F*C ≡ 1 (mod N-1)`:

```
i * F = f*C*F + c*F = f*N + c*F ≡ f + c*F = j   (mod N-1)
```

So `next(i) = i*F mod (N-1)` for `0 < i < N-1`, and `0` and `N-1` are fixed points. The permutation splits into disjoint cycles. Rotating one cycle needs only a single carried sample:

```
F=3, C=2, N-1 = 5, next(i) = 3i mod 5:   1 -> 3 -> 4 -> 2 -> 1
R0 (pos 1) -> pos 3, R1 (pos 3) -> pos 4, L2 (pos 4) -> pos 2, L1 (pos 2) -> pos 1
L0 R0 L1 R1 L2 R2   ->   L0 L1 L2 R0 R1 R2
```

**No bitmap: the cycle-leader test.** Rotate each cycle only from its **smallest** index. For a candidate `s`, walk the cycle: meeting an index `< s` means the cycle was handled already, and returning to `s` means `s` is the leader. This uses O(1) memory; the price is extra walking. In practice the total work is about O(N log N), which is fast enough for a 1M-sample buffer.

**Complexity.** Time: each cycle is rotated once (N moves in total) plus the leader walks, about O(N log N) in practice and O(N^2) in the worst theoretical case. Space O(1). A visited bitmap (N bits, 128 KB here) would give O(N), but it is not available.

**Common mistakes**
- Using an `F x C` scratch copy. It is trivially correct, but it doubles the RAM, which is exactly what the problem forbids.
- Forgetting that `N - 1` is the modulus (not `N`), and not special-casing `N < 3` (modulo by 0 when `N == 1`).
- Overflow in `i * F` with 32-bit math: `1 048 575 * 524 288` does not fit in 32 bits.
- Rotating every cycle once per member: each cycle is rotated many times, which scrambles the data.
- Swapping `buf[i]` with `buf[next(i)]` in a loop over `i`. Pairwise swaps only work for square matrices.

**Interview follow-ups**
- Prove that `i*F mod (N-1)` is the inverse of `i*C mod (N-1)`. Which one re-interleaves planar data for the DAC?
- With a few hundred bytes of scratch, how would you speed this up? (Block transposes; or a small bitmap of already-processed cycle leaders.)
- Avoid the problem entirely: configure the DMA with a **channel stride** (scatter mode) or use two DMA streams so the data lands planar. What hardware features do STM32/TI DSP DMA controllers offer for this?
- For `C = 2` (stereo), a simpler O(N log N) recursive "perfect shuffle" exists. Sketch it.
