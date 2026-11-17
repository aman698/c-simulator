@@@ meta
id: PTR-M-03
topic: Pointers
difficulty: Medium
type: FUNCTION
title: Generic Swap and Reverse with void Pointers and Element Size
tags: void-pointer, generic-programming, pointer-arithmetic, swap, aliasing
@@@ statement_md
Write two **type-agnostic** utilities, in the style of `qsort`'s interface:

```c
void gswap(void *a, void *b, size_t size);
void greverse(void *base, size_t n, size_t size);
```

- `gswap` exchanges the contents of two objects of `size` bytes each.
  - `a == b` must leave the object unchanged. `size == 0` does nothing.
  - The two objects are either identical (`a == b`) or do not overlap.
  - `size` can be large (up to 100000 bytes). Use **O(1) extra memory**: no `malloc`, no VLA, no buffer that grows with `size`.
- `greverse` reverses an array of `n` elements of `size` bytes each, in place.
  - `n` may be `0` or `1`. When `n == 0`, `base` may be `NULL`. `size == 0` does nothing.

**How it is tested.** A hidden `main()` keeps an `int` array, a `double` array and an array of `struct rec { char tag[5]; int id; double gain; }` (24 bytes with padding). It runs commands that call your functions and prints the arrays. Large `gswap` calls are checked against saved copies. Any write outside the arrays is reported.

**Input (read by the hidden harness)**: one command per line, until end of input.
- `I n v1..vn` / `D n v1..vn`: load the int / double array (prints nothing).
- `P n` followed by `n` lines `tag id gain`: load the record array (prints nothing).
- `rev T` (`T` is `i`, `d` or `r`): `greverse` on that array, then print it.
- `swp T x y`: `gswap(&arr[x], &arr[y], sizeof arr[0])`, then print the array.
- `zero`: `greverse(ints, n, 0)` and `gswap(&ints[0], &ints[n-1], 0)`, then print the int array.
- `nullrev`: `greverse(NULL, 0, sizeof(int))`, then print `ok`.
- `B size seed` / `A size seed`: swap two heap blocks of `size` bytes / swap a block with itself. Prints `big ok` / `alias ok` if correct.

**Output**
- ints as `%d`, doubles as `%.2f`, records as `tag:id:gain` (gain `%.1f`), separated by spaces. An empty array prints `(empty)`.

**Example**
```
Input:
I 5 1 2 3 4 5
rev i
swp i 0 4
swp i 2 2

Output:
5 4 3 2 1
1 4 3 2 5
1 4 3 2 5
```
@@@ constraints_md
- Arrays hold at most 50 elements; `0 <= x, y < n`.
- `1 <= size <= 100000` for `B` / `A`.
- O(1) extra memory in both functions; no `memcpy`/`memmove`/`memset` needed.
@@@ starter_code
#include <stddef.h>

/* Swap two non-overlapping (or identical) objects of `size` bytes. */
void gswap(void *a, void *b, size_t size)
{
    /* TODO */
}

/* Reverse n elements of `size` bytes each, in place. */
void greverse(void *base, size_t n, size_t size)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

/*USER_CODE*/

struct rec {
    char tag[5];
    int id;
    double gain;
};

#define CAP 50
#define G 2
static int ints_arena[G + CAP + G];
static double dbl_arena[G + CAP + G];
static struct rec rec_arena[G + CAP + G];
static int *ints = ints_arena + G;
static double *dbls = dbl_arena + G;
static struct rec *recs = rec_arena + G;
static int ni, nd, nr;
static struct rec rec_guard;

static void reset_guards(void)
{
    for (int k = 0; k < G; k++) {
        ints_arena[k] = ints_arena[G + CAP + k] = 0x6A6A6A6A;
        dbl_arena[k] = dbl_arena[G + CAP + k] = -777.0;
    }
    memset(&rec_guard, 0x5C, sizeof rec_guard);
    for (int k = 0; k < G; k++) {
        rec_arena[k] = rec_guard;
        rec_arena[G + CAP + k] = rec_guard;
    }
}

static int guards_ok(void)
{
    for (int k = 0; k < G; k++) {
        if (ints_arena[k] != 0x6A6A6A6A || ints_arena[G + CAP + k] != 0x6A6A6A6A) return 0;
        if (dbl_arena[k] != -777.0 || dbl_arena[G + CAP + k] != -777.0) return 0;
        if (memcmp(&rec_arena[k], &rec_guard, sizeof rec_guard) != 0) return 0;
        if (memcmp(&rec_arena[G + CAP + k], &rec_guard, sizeof rec_guard) != 0) return 0;
    }
    /* elements beyond the loaded length must stay untouched (zero) */
    for (int k = ni; k < CAP; k++) if (ints[k] != 0) return 0;
    for (int k = nd; k < CAP; k++) if (dbls[k] != 0.0) return 0;
    return 1;
}

static void print_arr(char t)
{
    int n = t == 'i' ? ni : t == 'd' ? nd : nr;
    if (n == 0) {
        printf("(empty)\n");
        return;
    }
    for (int k = 0; k < n; k++) {
        if (t == 'i') printf("%d", ints[k]);
        else if (t == 'd') printf("%.2f", dbls[k]);
        else printf("%s:%d:%.1f", recs[k].tag, recs[k].id, recs[k].gain);
        printf("%c", k == n - 1 ? '\n' : ' ');
    }
}

static unsigned char *lcg_block(size_t size, uint32_t seed)
{
    unsigned char *p = malloc(size);
    if (p == NULL) return NULL;
    uint32_t x = seed;
    for (size_t k = 0; k < size; k++) {
        x = x * 1103515245u + 12345u;
        p[k] = (unsigned char)(x >> 16);
    }
    return p;
}

int main(void)
{
    char cmd[16];
    reset_guards();
    while (scanf("%15s", cmd) == 1) {
        if (strcmp(cmd, "I") == 0 || strcmp(cmd, "D") == 0 || strcmp(cmd, "P") == 0) {
            int n;
            if (scanf("%d", &n) != 1 || n < 0 || n > CAP) return 0;
            if (cmd[0] == 'I') {
                memset(ints, 0, CAP * sizeof *ints);
                ni = n;
                for (int k = 0; k < n; k++) if (scanf("%d", &ints[k]) != 1) return 0;
            } else if (cmd[0] == 'D') {
                for (int k = 0; k < CAP; k++) dbls[k] = 0.0;
                nd = n;
                for (int k = 0; k < n; k++) if (scanf("%lf", &dbls[k]) != 1) return 0;
            } else {
                memset(recs, 0, CAP * sizeof *recs);
                nr = n;
                for (int k = 0; k < n; k++)
                    if (scanf("%4s %d %lf", recs[k].tag, &recs[k].id, &recs[k].gain) != 3) return 0;
            }
        } else if (strcmp(cmd, "rev") == 0) {
            char t;
            if (scanf(" %c", &t) != 1) return 0;
            if (t == 'i') greverse(ints, (size_t)ni, sizeof ints[0]);
            else if (t == 'd') greverse(dbls, (size_t)nd, sizeof dbls[0]);
            else greverse(recs, (size_t)nr, sizeof recs[0]);
            if (!guards_ok()) { printf("OUT OF BOUNDS WRITE\n"); return 0; }
            print_arr(t);
        } else if (strcmp(cmd, "swp") == 0) {
            char t;
            int x, y;
            if (scanf(" %c %d %d", &t, &x, &y) != 3) return 0;
            if (t == 'i') gswap(&ints[x], &ints[y], sizeof ints[0]);
            else if (t == 'd') gswap(&dbls[x], &dbls[y], sizeof dbls[0]);
            else gswap(&recs[x], &recs[y], sizeof recs[0]);
            if (!guards_ok()) { printf("OUT OF BOUNDS WRITE\n"); return 0; }
            print_arr(t);
        } else if (strcmp(cmd, "zero") == 0) {
            greverse(ints, (size_t)ni, 0);
            if (ni > 0) gswap(&ints[0], &ints[ni - 1], 0);
            if (!guards_ok()) { printf("OUT OF BOUNDS WRITE\n"); return 0; }
            print_arr('i');
        } else if (strcmp(cmd, "nullrev") == 0) {
            greverse(NULL, 0, sizeof(int));
            printf("ok\n");
        } else if (strcmp(cmd, "B") == 0 || strcmp(cmd, "A") == 0) {
            int size;
            unsigned seed;
            if (scanf("%d %u", &size, &seed) != 2 || size < 1) return 0;
            unsigned char *x = lcg_block((size_t)size, seed);
            unsigned char *y = lcg_block((size_t)size, seed * 7u + 1u);
            unsigned char *cx = lcg_block((size_t)size, seed);
            unsigned char *cy = lcg_block((size_t)size, seed * 7u + 1u);
            if (x && y && cx && cy) {
                if (cmd[0] == 'B') {
                    gswap(x, y, (size_t)size);
                    int ok = memcmp(x, cy, (size_t)size) == 0 && memcmp(y, cx, (size_t)size) == 0;
                    printf("%s\n", ok ? "big ok" : "big FAIL");
                } else {
                    gswap(x, x, (size_t)size);
                    printf("%s\n", memcmp(x, cx, (size_t)size) == 0 ? "alias ok" : "alias FAIL");
                }
            }
            free(x);
            free(y);
            free(cx);
            free(cy);
        }
    }
    return 0;
}
@@@ sample_input
I 5 1 2 3 4 5
rev i
swp i 0 4
swp i 2 2
@@@ sample_output
5 4 3 2 1
1 4 3 2 5
1 4 3 2 5

@@@ sample_input
D 4 1.5 -2.25 3 0
rev d
swp d 1 3
@@@ sample_output
0.00 3.00 -2.25 1.50
0.00 1.50 -2.25 3.00

@@@ hidden_input
P 3
ecu 7 1.5
abs 12 -0.5
eps 3 2
rev r
swp r 0 1
swp r 2 2
@@@ hidden_output
eps:3:2.0 abs:12:-0.5 ecu:7:1.5
abs:12:-0.5 eps:3:2.0 ecu:7:1.5
abs:12:-0.5 eps:3:2.0 ecu:7:1.5

@@@ hidden_input
B 100000 7
A 4096 9
@@@ hidden_output
big ok
alias ok

@@@ hidden_input
I 1 42
rev i
zero
nullrev
@@@ hidden_output
42
42
ok

@@@ hidden_input
I 0
rev i
I 2 -2147483648 2147483647
rev i
@@@ hidden_output
(empty)
2147483647 -2147483648

@@@ hidden_input
I 6 1 2 3 4 5 6
rev i
I 7 1 2 3 4 5 6 7
rev i
zero
@@@ hidden_output
6 5 4 3 2 1
7 6 5 4 3 2 1
7 6 5 4 3 2 1

@@@ hidden_input
D 2 1 2
swp d 0 0
swp d 1 0
P 0
rev r
@@@ hidden_output
1.00 2.00
2.00 1.00
(empty)

@@@ hidden_input
B 1 3
B 3 5
A 1 1
B 24 11
@@@ hidden_output
big ok
big ok
alias ok
big ok

@@@ hint
You cannot index a `void *`, so convert to `unsigned char *` and swap **byte by byte**: `size` iterations, one `unsigned char` temporary. Element `i` of the array starts at `(unsigned char *)base + i * size`.
@@@ hint
For `greverse`, keep a front pointer at element 0 and a back pointer at element `n - 1`. Swap, then move the front pointer up and the back pointer down by `size` bytes while front < back. Return early when `n < 2` or `size == 0`, so that you never compute `n - 1` on `n == 0`. Check `a == b` first in `gswap`, so that "clever" swaps cannot destroy the data.
@@@ solution_code
#include <stddef.h>

void gswap(void *a, void *b, size_t size)
{
    unsigned char *p = a;
    unsigned char *q = b;

    if (p == q)
        return;                         /* identical object: nothing to do */
    while (size--) {
        unsigned char t = *p;           /* O(1) memory: one byte at a time */
        *p++ = *q;
        *q++ = t;
    }
}

void greverse(void *base, size_t n, size_t size)
{
    if (base == NULL || n < 2 || size == 0)
        return;

    unsigned char *lo = base;                       /* element 0      */
    unsigned char *hi = lo + (n - 1) * size;        /* element n - 1  */
    while (lo < hi) {
        gswap(lo, hi, size);
        lo += size;                                 /* step by ELEMENT size, not by 1 */
        hi -= size;
    }
}
@@@ explanation_md
**Approach.** A generic C routine receives a `void *` plus the element size, exactly like `qsort`, `bsearch` and `memcpy`. All address computations are done in **bytes** on an `unsigned char *`:

```
element i  ->  (unsigned char *)base + i * size
```

`gswap` swaps byte by byte with a single `unsigned char` temporary, so it needs O(1) memory regardless of `size`. A 100000-byte VLA would overflow the stack of a small RTOS task. Swapping whole structs this way also swaps their padding bytes, which is harmless. `greverse` is the classic two-pointer reversal, except that the pointers move by `size` bytes instead of one element.

**Complexity.** `gswap`: time O(size), space O(1). `greverse`: time O(n * size) (n/2 swaps), space O(1).

**Common mistakes**
- Arithmetic on `void *` (`base + i * size`). It compiles with gcc as an extension, but it is not ISO C, clang warns about it, and MISRA forbids it.
- Stepping by 1 instead of `size`, or writing `(int *)base + i` in "generic" code, which silently assumes 4-byte elements.
- XOR swap (`*p ^= *q` ...) without the `a == b` check, which zeroes the object when swapping with itself (the `swp i 2 2` and `A` tests).
- `char tmp[size];` (a VLA) or `malloc(size)` for the temporary. That uses O(size) memory, can overflow the stack, and malloc may fail or be banned (MISRA Rule 21.3).
- Computing `(n - 1) * size` when `n == 0`. It wraps to a huge value, so `hi` points far outside the array.

**Interview follow-ups**
- Speed `gswap` up for large blocks by swapping through a fixed 64-byte stack buffer (`memcpy` in chunks). Why is that still O(1) space?
- Write a generic `insertion_sort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *))` using `gswap`.
- Why does the C standard's `qsort` take the element size as a separate parameter instead of inferring it?
- How would a `SWAP(a, b)` macro based on `__typeof__` (GNU) or C23 `typeof` differ, and what does it give you that `void *` cannot (type checking)?
