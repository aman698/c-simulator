@@@ meta
id: ARR-E-01
topic: Arrays
difficulty: Easy
type: CODE
title: Rotate an Array Right by K Steps (In-Place)
tags: rotation, in-place, reversal, asked-in-automotive
@@@ statement_md
Rotate an array of `n` integers to the **right** by `k` steps, **in place** (O(1) extra memory).

After one right-rotation, the last element moves to the front:
`[1 2 3 4 5] -> [5 1 2 3 4]`.

`k` can be much larger than `n`, so a loop that rotates one step at a time (`O(n*k)`) will not finish within the time limit.

**Input**
- Line 1: two integers `n` and `k`.
- Line 2: `n` space-separated integers.

**Output**
- The rotated array on one line, elements separated by a single space.

**Example**
```
Input:
7 3
1 2 3 4 5 6 7

Output:
5 6 7 1 2 3 4
```
@@@ constraints_md
- `1 <= n <= 100000`
- `0 <= k <= 1000000000`
- Each element fits in a 32-bit `int` (`INT_MIN` and `INT_MAX` may appear).
- Use O(1) extra memory besides the input array itself.
@@@ starter_code
#include <stdio.h>

static int a[100000];

int main(void)
{
    int n, k;
    if (scanf("%d %d", &n, &k) != 2) return 0;
    for (int i = 0; i < n; i++) scanf("%d", &a[i]);

    /* TODO: rotate a[0..n-1] right by k steps, in place */

    for (int i = 0; i < n; i++) printf("%d%c", a[i], i == n - 1 ? '\n' : ' ');
    return 0;
}
@@@ sample_input
7 3
1 2 3 4 5 6 7
@@@ sample_output
5 6 7 1 2 3 4

@@@ sample_input
4 6
-1 -100 3 99
@@@ sample_output
3 99 -1 -100

@@@ hidden_input
1 1000000000
42
@@@ hidden_output
42

@@@ hidden_input
5 0
1 2 3 4 5
@@@ hidden_output
1 2 3 4 5

@@@ hidden_input
5 5
1 2 3 4 5
@@@ hidden_output
1 2 3 4 5

@@@ hidden_input
3 1
-2147483648 0 2147483647
@@@ hidden_output
2147483647 -2147483648 0

@@@ hidden_input
6 4
7 7 7 7 7 7
@@@ hidden_output
7 7 7 7 7 7

@@@ hidden_input
2 1000000001
10 20
@@@ hidden_output
20 10

@@@ hidden_input
8 13
1 2 3 4 5 6 7 8
@@@ hidden_output
4 5 6 7 8 1 2 3

@@@ hint
`k` steps right is the same as `k % n` steps right. Reduce it first.
@@@ hint
Reverse the whole array, then reverse the first `k` elements, then reverse the remaining `n - k` elements.
@@@ solution_code
#include <stdio.h>

static int a[100000];

static void reverse(int *arr, int lo, int hi)
{
    while (lo < hi) {
        int t = arr[lo];
        arr[lo++] = arr[hi];
        arr[hi--] = t;
    }
}

int main(void)
{
    int n, k;
    if (scanf("%d %d", &n, &k) != 2 || n <= 0) return 0;
    for (int i = 0; i < n; i++)
        if (scanf("%d", &a[i]) != 1) return 0;

    k %= n;                 /* k > n wraps around */
    reverse(a, 0, n - 1);   /* 7 6 5 4 3 2 1 */
    reverse(a, 0, k - 1);   /* 5 6 7 | 4 3 2 1 */
    reverse(a, k, n - 1);   /* 5 6 7 | 1 2 3 4 */

    for (int i = 0; i < n; i++) printf("%d%c", a[i], i == n - 1 ? '\n' : ' ');
    return 0;
}
@@@ explanation_md
**Approach: three reversals.** Rotating right by `k` moves the last `k` elements to the front. Reversing the whole array puts them at the front, but in reverse order. Reversing the first `k` and then the last `n-k` elements restores both blocks' order.

```
[1 2 3 4 5 6 7], k=3
reverse all   -> 7 6 5 4 3 2 1
reverse [0,2] -> 5 6 7 4 3 2 1
reverse [3,6] -> 5 6 7 1 2 3 4
```

**Complexity.** Time O(n): each element is swapped at most twice. Space O(1).

**Common mistakes**
- Not reducing `k % n` first. With `k = 10^9` the one-step-at-a-time loop is `O(n*k)` and hits the time limit.
- Using a second array. That is O(n) extra memory and breaks the in-place requirement.
- Off-by-one in the reverse bounds (`k` vs `k-1`). When `k % n == 0`, `reverse(a, 0, -1)` must be a no-op, which `lo < hi` guarantees.

**Interview follow-ups**
- Rotate **left** by `k`. (Same idea: reverse the first `k`, then the rest, then the whole array; or rotate right by `n - k`.)
- Do it with the **juggling / cyclic-replacement** algorithm using `gcd(n, k)` cycles. Which approach touches memory more cache-friendly?
- Embedded angle: rotating a **circular log buffer** so the oldest entry is at index 0 before dumping it over UART, with no spare RAM.
