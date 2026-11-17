@@@ meta
id: MEM-M-01
topic: Dynamic Memory
difficulty: Medium
type: FUNCTION
title: Growable Int Vector With Doubling and Shrink Hysteresis
tags: realloc, dynamic-array, amortized-analysis, vector, capacity-doubling
@@@ statement_md
Implement a resizable array of `int` (like C++ `std::vector`) on top of `realloc`:

```c
struct ivec {
    int *data;   /* heap block of cap ints (NULL when cap == 0) */
    size_t len;  /* elements in use */
    size_t cap;  /* elements allocated */
};

int  ivec_push(struct ivec *v, int x);    /* append; 0 on success, -1 if out of memory */
int  ivec_pop(struct ivec *v, int *out);  /* remove last into *out; 0, or -1 if empty */
void ivec_free(struct ivec *v);           /* release; leave v as {NULL, 0, 0} */
```

A vector starts as `{NULL, 0, 0}`. The capacity policy is fixed so the harness can check it:

- **Grow** in `ivec_push` when `len == cap`: the new capacity is `4` if `cap == 0`, otherwise `2 * cap`.
- **Shrink** in `ivec_pop` after removing the element: if `cap > 4` and `len <= cap / 4`, the new capacity is `cap / 2`. (This hysteresis stops a push/pop at the boundary from reallocating every time.)
- If a `realloc` fails, the vector must stay valid and unchanged (`ivec_push` returns `-1`). A failed shrink is simply ignored.

**How it is tested.** The hidden harness runs a script of operations on one vector. After every operation it prints `cap A->B` if the capacity changed. At the end it calls your `ivec_free`.

**Input (read by the hidden harness)**, one operation per line:
- `P x`: push `x`.
- `R n seed`: push `n` pseudo-random values in `0..999` (from an LCG), then print `pushed n`.
- `O`: pop one; prints `pop <x>` or `empty`.
- `Q k`: pop up to `k` values; prints `popped <count> sum=<sum>`.
- `S`: prints `len=<len> cap=<cap>`, plus ` first=<data[0]> last=<data[len-1]> sum=<sum>` when `len > 0`.
- `F`: calls `ivec_free`, then prints `free ok` if the vector was reset to `{NULL, 0, 0}`.

**Example**
```
Input:
P 10
P 20
P 30
P 40
P 50
S
O
O
O
S

Output:
cap 0->4
cap 4->8
len=5 cap=8 first=10 last=50 sum=150
pop 50
pop 40
pop 30
cap 8->4
len=2 cap=4 first=10 last=20 sum=30
```
@@@ constraints_md
- At most 300000 elements in the vector, at most 300 script lines.
- Use `realloc` (or `malloc`/`free`). Growing by a constant amount instead of doubling is too slow for the large tests.
- Everything must be freed by `ivec_free`. Leak checking is always on.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

struct ivec {
    int *data;
    size_t len;
    size_t cap;
};

int ivec_push(struct ivec *v, int x)
{
    /* TODO: grow (0 -> 4, then x2) when full, then append */
    return -1;
}

int ivec_pop(struct ivec *v, int *out)
{
    /* TODO: remove the last element; shrink to cap/2 if cap > 4 && len <= cap/4 */
    return -1;
}

void ivec_free(struct ivec *v)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

/*USER_CODE*/

static void report_cap(size_t before, const struct ivec *v)
{
    if (v->cap != before)
        printf("cap %zu->%zu\n", before, v->cap);
}

int main(void)
{
    struct ivec v = { NULL, 0, 0 };
    char op[4];

    while (scanf("%3s", op) == 1) {
        size_t before = v.cap;
        if (op[0] == 'P') {
            int x;
            if (scanf("%d", &x) != 1)
                break;
            if (ivec_push(&v, x) != 0)
                printf("push failed\n");
            report_cap(before, &v);
        } else if (op[0] == 'R') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            for (int i = 0; i < n; i++) {
                seed = seed * 1103515245u + 12345u;
                size_t b = v.cap;
                if (ivec_push(&v, (int)((seed >> 16) % 1000u)) != 0) {
                    printf("push failed\n");
                    break;
                }
                report_cap(b, &v);
            }
            printf("pushed %d\n", n);
        } else if (op[0] == 'O') {
            int x;
            if (ivec_pop(&v, &x) == 0)
                printf("pop %d\n", x);
            else
                printf("empty\n");
            report_cap(before, &v);
        } else if (op[0] == 'Q') {
            int k, cnt = 0;
            long long sum = 0;
            if (scanf("%d", &k) != 1)
                break;
            for (int i = 0; i < k; i++) {
                int x;
                size_t b = v.cap;
                if (ivec_pop(&v, &x) != 0)
                    break;
                cnt++;
                sum += x;
                report_cap(b, &v);
            }
            printf("popped %d sum=%lld\n", cnt, sum);
        } else if (op[0] == 'S') {
            printf("len=%zu cap=%zu", v.len, v.cap);
            if (v.len > 0) {
                long long sum = 0;
                for (size_t i = 0; i < v.len; i++)
                    sum += v.data[i];
                printf(" first=%d last=%d sum=%lld", v.data[0], v.data[v.len - 1], sum);
            }
            printf("\n");
        } else if (op[0] == 'F') {
            ivec_free(&v);
            if (v.data == NULL && v.len == 0 && v.cap == 0)
                printf("free ok\n");
            else
                printf("FAIL: vector not reset by ivec_free\n");
        }
        if (v.len > v.cap)
            printf("FAIL: len > cap\n");
    }
    ivec_free(&v);
    return 0;
}
@@@ sample_input
P 10
P 20
P 30
P 40
P 50
S
O
O
O
S
@@@ sample_output
cap 0->4
cap 4->8
len=5 cap=8 first=10 last=50 sum=150
pop 50
pop 40
pop 30
cap 8->4
len=2 cap=4 first=10 last=20 sum=30

@@@ sample_input
O
S
P -7
O
O
S
@@@ sample_output
empty
len=0 cap=0
cap 0->4
pop -7
empty
len=0 cap=4

@@@ hidden_input
P 2147483647
P -2147483648
S
F
S
P 1
S
@@@ hidden_output
cap 0->4
len=2 cap=4 first=2147483647 last=-2147483648 sum=-1
free ok
len=0 cap=0
cap 0->4
len=1 cap=4 first=1 last=1 sum=1

@@@ hidden_input
P 1
P 2
P 3
P 4
P 5
P 6
P 7
P 8
P 9
O
P 9
O
P 9
S
Q 7
S
@@@ hidden_output
cap 0->4
cap 4->8
cap 8->16
pop 9
pop 9
len=9 cap=16 first=1 last=9 sum=45
cap 16->8
cap 8->4
popped 7 sum=42
len=2 cap=4 first=1 last=2 sum=3

@@@ hidden_input
R 100 1
S
Q 100
S
@@@ hidden_output
cap 0->4
cap 4->8
cap 8->16
cap 16->32
cap 32->64
cap 64->128
pushed 100
len=100 cap=128 first=838 last=289 sum=49808
cap 128->64
cap 64->32
cap 32->16
cap 16->8
cap 8->4
popped 100 sum=49808
len=0 cap=4

@@@ hidden_input
R 300000 7
S
Q 299990
S
F
@@@ hidden_output
cap 0->4
cap 4->8
cap 8->16
cap 16->32
cap 32->64
cap 64->128
cap 128->256
cap 256->512
cap 512->1024
cap 1024->2048
cap 2048->4096
cap 4096->8192
cap 8192->16384
cap 16384->32768
cap 32768->65536
cap 65536->131072
cap 131072->262144
cap 262144->524288
pushed 300000
len=300000 cap=524288 first=332 last=353 sum=149158824
cap 524288->262144
cap 262144->131072
cap 131072->65536
cap 65536->32768
cap 32768->16384
cap 16384->8192
cap 8192->4096
cap 4096->2048
cap 2048->1024
cap 1024->512
cap 512->256
cap 256->128
cap 128->64
cap 64->32
popped 299990 sum=149152990
len=10 cap=32 first=332 last=681 sum=5834
free ok

@@@ hidden_input
R 33 99
S
O
Q 24
S
Q 10
S
@@@ hidden_output
cap 0->4
cap 4->8
cap 8->16
cap 16->32
cap 32->64
pushed 33
len=33 cap=64 first=592 last=501 sum=13278
pop 501
cap 64->32
cap 32->16
popped 24 sum=9907
len=8 cap=16 first=592 last=267 sum=2870
cap 16->8
cap 8->4
popped 8 sum=2870
len=0 cap=4

@@@ hint
Grow with `realloc(v->data, newcap * sizeof *v->data)`, but **into a temporary** pointer. Only after checking it is not `NULL` do you store it in `v->data` and update `cap`. `realloc(NULL, n)` behaves like `malloc(n)`, so the first push needs no special case.
@@@ hint
Doubling makes `n` pushes cost O(n) copies in total: `4 + 8 + 16 + ... < 2n`. A fixed `+1` or `+16` costs O(n^2). Shrink only when the vector is a **quarter** full, to `cap / 2`. Shrinking at half-full would make push/pop at the boundary realloc every time.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

struct ivec {
    int *data;
    size_t len;
    size_t cap;
};

/* Resize to newcap elements; on failure v is left untouched. */
static int ivec_resize(struct ivec *v, size_t newcap)
{
    if (newcap > SIZE_MAX / sizeof *v->data)
        return -1;                                   /* byte count would overflow */
    int *p = realloc(v->data, newcap * sizeof *p);   /* temp: never lose v->data   */
    if (p == NULL)
        return -1;
    v->data = p;
    v->cap = newcap;
    return 0;
}

int ivec_push(struct ivec *v, int x)
{
    if (v->len == v->cap) {
        size_t newcap = v->cap ? v->cap * 2 : 4;
        if (newcap < v->cap || ivec_resize(v, newcap) != 0)
            return -1;
    }
    v->data[v->len++] = x;
    return 0;
}

int ivec_pop(struct ivec *v, int *out)
{
    if (v->len == 0)
        return -1;
    *out = v->data[--v->len];
    if (v->cap > 4 && v->len <= v->cap / 4)
        (void)ivec_resize(v, v->cap / 2);            /* failed shrink: keep the bigger block */
    return 0;
}

void ivec_free(struct ivec *v)
{
    free(v->data);
    v->data = NULL;
    v->len = 0;
    v->cap = 0;
}
@@@ explanation_md
**Approach.** Keep `len <= cap`. On push into a full vector, `realloc` to twice the capacity (4 the first time). On pop, shrink to half once the vector is only a quarter full. Every `realloc` result goes into a temporary pointer, so a failure leaves the old block, and the vector, intact.

**Why doubling?** Each element is copied at most once per growth step after it was inserted. Growing to `n` costs `4 + 8 + ... + n/2 + n < 2n` element copies, so **amortized O(1) per push**. Growing by a constant `c` costs `n^2 / (2c)` copies. The 300000-element test then copies about 45 billion bytes and times out.

**Why shrink at 1/4, not 1/2?** With "shrink at half", a vector at exactly `cap/2 + 1` elements that does pop, push, pop, push... would realloc on **every** operation (thrashing). The gap between the grow point (full) and the shrink point (a quarter full) guarantees about `cap/4` cheap operations between two reallocations.

**Complexity.** Push/pop are amortized O(1) and worst case O(n) (one realloc). Space is O(n): `cap <= 4 * len` once shrinking has settled.

**Common mistakes**
- `v->data = realloc(v->data, ...)`. If `realloc` fails, the only pointer to the old block is overwritten with `NULL`, which leaks the block and loses all elements.
- Updating `cap` before the `realloc` succeeds.
- `realloc(v->data, newcap)`: bytes instead of elements (missing `* sizeof *v->data`), a classic heap overflow.
- Forgetting the `newcap * sizeof(int)` overflow check on 32-bit targets, where `size_t` is 32 bits.
- `ivec_free` that does not reset the fields. A later push then writes into freed memory, or a second free double-frees.

**Interview follow-ups**
- Prove the amortized O(1) bound with the potential method. Does a growth factor of 1.5 (used by MSVC and folly) change the bound? Why might 1.5 reuse freed memory better?
- Make it generic: `vec_push(struct vec *v, const void *elem)` with an `elem_size`. Which alignment pitfalls appear?
- In an ECU without a heap, what replaces this? (A fixed-capacity array with an explicit "full" error, sized at build time from the worst case.)
