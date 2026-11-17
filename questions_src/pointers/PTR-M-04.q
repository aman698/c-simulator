@@@ meta
id: PTR-M-04
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Clipped Rectangle Fill in a Padded Framebuffer (Stride vs Width)
tags: embedded, 2d-array, stride, pointer-arithmetic, clipping, display-driver
@@@ statement_md
An instrument-cluster LCD driver keeps an 8-bit framebuffer in RAM. Each row is **`stride`** bytes long, but only the first **`width`** bytes are visible pixels. The remaining `stride - width` bytes are padding required by the DMA engine, and **must never be written** (the display controller uses them for line commands).

```
fb ->  [p p p p p p | pad pad]   row 0  (width = 6, stride = 8)
       [p p p p p p | pad pad]   row 1
       ...
pixel (x, y) is at  fb + y * stride + x
```

Implement

```c
void fb_fill_rect(uint8_t *fb, int width, int height, int stride,
                  int x, int y, int w, int h, uint8_t color);
```

It sets every visible pixel inside the rectangle with top-left corner `(x, y)`, width `w` and height `h` to `color`. The rectangle may lie partly or completely outside the screen, or have `w <= 0` / `h <= 0`. **Clip** it to the screen; pixels outside the screen are ignored. Rectangles can be huge (up to 10^9 in each direction), so a loop that visits every rectangle pixel and tests it is far too slow.

**How it is tested.** A hidden `main()` creates a framebuffer whose pixels are `.` and whose padding bytes hold a marker. It applies `q` fills and prints the visible pixels, or `PADDING WRITE` / `OUT OF BOUNDS WRITE` if you touched memory you must not touch.

**Input (read by the hidden harness)**
- Line 1: `width height stride q`
- Next `q` lines: `x y w h c`, where `c` is a printable character used as the color.

**Output**
- `height` lines of `width` characters: the framebuffer after all fills.

**Example**
```
Input:
6 4 8 2
1 1 3 2 #
-2 -1 4 2 o

Output:
oo....
.###..
.###..
......
```
The second rectangle covers x in [-2, 2) and y in [-1, 1). Only x = 0, 1 on row 0 are visible.
@@@ constraints_md
- `1 <= width <= 32`, `1 <= height <= 16`, `width <= stride <= 40`, `1 <= q <= 20`
- `-10^9 <= x, y, w, h <= 10^9`, so `x + w` and `y + h` fit in an `int`.
- Time limit: O(visible pixels) per call.
@@@ starter_code
#include <stdint.h>

void fb_fill_rect(uint8_t *fb, int width, int height, int stride,
                  int x, int y, int w, int h, uint8_t color)
{
    /* TODO: clip, then fill row by row using the stride */
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/*USER_CODE*/

#define GUARD 64
#define PAD_MARK 0xEE
#define CANARY 0xA5
static uint8_t arena[GUARD + 16 * 40 + GUARD];

int main(void)
{
    int width, height, stride, q;
    if (scanf("%d %d %d %d", &width, &height, &stride, &q) != 4) return 0;
    memset(arena, CANARY, sizeof arena);
    uint8_t *fb = arena + GUARD;
    for (int r = 0; r < height; r++)
        for (int c = 0; c < stride; c++)
            fb[r * stride + c] = c < width ? (uint8_t)'.' : (uint8_t)PAD_MARK;

    for (int i = 0; i < q; i++) {
        int x, y, w, h;
        char col;
        if (scanf("%d %d %d %d %c", &x, &y, &w, &h, &col) != 5) return 0;
        fb_fill_rect(fb, width, height, stride, x, y, w, h, (uint8_t)col);
    }

    for (size_t k = 0; k < sizeof arena; k++) {
        int inside = k >= GUARD && k < (size_t)(GUARD + height * stride);
        if (!inside && arena[k] != CANARY) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    for (int r = 0; r < height; r++)
        for (int c = width; c < stride; c++)
            if (fb[r * stride + c] != PAD_MARK) {
                printf("PADDING WRITE\n");
                return 0;
            }
    for (int r = 0; r < height; r++)
        printf("%.*s\n", width, (const char *)(fb + r * stride));
    return 0;
}
@@@ sample_input
6 4 8 2
1 1 3 2 #
-2 -1 4 2 o
@@@ sample_output
oo....
.###..
.###..
......

@@@ sample_input
4 3 4 1
0 0 4 3 a
@@@ sample_output
aaaa
aaaa
aaaa

@@@ hidden_input
5 2 7 3
5 0 3 1 x
0 2 1 1 x
-3 0 3 2 x
@@@ hidden_output
.....
.....

@@@ hidden_input
3 3 3 2
0 0 0 3 z
1 1 -2 2 z
@@@ hidden_output
...
...
...

@@@ hidden_input
4 2 6 1
-1000000000 -1000000000 2000000000 2000000000 *
@@@ hidden_output
****
****

@@@ hidden_input
1 1 1 2
0 0 1 1 Q
0 0 5 5 R
@@@ hidden_output
R

@@@ hidden_input
8 5 12 3
0 0 8 5 -
2 1 4 3 +
7 4 9 9 E
@@@ hidden_output
--------
--++++--
--++++--
--++++--
-------E

@@@ hidden_input
5 3 9 2
3 0 10 3 #
0 2 2 10 @
@@@ hidden_output
...##
...##
@@.##

@@@ hidden_input
32 16 40 2
31 15 1 1 X
0 0 1 1 Y
@@@ hidden_output
Y...............................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
...............................X

@@@ hint
First compute the visible part as a half-open box: `x0 = max(x, 0)`, `x1 = min(x + w, width)`, and the same for y. If `x0 >= x1` or `y0 >= y1`, there is nothing to draw.
@@@ hint
Then, for each row `r` in `[y0, y1)`, get the row pointer `uint8_t *row = fb + (size_t)r * stride;` and fill `row[x0 .. x1)`. Rows are `stride` bytes apart, **not** `width`.
@@@ solution_code
#include <stdint.h>

void fb_fill_rect(uint8_t *fb, int width, int height, int stride,
                  int x, int y, int w, int h, uint8_t color)
{
    if (fb == 0 || w <= 0 || h <= 0)
        return;

    /* clip to [0, width) x [0, height); |x|,|w| <= 1e9 so x + w cannot overflow */
    int x0 = x < 0 ? 0 : x;
    int y0 = y < 0 ? 0 : y;
    int x1 = x + w > width ? width : x + w;
    int y1 = y + h > height ? height : y + h;
    if (x0 >= x1 || y0 >= y1)
        return;

    for (int r = y0; r < y1; r++) {
        uint8_t *row = fb + (size_t)r * (size_t)stride;   /* stride, NOT width */
        for (uint8_t *p = row + x0, *end = row + x1; p < end; p++)
            *p = color;
    }
}
@@@ explanation_md
**Approach.** A 2-D image in a 1-D buffer is addressed as `base + y * stride + x`. The **stride** (also called *pitch* or *line length*) is the distance in bytes between the starts of two consecutive rows. It is often larger than the visible width because of alignment, DMA burst sizes, or a framebuffer that is a window into a larger canvas.

1. **Clip once** with half-open bounds: `[max(x,0), min(x+w,width)) x [max(y,0), min(y+h,height))`. An empty box means nothing to do.
2. **Fill row by row** through a row pointer. Only the clipped pixels are visited, so the cost is O(visible pixels), even for a 10^9 x 10^9 rectangle.

**Complexity.** Time O(clipped area) <= O(width * height). Space O(1).

**Common mistakes**
- Using `y * width` instead of `y * stride`. With `stride == width` the tests pass, but on padded buffers every row is shifted and the padding gets overwritten (`PADDING WRITE`).
- Looping over the full rectangle and testing each pixel. That is correct, but O(w*h) = 10^18 iterations: time limit exceeded.
- Clipping only the right/bottom edges. Negative `x`/`y` then index **before** the framebuffer (`OUT OF BOUNDS WRITE`).
- Forgetting that `w <= 0` / `h <= 0` means "empty". With `x1 = x + w < x0`, a `!=` loop condition runs away.
- Computing `x + w` on unbounded inputs. Here the constraints keep it in range; in production you would clip `w` as `width - x0` without forming `x + w`.

**Interview follow-ups**
- How would you use `memset(row + x0, color, x1 - x0)` here, and what changes for a 16-bit RGB565 framebuffer (`uint16_t *`, stride still in **bytes**)?
- Write `blit()` that copies a sub-rectangle between two framebuffers with different strides, including clipping on both. Which overlap case needs `memmove`?
- Why do display controllers and DMA2D engines require the stride to be a multiple of 4 or 32 bytes?
- How do you pass a framebuffer to a function as `uint8_t (*fb)[STRIDE]` (pointer to row), and what does `fb + 1` then mean?
