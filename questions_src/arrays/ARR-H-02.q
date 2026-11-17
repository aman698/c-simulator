@@@ meta
id: ARR-H-02
topic: Arrays
difficulty: Hard
type: FUNCTION
title: Sliding-Window Peak-to-Peak With Monotonic Deques
tags: embedded, sliding-window, monotonic-deque, circular-index, vibration-monitoring
@@@ statement_md
A bearing-wear monitor samples an accelerometer and computes the **peak-to-peak amplitude** (max minus min) over the last `k` samples, for every window position. A brute-force rescan of each window costs O(n*k), which is far too slow for `n = 10^6` samples and `k` up to `n`.

Implement

```c
void window_p2p(const int16_t *x, int n, int k, int32_t *out, int *work);
```

- For every `i` in `k-1 .. n-1`, write `out[i - k + 1] = max(x[i-k+1..i]) - min(x[i-k+1..i])`. That is `n - k + 1` outputs.
- `work` is caller-provided scratch space of **exactly `2 * k` ints**. Use it for your two deques. Do not use any other memory that grows with `n` or `k` (no static or global arrays, no `malloc`).
- The total time must be O(n), independent of `k`.

**How it is tested.** A hidden `main()` calls your function once. `work` is surrounded by guard words, so touching `work[2k]` or beyond is reported as `OUT OF BOUNDS WRITE`. Small tests print every output. Large generated tests compare with a reference and print `OK checksum=...`.

**Input (read by the hidden harness)**
- Either: line 1 `n k`, line 2 the `n` samples,
- or: one line `GEN n k seed`.

**Output**
- The `n - k + 1` peak-to-peak values on one line, or `OK checksum=X` / `WRONG at i`.

**Example**
```
Input:
8 3
1 3 -1 -3 5 3 6 7

Output:
4 6 8 8 3 4
```
Window `[-1 -3 5]` has max 5 and min -3, so its peak-to-peak value is 8.
@@@ constraints_md
- `1 <= k <= n <= 1000000`
- `-32768 <= x[i] <= 32767` (`int16_t`), so a result can be up to 65535
- O(n) time, O(k) extra memory, only inside `work[0 .. 2k-1]`
@@@ starter_code
#include <stdint.h>

/* out[i-k+1] = max - min of x[i-k+1..i] for i = k-1..n-1.
 * work: scratch space for exactly 2*k ints. */
void window_p2p(const int16_t *x, int n, int k, int32_t *out, int *work)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

/*USER_CODE*/

#define MAXN 1000000
#define GUARD 16
#define CANARY 0x2BADC0DE

static int16_t x[MAXN];
static int32_t out[MAXN + GUARD];
static int work_arena[GUARD + 2 * MAXN + GUARD];
static int rq_max[MAXN], rq_min[MAXN];

int main(void)
{
    char tok[16];
    int n, k;
    int gen = 0;
    if (scanf("%15s", tok) != 1) return 0;
    if (strcmp(tok, "GEN") == 0) {
        unsigned int seed;
        if (scanf("%d %d %u", &n, &k, &seed) != 3) return 0;
        if (n < 1 || n > MAXN || k < 1 || k > n) return 0;
        gen = 1;
        uint32_t s = seed;
        int32_t level = 0;
        for (int i = 0; i < n; i++) {               /* random walk + noise, clamped */
            s = s * 1103515245u + 12345u;
            level += (int32_t)((s >> 16) % 201u) - 100;
            if (level > 30000) level = 30000;
            if (level < -30000) level = -30000;
            int32_t v = level + (int32_t)((s >> 8) % 5001u) - 2500;
            if (v > 32767) v = 32767;
            if (v < -32768) v = -32768;
            x[i] = (int16_t)v;
        }
    } else {
        if (sscanf(tok, "%d", &n) != 1 || scanf("%d", &k) != 1) return 0;
        if (n < 1 || n > MAXN || k < 1 || k > n) return 0;
        for (int i = 0; i < n; i++) {
            int v;
            if (scanf("%d", &v) != 1) return 0;
            x[i] = (int16_t)v;
        }
    }
    int m = n - k + 1;
    for (int i = 0; i < GUARD + 2 * k + GUARD; i++) work_arena[i] = CANARY;
    for (int i = 0; i < m + GUARD; i++) out[i] = CANARY;

    window_p2p(x, n, k, out, work_arena + GUARD);

    for (int i = 0; i < GUARD; i++) {
        if (work_arena[i] != CANARY || work_arena[GUARD + 2 * k + i] != CANARY || out[m + i] != CANARY) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
    }
    if (!gen) {
        for (int i = 0; i < m; i++) printf("%d%c", (int)out[i], i == m - 1 ? '\n' : ' ');
        return 0;
    }
    /* reference: monotonic deques over plain arrays */
    int fa = 0, ba = 0, fi = 0, bi = 0;
    uint64_t checksum = 0;
    for (int i = 0; i < n; i++) {
        while (ba > fa && x[rq_max[ba - 1]] <= x[i]) ba--;
        rq_max[ba++] = i;
        while (bi > fi && x[rq_min[bi - 1]] >= x[i]) bi--;
        rq_min[bi++] = i;
        if (rq_max[fa] <= i - k) fa++;
        if (rq_min[fi] <= i - k) fi++;
        if (i >= k - 1) {
            int32_t want = (int32_t)x[rq_max[fa]] - (int32_t)x[rq_min[fi]];
            if (out[i - k + 1] != want) {
                printf("WRONG at %d: got %d, expected %d\n", i - k + 1, (int)out[i - k + 1], (int)want);
                return 0;
            }
            checksum = checksum * 1000003u + (uint64_t)want;
        }
    }
    printf("OK checksum=%llu\n", (unsigned long long)checksum);
    return 0;
}
@@@ sample_input
8 3
1 3 -1 -3 5 3 6 7
@@@ sample_output
4 6 8 8 3 4

@@@ sample_input
5 1
10 -10 0 32767 -32768
@@@ sample_output
0 0 0 0 0

@@@ hidden_input
4 4
-32768 0 32767 5
@@@ hidden_output
65535

@@@ hidden_input
1 1
-7
@@@ hidden_output
0

@@@ hidden_input
6 2
5 5 5 5 5 5
@@@ hidden_output
0 0 0 0 0

@@@ hidden_input
6 3
6 5 4 3 2 1
@@@ hidden_output
2 2 2 2

@@@ hidden_input
7 3
2 7 7 1 7 1 1
@@@ hidden_output
5 6 6 6 6

@@@ hidden_input
9 4
-32768 32767 -32768 32767 0 0 0 0 1
@@@ hidden_output
65535 65535 65535 32767 0 1

@@@ hidden_input
GEN 1000000 1000 1
@@@ hidden_output
OK checksum=333973820590791636

@@@ hidden_input
GEN 1000000 500000 2
@@@ hidden_output
OK checksum=15403965319965924899

@@@ hidden_input
GEN 1000000 999999 3
@@@ hidden_output
OK checksum=64964259856

@@@ hidden_input
GEN 300000 2 4
@@@ hidden_output
OK checksum=15009235160889323962

@@@ hint
For the maximum, keep a deque of **indices** whose samples are strictly decreasing from front to back. Before pushing `i`, pop from the back every index whose sample is `<= x[i]`: those can never be the maximum again while `i` is in the window. The front is the current maximum. Drop it once it falls out of the window (`front <= i - k`). The minimum uses a mirrored deque.
@@@ hint
At most `k` indices are alive at any time, so each deque fits in `k` ints if you store it as a **ring**: keep a head position and a length, and wrap positions with `if (p == k) p = 0;`. Expire the old front *before* pushing `i`. Then a deque never holds more than `k` entries. Each index is pushed and popped at most once, which gives O(n) in total.
@@@ solution_code
#include <stdint.h>

/* ring deque of indices living in a caller-provided array of 'cap' ints */
typedef struct {
    int *buf;
    int cap;
    int head;   /* position of the front element */
    int len;    /* number of elements            */
} ring_dq_t;

static int dq_pos(const ring_dq_t *d, int off)
{
    int p = d->head + off;
    return p >= d->cap ? p - d->cap : p;
}

static int dq_front(const ring_dq_t *d) { return d->buf[d->head]; }
static int dq_back(const ring_dq_t *d) { return d->buf[dq_pos(d, d->len - 1)]; }

static void dq_pop_front(ring_dq_t *d)
{
    d->head = dq_pos(d, 1);
    d->len--;
}

static void dq_push_back(ring_dq_t *d, int v)
{
    d->buf[dq_pos(d, d->len)] = v;
    d->len++;
}

void window_p2p(const int16_t *x, int n, int k, int32_t *out, int *work)
{
    ring_dq_t mx = { work, k, 0, 0 };        /* indices, samples strictly decreasing  */
    ring_dq_t mn = { work + k, k, 0, 0 };    /* indices, samples strictly increasing  */

    for (int i = 0; i < n; i++) {
        /* 1) expire the index that just left the window (at most one per step) */
        if (mx.len > 0 && dq_front(&mx) <= i - k) dq_pop_front(&mx);
        if (mn.len > 0 && dq_front(&mn) <= i - k) dq_pop_front(&mn);

        /* 2) remove dominated candidates from the back, then push i (len <= k holds) */
        while (mx.len > 0 && x[dq_back(&mx)] <= x[i]) mx.len--;
        dq_push_back(&mx, i);
        while (mn.len > 0 && x[dq_back(&mn)] >= x[i]) mn.len--;
        dq_push_back(&mn, i);

        /* 3) the fronts are the window max and min; widen before subtracting */
        if (i >= k - 1)
            out[i - k + 1] = (int32_t)x[dq_front(&mx)] - (int32_t)x[dq_front(&mn)];
    }
}
@@@ explanation_md
**Approach: two monotonic deques.** For the window maximum, keep candidate indices whose samples **strictly decrease** from front to back. When `x[i]` arrives, every back entry with `x[j] <= x[i]` is dominated: `i` is newer and at least as large, so `j` can never be a maximum again. Pop those and push `i`. The front is the window maximum; remove it once its index is `<= i - k`. The minimum deque is the mirror image. Peak-to-peak is `x[front_max] - x[front_min]`.

```
x = 1 3 -1 -3 5 ...   k = 3
i=2 max-dq [3,-1]      min-dq [-1]       -> 3 - (-1) = 4
i=3 max-dq [3,-1,-3]   min-dq [-3]       -> 6
i=4 max-dq [5]         min-dq [-3,5]     -> 8
```

**O(k) memory in a fixed buffer.** The live indices always lie in `(i-k, i]`, so each deque holds at most `k` entries. If the expired front is removed **before** the push, the deque never exceeds `k`. That is why it can be a ring of exactly `k` ints. A deque that only grows to the right would need `n` slots.

**Complexity.** Time O(n) amortised: each index is pushed once and popped at most once per deque, whatever `k` is. Space O(k), in `work`.

**Common mistakes**
- Storing **values** instead of indices. You then cannot tell when the front has left the window, especially with duplicates.
- Expiring after the push. The deque briefly holds `k + 1` entries and writes `work[2k]`, which the guard catches.
- Using `<` instead of `<=` when popping (or the reverse in the min deque). It is still correct, but duplicates pile up; with `k = n` and constant input the ring overflows its `k` slots if expiry is also late.
- `int16_t` result: `32767 - (-32768) = 65535` does not fit. Widen before subtracting.
- O(n*k) rescans: for `k = 500 000` that is 5 * 10^11 operations.

**Interview follow-ups**
- Return the **longest** window whose peak-to-peak stays below a threshold (two pointers plus the same two deques).
- A streaming version for an ISR: one sample in, one p2p value out, O(1) amortised. What is the worst-case time of a single call, and why does that matter for interrupt latency? (The back-pop loop can take O(k) once.)
- Compare with a van Herk/Gil-Werman block algorithm (3 comparisons per sample, worst-case bounded) for hard real-time use.
- How do you extend this to a **sliding median**? (Two heaps or an order-statistic structure; see the median-filter question.)
