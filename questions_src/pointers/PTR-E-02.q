@@@ meta
id: PTR-E-02
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Reverse a Half-Open Range with Two Pointers
tags: pointer-arithmetic, two-pointers, half-open-range, in-place
@@@ statement_md
Implement

```c
void reverse_range(int *first, int *last);
```

It reverses, in place, the elements in the **half-open range** `[first, last)`. `first` points to the first element and `last` points **one past** the last element, as in the C++ STL. So `reverse_range(a, a + n)` reverses a whole array of `n` elements. An empty range (`first == last`) is valid and does nothing.

Work with the two pointers directly: move them towards each other and swap. Do not compute an element count first.

**How it is tested.** A hidden `main()` reads an array and a list of `l r` pairs. For each pair it calls `reverse_range(arr + l, arr + r)` and prints the whole array.

**Input (read by the hidden harness)**
- Line 1: `n q`
- Line 2: `n` integers
- Next `q` lines: `l r` with `0 <= l <= r <= n`

**Output**
- After each call, the whole array on one line, separated by single spaces.

**Example**
```
Input:
6 2
1 2 3 4 5 6
0 6
1 4

Output:
6 5 4 3 2 1
6 3 4 5 2 1
```
The second call reverses `arr[1..3]` (`5 4 3`) of the already reversed array.
@@@ constraints_md
- `1 <= n <= 1000`, `1 <= q <= 50`
- `0 <= l <= r <= n` (`l == r` is an empty range)
- Elements are 32-bit `int` values, including `INT_MIN` and `INT_MAX`.
- Never write outside `[first, last)`.
@@@ starter_code
/* Reverse the half-open range [first, last) in place. */
void reverse_range(int *first, int *last)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>

/*USER_CODE*/

#define GUARD 4
#define GUARD_VAL 0x7E57C0DE

static int arena[GUARD + 1000 + GUARD];

int main(void)
{
    int n, q;
    if (scanf("%d %d", &n, &q) != 2) return 0;
    int *arr = arena + GUARD;
    for (int k = 0; k < GUARD; k++) {
        arena[k] = GUARD_VAL;
        arr[n + k] = GUARD_VAL;
    }
    for (int k = 0; k < n; k++)
        if (scanf("%d", &arr[k]) != 1) return 0;
    for (int t = 0; t < q; t++) {
        int l, r;
        if (scanf("%d %d", &l, &r) != 2) return 0;
        int saved_l = l < n ? arr[l] : 0;
        int saved_prev = l > 0 ? arr[l - 1] : 0;
        int saved_r = r < n ? arr[r] : 0;
        reverse_range(arr + l, arr + r);
        int bad = 0;
        for (int k = 0; k < GUARD; k++)
            if (arena[k] != GUARD_VAL || arr[n + k] != GUARD_VAL) bad = 1;
        if (l > 0 && arr[l - 1] != saved_prev) bad = 1;   /* element just before the range */
        if (r < n && arr[r] != saved_r) bad = 1;          /* element just after the range  */
        if (l == r && l < n && arr[l] != saved_l) bad = 1;
        if (bad) {
            printf("WRITE OUTSIDE THE RANGE\n");
            return 0;
        }
        for (int k = 0; k < n; k++) printf("%d%c", arr[k], k == n - 1 ? '\n' : ' ');
    }
    return 0;
}
@@@ sample_input
6 2
1 2 3 4 5 6
0 6
1 4
@@@ sample_output
6 5 4 3 2 1
6 3 4 5 2 1

@@@ sample_input
3 2
7 8 9
0 0
2 3
@@@ sample_output
7 8 9
7 8 9

@@@ hidden_input
1 1
42
0 1
@@@ hidden_output
42

@@@ hidden_input
2 1
-2147483648 2147483647
0 2
@@@ hidden_output
2147483647 -2147483648

@@@ hidden_input
5 1
1 2 3 4 5
0 5
@@@ hidden_output
5 4 3 2 1

@@@ hidden_input
4 3
10 20 30 40
4 4
0 2
2 4
@@@ hidden_output
10 20 30 40
20 10 30 40
20 10 40 30

@@@ hidden_input
7 2
3 3 3 1 3 3 3
0 7
3 3
@@@ hidden_output
3 3 3 1 3 3 3
3 3 3 1 3 3 3

@@@ hidden_input
10 3
0 1 2 3 4 5 6 7 8 9
0 10
0 5
5 10
@@@ hidden_output
9 8 7 6 5 4 3 2 1 0
5 6 7 8 9 4 3 2 1 0
5 6 7 8 9 0 1 2 3 4

@@@ hint
Keep two pointers: `first` at the front and `last` one past the back. The element at the back is `*(last - 1)`, not `*last`.
@@@ hint
Loop `while (first < last && first < --last)`: decrement `last` first so it points at a real element, then swap `*first` and `*last` and advance `first`. The loop must stop when the pointers meet or cross. An empty range must never touch memory.
@@@ solution_code
void reverse_range(int *first, int *last)
{
    /* Invariant: [first, last) is the part that is still unreversed. */
    while (first < last) {
        --last;                 /* last now points at a real element */
        if (first == last)      /* odd length: the middle element stays put */
            break;
        int tmp = *first;
        *first = *last;
        *last = tmp;
        ++first;
    }
}
@@@ explanation_md
**Approach.** Two pointers move towards each other. A half-open range `[first, last)` means `last` itself is *not* an element, so decrement it before you dereference it. Each iteration swaps the outermost unreversed pair and shrinks the range by one at each end:

```
[1 2 3 4 5 6)   first->1, last-1 -> 6   swap -> 6 2 3 4 5 1
  [2 3 4 5)     swap -> 6 5 3 4 2 1
    [3 4)       swap -> 6 5 4 3 2 1
     [)         first == last -> stop
```

When `first == last` at the start, the loop body never runs, so the range is never touched.

The last test shows a useful trick: reversing the whole array and then each half rotates the array (the three-reversal rotation).

**Complexity.** Time O(n) for a range of n elements (n/2 swaps), space O(1).

**Common mistakes**
- Dereferencing `last` itself. That is one past the end: a read out of bounds, and on the last element of the array, past the whole array.
- The loop condition `first != last` combined with *two* pointer moves per iteration. For even lengths the pointers cross without ever being equal, so the loop runs off the range.
- Computing `last - 1` on an empty range at the start of an array. `arr - 1` is a pointer before the array, which is undefined behavior even if it is never dereferenced (C11 6.5.6p8).
- Comparing pointers from different arrays with `<`. That is only defined inside the same array (or one past it).

**Interview follow-ups**
- Why does the standard allow a pointer one past the end of an array but not one before the start?
- Rewrite this using `ptrdiff_t n = last - first` and indices. Which version generates better code on a Cortex-M, and why does it rarely matter at `-O2`?
- Use `reverse_range` to rotate an array left by `k` in O(n) time and O(1) space.
- How would you make the function generic for any element type? (`void *`, element size, byte swaps.)
