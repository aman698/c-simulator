@@@ meta
id: PTR-M-02
topic: Pointers
difficulty: Medium
type: FUNCTION
title: qsort an Array of String Pointers (Length, Then Alphabetical)
tags: qsort, comparator, array-of-pointers, double-indirection, strings
@@@ statement_md
A calibration tool lists ECU signal names. The names are stored once in a string pool, and the tool only keeps an **array of pointers** to them. Implement

```c
void sort_signals(const char **names, size_t n);
```

It reorders the **pointers** in `names[0..n-1]` with the standard library **`qsort`** so that:

1. shorter names come first, and
2. names of equal length are in ascending `strcmp` order (byte order, so `'C' < 'a'`).

Rules:
- You must call `qsort` (the harness counts the calls). Write your own comparator for it.
- Move only the pointers. The characters in the pool must not be changed or copied.
- `names` is never `NULL`; `n` may be `0` or `1`.

**How it is tested.** A hidden `main()` builds the pointer array, calls your function, checks that the result is a permutation of the original pointers and that the pool is untouched, and prints the names in their new order.

**Input (read by the hidden harness)**
- Line 1: `n`
- Line 2: `n` names (1 to 31 printable characters, no spaces).

**Output**
- The sorted names, one per line.

**Example**
```
Input:
6
rpm speed abs esp throttle_pos brake

Output:
abs
esp
rpm
brake
speed
throttle_pos
```
@@@ constraints_md
- `0 <= n <= 1000`
- Names may repeat.
- Use `qsort` from `<stdlib.h>`.
@@@ starter_code
#include <stdlib.h>
#include <string.h>

/* Comparator for qsort: what do a and b really point to? */
static int cmp_signal(const void *a, const void *b)
{
    /* TODO */
    return 0;
}

void sort_signals(const char **names, size_t n)
{
    /* TODO: call qsort with cmp_signal */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

static int qsort_calls;
static int qsort_bad_size;

static void counted_qsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *))
{
    qsort_calls++;
    if (size != sizeof(const char *)) {
        qsort_bad_size = 1;
        return;
    }
    qsort(base, n, size, cmp);
}
#define qsort counted_qsort

/*USER_CODE*/

#undef qsort

#define SLOT 32
static char pool[1000 * SLOT];
static char pool_copy[1000 * SLOT];
static const char *names[1000];
static unsigned char used[1000];

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%31s", pool + (size_t)i * SLOT) != 1) return 0;
        names[i] = pool + (size_t)i * SLOT;
    }
    memcpy(pool_copy, pool, sizeof pool);

    sort_signals(names, (size_t)n);

    if (qsort_bad_size) {
        printf("BAD ELEMENT SIZE PASSED TO QSORT\n");
        return 0;
    }
    if (n >= 2 && qsort_calls == 0) {
        printf("QSORT NOT USED\n");
        return 0;
    }
    if (memcmp(pool, pool_copy, sizeof pool) != 0) {
        printf("STRINGS WERE MODIFIED\n");
        return 0;
    }
    for (int i = 0; i < n; i++) {
        ptrdiff_t off = names[i] - pool;
        if (names[i] == NULL || off < 0 || off >= (ptrdiff_t)sizeof pool || off % SLOT != 0 || used[off / SLOT]) {
            printf("POINTER ARRAY CORRUPTED\n");
            return 0;
        }
        used[off / SLOT] = 1;
    }
    for (int i = 0; i < n; i++) printf("%s\n", names[i]);
    return 0;
}
@@@ sample_input
6
rpm speed abs esp throttle_pos brake
@@@ sample_output
abs
esp
rpm
brake
speed
throttle_pos

@@@ sample_input
4
can CAN cAN Can
@@@ sample_output
CAN
Can
cAN
can

@@@ hidden_input
1
x
@@@ hidden_output
x

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
5
lin lin can lin can
@@@ hidden_output
can
can
lin
lin
lin

@@@ hidden_input
5
eeeee dddd ccc bb a
@@@ hidden_output
a
bb
ccc
dddd
eeeee

@@@ hidden_input
6
gear2 gear1 gear10 gear0 gear11 gear9
@@@ hidden_output
gear0
gear1
gear2
gear9
gear10
gear11

@@@ hidden_input
3
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa b aaaaaaaaaaaaaaaaaaaaaaaaaaaaaab
@@@ hidden_output
b
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaab

@@@ hidden_input
12
wheel_speed_fl wheel_speed_fr yaw_rate lat_acc steer_angle brake_press abs_active esp_off gear rpm vbat ign
@@@ hidden_output
ign
rpm
gear
vbat
esp_off
lat_acc
yaw_rate
abs_active
brake_press
steer_angle
wheel_speed_fl
wheel_speed_fr

@@@ hint
`qsort` passes your comparator **pointers to the elements**. The elements are `const char *`, so `a` and `b` are really `const char *const *` (pointers to pointers), not strings.
@@@ hint
Inside the comparator: `const char *sa = *(const char *const *)a;`. Then compare `strlen(sa)` with `strlen(sb)` using `(la > lb) - (la < lb)` (no subtraction of `size_t`!), and fall back to `strcmp(sa, sb)` when the lengths are equal.
@@@ solution_code
#include <stdlib.h>
#include <string.h>

static int cmp_signal(const void *a, const void *b)
{
    /* qsort hands us pointers TO the array elements; each element is a const char * */
    const char *sa = *(const char *const *)a;
    const char *sb = *(const char *const *)b;
    size_t la = strlen(sa), lb = strlen(sb);

    if (la != lb)
        return (la > lb) - (la < lb);   /* no size_t subtraction: it would wrap, not go negative */
    return strcmp(sa, sb);               /* total order: equal only if the strings are equal */
}

void sort_signals(const char **names, size_t n)
{
    if (n < 2)
        return;
    qsort(names, n, sizeof names[0], cmp_signal);   /* element = one pointer */
}
@@@ explanation_md
**Approach.** `qsort(base, n, size, cmp)` knows nothing about types. It moves `size`-byte blocks around and calls `cmp` with the **addresses of two elements**. Here each element is a `const char *`, so the comparator receives a `const char *const *` disguised as `const void *`, and must dereference it once to reach the string:

```
names:  [ptr0][ptr1][ptr2]          cmp(&names[i], &names[j])
           |     |     |            a = &names[i]  (const char *const *)
           v     v     v            *a = names[i]  (const char *) -> "rpm"
          "rpm" "abs" "brake"
```

The key is (length, then `strcmp`). Two elements compare equal only when the strings are identical, so the order is **total** and the output is the same with every `qsort` implementation (glibc uses merge sort, Windows uses an introsort-like algorithm, and neither is guaranteed to be stable).

Only 8-byte pointers are swapped, never the strings. That is why sorting an array of pointers is the standard way to sort large records.

**Complexity.** O(n log n) comparisons, each O(L) for names of length L. Extra space O(1) for the caller (qsort may use O(log n) stack).

**Common mistakes**
- `strcmp((const char *)a, (const char *)b)`. This compares the **bytes of the pointers** as if they were text: garbage order or a crash. It is the most common qsort bug in interviews.
- `qsort(names, n, sizeof(char), ...)` or `sizeof(*names[0])`. The element size is `sizeof(char *)`.
- `return strlen(sa) - strlen(sb);`. `size_t` subtraction wraps to a huge positive value, and converting it to `int` is implementation-defined.
- Copying the strings into a 2-D array and sorting that. It works, but it moves 32 bytes per swap and breaks the "pool is read-only" requirement.

**Interview follow-ups**
- How would you sort an array of `struct dtc *` pointers by a field, and what changes compared with sorting an array of `struct dtc` values?
- `qsort` is not stable. How do you make equal keys keep their input order? (Add the original index as a last tie-breaker.)
- Write a comparator for "natural order" (`gear2 < gear10`) without relying on the length trick.
- Why is a comparator like `return *(int *)a - *(int *)b;` wrong for `int` keys?
