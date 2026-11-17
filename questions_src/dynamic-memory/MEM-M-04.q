@@@ meta
id: MEM-M-04
topic: Dynamic Memory
difficulty: Medium
type: FUNCTION
title: Deep Clone a Sensor Configuration Chain
tags: embedded, deep-copy, struct, ownership, malloc-failure, asked-in-automotive
@@@ statement_md
A calibration tool keeps sensor configurations on the heap. Each configuration owns a name, a table of calibration points and an optional **fallback** configuration, which owns its own name, table and fallback, and so on. Before an engineer edits a configuration, the tool takes a snapshot that must be completely **independent** of the original:

```c
struct cal_point {
    int raw;
    int phys;
};

struct sensor_cfg {
    char *name;                  /* heap string, never NULL */
    struct cal_point *points;    /* heap array of n_points; NULL when n_points == 0 */
    size_t n_points;
    struct sensor_cfg *fallback; /* owned nested config, or NULL */
};

struct sensor_cfg *cfg_clone(const struct sensor_cfg *src);
void cfg_free(struct sensor_cfg *cfg);
```

- `cfg_clone(src)` returns a **deep copy**: new struct, new name string, new points array (only when `n_points > 0`), and a deep copy of the whole fallback chain. `cfg_clone(NULL)` returns `NULL`.
- Allocate **only** with `xmalloc(size)` (provided by the harness; it behaves like `malloc` but the harness can make one call fail). Make exactly one allocation for each struct, each name, and each non-empty points array.
- If **any** allocation fails, return `NULL` and leave **nothing** allocated.
- `cfg_free(cfg)` releases a configuration and its whole fallback chain. `cfg_free(NULL)` does nothing.

**How it is tested.** The harness builds the original chain with plain `malloc`, then calls `cfg_clone`. Next it **destroys the original** (after scribbling over its name and points), prints the clone, and frees the clone with your `cfg_free`. A shallow copy then reads freed memory.

**Input (read by the hidden harness)**
- Line 1: `fail <k>`. The `k`-th call to `xmalloc` returns `NULL` (`0` = never).
- Line 2: `levels` (`0` means the original is `NULL`).
- `levels` lines: `name n raw1 phys1 ... rawn physn`. Level 0 is the head; each next line is the previous level's fallback.

**Output (printed by the harness)**
- `clone: NULL`, or `clone: ok` followed by one line per level: `level <i>: name=<name> points=<n> [raw:phys ...]`.

**Example**
```
Input:
fail 0
2
TEMP_SENSOR 3 0 -40 2048 25 4095 125
TEMP_FALLBACK 0

Output:
clone: ok
level 0: name=TEMP_SENSOR points=3 [0:-40 2048:25 4095:125]
level 1: name=TEMP_FALLBACK points=0 []
```
@@@ constraints_md
- `0 <= levels <= 10`, `0 <= n <= 100`, names have 1..63 characters.
- Use `xmalloc` for every allocation of the clone and `free` to release. Do not call `malloc` directly.
- Leak checking is always on, including on the failure paths.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t size); /* provided by the harness: like malloc, may fail on demand */

struct cal_point {
    int raw;
    int phys;
};

struct sensor_cfg {
    char *name;
    struct cal_point *points;
    size_t n_points;
    struct sensor_cfg *fallback;
};

void cfg_free(struct sensor_cfg *cfg)
{
    /* TODO */
}

struct sensor_cfg *cfg_clone(const struct sensor_cfg *src)
{
    /* TODO */
    return NULL;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_calls;
static int g_fail_at;

void *xmalloc(size_t size)
{
    g_calls++;
    if (g_calls == g_fail_at)
        return NULL;
    return malloc(size);
}

/*USER_CODE*/

/* harness-owned helpers for the ORIGINAL chain (plain malloc/free) */
static void orig_free(struct sensor_cfg *c)
{
    while (c != NULL) {
        struct sensor_cfg *next = c->fallback;
        memset(c->name, '#', strlen(c->name));          /* scribble before freeing */
        for (size_t i = 0; i < c->n_points; i++)
            c->points[i].phys = -1;
        free(c->name);
        free(c->points);
        free(c);
        c = next;
    }
}

int main(void)
{
    char word[8];
    int levels;
    if (scanf("%7s %d %d", word, &g_fail_at, &levels) != 3)
        return 0;

    if (cfg_clone(NULL) != NULL)
        printf("FAIL: cfg_clone(NULL) must return NULL\n");
    cfg_free(NULL);
    g_calls = 0;

    struct sensor_cfg *orig = NULL, **link = &orig;
    for (int l = 0; l < levels; l++) {
        char name[64];
        int n;
        if (scanf("%63s %d", name, &n) != 2)
            return 0;
        struct sensor_cfg *c = malloc(sizeof *c);
        if (c == NULL)
            return 1;
        c->name = malloc(strlen(name) + 1);
        if (c->name == NULL)
            return 1;
        strcpy(c->name, name);
        c->n_points = (size_t)n;
        c->points = NULL;
        if (n > 0) {
            c->points = malloc((size_t)n * sizeof *c->points);
            if (c->points == NULL)
                return 1;
            for (int i = 0; i < n; i++)
                if (scanf("%d %d", &c->points[i].raw, &c->points[i].phys) != 2)
                    return 0;
        }
        c->fallback = NULL;
        *link = c;
        link = &c->fallback;
    }

    struct sensor_cfg *copy = cfg_clone(orig);
    orig_free(orig);                       /* the original is gone now */

    if (copy == NULL) {
        printf("clone: NULL\n");
        return 0;
    }
    printf("clone: ok\n");
    int l = 0;
    for (const struct sensor_cfg *c = copy; c != NULL && l <= levels; c = c->fallback, l++) {
        printf("level %d: name=%s points=%zu [", l, c->name, c->n_points);
        for (size_t i = 0; i < c->n_points; i++)
            printf("%s%d:%d", i ? " " : "", c->points[i].raw, c->points[i].phys);
        printf("]\n");
    }
    cfg_free(copy);
    return 0;
}
@@@ sample_input
fail 0
2
TEMP_SENSOR 3 0 -40 2048 25 4095 125
TEMP_FALLBACK 0
@@@ sample_output
clone: ok
level 0: name=TEMP_SENSOR points=3 [0:-40 2048:25 4095:125]
level 1: name=TEMP_FALLBACK points=0 []

@@@ sample_input
fail 3
2
TEMP_SENSOR 3 0 -40 2048 25 4095 125
TEMP_FALLBACK 0
@@@ sample_output
clone: NULL

@@@ hidden_input
fail 0
0
@@@ hidden_output
clone: NULL

@@@ hidden_input
fail 1
1
P 1 5 6
@@@ hidden_output
clone: NULL

@@@ hidden_input
fail 4
1
P 1 5 6
@@@ hidden_output
clone: ok
level 0: name=P points=1 [5:6]

@@@ hidden_input
fail 5
3
RAIL_PRESSURE 2 100 0 3900 2000
RAIL_PRESSURE_BACKUP 1 512 1000
LIMP_HOME 0
@@@ hidden_output
clone: NULL

@@@ hidden_input
fail 8
3
RAIL_PRESSURE 2 100 0 3900 2000
RAIL_PRESSURE_BACKUP 1 512 1000
LIMP_HOME 0
@@@ hidden_output
clone: NULL

@@@ hidden_input
fail 9
3
RAIL_PRESSURE 2 100 0 3900 2000
RAIL_PRESSURE_BACKUP 1 512 1000
LIMP_HOME 0
@@@ hidden_output
clone: ok
level 0: name=RAIL_PRESSURE points=2 [100:0 3900:2000]
level 1: name=RAIL_PRESSURE_BACKUP points=1 [512:1000]
level 2: name=LIMP_HOME points=0 []

@@@ hidden_input
fail 0
4
A 0
B 2 -2147483648 2147483647 0 0
C 0
D 1 7 7
@@@ hidden_output
clone: ok
level 0: name=A points=0 []
level 1: name=B points=2 [-2147483648:2147483647 0:0]
level 2: name=C points=0 []
level 3: name=D points=1 [7:7]

@@@ hint
Copy level by level: the struct, then `name` (`strlen + 1` bytes), then `points` (`n_points * sizeof *points`, only if `n_points > 0`), then **recurse** for `fallback`. Copying the struct with `*dst = *src` copies the pointers, not what they point to (a shallow copy).
@@@ hint
Make the destructor robust first: `cfg_free` must accept a half-built struct whose missing members are `NULL`. Then initialise every pointer member of the new struct to `NULL` right after allocating it, and on any failure just call `cfg_free(dst)` and return `NULL`. A failed recursive clone of the fallback is handled the same way.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t size); /* provided by the harness: like malloc, may fail on demand */

struct cal_point {
    int raw;
    int phys;
};

struct sensor_cfg {
    char *name;
    struct cal_point *points;
    size_t n_points;
    struct sensor_cfg *fallback;
};

void cfg_free(struct sensor_cfg *cfg)
{
    while (cfg != NULL) {                      /* iterative: no recursion depth */
        struct sensor_cfg *next = cfg->fallback;
        free(cfg->name);                       /* free(NULL) is fine for half-built nodes */
        free(cfg->points);
        free(cfg);
        cfg = next;
    }
}

static char *dup_string(const char *s)
{
    size_t n = strlen(s) + 1;
    char *p = xmalloc(n);
    if (p != NULL)
        memcpy(p, s, n);
    return p;
}

struct sensor_cfg *cfg_clone(const struct sensor_cfg *src)
{
    if (src == NULL)
        return NULL;

    struct sensor_cfg *dst = xmalloc(sizeof *dst);
    if (dst == NULL)
        return NULL;
    dst->name = NULL;                          /* safe state for cfg_free */
    dst->points = NULL;
    dst->n_points = src->n_points;
    dst->fallback = NULL;

    dst->name = dup_string(src->name);
    if (dst->name == NULL)
        goto fail;

    if (src->n_points > 0) {
        if (src->n_points > SIZE_MAX / sizeof *dst->points)
            goto fail;
        dst->points = xmalloc(src->n_points * sizeof *dst->points);
        if (dst->points == NULL)
            goto fail;
        memcpy(dst->points, src->points, src->n_points * sizeof *dst->points);
    }

    if (src->fallback != NULL) {
        dst->fallback = cfg_clone(src->fallback);   /* deep copy of the chain */
        if (dst->fallback == NULL)
            goto fail;
    }
    return dst;

fail:
    cfg_free(dst);                             /* releases whatever was built */
    return NULL;
}
@@@ explanation_md
**Approach.** A deep copy follows **ownership**. Each pointer member the struct owns gets a fresh allocation with copied contents:

| member | copy |
|---|---|
| `name` | `xmalloc(strlen + 1)` + `memcpy` (terminator included) |
| `points` | `xmalloc(n * sizeof *points)` + `memcpy`, only if `n > 0` |
| `n_points` | plain value |
| `fallback` | recursive `cfg_clone` |

**Failure handling made simple.** Right after allocating the new struct, set all its pointers to `NULL`. Then the destructor works on a **half-built** object (`free(NULL)` is a no-op), and every failure path is the same two lines: `cfg_free(dst); return NULL;`. If the recursive clone of the fallback fails, it has already cleaned up its own partial chain, and you only free your level.

The destructor walks the chain **iteratively**. A recursive destructor uses one stack frame per level, and on an MCU with a 1 KB task stack, deep chains overflow it.

**Complexity.** Time O(total bytes copied), i.e. the sum of name lengths and points over all levels. Space is the same amount for the clone. Clone recursion depth is O(levels).

**Common mistakes**
- `*dst = *src;` and stopping there: a shallow copy. Both configs share `name`/`points`, so freeing the original leaves the clone dangling, and freeing both double-frees.
- Copying `name` with `xmalloc(strlen(src->name))`, without room for the terminator.
- `xmalloc(0)` for an empty table, which is implementation-defined. Keep `points = NULL` instead.
- Leaking on failure: returning `NULL` when the fallback clone fails without freeing this level's name/points/struct.
- Leaving pointer members uninitialized before the first failure point, then calling `free` on garbage.

**Interview follow-ups**
- How would you make the clone use **one** allocation for the whole chain (compute the total size first, then lay out structs, tables and strings in one block)? What alignment rules must the layout respect?
- What if two configs in the chain point to the **same** fallback (a DAG, not a chain)? How do you avoid cloning it twice or freeing it twice? (Reference counting, or an old-to-new pointer map.)
- In AUTOSAR, calibration data lives in flash and is copied to RAM by the calibration manager. Why are pointer-free, fixed-size structs preferred there?
