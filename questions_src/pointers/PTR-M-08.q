@@@ meta
id: PTR-M-08
topic: Pointers
difficulty: Medium
type: FIND_THE_BUG
title: qsort Comparator Breaks on Extreme Sensor Offsets
tags: qsort, comparator, integer-overflow, void-pointer, asked-in-automotive
@@@ statement_md
An end-of-line tester collects raw **offset calibration values** (signed 32-bit) from many sensors. It sorts them in **ascending** order with `qsort`, prints the sorted list, and prints the **lower median** `v[(n-1)/2]`.

The tool works in the lab, but on a production batch where some sensors report saturated values near `INT_MIN`/`INT_MAX` the output order is wrong, and the sanitizer build aborts with a runtime error. Find and fix the bug. Keep using `qsort`.

**Input**
- Line 1: `n`
- Line 2: `n` integers.

**Output**
- Line 1: the sorted values separated by single spaces.
- Line 2: `median <value>`.
- For `n = 0`, print only `empty`.

**Example**
```
Input:
5
30 -10 20 0 -5

Output:
-10 -5 0 20 30
median 0
```
@@@ constraints_md
- `0 <= n <= 100000`
- `INT_MIN <= value <= INT_MAX`
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

static int v[100000];

/* Ascending order for qsort. */
static int cmp_int(const void *a, const void *b)
{
    return *(const int *)a - *(const int *)b;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    if (n <= 0) {
        printf("empty\n");
        return 0;
    }
    for (int i = 0; i < n; i++)
        if (scanf("%d", &v[i]) != 1) return 0;

    qsort(v, (size_t)n, sizeof v[0], cmp_int);

    for (int i = 0; i < n; i++) printf("%d%c", v[i], i == n - 1 ? '\n' : ' ');
    printf("median %d\n", v[(n - 1) / 2]);
    return 0;
}
@@@ sample_input
5
30 -10 20 0 -5
@@@ sample_output
-10 -5 0 20 30
median 0

@@@ sample_input
4
2000000000 -2000000000 5 -5
@@@ sample_output
-2000000000 -5 5 2000000000
median -5

@@@ hidden_input
1
-2147483648
@@@ hidden_output
-2147483648
median -2147483648

@@@ hidden_input
0
@@@ hidden_output
empty

@@@ hidden_input
3
2147483647 -2147483648 0
@@@ hidden_output
-2147483648 0 2147483647
median 0

@@@ hidden_input
6
7 7 -7 7 -7 0
@@@ hidden_output
-7 -7 0 7 7 7
median 0

@@@ hidden_input
4
-2147483648 1 -2147483648 2147483647
@@@ hidden_output
-2147483648 -2147483648 1 2147483647
median -2147483648

@@@ hidden_input
8
100 -1 2147483647 -2147483647 3 -1 0 1500000000
@@@ hidden_output
-2147483647 -1 -1 0 3 100 1500000000 2147483647
median 0

@@@ hint
What does `a - b` evaluate to when `a = 2000000000` and `b = -2000000000`? Does the result fit in an `int`?
@@@ hint
Signed overflow is undefined behavior, and in practice it wraps to a value with the **wrong sign**, so the comparator reports "less" when it should report "greater". Compare instead of subtracting: `(x > y) - (x < y)` gives -1, 0 or 1 and can never overflow.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

static int v[100000];

/* Ascending order for qsort. */
static int cmp_int(const void *a, const void *b)
{
    const int x = *(const int *)a;
    const int y = *(const int *)b;
    return (x > y) - (x < y);   /* FIX: x - y overflows for operands of opposite sign */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    if (n <= 0) {
        printf("empty\n");
        return 0;
    }
    for (int i = 0; i < n; i++)
        if (scanf("%d", &v[i]) != 1) return 0;

    qsort(v, (size_t)n, sizeof v[0], cmp_int);

    for (int i = 0; i < n; i++) printf("%d%c", v[i], i == n - 1 ? '\n' : ' ');
    printf("median %d\n", v[(n - 1) / 2]);
    return 0;
}
@@@ explanation_md
**Bug.** `return *(const int *)a - *(const int *)b;` is the textbook comparator, and it is wrong for the full `int` range. When the operands have opposite signs and are large, the true difference does not fit in 32 bits:

```
 2000000000 - (-2000000000) = 4000000000  > INT_MAX
```

Signed overflow is **undefined behavior** (C11 6.5p5). UBSan aborts with "signed integer overflow". Without sanitizers it typically wraps to `-294967296`, so the comparator claims `2e9 < -2e9`. `qsort` then gets an inconsistent order, the array ends up partly unsorted, and the median is wrong.

**Fix.** Never subtract to compare. `(x > y) - (x < y)` evaluates to exactly -1, 0 or +1 and cannot overflow. Writing out `if (x < y) return -1; if (x > y) return 1; return 0;` is equally correct.

**Complexity.** O(n log n) time for the sort, O(1) extra space (besides qsort's internal recursion).

**Common mistakes**
- "Fixing" it by casting to `unsigned`. The difference then wraps silently and the sign is still wrong.
- Using `(long)x - y`. That only works where `long` is 64-bit (Linux), not on Windows or 32-bit ARM, where `long` is 32 bits. `(long long)x - y` is correct, but the result must still be reduced to -1/0/1 before it is returned as `int`.
- Comparing `const void *` pointers themselves (`a < b`) instead of the values they point to.
- The same overflow trap in the opposite direction: `b - a` for a descending sort.

**Interview follow-ups**
- Write a descending comparator for `uint32_t` timestamps. Why is `b - a` wrong there too (unsigned wrap)?
- `qsort` requires a **consistent total order**. What can happen inside an introsort or merge sort if the comparator is not transitive?
- How would you find the median in O(n) average time without sorting (quickselect)?
- For a 16-bit `int16_t` key, is `a - b` safe? (Yes: both promote to `int`, and the difference fits.)
