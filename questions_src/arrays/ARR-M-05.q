@@@ meta
id: ARR-M-05
topic: Arrays
difficulty: Medium
type: FUNCTION
title: Rotate a Square Framebuffer 90 Degrees In Place
tags: embedded, matrix-rotation, transpose, in-place, 2d-array, display
@@@ statement_md
A TFT display is mounted in the instrument cluster rotated by 90 degrees. Before each square sprite tile is sent to the panel by DMA, it must be rotated **90 degrees clockwise**. RAM is tight, so there is **no second framebuffer**: the rotation must be done **in place** with O(1) extra memory.

The tile is `n x n` RGB565 pixels stored **row-major** in a flat array: pixel `(r, c)` is `img[r * n + c]`. Implement

```c
void rotate_cw(uint16_t *img, int n);
```

After the call, `new(r, c) == old(n - 1 - c, r)`: the left column (read bottom to top) becomes the top row.

```
1 2 3        7 4 1
4 5 6   ->   8 5 2
7 8 9        9 6 3
```

- `img` may be `NULL` only when `n == 0`.
- Do not allocate a temporary tile, not even a static one. A single temporary row is also not allowed: only a few scalar temporaries.

**How it is tested.** A hidden `main()` calls your function and prints the tile, or for large generated tiles (up to 1024 x 1024) compares the result with a reference and prints `OK` or `WRONG`. Guard words around the buffer detect out-of-bounds writes.

**Input (read by the hidden harness)**
- Either: line 1 `n`, then `n` lines of `n` pixel values,
- or: one line `GEN n seed`.

**Output**
- The rotated tile, one row per line (nothing for `n = 0`), or `OK` / `WRONG`.

**Example**
```
Input:
3
1 2 3
4 5 6
7 8 9

Output:
7 4 1
8 5 2
9 6 3
```
@@@ constraints_md
- `0 <= n <= 1024`
- `0 <= pixel <= 65535`
- O(n^2) time, O(1) extra memory.
@@@ starter_code
#include <stdint.h>

/* Rotate the n x n row-major tile 90 degrees clockwise, in place. */
void rotate_cw(uint16_t *img, int n)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/*USER_CODE*/

#define MAXN 1024
#define GUARD 16
#define CANARY 0xA5A5u

static uint16_t arena[GUARD + MAXN * MAXN + GUARD];
static uint16_t ref[MAXN * MAXN];

int main(void)
{
    char tok[16];
    int n;
    int gen = 0;
    if (scanf("%15s", tok) != 1) return 0;
    uint16_t *img = arena + GUARD;
    if (strcmp(tok, "GEN") == 0) {
        unsigned int seed;
        if (scanf("%d %u", &n, &seed) != 2 || n < 0 || n > MAXN) return 0;
        gen = 1;
        uint32_t x = seed;
        for (int i = 0; i < n * n; i++) {
            x = x * 1103515245u + 12345u;
            img[i] = (uint16_t)(x >> 16);
        }
    } else {
        if (sscanf(tok, "%d", &n) != 1 || n < 0 || n > MAXN) return 0;
        for (int i = 0; i < n * n; i++) {
            unsigned v;
            if (scanf("%u", &v) != 1) return 0;
            img[i] = (uint16_t)v;
        }
    }
    for (int i = 0; i < GUARD; i++) {
        arena[i] = CANARY;
        arena[GUARD + n * n + i] = CANARY;
    }
    for (int r = 0; r < n; r++)
        for (int c = 0; c < n; c++)
            ref[r * n + c] = img[(n - 1 - c) * n + r];

    rotate_cw(n == 0 ? NULL : img, n);

    for (int i = 0; i < GUARD; i++) {
        if (arena[i] != CANARY || arena[GUARD + n * n + i] != CANARY) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    if (gen) {
        printf("%s\n", memcmp(ref, img, (size_t)n * (size_t)n * sizeof img[0]) == 0 ? "OK" : "WRONG");
    } else {
        for (int r = 0; r < n; r++)
            for (int c = 0; c < n; c++)
                printf("%u%c", (unsigned)img[r * n + c], c == n - 1 ? '\n' : ' ');
    }
    return 0;
}
@@@ sample_input
3
1 2 3
4 5 6
7 8 9
@@@ sample_output
7 4 1
8 5 2
9 6 3

@@@ sample_input
4
1 2 3 4
5 6 7 8
9 10 11 12
13 14 15 16
@@@ sample_output
13 9 5 1
14 10 6 2
15 11 7 3
16 12 8 4

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
1
65535
@@@ hidden_output
65535

@@@ hidden_input
2
1 2
3 4
@@@ hidden_output
3 1
4 2

@@@ hidden_input
5
1 2 3 4 5
6 7 8 9 10
11 12 13 14 15
16 17 18 19 20
21 22 23 24 25
@@@ hidden_output
21 16 11 6 1
22 17 12 7 2
23 18 13 8 3
24 19 14 9 4
25 20 15 10 5

@@@ hidden_input
3
7 7 7
7 7 7
7 7 7
@@@ hidden_output
7 7 7
7 7 7
7 7 7

@@@ hidden_input
GEN 1024 1
@@@ hidden_output
OK

@@@ hidden_input
GEN 999 7
@@@ hidden_output
OK

@@@ hidden_input
GEN 2 3
@@@ hidden_output
OK

@@@ hint
A clockwise rotation equals two simple in-place reflections. One of them is the transpose (swap `(r, c)` with `(c, r)` for `c > r`). What is the second one?
@@@ hint
Transpose, then reverse every row: `transpose -> new(r,c) = old(c,r)`, `reverse row -> new(r,c) = old(n-1-c, r)`. Alternatively rotate ring by ring, moving four pixels at a time with one temporary (top <- left <- bottom <- right <- top).
@@@ solution_code
#include <stdint.h>

static void swap16(uint16_t *a, uint16_t *b)
{
    uint16_t t = *a;
    *a = *b;
    *b = t;
}

void rotate_cw(uint16_t *img, int n)
{
    if (img == NULL || n < 2)
        return;

    /* 1) transpose across the main diagonal: (r,c) <-> (c,r) */
    for (int r = 0; r < n; r++)
        for (int c = r + 1; c < n; c++)
            swap16(&img[r * n + c], &img[c * n + r]);

    /* 2) mirror every row left <-> right */
    for (int r = 0; r < n; r++) {
        uint16_t *row = img + r * n;
        for (int lo = 0, hi = n - 1; lo < hi; lo++, hi--)
            swap16(&row[lo], &row[hi]);
    }
}
@@@ explanation_md
**Approach: transpose + horizontal mirror.** Each step is an in-place permutation made of pairwise swaps, and together they form the rotation:

```
1 2 3   transpose   1 4 7   mirror rows   7 4 1
4 5 6  ---------->  2 5 8  ------------>  8 5 2
7 8 9               3 6 9                 9 6 3
```

Formally: transpose gives `T(r,c) = old(c,r)`, and mirroring gives `new(r,c) = T(r, n-1-c) = old(n-1-c, r)`.

**Alternative: 4-way cycle per ring.** For each ring `layer = 0 .. n/2-1` and each offset `i`, the four pixels top, right, bottom and left form a cycle of length 4. Rotate them with one temporary. That is exactly one read and one write per pixel (fewer memory operations than the two-pass method, which matters for slow external SRAM), but the index math is easier to get wrong.

**Complexity.** Time O(n^2): each pixel is swapped at most twice. Space O(1).

**Common mistakes**
- Transposing with `c` from `0` instead of `r + 1`. Every pair is swapped twice and the transpose undoes itself.
- Mirroring columns (top/bottom) instead of rows. That gives the **counter-clockwise** rotation.
- Copying into a static temporary tile. It gives correct output, but 2 MB of RAM does not exist on the target and is explicitly forbidden.
- Index overflow on huge tiles: `r * n + c` in `int` is fine for 1024, but for a 50 000 x 50 000 image it overflows. Use `size_t` for the linear index.

**Interview follow-ups**
- Rotate **counter-clockwise**, or by 180 degrees (reverse the whole flat array).
- A non-square `R x C` image rotated in place: the shape changes, and the in-place version becomes a cycle-following permutation (see the in-place transpose problem).
- The panel controller (e.g. ILI9341 MADCTL register) can rotate in hardware. When would you still rotate in software?
- Cache and DMA: why can the column-wise access pattern of the transpose be slow, and how does blocking (tiling 8x8) help?
