@@@ meta
id: PTR-H-07
topic: Pointers
difficulty: Hard
type: FIND_THE_BUG
title: CAN Trace Analyzer Keeps Pointers into a Growing Array
tags: dangling-pointer, realloc, use-after-free, dynamic-array, can
@@@ statement_md
A CAN trace analyzer reads frames (timestamp in ms, 11-bit identifier in hex) until end of input. It stores them in a dynamically growing array (capacity 4, doubled when full). For every frame it remembers the **previous frame with the same identifier**, so that it can print the period between them.

After reading everything, it prints one line per frame, in input order:

```
<t> <ID> first        (no earlier frame with this ID)
<t> <ID> +<period>    (period = t - t_of_previous_frame_with_same_ID)
```

`ID` is printed as at least 3 uppercase hex digits (`%03X`).

Short traces work. Longer traces print absurd periods or abort with a memory error, and the failure starts exactly at the 5th frame. Find and fix the bug. Keep the growing array: the number of frames is not known in advance.

**Input**
- Lines `t id` (decimal `t`, hex `id`) until end of input. Timestamps never decrease.

**Output**
- As described above.

**Example**
```
Input:
0 100
10 100
20 200
30 100
40 200
50 100

Output:
0 100 first
10 100 +10
20 200 first
30 100 +20
40 200 +20
50 100 +20
```
@@@ constraints_md
- At most 10000 frames; `0 <= t <= INT_MAX`; `0 <= id <= 0x7FF`.
- Free all memory before exit.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

struct frame {
    int t;                        /* timestamp, ms */
    unsigned id;                  /* CAN identifier */
    const struct frame *prev;     /* previous frame with the same id, or NULL */
};

struct trace {
    struct frame *v;
    size_t len, cap;
};

/* Append one slot (growing the array if needed) and return it. */
static struct frame *trace_push(struct trace *tr)
{
    if (tr->len == tr->cap) {
        size_t ncap = tr->cap ? tr->cap * 2 : 4;
        struct frame *nv = realloc(tr->v, ncap * sizeof *nv);
        if (nv == NULL)
            return NULL;
        tr->v = nv;
        tr->cap = ncap;
    }
    return &tr->v[tr->len++];
}

/* Most recent frame with this id, or NULL. */
static const struct frame *find_last(const struct trace *tr, unsigned id)
{
    for (size_t i = tr->len; i-- > 0;)
        if (tr->v[i].id == id)
            return &tr->v[i];
    return NULL;
}

int main(void)
{
    struct trace tr = {NULL, 0, 0};
    int t;
    unsigned id;

    while (scanf("%d %x", &t, &id) == 2) {
        const struct frame *prev = find_last(&tr, id);
        struct frame *f = trace_push(&tr);
        if (f == NULL)
            break;
        f->t = t;
        f->id = id;
        f->prev = prev;
    }

    for (size_t i = 0; i < tr.len; i++) {
        const struct frame *f = &tr.v[i];
        if (f->prev != NULL)
            printf("%d %03X +%d\n", f->t, f->id, f->t - f->prev->t);
        else
            printf("%d %03X first\n", f->t, f->id);
    }
    free(tr.v);
    return 0;
}
@@@ sample_input
100 123
110 456
120 123
@@@ sample_output
100 123 first
110 456 first
120 123 +20

@@@ sample_input
0 100
10 100
20 200
30 100
40 200
50 100
@@@ sample_output
0 100 first
10 100 +10
20 200 first
30 100 +20
40 200 +20
50 100 +20

@@@ hidden_input
@@@ hidden_output

@@@ hidden_input
5 7FF
@@@ hidden_output
5 7FF first

@@@ hidden_input
0 1
1 1
2 1
3 1
@@@ hidden_output
0 001 first
1 001 +1
2 001 +1
3 001 +1

@@@ hidden_input
0 0C1
5 0C2
10 0C1
15 0C2
20 0C1
25 0C2
30 0C1
35 0C2
40 0C1
@@@ hidden_output
0 0C1 first
5 0C2 first
10 0C1 +10
15 0C2 +10
20 0C1 +10
25 0C2 +10
30 0C1 +10
35 0C2 +10
40 0C1 +10

@@@ hidden_input
1000 3E8
1003 1A0
1010 3E8
1019 3E8
1020 1A0
1031 7DF
1040 3E8
1041 1A0
1050 7DF
1060 3E8
1061 1A0
1070 7DF
@@@ hidden_output
1000 3E8 first
1003 1A0 first
1010 3E8 +10
1019 3E8 +9
1020 1A0 +17
1031 7DF first
1040 3E8 +21
1041 1A0 +21
1050 7DF +19
1060 3E8 +20
1061 1A0 +20
1070 7DF +20

@@@ hidden_input
0 1
0 2
0 3
0 4
0 5
0 6
@@@ hidden_output
0 001 first
0 002 first
0 003 first
0 004 first
0 005 first
0 006 first

@@@ hidden_input
0 0
1 0
2 0
3 0
2147483647 0
@@@ hidden_output
0 000 first
1 000 +1
2 000 +1
3 000 +1
2147483647 000 +2147483644

@@@ hint
The 5th frame is exactly when `trace_push` has to grow the array from 4 to 8 elements. What does `realloc` do with the old block, and what happens to every pointer that pointed into it?
@@@ hint
`realloc` may move the data to a new address and free the old block. Every `prev` pointer stored so far, and the `prev` you computed just before the push, then dangles. Store the **index** of the previous frame instead of its address. An index stays valid when the array moves.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

struct frame {
    int t;                        /* timestamp, ms */
    unsigned id;                  /* CAN identifier */
    int prev;                     /* FIX: index of the previous frame with the same id, or -1 (pointers dangle after realloc) */
};

struct trace {
    struct frame *v;
    size_t len, cap;
};

/* Append one slot (growing the array if needed) and return it. */
static struct frame *trace_push(struct trace *tr)
{
    if (tr->len == tr->cap) {
        size_t ncap = tr->cap ? tr->cap * 2 : 4;
        struct frame *nv = realloc(tr->v, ncap * sizeof *nv);
        if (nv == NULL)
            return NULL;
        tr->v = nv;
        tr->cap = ncap;
    }
    return &tr->v[tr->len++];
}

/* Index of the most recent frame with this id, or -1. */
static int find_last(const struct trace *tr, unsigned id)   /* FIX: return an index */
{
    for (size_t i = tr->len; i-- > 0;)
        if (tr->v[i].id == id)
            return (int)i;                                     /* FIX */
    return -1;                                                 /* FIX */
}

int main(void)
{
    struct trace tr = {NULL, 0, 0};
    int t;
    unsigned id;

    while (scanf("%d %x", &t, &id) == 2) {
        int prev = find_last(&tr, id);                         /* FIX */
        struct frame *f = trace_push(&tr);
        if (f == NULL)
            break;
        f->t = t;
        f->id = id;
        f->prev = prev;
    }

    for (size_t i = 0; i < tr.len; i++) {
        const struct frame *f = &tr.v[i];
        if (f->prev >= 0)                                       /* FIX */
            printf("%d %03X +%d\n", f->t, f->id, f->t - tr.v[f->prev].t);   /* FIX: look up by index */
        else
            printf("%d %03X first\n", f->t, f->id);
    }
    free(tr.v);
    return 0;
}
@@@ explanation_md
**Bug.** `realloc` may *move* the array: it allocates a new block, copies the contents, and frees the old one. Every pointer into the old block becomes **dangling**:

```
before push #5:  v -> [f0 f1 f2 f3]          f3.prev -> &old[1]
after realloc :  v -> [f0 f1 f2 f3 f4 . . .] (new address)
                 old block freed  ->  f2.prev, f3.prev, and `prev` for f4 all point into freed memory
```

Two things go wrong at once. The `prev` computed *before* `trace_push` dangles immediately, and every `prev` already stored *inside* the array dangles too, because the array copied the pointer values, not what they meant. Dereferencing them later (`f->prev->t`) is a use-after-free (C11 7.22.3.5: "the old object is deallocated"). ASan reports *heap-use-after-free*; without it you read freed memory and get absurd periods.

With 4 or fewer frames there is no reallocation, so short traces work. That is why the bug survives quick bench tests.

**Fix.** Store **indices** (relative positions) instead of absolute addresses. An index is still correct after the array moves. Doing the linking in a second pass after all frames are read also works, but only as long as nothing is appended afterwards.

**Complexity.** `find_last` is O(n) per frame, so O(n^2) overall (fine for 10^4). A `last_index[0x800]` table indexed by ID would make it O(1) per frame. Amortized O(1) per push; space O(n).

**Common mistakes**
- Assuming `realloc` grows "in place". It may, it may not, and the sanitizer build always moves the block.
- Updating `tr->v` but keeping a cached `struct frame *cur = tr->v + i` across a push. Same bug, one line.
- `tr->v = realloc(tr->v, ...)` without a temporary. On failure it leaks the old block (this code already does it right).
- Fixing only the `prev` computed before the push: the pointers already stored inside the array still dangle after the *next* growth.

**Interview follow-ups**
- Which C++ rule is this? (`std::vector` iterator/pointer invalidation on `push_back`.) How do you avoid it in C without indices (chunked/linked storage, a pre-sized pool)?
- Replace the O(n) `find_last` with an O(1) table of the last index per 11-bit ID. How much RAM does that cost?
- Why do many ECU coding guidelines forbid `realloc` entirely, and what would you use for an unbounded trace buffer on a target (ring buffer, overwrite-oldest)?
- How would you compute the period across a 32-bit millisecond timestamp **wrap-around**?
