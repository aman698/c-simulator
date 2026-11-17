@@@ meta
id: PTR-E-09
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Return Min and Max Through Pointer-to-Pointer Out-Parameters
tags: pointer-to-pointer, out-parameter, const-correctness, null-check
@@@ statement_md
Implement

```c
int find_extremes(const int *a, size_t n, const int **pmin, const int **pmax);
```

Instead of returning values, the function returns **pointers into the caller's array**, so the caller can also update the element or compute its index. Because a function can only change the caller's pointer variable through its address, the out-parameters have type `const int **`.

Rules:
- If `a == NULL` or `n == 0`: return `0`, and store `NULL` into `*pmin` and `*pmax`.
- Otherwise return `1`. Store a pointer to the **first** occurrence of the minimum into `*pmin`, and a pointer to the **last** occurrence of the maximum into `*pmax` (the same tie rule as C++ `std::minmax_element`).
- The caller may pass `pmin == NULL` and/or `pmax == NULL` if it is not interested in that result. Never write through a `NULL` out-parameter.

**How it is tested.** A hidden `main()` initialises its two result pointers to a sentinel, calls your function, and prints the return value and the **index** of each result (`*pmin - a`).

**Input (read by the hidden harness)**
- Line 1: `n mode`. `mode` is `both`, `min`, `max`, `none` (which out-parameters are passed) or `nullarr` (both out-parameters are passed, but `a` is `NULL`).
- Line 2: `n` integers (absent when `n = 0`).

**Output**
- `ret=R min=X max=Y`. `X`/`Y` is the index, `NULL` if the function stored `NULL`, `-` if that out-parameter was not passed, or `UNCHANGED` if the function failed to store anything.

**Example**
```
Input:
6 both
4 -5 9 -5 9 0

Output:
ret=1 min=1 max=4
```
The minimum `-5` occurs at indices 1 and 3 (first: 1). The maximum `9` occurs at 2 and 4 (last: 4).
@@@ constraints_md
- `0 <= n <= 1000`
- Elements are 32-bit `int` values (`INT_MIN` and `INT_MAX` may appear).
- Single pass over the array; do not modify it.
@@@ starter_code
#include <stddef.h>

/* *pmin -> first minimum, *pmax -> last maximum. Return 1, or 0 if empty. */
int find_extremes(const int *a, size_t n, const int **pmin, const int **pmax)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

/*USER_CODE*/

static int data[1000];
static const int sentinel = 12345;

static void show(const char *name, int asked, const int *p, const int *a, size_t n)
{
    printf("%s=", name);
    if (!asked) printf("-");
    else if (p == NULL) printf("NULL");
    else if (p == &sentinel) printf("UNCHANGED");
    else if (a != NULL && p >= a && p < a + n) printf("%td", p - a);
    else printf("BAD_POINTER");
}

int main(void)
{
    int n;
    char mode[16];
    if (scanf("%d %15s", &n, mode) != 2) return 0;
    for (int i = 0; i < n; i++)
        if (scanf("%d", &data[i]) != 1) return 0;

    const int *mn = &sentinel, *mx = &sentinel;
    int want_min = strcmp(mode, "both") == 0 || strcmp(mode, "min") == 0 || strcmp(mode, "nullarr") == 0;
    int want_max = strcmp(mode, "both") == 0 || strcmp(mode, "max") == 0 || strcmp(mode, "nullarr") == 0;
    const int *arr = strcmp(mode, "nullarr") == 0 ? NULL : data;

    int ret = find_extremes(arr, (size_t)n, want_min ? &mn : NULL, want_max ? &mx : NULL);

    printf("ret=%d ", ret);
    show("min", want_min, mn, arr, (size_t)n);
    printf(" ");
    show("max", want_max, mx, arr, (size_t)n);
    printf("\n");
    return 0;
}
@@@ sample_input
6 both
4 -5 9 -5 9 0
@@@ sample_output
ret=1 min=1 max=4

@@@ sample_input
0 both
@@@ sample_output
ret=0 min=NULL max=NULL

@@@ hidden_input
3 both
7 7 7
@@@ hidden_output
ret=1 min=0 max=2

@@@ hidden_input
1 both
-2147483648
@@@ hidden_output
ret=1 min=0 max=0

@@@ hidden_input
4 min
2147483647 -2147483648 2147483647 -2147483648
@@@ hidden_output
ret=1 min=1 max=-

@@@ hidden_input
4 max
2147483647 -2147483648 2147483647 -2147483648
@@@ hidden_output
ret=1 min=- max=2

@@@ hidden_input
5 none
1 2 3 4 5
@@@ hidden_output
ret=1 min=- max=-

@@@ hidden_input
3 nullarr
1 2 3
@@@ hidden_output
ret=0 min=NULL max=NULL

@@@ hidden_input
0 max
@@@ hidden_output
ret=0 min=- max=NULL

@@@ hidden_input
5 both
5 4 3 2 1
@@@ hidden_output
ret=1 min=4 max=0

@@@ hint
Track two **local** pointers `lo` and `hi` while scanning. At the end, store them through the out-parameters: `*pmin = lo;`, but only `if (pmin != NULL)`.
@@@ hint
The tie rules decide `<` versus `<=`. A new minimum replaces `lo` only if it is strictly smaller (`*p < *lo`), which keeps the first one. A maximum replaces `hi` when `*p >= *hi`, which keeps the last one.
@@@ solution_code
#include <stddef.h>

int find_extremes(const int *a, size_t n, const int **pmin, const int **pmax)
{
    const int *lo = NULL, *hi = NULL;
    int found = 0;

    if (a != NULL && n > 0) {
        const int *end = a + n;
        lo = hi = a;
        for (const int *p = a + 1; p < end; p++) {
            if (*p < *lo) lo = p;      /* strict: keep the FIRST minimum */
            if (*p >= *hi) hi = p;     /* non-strict: move to the LAST maximum */
        }
        found = 1;
    }

    if (pmin != NULL) *pmin = lo;      /* NULL when nothing was found */
    if (pmax != NULL) *pmax = hi;
    return found;
}
@@@ explanation_md
**Approach.** To change a variable of type `T` in the caller, you pass a `T *`. The caller's variables here have type `const int *`, so the out-parameters are `const int **`. Inside the function, `*pmin = lo;` writes into the caller's pointer variable.

```
caller:  const int *mn;            find_extremes(a, n, &mn, NULL);
                 ^                                     |
callee:  const int **pmin = &mn  --*pmin = lo-------- +
```

Scan once with two local pointers, then publish them. The tie rule is just the comparison operator: `<` keeps the first minimum and `>=` moves to the last maximum.

**Complexity.** Time O(n) (a single pass), space O(1).

**Common mistakes**
- Declaring the parameter as `const int *pmin` and assigning `pmin = lo;`. That changes only the function's local copy, and the caller sees nothing (the `UNCHANGED` output).
- Writing through a `NULL` out-parameter (crash), or not writing `NULL` for an empty array, which leaves the caller with an uninitialised or stale pointer.
- Returning a pointer to a **local copy** of the minimum value instead of into the array. It dangles as soon as the function returns.
- Mixing up `<` and `<=`, which silently breaks the documented tie rules.

**Interview follow-ups**
- Why does `int **` not convert implicitly to `const int **`? Show the loophole it would open (C FAQ 11.10).
- Find both min and max with about `3n/2` comparisons instead of `2n` (process elements in pairs).
- When would you return an **index** (`size_t`, with `SIZE_MAX` as "none") instead of a pointer? Think about arrays that may be reallocated, and data stored in NVM.
- How does this pattern appear in APIs such as `strtol(const char *s, char **endptr, int base)`?
