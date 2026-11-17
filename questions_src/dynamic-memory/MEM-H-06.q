@@@ meta
id: MEM-H-06
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: Debug Allocator That Reports Leaks, Double Frees and Overflows
tags: embedded, leak-detection, canary, debug-allocator, double-free, heap-overflow, asked-in-automotive
@@@ statement_md
During ECU integration there is no Valgrind or AddressSanitizer on the target, so teams wrap `malloc` in a **debug allocator**. It remembers every live block, guards its end with a canary, and dumps the leaks at shutdown. Implement it:

```c
void  *trk_malloc(size_t n, const char *tag);
int    trk_free(void *p);
size_t trk_report(void);
void   trk_stats(size_t *live_blocks, size_t *live_bytes, size_t *peak_bytes);
void   trk_shutdown(void);
```

- `trk_malloc(n, tag)`: return `NULL` if `n == 0` or if the size computation would overflow. Otherwise make **one** `malloc` holding a header (your bookkeeping), the `n` user bytes, and **4 canary bytes `DE AD BE EF`** directly after them, and return the user pointer. The user area must be aligned like `malloc`'s result (16 bytes on x86-64). Each successful call gets the next id (1, 2, 3, ...). `tag` points to a string that outlives the block; store the pointer.
- `trk_free(p)`:
  - `NULL`: return `0`.
  - If `p` is not the user pointer of a **live** tracked block (a double free, an interior pointer, garbage), return `-1` **without touching the memory at `p`** (it may already be freed). Look `p` up in your list of live blocks instead of trusting a header in front of it.
  - Otherwise verify the canary, release the block (it is untracked from now on), and return `0`, or `-2` if the canary was overwritten (overflow detected; the block is still released).
- `trk_report()`: for every live block in **allocation order**, print `LEAK #<id> <n> bytes [<tag>]` and return the number of live blocks.
- `trk_stats`: live block count, live user bytes, and the **peak** live user bytes ever reached (the high-water mark used to size the production heap).
- `trk_shutdown()`: really free every block that is still live (after a report), and set the live counters to 0. The peak and the id counter keep their values.

**Input (read by the hidden harness)**, one operation per line. Successful allocations get handles 1, 2, 3, ...:
- `A <n> <tag>`: prints `A#<k> <n> [<tag>]` or `A(<n>) -> NULL`. The harness fills the `n` user bytes.
- `F <k>`: prints `F #<k> -> <rc>`. `N`: `trk_free(NULL)`. `X <k> <off>`: `trk_free(handle k + off)`.
- `O <k> <m>`: the harness writes `m` (1..4) bytes past the end of block `k` (a simulated overflow).
- `L`: calls `trk_report()`, then prints `report -> <count>`. `S`: prints `live=<blocks> bytes=<bytes> peak=<peak>`.
- `R <n> <seed>`: random stress with a summary.
- At the end the harness calls `trk_shutdown()` and prints `shutdown: live=<blocks> bytes=<bytes>`.

**Example**
```
Input:
A 16 can_rx
A 100 uds_buf
A 8 tmp
F 1
L
S

Output:
A#1 16 [can_rx]
A#2 100 [uds_buf]
A#3 8 [tmp]
F #1 -> 0
LEAK #2 100 bytes [uds_buf]
LEAK #3 8 bytes [tmp]
report -> 2
live=2 bytes=108 peak=124
shutdown: live=0 bytes=0
```
@@@ constraints_md
- At most 5000 operations, `0 <= n < 2^64` (real allocations are at most 4096 bytes).
- Use `malloc`/`free` underneath. After `trk_shutdown` nothing may be left allocated (leak checking is on).
- A linear search of the live list in `trk_free` is acceptable.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void *trk_malloc(size_t n, const char *tag)
{
    /* TODO: header + n bytes + 4 canary bytes in one malloc; link into the live list */
    return NULL;
}

int trk_free(void *p)
{
    /* TODO: find p in the live list (never read memory at p first), check canary, release */
    return -1;
}

size_t trk_report(void)
{
    /* TODO */
    return 0;
}

void trk_stats(size_t *live_blocks, size_t *live_bytes, size_t *peak_bytes)
{
    /* TODO */
    *live_blocks = 0;
    *live_bytes = 0;
    *peak_bytes = 0;
}

void trk_shutdown(void)
{
    /* TODO */
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*USER_CODE*/

#define MAXH 5100
static unsigned char *h[MAXH + 1];
static size_t hsize[MAXH + 1];
static int live[MAXH + 1];
static char tags[MAXH + 1][24];
static int nh;

static int alloc_handle(size_t n, const char *tag_src)
{
    if (nh >= MAXH)
        return 0;
    snprintf(tags[nh + 1], sizeof tags[0], "%s", tag_src);
    unsigned char *p = trk_malloc(n, tags[nh + 1]);
    if (p == NULL)
        return 0;
    if ((uintptr_t)p % 16u != 0)
        printf("FAIL: user area not 16-byte aligned\n");
    h[++nh] = p;
    hsize[nh] = n;
    live[nh] = 1;
    memset(p, 0x5A, n);
    return 1;
}

int main(void)
{
    char op[4], tag[24];
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'A') {
            unsigned long long n;
            if (scanf("%llu %23s", &n, tag) != 2)
                break;
            if (n <= 4096u && alloc_handle((size_t)n, tag))
                printf("A#%d %llu [%s]\n", nh, n, tag);
            else if (n > 4096u && trk_malloc((size_t)n, "huge") != NULL)
                printf("A(%llu) -> FAIL: should be NULL\n", n);
            else
                printf("A(%llu) -> NULL\n", n);
        } else if (op[0] == 'F') {
            int k;
            if (scanf("%d", &k) != 1 || k < 1 || k > nh)
                break;
            int rc = trk_free(h[k]);
            if (rc == 0 || rc == -2)
                live[k] = 0;
            printf("F #%d -> %d\n", k, rc);
        } else if (op[0] == 'N') {
            printf("N -> %d\n", trk_free(NULL));
        } else if (op[0] == 'X') {
            int k, off;
            if (scanf("%d %d", &k, &off) != 2 || k < 1 || k > nh || !live[k] || off < 1 || (size_t)off >= hsize[k])
                break;
            printf("X #%d+%d -> %d\n", k, off, trk_free(h[k] + off));
        } else if (op[0] == 'O') {
            int k, m;
            if (scanf("%d %d", &k, &m) != 2 || k < 1 || k > nh || !live[k] || m < 1 || m > 4)
                break;
            memset(h[k] + hsize[k], 0x00, (size_t)m);    /* lands in the canary */
            printf("O #%d +%d\n", k, m);
        } else if (op[0] == 'L') {
            size_t c = trk_report();
            printf("report -> %zu\n", c);
        } else if (op[0] == 'S') {
            size_t a, b, c;
            trk_stats(&a, &b, &c);
            printf("live=%zu bytes=%zu peak=%zu\n", a, b, c);
        } else if (op[0] == 'R') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            int ok = 0, dbl = 0, ovf = 0, bad = 0;
            for (int i = 0; i < n && nh < MAXH; i++) {
                seed = seed * 1103515245u + 12345u;
                unsigned int r = (seed >> 16) & 0x7FFFu;
                int k = nh > 0 ? 1 + (int)(r % (unsigned int)nh) : 0;
                if (r % 8u < 4u || k == 0) {
                    if (alloc_handle(1u + r % 500u, "r"))
                        ok++;
                } else if (r % 8u == 7u && live[k]) {
                    memset(h[k] + hsize[k], 0x00, 1u);
                    ovf += trk_free(h[k]) == -2;
                    live[k] = 0;
                } else {
                    int rc = trk_free(h[k]);
                    if (live[k]) {
                        bad += rc != 0;
                        live[k] = 0;
                    } else {
                        dbl += rc == -1;
                    }
                }
            }
            size_t a, b, c;
            trk_stats(&a, &b, &c);
            printf("R allocs=%d double_frees_caught=%d overflows_caught=%d bad=%d live=%zu bytes=%zu peak=%zu\n", ok,
                   dbl, ovf, bad, a, b, c);
        }
    }
    trk_shutdown();
    size_t a, b, c;
    trk_stats(&a, &b, &c);
    printf("shutdown: live=%zu bytes=%zu\n", a, b);
    return 0;
}
@@@ sample_input
A 16 can_rx
A 100 uds_buf
A 8 tmp
F 1
L
S
@@@ sample_output
A#1 16 [can_rx]
A#2 100 [uds_buf]
A#3 8 [tmp]
F #1 -> 0
LEAK #2 100 bytes [uds_buf]
LEAK #3 8 bytes [tmp]
report -> 2
live=2 bytes=108 peak=124
shutdown: live=0 bytes=0

@@@ sample_input
A 10 a
F 1
F 1
N
A 20 b
X 2 1
O 2 1
F 2
S
L
@@@ sample_output
A#1 10 [a]
F #1 -> 0
F #1 -> -1
N -> 0
A#2 20 [b]
X #2+1 -> -1
O #2 +1
F #2 -> -2
live=0 bytes=0 peak=20
report -> 0
shutdown: live=0 bytes=0

@@@ hidden_input
A 0 zero
A 18446744073709551615 max
A 18446744073709551600 nearmax
S
L
@@@ hidden_output
A(0) -> NULL
A(18446744073709551615) -> NULL
A(18446744073709551600) -> NULL
live=0 bytes=0 peak=0
report -> 0
shutdown: live=0 bytes=0

@@@ hidden_input
A 1 a
A 2 b
A 3 c
A 4 d
A 5 e
F 2
F 4
L
F 5
L
S
@@@ hidden_output
A#1 1 [a]
A#2 2 [b]
A#3 3 [c]
A#4 4 [d]
A#5 5 [e]
F #2 -> 0
F #4 -> 0
LEAK #1 1 bytes [a]
LEAK #3 3 bytes [c]
LEAK #5 5 bytes [e]
report -> 3
F #5 -> 0
LEAK #1 1 bytes [a]
LEAK #3 3 bytes [c]
report -> 2
live=2 bytes=4 peak=15
shutdown: live=0 bytes=0

@@@ hidden_input
A 64 dma_rx
A 64 dma_tx
O 1 4
O 2 2
F 2
F 1
F 1
A 4096 flash_page
F 3
S
@@@ hidden_output
A#1 64 [dma_rx]
A#2 64 [dma_tx]
O #1 +4
O #2 +2
F #2 -> -2
F #1 -> -2
F #1 -> -1
A#3 4096 [flash_page]
F #3 -> 0
live=0 bytes=0 peak=4096
shutdown: live=0 bytes=0

@@@ hidden_input
A 7 x
A 9 y
X 1 3
X 2 8
F 2
X 1 6
L
@@@ hidden_output
A#1 7 [x]
A#2 9 [y]
X #1+3 -> -1
X #2+8 -> -1
F #2 -> 0
X #1+6 -> -1
LEAK #1 7 bytes [x]
report -> 1
shutdown: live=0 bytes=0

@@@ hidden_input
R 3000 5
S
@@@ hidden_output
R allocs=1487 double_frees_caught=794 overflows_caught=172 bad=0 live=768 bytes=193250 peak=194096
live=768 bytes=193250 peak=194096
shutdown: live=0 bytes=0

@@@ hidden_input
R 120 77
L
@@@ hidden_output
R allocs=54 double_frees_caught=37 overflows_caught=9 bad=0 live=25 bytes=4654 peak=5625
LEAK #11 4 bytes [r]
LEAK #13 367 bytes [r]
LEAK #18 67 bytes [r]
LEAK #19 106 bytes [r]
LEAK #21 379 bytes [r]
LEAK #23 326 bytes [r]
LEAK #28 406 bytes [r]
LEAK #30 80 bytes [r]
LEAK #34 39 bytes [r]
LEAK #35 459 bytes [r]
LEAK #36 21 bytes [r]
LEAK #38 203 bytes [r]
LEAK #41 130 bytes [r]
LEAK #42 201 bytes [r]
LEAK #43 80 bytes [r]
LEAK #44 21 bytes [r]
LEAK #46 136 bytes [r]
LEAK #47 147 bytes [r]
LEAK #48 395 bytes [r]
LEAK #49 335 bytes [r]
LEAK #50 71 bytes [r]
LEAK #51 37 bytes [r]
LEAK #52 75 bytes [r]
LEAK #53 333 bytes [r]
LEAK #54 236 bytes [r]
report -> 25
shutdown: live=0 bytes=0

@@@ hint
Put a header in front of every user block: `prev`/`next` links (a doubly linked list of live blocks, appended at the tail so it stays in allocation order), `id`, `size`, `tag`. Round the header size up to 16 so the user area stays aligned. The canary goes at `user + size`, so allocate `header + n + 4` and check `n > SIZE_MAX - header - 4` first.
@@@ hint
In `trk_free`, walk the live list and compare each block's user pointer with `p` (`==` is fine on any pointers). Only after a match may you read the header and canary (`memcmp` with `DE AD BE EF`), unlink in O(1) thanks to `prev`/`next`, update the counters and `free` the real block. No match: return -1 and touch nothing, because reading at `p - header` after a double free would itself be a use-after-free.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct trk_hdr {
    struct trk_hdr *prev;
    struct trk_hdr *next;
    const char *tag;
    size_t size;
    size_t id;
};

/* header rounded up to 16 so that the user area keeps malloc's alignment */
#define TRK_HDR ((sizeof(struct trk_hdr) + 15u) & ~(size_t)15u)
#define TRK_CANARY 4u

static const unsigned char k_canary[TRK_CANARY] = { 0xDE, 0xAD, 0xBE, 0xEF };
static struct trk_hdr *s_head, *s_tail;      /* live blocks, allocation order */
static size_t s_next_id = 1;
static size_t s_live_blocks, s_live_bytes, s_peak;

static unsigned char *user_of(struct trk_hdr *h)
{
    return (unsigned char *)h + TRK_HDR;
}

void *trk_malloc(size_t n, const char *tag)
{
    if (n == 0 || n > SIZE_MAX - TRK_HDR - TRK_CANARY)
        return NULL;
    struct trk_hdr *h = malloc(TRK_HDR + n + TRK_CANARY);
    if (h == NULL)
        return NULL;
    h->tag = tag;
    h->size = n;
    h->id = s_next_id++;
    h->next = NULL;
    h->prev = s_tail;                        /* append: list stays in id order */
    if (s_tail != NULL)
        s_tail->next = h;
    else
        s_head = h;
    s_tail = h;
    memcpy(user_of(h) + n, k_canary, TRK_CANARY);
    s_live_blocks++;
    s_live_bytes += n;
    if (s_live_bytes > s_peak)
        s_peak = s_live_bytes;
    return user_of(h);
}

static void release(struct trk_hdr *h)
{
    if (h->prev != NULL)
        h->prev->next = h->next;
    else
        s_head = h->next;
    if (h->next != NULL)
        h->next->prev = h->prev;
    else
        s_tail = h->prev;
    s_live_blocks--;
    s_live_bytes -= h->size;
    free(h);
}

int trk_free(void *p)
{
    if (p == NULL)
        return 0;
    for (struct trk_hdr *h = s_head; h != NULL; h = h->next) {
        if (user_of(h) != (unsigned char *)p)
            continue;                        /* never dereference p before a match */
        int rc = memcmp(user_of(h) + h->size, k_canary, TRK_CANARY) == 0 ? 0 : -2;
        release(h);
        return rc;
    }
    return -1;                               /* double free / interior / foreign pointer */
}

size_t trk_report(void)
{
    size_t n = 0;
    for (struct trk_hdr *h = s_head; h != NULL; h = h->next, n++)
        printf("LEAK #%zu %zu bytes [%s]\n", h->id, h->size, h->tag);
    return n;
}

void trk_stats(size_t *live_blocks, size_t *live_bytes, size_t *peak_bytes)
{
    *live_blocks = s_live_blocks;
    *live_bytes = s_live_bytes;
    *peak_bytes = s_peak;
}

void trk_shutdown(void)
{
    while (s_head != NULL)
        release(s_head);
}
@@@ explanation_md
**Approach.** Each allocation becomes one real block:

```
[ header: prev | next | tag | size | id ][ user bytes (n) ][ DE AD BE EF ]
^ real malloc pointer                    ^ returned to the caller
```

- **Live list.** A doubly linked list of headers, appended at the tail. The report walks it in allocation order, and unlinking is O(1) once a block is found.
- **Lookup instead of trust.** `trk_free` searches the list for a block whose user pointer equals `p`, comparing with `==` only. A double free, an interior pointer or a foreign pointer is not in the list, so it is rejected **without reading** `p - header`. That memory may already be freed and reused; reading it would be the very use-after-free this tool is supposed to catch.
- **Canary.** 4 known bytes right after the user area. A typical off-by-one (`buf[n] = 0`) overwrites the first byte and is caught at free time, like the heap checker in this judge does with its 16-byte redzones.
- **Peak.** `max(live_bytes)` over time is the number you need to size the production heap or static pool.

**Complexity.** `trk_malloc` O(1). `trk_free` O(L) for L live blocks (the search), O(1) unlink. `trk_report`/`trk_shutdown` O(L). Space: 48 bytes of header plus 4 bytes of canary per block.

**Common mistakes**
- Reading the header at `p - 48` to decide whether `p` is valid. On a double free that read is itself undefined behavior, and the header may have been overwritten by a new owner.
- Header size not a multiple of 16: the user area then loses `malloc`'s alignment (`max_align_t`, SSE types).
- Overflow in `header + n + 4` for huge `n`.
- Checking the canary but **not** releasing the block when it is corrupted (leak), or releasing it twice.
- Printing the report in reverse (prepending to the list without walking it backwards).

**Interview follow-ups**
- How would you also record the **caller's file and line** with zero changes at call sites? (`#define malloc(n) trk_malloc_dbg((n), __FILE__, __LINE__)`, which is exactly what this judge's Windows heap checker does.)
- Add a **front** canary and a "freed" fill pattern plus a quarantine to catch writes after free. What does the quarantine cost in RAM?
- On an ECU, where would you print the leak report (UART, a RAM log section kept across reset, UDS DID readout)?
- Why should this wrapper only exist in debug/integration builds, while production follows MISRA C:2012 Rule 21.3 / Dir 4.12 with static pools?
