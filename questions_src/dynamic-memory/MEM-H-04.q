@@@ meta
id: MEM-H-04
topic: Dynamic Memory
difficulty: Hard
type: FUNCTION
title: Owning Hash Map With Rehash and Out-of-Memory Safety
tags: hash-map, chaining, rehash, ownership, malloc-failure, linked-list
@@@ statement_md
A diagnostic gateway keeps a table of active trouble codes (DTC string to occurrence counter). Implement a chained hash map that **owns copies of its keys**, grows by rehashing, and stays consistent when allocations fail:

```c
void *xmalloc(size_t n);   /* provided: like malloc, the harness can make chosen calls fail; free() to release */

struct entry {
    char *key;             /* owned heap copy */
    int value;
    struct entry *next;
};

struct hmap {
    struct entry **buckets;   /* nbuckets chain heads */
    size_t nbuckets;          /* power of two */
    size_t count;             /* number of keys */
};

int  hmap_init(struct hmap *m, size_t nbuckets);           /* 0, or -1 */
int  hmap_put(struct hmap *m, const char *key, int value); /* 1 inserted, 0 updated, -1 out of memory */
int  hmap_get(const struct hmap *m, const char *key, int *out); /* 1 found, 0 missing */
int  hmap_remove(struct hmap *m, const char *key);         /* 1 removed, 0 missing */
void hmap_destroy(struct hmap *m);
```

The policies are fixed, because the harness dumps the buckets:
- **Hash**: 32-bit FNV-1a over the key bytes (`h = 2166136261u; for each byte: h ^= byte; h *= 16777619u;`). Bucket = `h & (nbuckets - 1)`.
- `hmap_init`: `nbuckets` must be a power of two `>= 1`, else return -1. Allocate the bucket array with **one** `xmalloc` and set every head to `NULL`. On any failure, leave `*m` as `{NULL, 0, 0}`.
- `hmap_put` for a **new** key: exactly two allocations, in this order: the `struct entry`, then the key copy (`strlen + 1`). Insert at the **head** of its chain. If either allocation fails, return -1 and leave the map unchanged and leak-free. Updating an existing key allocates nothing.
- **Grow**: after inserting, if `count > 2 * nbuckets`, allocate a new bucket array of `2 * nbuckets` (one `xmalloc`) and move every **existing** node (no new entries, no new keys). Visit old buckets `0, 1, 2, ...` and each chain from head to tail, pushing each node onto the **head** of its new bucket. If that allocation fails, keep the old array. The insert still succeeded, and the next insert tries to grow again.
- `hmap_remove` unlinks the node and frees its key and the node. `hmap_destroy` frees everything and leaves `{NULL, 0, 0}`. It must also work after a failed `hmap_init`.

**Input (read by the hidden harness)**
- Line 1: `fail <c> <call numbers...>`: those `xmalloc` calls (counted from 1) return `NULL`.
- Line 2: `init <nbuckets>`, which prints `init <n> -> <rc>`.
- Then: `P <key> <value>`, `G <key>`, `D <key>`, `S` (prints `count=<c> buckets=<b> longest=<longest chain>`), `B` (dumps non-empty buckets as `[i] key=value ...`, chain order), and `R <n> <seed>` (random stress plus a summary).

**Example**
```
Input:
fail 0
init 4
P P0300 1
P U0100 2
P P0300 5
G P0300
G C0035
D U0100
D U0100
S

Output:
init 4 -> 0
P P0300 -> inserted
P U0100 -> inserted
P P0300 -> updated
G P0300 -> 5
G C0035 -> missing
D U0100 -> removed
D U0100 -> missing
count=1 buckets=4 longest=1
```
@@@ constraints_md
- Keys: 1..15 printable characters without spaces. Values fit in `int`.
- At most 20000 operations per test. The bucket array never exceeds 2^16 heads in the tests.
- Use `xmalloc` for every allocation and `free` to release. Leak checking is on (the harness calls `hmap_destroy` at the end).
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided: like malloc, may fail on demand */

struct entry {
    char *key;
    int value;
    struct entry *next;
};

struct hmap {
    struct entry **buckets;
    size_t nbuckets;
    size_t count;
};

int hmap_init(struct hmap *m, size_t nbuckets)
{
    /* TODO */
    return -1;
}

int hmap_put(struct hmap *m, const char *key, int value)
{
    /* TODO: update, or insert at chain head (entry, then key copy), then maybe grow */
    return -1;
}

int hmap_get(const struct hmap *m, const char *key, int *out)
{
    /* TODO */
    return 0;
}

int hmap_remove(struct hmap *m, const char *key)
{
    /* TODO */
    return 0;
}

void hmap_destroy(struct hmap *m)
{
    /* TODO */
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_calls;
static int g_fail[32];
static int g_nfail;

void *xmalloc(size_t n)
{
    g_calls++;
    for (int i = 0; i < g_nfail; i++)
        if (g_fail[i] == g_calls)
            return NULL;
    return malloc(n);
}

/*USER_CODE*/

static void stats(const struct hmap *m, size_t *longest)
{
    *longest = 0;
    for (size_t i = 0; i < m->nbuckets; i++) {
        size_t len = 0;
        for (const struct entry *e = m->buckets[i]; e != NULL && len <= m->count; e = e->next)
            len++;
        if (len > *longest)
            *longest = len;
    }
}

int main(void)
{
    char word[16];
    if (scanf("%15s %d", word, &g_nfail) != 2 || g_nfail < 0 || g_nfail > 32)
        return 0;
    for (int i = 0; i < g_nfail; i++)
        if (scanf("%d", &g_fail[i]) != 1)
            return 0;

    struct hmap m;
    unsigned long long nb;
    if (scanf("%15s %llu", word, &nb) != 2)
        return 0;
    int rc = hmap_init(&m, (size_t)nb);
    printf("init %llu -> %d\n", nb, rc);
    if (rc != 0) {
        if (m.buckets != NULL || m.nbuckets != 0 || m.count != 0)
            printf("FAIL: map not reset after failed init\n");
        hmap_destroy(&m);
        return 0;
    }

    char op[4], key[32];
    while (scanf("%3s", op) == 1) {
        if (op[0] == 'P') {
            int v;
            if (scanf("%31s %d", key, &v) != 2)
                break;
            int r = hmap_put(&m, key, v);
            printf("P %s -> %s\n", key, r == 1 ? "inserted" : r == 0 ? "updated" : "OOM");
        } else if (op[0] == 'G') {
            int v = 0;
            if (scanf("%31s", key) != 1)
                break;
            if (hmap_get(&m, key, &v))
                printf("G %s -> %d\n", key, v);
            else
                printf("G %s -> missing\n", key);
        } else if (op[0] == 'D') {
            if (scanf("%31s", key) != 1)
                break;
            printf("D %s -> %s\n", key, hmap_remove(&m, key) ? "removed" : "missing");
        } else if (op[0] == 'S') {
            size_t longest;
            stats(&m, &longest);
            printf("count=%zu buckets=%zu longest=%zu\n", m.count, m.nbuckets, longest);
        } else if (op[0] == 'B') {
            int any = 0;
            for (size_t i = 0; i < m.nbuckets; i++) {
                if (m.buckets[i] == NULL)
                    continue;
                any = 1;
                printf("[%zu]", i);
                size_t guard = 0;
                for (const struct entry *e = m.buckets[i]; e != NULL && guard <= m.count; e = e->next, guard++)
                    printf(" %s=%d", e->key, e->value);
                printf("\n");
            }
            if (!any)
                printf("(empty)\n");
        } else if (op[0] == 'R') {
            int n;
            unsigned int seed;
            if (scanf("%d %u", &n, &seed) != 2)
                break;
            int ins = 0, upd = 0, oom = 0, found = 0, miss = 0, rem = 0;
            long long sum = 0;
            for (int i = 0; i < n; i++) {
                seed = seed * 1103515245u + 12345u;
                unsigned int r = (seed >> 16) & 0x7FFFu;
                snprintf(key, sizeof key, "k%u", (r / 10u) % 700u);
                unsigned int kind = r % 10u;
                if (kind < 6u) {
                    int x = hmap_put(&m, key, i);
                    if (x == 1) ins++;
                    else if (x == 0) upd++;
                    else oom++;
                } else if (kind < 8u) {
                    int v;
                    if (hmap_get(&m, key, &v)) {
                        found++;
                        sum += v;
                    } else {
                        miss++;
                    }
                } else {
                    rem += hmap_remove(&m, key);
                }
            }
            size_t longest;
            stats(&m, &longest);
            printf("R ins=%d upd=%d oom=%d found=%d miss=%d rem=%d sum=%lld count=%zu buckets=%zu longest=%zu\n", ins,
                   upd, oom, found, miss, rem, sum, m.count, m.nbuckets, longest);
        }
    }
    hmap_destroy(&m);
    if (m.buckets != NULL || m.nbuckets != 0 || m.count != 0)
        printf("FAIL: map not reset by hmap_destroy\n");
    return 0;
}
@@@ sample_input
fail 0
init 4
P P0300 1
P U0100 2
P P0300 5
G P0300
G C0035
D U0100
D U0100
S
@@@ sample_output
init 4 -> 0
P P0300 -> inserted
P U0100 -> inserted
P P0300 -> updated
G P0300 -> 5
G C0035 -> missing
D U0100 -> removed
D U0100 -> missing
count=1 buckets=4 longest=1

@@@ sample_input
fail 0
init 1
P a 1
P b 2
B
P c 3
S
B
@@@ sample_output
init 1 -> 0
P a -> inserted
P b -> inserted
[0] b=2 a=1
P c -> inserted
count=3 buckets=2 longest=2
[0] a=1 c=3
[1] b=2

@@@ hidden_input
fail 0
init 3
@@@ hidden_output
init 3 -> -1

@@@ hidden_input
fail 1 1
init 8
@@@ hidden_output
init 8 -> -1

@@@ hidden_input
fail 1 3
init 4
P B1234 7
P B1234 8
G B1234
S
@@@ hidden_output
init 4 -> 0
P B1234 -> OOM
P B1234 -> inserted
G B1234 -> 8
count=1 buckets=4 longest=1

@@@ hidden_input
fail 2 2 5
init 2
P C0035 1
P C0035 2
P C0035 3
P U0073 4
G C0035
G U0073
S
@@@ hidden_output
init 2 -> 0
P C0035 -> OOM
P C0035 -> inserted
P C0035 -> updated
P U0073 -> OOM
G C0035 -> 3
G U0073 -> missing
count=1 buckets=2 longest=1

@@@ hidden_input
fail 1 8
init 1
P a 1
P b 2
P c 3
S
P d 4
S
B
D a
D d
D c
D b
B
S
@@@ hidden_output
init 1 -> 0
P a -> inserted
P b -> inserted
P c -> inserted
count=3 buckets=1 longest=3
P d -> inserted
count=4 buckets=2 longest=2
[0] a=1 c=3
[1] b=2 d=4
D a -> removed
D d -> removed
D c -> removed
D b -> removed
(empty)
count=0 buckets=2 longest=0

@@@ hidden_input
fail 0
init 2
R 20000 5
S
@@@ hidden_output
init 2 -> 0
R ins=3330 upd=8573 oom=0 found=2920 miss=1150 rem=2819 sum=27867759 count=511 buckets=512 longest=4
count=511 buckets=512 longest=4

@@@ hidden_input
fail 6 3 50 101 400 1001 1002
init 1
R 6000 9
@@@ hidden_output
init 1 -> 0
R ins=1305 upd=2281 oom=6 found=774 miss=402 rem=789 sum=2043248 count=516 buckets=512 longest=4

@@@ hint
Write a helper that returns the **link** (`struct entry **`) pointing at the node with the key, or at the `NULL` that ends the chain. `put` (update vs insert), `get` and `remove` (`*link = node->next`) all become a few lines. Do both allocations of a new entry **before** linking it in, so a failure has nothing to undo except `free(entry)`.
@@@ hint
Rehash without allocating entries: detach every node from the old chains (save `next` first) and push it onto `new_buckets[hash & (2n - 1)]`. Only after the new array was successfully allocated may you touch the old chains. Then `free(old_array)`. The keys and nodes stay where they are, so pointers to them stay valid.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided: like malloc, may fail on demand */

struct entry {
    char *key;
    int value;
    struct entry *next;
};

struct hmap {
    struct entry **buckets;
    size_t nbuckets;
    size_t count;
};

static uint32_t fnv1a(const char *s)
{
    uint32_t h = 2166136261u;
    while (*s != '\0') {
        h ^= (unsigned char)*s++;
        h *= 16777619u;
    }
    return h;
}

static struct entry **alloc_buckets(size_t n)
{
    if (n > SIZE_MAX / sizeof(struct entry *))
        return NULL;
    struct entry **b = xmalloc(n * sizeof *b);
    if (b != NULL)
        for (size_t i = 0; i < n; i++)
            b[i] = NULL;
    return b;
}

int hmap_init(struct hmap *m, size_t nbuckets)
{
    m->buckets = NULL;
    m->nbuckets = 0;
    m->count = 0;
    if (nbuckets == 0 || (nbuckets & (nbuckets - 1)) != 0)
        return -1;
    struct entry **b = alloc_buckets(nbuckets);
    if (b == NULL)
        return -1;
    m->buckets = b;
    m->nbuckets = nbuckets;
    return 0;
}

/* link that points at the node holding key, or at the terminating NULL of its chain */
static struct entry **find_link(const struct hmap *m, const char *key)
{
    struct entry **link = &m->buckets[fnv1a(key) & (m->nbuckets - 1)];
    while (*link != NULL && strcmp((*link)->key, key) != 0)
        link = &(*link)->next;
    return link;
}

static void grow(struct hmap *m)
{
    size_t nn = m->nbuckets * 2;
    if (nn < m->nbuckets)
        return;
    struct entry **nb = alloc_buckets(nn);
    if (nb == NULL)
        return;                                    /* keep the old table: still valid */
    for (size_t i = 0; i < m->nbuckets; i++) {
        struct entry *e = m->buckets[i];
        while (e != NULL) {
            struct entry *next = e->next;          /* save before relinking */
            size_t j = fnv1a(e->key) & (nn - 1);
            e->next = nb[j];
            nb[j] = e;
            e = next;
        }
    }
    free(m->buckets);
    m->buckets = nb;
    m->nbuckets = nn;
}

int hmap_put(struct hmap *m, const char *key, int value)
{
    if (m->buckets == NULL || key == NULL)
        return -1;
    struct entry **link = find_link(m, key);
    if (*link != NULL) {
        (*link)->value = value;                    /* update: no allocation */
        return 0;
    }
    struct entry *e = xmalloc(sizeof *e);
    if (e == NULL)
        return -1;
    size_t len = strlen(key) + 1;
    e->key = xmalloc(len);
    if (e->key == NULL) {
        free(e);                                   /* undo the first allocation */
        return -1;
    }
    memcpy(e->key, key, len);
    e->value = value;
    size_t b = fnv1a(key) & (m->nbuckets - 1);
    e->next = m->buckets[b];                       /* insert at chain head */
    m->buckets[b] = e;
    m->count++;
    if (m->count > 2 * m->nbuckets)
        grow(m);
    return 1;
}

int hmap_get(const struct hmap *m, const char *key, int *out)
{
    if (m->buckets == NULL || key == NULL)
        return 0;
    struct entry *e = *find_link(m, key);
    if (e == NULL)
        return 0;
    if (out != NULL)
        *out = e->value;
    return 1;
}

int hmap_remove(struct hmap *m, const char *key)
{
    if (m->buckets == NULL || key == NULL)
        return 0;
    struct entry **link = find_link(m, key);
    struct entry *e = *link;
    if (e == NULL)
        return 0;
    *link = e->next;                               /* unlink first ... */
    free(e->key);                                  /* ... then free what it owned */
    free(e);
    m->count--;
    return 1;
}

void hmap_destroy(struct hmap *m)
{
    for (size_t i = 0; i < m->nbuckets; i++) {
        struct entry *e = m->buckets[i];
        while (e != NULL) {
            struct entry *next = e->next;
            free(e->key);
            free(e);
            e = next;
        }
    }
    free(m->buckets);
    m->buckets = NULL;
    m->nbuckets = 0;
    m->count = 0;
}
@@@ explanation_md
**Approach.** Three ownership levels: the map owns the bucket array, each chain owns its nodes, and each node owns its key copy. Every operation keeps the invariant "every heap block is reachable from the map exactly once".

- **Link helper.** `find_link` returns the address of the pointer that refers to the matching node (or the chain's final `NULL`). Insert, update, lookup and unlink then share one loop, and removing the head needs no special case.
- **Insert is transactional.** Allocate the node, then the key. Only when both succeeded do you modify the map. If the key allocation fails, free the node; nothing else has changed.
- **Rehash moves, never copies.** New array first (if that fails, simply keep the old one, which is still a valid map with longer chains). Then relink each node with saved `next` pointers, and free the old **array only**. Keys and nodes are untouched, so there are no extra allocations and no new failure points.

```
old (1 bucket):  [0] c -> b -> a
grow to 2: visit c, b, a; push each onto new head
new:             [h&1] ...  (each chain reversed relative to the visit order)
```

**Complexity.** `put`/`get`/`remove` are O(1) average (load factor <= 2), O(n) worst case. A grow is O(n), amortized O(1) per insert. Space is O(n + nbuckets) plus key bytes.

**Common mistakes**
- Storing the caller's `key` pointer instead of a copy. The harness reuses its key buffer, so all keys would change together (and freeing them would be an invalid free).
- Leaking the node when the key copy fails, or linking the node into the chain **before** the key allocation (half-initialized node on failure).
- Rehash that allocates new entries, or that frees the old nodes, so every outstanding pointer dangles.
- Losing `e->next` while relinking during rehash (reading it after overwriting it).
- `hmap_remove` that frees the node but leaves the predecessor's `next` pointing at it.
- Growing **before** checking whether the key already exists (updates must not grow).

**Interview follow-ups**
- Open addressing (linear probing) instead of chains: how does deletion work (tombstones), and why is it more cache-friendly on an MCU?
- How would you bound the worst case for a safety-relevant system? (A static node pool, fixed bucket count, no rehash; reject inserts when full.)
- Why is FNV-1a a poor choice when keys come from an attacker (hash flooding), and what would you use instead (SipHash)?
