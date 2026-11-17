@@@ meta
id: MEM-H-07
topic: Dynamic Memory
difficulty: Hard
type: FIND_THE_BUG
title: Signal Registry With a Pointer That Dies on realloc
tags: embedded, use-after-free, realloc, iterator-invalidation, dangling-pointer, asked-in-automotive
@@@ statement_md
A calibration tool keeps a registry of named signals in a growable array. `reg_get()` returns a pointer to the signal with the given name and **creates** it (value 0) if it does not exist yet. The tool processes a script:

- `SET <name> <v>`: sets the value (counts one write).
- `COPY <dst> <src>`: copies the value of `src` into `dst` (counts one read of `src` and one write of `dst`). Either signal may not exist yet; it is created with value 0.
- `DUMP`: prints all signals in creation order as `<name>=<value> w=<writes> r=<reads>`.

The tool passes the regression suite, in which every `COPY` used existing signals. A new script that copies into fresh signals gives garbage values on one machine, and AddressSanitizer reports **heap-use-after-free** in the judge. Find and fix the bug. The fix is one line; do not restructure the program.

**Input**
- Line 1: `n`. Next `n` lines: commands as above. Names have 1..15 characters, without spaces.

**Output**
- The lines printed by `DUMP` commands.

**Example**
```
Input:
4
SET rpm 3000
SET speed 88
COPY rpm_disp rpm
DUMP

Output:
rpm=3000 w=1 r=1
speed=88 w=1 r=0
rpm_disp=3000 w=1 r=0
```
@@@ constraints_md
- `0 <= n <= 2000`, at most 500 distinct signals.
- Values fit in `int`.
- The registry array must be freed before exit (leak checking is on).
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct signal {
    char name[16];
    int value;
    int writes;
    int reads;
};

struct registry {
    struct signal *items;
    size_t len;
    size_t cap;
};

/* Find the signal called name; create it (value 0) if missing. NULL if out of memory. */
static struct signal *reg_get(struct registry *r, const char *name)
{
    for (size_t i = 0; i < r->len; i++)
        if (strcmp(r->items[i].name, name) == 0)
            return &r->items[i];

    if (r->len == r->cap) {
        size_t newcap = r->cap ? r->cap * 2 : 2;
        struct signal *tmp = realloc(r->items, newcap * sizeof *tmp);
        if (tmp == NULL)
            return NULL;
        r->items = tmp;
        r->cap = newcap;
    }
    struct signal *s = &r->items[r->len++];
    snprintf(s->name, sizeof s->name, "%s", name);
    s->value = 0;
    s->writes = 0;
    s->reads = 0;
    return s;
}

int main(void)
{
    struct registry reg = { NULL, 0, 0 };
    int n;
    char cmd[8], a[16], b[16];

    if (scanf("%d", &n) != 1)
        return 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%7s", cmd) != 1)
            break;
        if (strcmp(cmd, "SET") == 0) {
            int v;
            if (scanf("%15s %d", a, &v) != 2)
                break;
            struct signal *s = reg_get(&reg, a);
            if (s == NULL)
                break;
            s->value = v;
            s->writes++;
        } else if (strcmp(cmd, "COPY") == 0) {
            if (scanf("%15s %15s", a, b) != 2)
                break;
            struct signal *src = reg_get(&reg, b);
            struct signal *dst = reg_get(&reg, a);
            if (src == NULL || dst == NULL)
                break;
            src->reads++;
            dst->value = src->value;
            dst->writes++;
        } else if (strcmp(cmd, "DUMP") == 0) {
            for (size_t k = 0; k < reg.len; k++)
                printf("%s=%d w=%d r=%d\n", reg.items[k].name, reg.items[k].value,
                       reg.items[k].writes, reg.items[k].reads);
        }
    }
    free(reg.items);
    return 0;
}
@@@ sample_input
4
SET rpm 3000
SET speed 88
COPY rpm_disp rpm
DUMP
@@@ sample_output
rpm=3000 w=1 r=1
speed=88 w=1 r=0
rpm_disp=3000 w=1 r=0

@@@ sample_input
4
SET a 1
SET b 2
COPY a b
DUMP
@@@ sample_output
a=2 w=2 r=0
b=2 w=1 r=1

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
3
COPY z z
COPY z z
DUMP
@@@ hidden_output
z=0 w=2 r=2

@@@ hidden_input
6
SET a -5
SET b 7
COPY d c
COPY e d
SET d 2147483647
DUMP
@@@ hidden_output
a=-5 w=1 r=0
b=7 w=1 r=0
c=0 w=0 r=1
d=2147483647 w=2 r=1
e=0 w=1 r=0

@@@ hidden_input
11
SET s0 -2147483648
COPY s1 s0
COPY s2 s1
COPY s3 s2
COPY s4 s3
COPY s5 s4
COPY s6 s5
COPY s7 s6
COPY s8 s7
COPY s9 s8
DUMP
@@@ hidden_output
s0=-2147483648 w=1 r=1
s1=-2147483648 w=1 r=1
s2=-2147483648 w=1 r=1
s3=-2147483648 w=1 r=1
s4=-2147483648 w=1 r=1
s5=-2147483648 w=1 r=1
s6=-2147483648 w=1 r=1
s7=-2147483648 w=1 r=1
s8=-2147483648 w=1 r=1
s9=-2147483648 w=1 r=0

@@@ hidden_input
7
SET torque 250
SET gear 3
COPY gear torque
SET torque 300
COPY torque gear
DUMP
DUMP
@@@ hidden_output
torque=250 w=3 r=1
gear=250 w=2 r=1
torque=250 w=3 r=1
gear=250 w=2 r=1

@@@ hidden_input
9
SET v1 11
SET v2 22
SET v3 33
SET v4 44
COPY v5 v4
COPY v6 v1
COPY v7 v2
COPY v8 v3
DUMP
@@@ hidden_output
v1=11 w=1 r=1
v2=22 w=1 r=1
v3=33 w=1 r=1
v4=44 w=1 r=1
v5=44 w=1 r=0
v6=11 w=1 r=0
v7=22 w=1 r=0
v8=33 w=1 r=0

@@@ hint
`reg_get` may call `realloc` on `r->items`. What happens to every `struct signal *` that was obtained **before** that call, if `realloc` had to move the array?
@@@ hint
In `COPY`, `src` is looked up first, and then the lookup of a **new** `dst` can grow (and move) the array. `src` then points into the freed old block: the read of `src->value` returns garbage, and `src->reads++` writes to freed memory. Look `src` up again after `dst` (it already exists by then, so the second lookup cannot grow the array).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct signal {
    char name[16];
    int value;
    int writes;
    int reads;
};

struct registry {
    struct signal *items;
    size_t len;
    size_t cap;
};

/* Find the signal called name; create it (value 0) if missing. NULL if out of memory. */
static struct signal *reg_get(struct registry *r, const char *name)
{
    for (size_t i = 0; i < r->len; i++)
        if (strcmp(r->items[i].name, name) == 0)
            return &r->items[i];

    if (r->len == r->cap) {
        size_t newcap = r->cap ? r->cap * 2 : 2;
        struct signal *tmp = realloc(r->items, newcap * sizeof *tmp);
        if (tmp == NULL)
            return NULL;
        r->items = tmp;
        r->cap = newcap;
    }
    struct signal *s = &r->items[r->len++];
    snprintf(s->name, sizeof s->name, "%s", name);
    s->value = 0;
    s->writes = 0;
    s->reads = 0;
    return s;
}

int main(void)
{
    struct registry reg = { NULL, 0, 0 };
    int n;
    char cmd[8], a[16], b[16];

    if (scanf("%d", &n) != 1)
        return 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%7s", cmd) != 1)
            break;
        if (strcmp(cmd, "SET") == 0) {
            int v;
            if (scanf("%15s %d", a, &v) != 2)
                break;
            struct signal *s = reg_get(&reg, a);
            if (s == NULL)
                break;
            s->value = v;
            s->writes++;
        } else if (strcmp(cmd, "COPY") == 0) {
            if (scanf("%15s %15s", a, b) != 2)
                break;
            struct signal *src = reg_get(&reg, b);
            struct signal *dst = reg_get(&reg, a);
            src = reg_get(&reg, b); /* FIX: creating dst may have moved the array; re-fetch src (it exists now, so no realloc) */
            if (src == NULL || dst == NULL)
                break;
            src->reads++;
            dst->value = src->value;
            dst->writes++;
        } else if (strcmp(cmd, "DUMP") == 0) {
            for (size_t k = 0; k < reg.len; k++)
                printf("%s=%d w=%d r=%d\n", reg.items[k].name, reg.items[k].value,
                       reg.items[k].writes, reg.items[k].reads);
        }
    }
    free(reg.items);
    return 0;
}
@@@ explanation_md
**Bug.** `reg_get` returns a pointer **into** the array, and it may `realloc` that array. `realloc` is allowed to move the block. The old block is freed, and every pointer into it becomes dangling (C11 7.22.3.5: "the old object is deallocated"). In `COPY dst src`:

```
src = reg_get(src)   -> &items[0]   (old block)
dst = reg_get(dst)   -> len == cap: realloc moves items, old block freed
src->reads++         -> write to freed memory  (heap-use-after-free)
dst->value = src->value -> read of freed memory (garbage)
```

This is the C version of C++ **iterator invalidation** (`std::vector::push_back` invalidates references). The regression suite never created a signal inside `COPY`, so the array never grew between the two lookups. With glibc, small reallocs often grow **in place**, so even the new script "worked" on some machines. AddressSanitizer and this judge's heap checker make `realloc` always move, which exposes the bug every time.

**Fix.** After the lookup that may grow the array, look `src` up again. By then both signals exist, so the second lookup cannot reallocate, and both pointers are valid until the next growing call. Sturdier designs keep **indices** instead of pointers (`size_t reg_find_or_add(...)` and `reg.items[i]` at the point of use). Another option is to store the signals as separately allocated nodes, so their addresses never change.

**Complexity.** Each lookup is O(len), so a script of n commands costs O(n * signals). The extra lookup does not change the bound.

**Common mistakes**
- "Fixing" it by swapping the two lookups. Then creating a new `src` moves the array under `dst`.
- Caching `&items[i]` in a long-lived struct (a callback table or a UI binding) while the array can still grow.
- Assuming `realloc` to a bigger size returns the same pointer when "there is free space after the block". It may or may not; the standard promises nothing.
- Using `realloc`'s return value check alone as proof of safety. The pointer you saved earlier is still stale.

**Interview follow-ups**
- Redesign `reg_get` to return an index. What does the caller have to change, and when can an index become invalid (removal with swap-with-last)?
- In a production ECU the signal table is generated at build time (from DBC/ARXML) as a `const` array. Why does that remove this whole class of bugs?
- Which tools would have found this before release (ASan, Valgrind, `-D_GLIBCXX_DEBUG`-like checked containers, static analyzers that track `realloc`)?
