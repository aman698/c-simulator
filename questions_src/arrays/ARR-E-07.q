@@@ meta
id: ARR-E-07
topic: Arrays
difficulty: Easy
type: PREDICT_OUTPUT
title: sizeof on an Array Parameter (ADC Buffer)
tags: embedded, sizeof, array-decay, array-size-macro, memset
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `uint16_t` = 2 bytes**.

```c
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static size_t count_in_func(uint16_t samples[8])
{
    return ARRAY_SIZE(samples);
}

static void clear_buffer(uint16_t buf[8])
{
    memset(buf, 0xFF, sizeof buf);      /* meant to fill all 8 samples */
}

int main(void)
{
    uint16_t samples[8] = {0};
    uint16_t *p = samples;
    char tag[] = "ADC1";

    printf("%zu %zu %zu\n", sizeof samples, ARRAY_SIZE(samples), count_in_func(samples));
    printf("%zu %zu %zu\n", sizeof p, sizeof *p, sizeof tag);

    clear_buffer(samples);
    printf("%u %u\n", (unsigned)samples[3], (unsigned)samples[4]);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, `sizeof(uint16_t *)` = 8, `sizeof(uint16_t)` = 2.
- The program compiles. gcc does print warnings for it; whether they matter is part of the question.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static size_t count_in_func(uint16_t samples[8])
{
    return ARRAY_SIZE(samples);
}

static void clear_buffer(uint16_t buf[8])
{
    memset(buf, 0xFF, sizeof buf);      /* meant to fill all 8 samples */
}

int main(void)
{
    uint16_t samples[8] = {0};
    uint16_t *p = samples;
    char tag[] = "ADC1";

    printf("%zu %zu %zu\n", sizeof samples, ARRAY_SIZE(samples), count_in_func(samples));
    printf("%zu %zu %zu\n", sizeof p, sizeof *p, sizeof tag);

    clear_buffer(samples);
    printf("%u %u\n", (unsigned)samples[3], (unsigned)samples[4]);
    return 0;
}
@@@ predict_answer
16 8 4
8 2 5
65535 0
@@@ hint
A parameter declared as `uint16_t samples[8]` is **adjusted** by the compiler to `uint16_t *samples`. The `8` is ignored.
@@@ hint
Inside the functions, `sizeof samples` and `sizeof buf` are the size of a pointer (8), not of the array (16). `memset` therefore clears only 8 bytes, which is 4 samples.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

/* The parameter is really 'uint16_t *samples' (C11 6.7.6.3p7):
 * ARRAY_SIZE = sizeof(uint16_t *) / sizeof(uint16_t) = 8 / 2 = 4, not 8. */
static size_t count_in_func(uint16_t samples[8])
{
    return ARRAY_SIZE(samples);
}

/* sizeof buf == 8 (a pointer), so only bytes 0..7 = samples[0..3] are set to 0xFF. */
static void clear_buffer(uint16_t buf[8])
{
    memset(buf, 0xFF, sizeof buf);
}

int main(void)
{
    uint16_t samples[8] = {0};
    uint16_t *p = samples;
    char tag[] = "ADC1";                 /* 4 chars + '\0' = 5 bytes */

    /* a real array here: 8 * 2 = 16 bytes, 8 elements; in the function: 4 */
    printf("%zu %zu %zu\n", sizeof samples, ARRAY_SIZE(samples), count_in_func(samples)); /* 16 8 4 */
    /* pointer = 8, pointee = 2, char array including the terminator = 5 */
    printf("%zu %zu %zu\n", sizeof p, sizeof *p, sizeof tag);                           /* 8 2 5 */

    clear_buffer(samples);
    /* samples[0..3] = 0xFFFF = 65535, samples[4..7] are still 0 */
    printf("%u %u\n", (unsigned)samples[3], (unsigned)samples[4]);                     /* 65535 0 */
    return 0;
}
@@@ explanation_md
**Answer:**
```
16 8 4
8 2 5
65535 0
```

**Why.** An array is not a pointer, but two rules make it look like one:
1. In most expressions an array **decays** to a pointer to its first element. The exceptions are `sizeof`, unary `&`, and a string literal used to initialise an array (C11 6.3.2.1p3).
2. A function parameter declared with array type is **adjusted** to a pointer (C11 6.7.6.3p7). `uint16_t samples[8]` in a parameter list *means* `uint16_t *samples`. The `8` is documentation only.

| expression | where | value |
|---|---|---|
| `sizeof samples` | `main`, real array | 8 * 2 = **16** |
| `ARRAY_SIZE(samples)` | `main` | 16 / 2 = **8** |
| `ARRAY_SIZE(samples)` | inside function | 8 / 2 = **4** |
| `sizeof p` / `sizeof *p` | pointer / pointee | **8** / **2** |
| `sizeof tag` | `"ADC1"` plus NUL | **5** |

`memset(buf, 0xFF, sizeof buf)` fills only `sizeof(uint16_t *)` = 8 bytes, which is the first **four** samples. So `samples[3] == 0xFFFF == 65535` and `samples[4]` is still `0`. This is a classic field bug: half of a DMA or CAN buffer is "cleared", and the stale half causes intermittent faults.

**Complexity.** N/A (`sizeof` is evaluated at compile time; no runtime cost).

**Common mistakes**
- Believing that `uint16_t buf[8]` in a parameter keeps the size. It does not, and `sizeof buf` inside the function is always the pointer size.
- Ignoring the compiler warnings `-Wsizeof-array-argument` and `-Wsizeof-pointer-memaccess`. They point exactly at these lines. Treat them as errors in production builds.
- Forgetting the `'\0'` in `sizeof "ADC1"` (5, not 4). `strlen` gives 4.

**Interview follow-ups**
- How do you pass an array so that the callee *does* know the size? (Pass `n` explicitly; pass a pointer to the whole array `uint16_t (*buf)[8]` so that `sizeof *buf == 16`; or wrap it in a struct.)
- Write an `ARRAY_SIZE` macro that **fails to compile** when given a pointer. (GCC/Linux-kernel trick with `__builtin_types_compatible_p`, or C11 `_Static_assert` with `_Generic`.)
- What does `void f(int a[static 8])` promise to the compiler, and does it change `sizeof a`?
