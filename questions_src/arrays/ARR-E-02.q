@@@ meta
id: ARR-E-02
topic: Arrays
difficulty: Easy
type: FUNCTION
title: Second Largest Distinct Value Without Sentinels
tags: second-largest, single-pass, edge-cases, int-min, api-contract
@@@ statement_md
Implement

```c
int second_largest(const int *a, int n, int *out);
```

It finds the **second largest distinct value** in `a[0..n-1]` in a **single pass** without modifying the array.

- If it exists, store it in `*out` and return `1`.
- If it does not exist, return `0` and leave `*out` **unchanged**. This happens when `a == NULL`, when `n < 2`, or when all elements are equal.

"Distinct" means duplicates of the maximum do not count: for `{9, 9, 4}` the answer is `4`, not `9`.

Every 32-bit value is a legal element, **including `INT_MIN`**. Do not use `INT_MIN` (or any other value) as a "not found yet" sentinel.

**How it is tested.** A hidden `main()` reads several test cases, calls your function once per case and prints the result. It also checks that the array is not modified and that `*out` is untouched when you return `0`. `qsort` is disabled.

**Input (read by the hidden harness)**
- Line 1: the number of test cases `t`.
- Next `t` lines: `n` followed by `n` integers, or the word `NULL` followed by `n` (the harness then passes `a = NULL`).

**Output**
- One line per test case: the second largest distinct value, or `none`.

**Example**
```
Input:
3
5 12 35 1 10 34
4 10 10 10 10
1 7

Output:
34
none
none
```
@@@ constraints_md
- `1 <= t <= 20`, `0 <= n <= 1000`
- Elements are any 32-bit `int` values (`INT_MIN` and `INT_MAX` may appear).
- O(n) time, O(1) extra memory, one pass over the array.
@@@ starter_code
#include <stddef.h>

/*
 * Return 1 and store the second largest DISTINCT value in *out.
 * Return 0 and leave *out unchanged if there is none
 * (a == NULL, n < 2, or all elements equal).
 */
int second_largest(const int *a, int n, int *out)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <limits.h>

#define qsort(...) qsort_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef qsort

#define MAXN 1000
#define OUT_SENTINEL 0x5A5A5A5A

static int buf[MAXN];
static int copy[MAXN];

int main(void)
{
    int t;
    if (scanf("%d", &t) != 1) return 0;
    while (t-- > 0) {
        char tok[32];
        int n;
        int is_null = 0;
        if (scanf("%31s", tok) != 1) return 0;
        if (strcmp(tok, "NULL") == 0) {
            is_null = 1;
            if (scanf("%d", &n) != 1) return 0;
        } else {
            n = atoi(tok);
        }
        if (n < 0 || n > MAXN) return 0;
        if (!is_null) {
            for (int i = 0; i < n; i++)
                if (scanf("%d", &buf[i]) != 1) return 0;
            memcpy(copy, buf, (size_t)n * sizeof buf[0]);
        }

        int out = OUT_SENTINEL;
        int ret = second_largest(is_null ? NULL : buf, n, &out);

        if (!is_null && memcmp(copy, buf, (size_t)n * sizeof buf[0]) != 0) {
            printf("ARRAY WAS MODIFIED\n");
            continue;
        }
        if (ret == 1)
            printf("%d\n", out);
        else if (ret == 0)
            puts(out == OUT_SENTINEL ? "none" : "none (but *out was modified)");
        else
            printf("BAD RETURN VALUE %d\n", ret);
    }
    return 0;
}
@@@ sample_input
3
5 12 35 1 10 34
4 10 10 10 10
1 7
@@@ sample_output
34
none
none

@@@ sample_input
2
3 -5 -1 -3
2 2147483647 -2147483648
@@@ sample_output
-3
-2147483648

@@@ hidden_input
3
NULL 5
NULL 0
0
@@@ hidden_output
none
none
none

@@@ hidden_input
4
2 5 -2147483648
2 -2147483648 5
3 -2147483648 -2147483648 -2147483648
3 -2147483648 -2147483647 -2147483648
@@@ hidden_output
-2147483648
-2147483648
none
-2147483648

@@@ hidden_input
3
6 1 9 9 2 9 9
5 8 3 8 10 1
6 4 4 4 4 4 3
@@@ hidden_output
2
8
3

@@@ hidden_input
4
5 1 2 3 4 5
5 5 4 3 2 1
2 3 3
2 3 4
@@@ hidden_output
4
4
none
3

@@@ hidden_input
3
4 2147483647 2147483647 2147483646 2147483647
3 0 0 -1
3 -7 -7 0
@@@ hidden_output
2147483646
-1
-7

@@@ hidden_input
2
10 3 1 4 1 5 9 2 6 5 3
8 -10 -20 -30 -40 -50 -60 -70 -80
@@@ hidden_output
6
-20

@@@ hint
Keep two variables, `first` and `second`. A new value can beat `first`, fall strictly between `first` and `second`, or be equal to `first`. Equal to `first` must be ignored.
@@@ hint
Do not start `second` at `INT_MIN`. A valid answer can be `INT_MIN`. Start `first` at `a[0]` and keep a separate `have_second` flag that records whether `second` holds a real value.
@@@ solution_code
#include <stddef.h>

int second_largest(const int *a, int n, int *out)
{
    if (a == NULL || n < 2)
        return 0;

    int first = a[0];
    int second = 0;          /* meaningless until have_second is set */
    int have_second = 0;

    for (int i = 1; i < n; i++) {
        int x = a[i];
        if (x > first) {
            second = first;              /* old max becomes the runner-up */
            first = x;
            have_second = 1;
        } else if (x < first && (!have_second || x > second)) {
            second = x;                  /* strictly below the max */
            have_second = 1;
        }
        /* x == first: a duplicate of the max, ignore it */
    }

    if (!have_second)
        return 0;                        /* all elements were equal */
    *out = second;
    return 1;
}
@@@ explanation_md
**Approach.** Make one pass and keep `first` (the maximum so far) and `second` (the largest value strictly below `first`). For each `x`:

| case | action |
|---|---|
| `x > first` | `second = first; first = x;` |
| `second < x < first`, or `second` is not set yet | `second = x;` |
| `x == first` | ignore (a duplicate of the max is not a distinct value) |

A flag `have_second` replaces the usual `INT_MIN` sentinel, so the function is correct for every input, including arrays whose real answer is `INT_MIN`.

**Complexity.** Time O(n), one pass. Space O(1). Sorting first would be O(n log n) and would also need a copy, because the array is `const`.

**Common mistakes**
- Initialising `second = INT_MIN` and returning "none" when `second == INT_MIN`. For `{5, INT_MIN}` the correct answer *is* `INT_MIN`.
- Using `x >= first` in the first branch. A duplicate max then pushes the max into `second`, so `{9, 9, 4}` gives `9`.
- Forgetting the `x < first` check in the second branch, which also lets the max leak into `second`.
- Writing `*out` on failure. Callers often keep a default value in `*out`, so an API that says "unchanged on failure" must keep that promise.
- Not handling `a == NULL` or `n < 2` before reading `a[0]`.

**Interview follow-ups**
- Return the **k-th** largest distinct value. (For small k, keep a sorted array of k slots. In general, use quickselect on a copy or a size-k min-heap: O(n log k).)
- Find the largest and second largest with the fewest comparisons: `n + ceil(log2 n) - 2` using a tournament.
- If duplicates *do* count (`{9, 9, 4}` -> `9`), what changes? (Only the `x == first` branch.)
- Why is `const int *a` part of the contract, and what does it let the compiler and a reviewer assume?
