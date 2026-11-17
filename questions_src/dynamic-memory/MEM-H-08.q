@@@ meta
id: MEM-H-08
topic: Dynamic Memory
difficulty: Hard
type: FIND_THE_BUG
title: CAN Database Loader That Leaks on Partial Failure
tags: embedded, memory-leak, error-path, partial-construction, goto-cleanup, can-bus
@@@ statement_md
A diagnostic tester loads a CAN database (messages, each with named signals) into a nested heap structure:

```c
struct sig_def { char *name; int start_bit; int length; };
struct msg_def { unsigned int id; char *name; size_t n_sigs; struct sig_def *sigs; };
struct db      { size_t n_msgs; struct msg_def *msgs; };
```

`db_load()` builds the structure from a parsed source description (filled by the hidden `main()`), and `db_free()` releases it. Every allocation goes through `xmalloc()`, a wrapper the test harness can make fail on a chosen call to simulate memory exhaustion. If any allocation fails, `db_load()` must return `NULL` **and release everything it allocated so far**.

The loader passes every functional test, and also the out-of-memory tests where the failure hits the database header or a message name. When the failure hits a **signal table** or a **signal name**, the judge reports **Memory Leak**. Find and fix the bug (one statement is misplaced).

**Input (read by the hidden harness)**
- Line 1: `fail <k>`: the `k`-th `xmalloc` call returns `NULL` (`0` = never).
- Line 2: `n`, the number of messages.
- Next `n` lines: `<id hex> <name> <m> <sig1> <start1> <len1> ... <sigm> <startm> <lenm>`.

**Output (printed by the harness)**
- `load failed`, or `loaded <n> messages` followed by one line per message: `0x<ID> <name>: <sig>@<start>/<len> ...` (or `-` if it has no signals).

**Example**
```
Input:
fail 0
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4

Output:
loaded 2 messages
0x100 EngineData: RPM@0/16 Temp@16/8
0x200 Gear: GearPos@0/4
```
Allocation order: database header, message array, then per message: its name, its signal table (only if it has signals), then each signal name.
@@@ constraints_md
- `0 <= n <= 16` messages, `0 <= m <= 8` signals each, names of 1..31 characters.
- No `xmalloc(0)` calls: empty arrays stay `NULL`.
- Leak checking is on, including after a failed load.
@@@ starter_code
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided by the harness: like malloc, may fail on demand */

/* struct sig_def, msg_def, db and the source structs msg_src/sig_src are provided above */

static char *dup_str(const char *s)
{
    size_t n = strlen(s) + 1;
    char *p = xmalloc(n);
    if (p != NULL)
        memcpy(p, s, n);
    return p;
}

void db_free(struct db *db)
{
    if (db == NULL)
        return;
    for (size_t i = 0; i < db->n_msgs; i++) {
        struct msg_def *m = &db->msgs[i];
        for (size_t k = 0; k < m->n_sigs; k++)
            free(m->sigs[k].name);
        free(m->sigs);
        free(m->name);
    }
    free(db->msgs);
    free(db);
}

struct db *db_load(const struct msg_src *src, size_t n)
{
    struct db *db = xmalloc(sizeof *db);
    if (db == NULL)
        return NULL;
    db->n_msgs = 0;
    db->msgs = NULL;
    if (n > 0) {
        db->msgs = xmalloc(n * sizeof *db->msgs);
        if (db->msgs == NULL)
            goto fail;
    }

    for (size_t i = 0; i < n; i++) {
        struct msg_def *m = &db->msgs[i];
        m->id = src[i].id;
        m->name = NULL;
        m->sigs = NULL;
        m->n_sigs = 0;

        m->name = dup_str(src[i].name);
        if (m->name == NULL)
            goto fail;
        if (src[i].n_sigs > 0) {
            m->sigs = xmalloc(src[i].n_sigs * sizeof *m->sigs);
            if (m->sigs == NULL)
                goto fail;
        }
        for (size_t k = 0; k < src[i].n_sigs; k++) {
            m->sigs[k].start_bit = src[i].sigs[k].start_bit;
            m->sigs[k].length = src[i].sigs[k].length;
            m->sigs[k].name = dup_str(src[i].sigs[k].name);
            if (m->sigs[k].name == NULL)
                goto fail;
            m->n_sigs++;
        }
        db->n_msgs++;          /* message i is complete */
    }
    return db;

fail:
    db_free(db);               /* releases everything that was built */
    return NULL;
}
@@@ harness_code
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct sig_def {
    char *name;
    int start_bit;
    int length;
};

struct msg_def {
    unsigned int id;
    char *name;
    size_t n_sigs;
    struct sig_def *sigs;
};

struct db {
    size_t n_msgs;
    struct msg_def *msgs;
};

/* parsed source description (filled by main) */
struct sig_src {
    char name[32];
    int start_bit;
    int length;
};

struct msg_src {
    unsigned int id;
    char name[32];
    size_t n_sigs;
    struct sig_src sigs[8];
};

static int g_calls;
static int g_fail_at;

void *xmalloc(size_t n)
{
    g_calls++;
    if (n == 0)
        printf("FAIL: xmalloc(0) called\n");
    if (g_calls == g_fail_at)
        return NULL;
    return malloc(n);
}

/*USER_CODE*/

int main(void)
{
    static struct msg_src src[16];
    char word[8];
    int n;
    if (scanf("%7s %d %d", word, &g_fail_at, &n) != 3 || n < 0 || n > 16)
        return 0;
    for (int i = 0; i < n; i++) {
        int m;
        if (scanf("%x %31s %d", &src[i].id, src[i].name, &m) != 3 || m < 0 || m > 8)
            return 0;
        src[i].n_sigs = (size_t)m;
        for (int k = 0; k < m; k++)
            if (scanf("%31s %d %d", src[i].sigs[k].name, &src[i].sigs[k].start_bit, &src[i].sigs[k].length) != 3)
                return 0;
    }

    struct db *db = db_load(src, (size_t)n);
    if (db == NULL) {
        printf("load failed\n");
        return 0;
    }
    printf("loaded %zu messages\n", db->n_msgs);
    for (size_t i = 0; i < db->n_msgs; i++) {
        const struct msg_def *m = &db->msgs[i];
        printf("0x%X %s:", m->id, m->name);
        if (m->n_sigs == 0)
            printf(" -");
        for (size_t k = 0; k < m->n_sigs; k++)
            printf(" %s@%d/%d", m->sigs[k].name, m->sigs[k].start_bit, m->sigs[k].length);
        printf("\n");
    }
    db_free(db);
    return 0;
}
@@@ sample_input
fail 0
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ sample_output
loaded 2 messages
0x100 EngineData: RPM@0/16 Temp@16/8
0x200 Gear: GearPos@0/4

@@@ sample_input
fail 4
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ sample_output
load failed

@@@ hidden_input
fail 0
0
@@@ hidden_output
loaded 0 messages

@@@ hidden_input
fail 3
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ hidden_output
load failed

@@@ hidden_input
fail 6
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ hidden_output
load failed

@@@ hidden_input
fail 9
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ hidden_output
load failed

@@@ hidden_input
fail 10
2
100 EngineData 2 RPM 0 16 Temp 16 8
200 Gear 1 GearPos 0 4
@@@ hidden_output
loaded 2 messages
0x100 EngineData: RPM@0/16 Temp@16/8
0x200 Gear: GearPos@0/4

@@@ hidden_input
fail 1
1
7DF Diag 0
@@@ hidden_output
load failed

@@@ hidden_input
fail 8
3
7E0 Request 1 Sid 0 8
7E8 Response 2 Sid 0 8 Nrc 8 8
101 Heartbeat 0
@@@ hidden_output
load failed

@@@ hidden_input
fail 11
3
7E0 Request 1 Sid 0 8
7E8 Response 2 Sid 0 8 Nrc 8 8
101 Heartbeat 0
@@@ hidden_output
loaded 3 messages
0x7E0 Request: Sid@0/8
0x7E8 Response: Sid@0/8 Nrc@8/8
0x101 Heartbeat: -

@@@ hint
Pick a failing test and replay the allocations: header, array, message 0 name, message 0 signal table (fails). At that moment, what is `db->n_msgs`, and which messages will `db_free` look at?
@@@ hint
`db_free` only visits messages `0 .. n_msgs-1`, but `n_msgs` counts a message only once it is **complete**. The half-built message (its name, its table and the signal names built so far) is invisible to the cleanup. Count the message as soon as its pointer fields are in a freeable state (all `NULL`, `n_sigs = 0`). `db_free` can then release a partial message, because it uses `n_sigs` and `free(NULL)` is harmless.
@@@ solution_code
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

void *xmalloc(size_t n); /* provided by the harness: like malloc, may fail on demand */

/* struct sig_def, msg_def, db and the source structs msg_src/sig_src are provided above */

static char *dup_str(const char *s)
{
    size_t n = strlen(s) + 1;
    char *p = xmalloc(n);
    if (p != NULL)
        memcpy(p, s, n);
    return p;
}

void db_free(struct db *db)
{
    if (db == NULL)
        return;
    for (size_t i = 0; i < db->n_msgs; i++) {
        struct msg_def *m = &db->msgs[i];
        for (size_t k = 0; k < m->n_sigs; k++)
            free(m->sigs[k].name);
        free(m->sigs);
        free(m->name);
    }
    free(db->msgs);
    free(db);
}

struct db *db_load(const struct msg_src *src, size_t n)
{
    struct db *db = xmalloc(sizeof *db);
    if (db == NULL)
        return NULL;
    db->n_msgs = 0;
    db->msgs = NULL;
    if (n > 0) {
        db->msgs = xmalloc(n * sizeof *db->msgs);
        if (db->msgs == NULL)
            goto fail;
    }

    for (size_t i = 0; i < n; i++) {
        struct msg_def *m = &db->msgs[i];
        m->id = src[i].id;
        m->name = NULL;
        m->sigs = NULL;
        m->n_sigs = 0;
        db->n_msgs++;          /* FIX: count message i as soon as it is safely freeable, so db_free sees a partial message */

        m->name = dup_str(src[i].name);
        if (m->name == NULL)
            goto fail;
        if (src[i].n_sigs > 0) {
            m->sigs = xmalloc(src[i].n_sigs * sizeof *m->sigs);
            if (m->sigs == NULL)
                goto fail;
        }
        for (size_t k = 0; k < src[i].n_sigs; k++) {
            m->sigs[k].start_bit = src[i].sigs[k].start_bit;
            m->sigs[k].length = src[i].sigs[k].length;
            m->sigs[k].name = dup_str(src[i].sigs[k].name);
            if (m->sigs[k].name == NULL)
                goto fail;
            m->n_sigs++;
        }
    }
    return db;

fail:
    db_free(db);               /* releases everything that was built */
    return NULL;
}
@@@ explanation_md
**Bug.** The cleanup reuses the destructor, which is good practice, but the destructor only sees what the counters describe. `db->n_msgs` was incremented **after** a message was complete, so when an allocation inside message `i` fails, `db_free` walks messages `0..i-1` and never looks at message `i`. Whatever message `i` had already acquired leaks:

| failing allocation (example) | leaked by the buggy loader |
|---|---|
| header / message array / message name | nothing (passes) |
| signal table of message `i` | the name of message `i` |
| signal name `k` of message `i` | name, signal table, signal names `0..k-1` |

**Fix.** Put each element into a **destructible state first** (pointers `NULL`, counts 0), **then** count it (`db->n_msgs++`), and only then start acquiring its resources. The same rule already holds one level down: `m->n_sigs++` happens only after a signal name succeeded, and `db_free` frees exactly `n_sigs` names. With this invariant ("everything counted is safely freeable"), one `goto fail` + destructor covers every failure point.

**Complexity.** O(total messages + signals + name bytes) to load or free. The fix changes nothing.

**Common mistakes**
- Writing a separate hand-made cleanup for every failure point, which grows quadratically and is easy to get wrong.
- Counting the element **before** initializing its pointer fields. The destructor then frees garbage pointers (invalid free).
- Calling `xmalloc(0)` for an empty signal list (implementation-defined result; the harness flags it).
- Testing only the happy path. Error-path leaks are the most common leaks in production C code; fault injection (as done here) is the systematic way to cover every allocation.

**Interview follow-ups**
- How would you test **every** failure point automatically? (Run the load in a loop with `fail = 1, 2, 3, ...` until it succeeds, checking for leaks each time. That is exactly what these hidden tests sample.)
- Rewrite the loader with a single arena/bump allocation for the whole database. Which failure paths disappear, and what do you lose?
- Embedded tools often load DBC/ARXML only once at startup. Why does that make "allocate at init, never free" (allowed by many MISRA deviation procedures) attractive?
