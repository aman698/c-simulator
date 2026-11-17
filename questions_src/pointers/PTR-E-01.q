@@@ meta
id: PTR-E-01
topic: Pointers
difficulty: Easy
type: FUNCTION
title: Swap Two Integers Through Pointers (Alias- and NULL-Safe)
tags: swap, pass-by-reference, aliasing, null-check, asked-in-automotive
@@@ statement_md
Implement

```c
void swap_int(int *a, int *b);
```

It exchanges the two integers that `a` and `b` point to. C passes arguments **by value**, so this only works because the caller passes the *addresses* of its variables.

Your function must be robust, as required by most automotive coding guidelines:

- If `a` or `b` is `NULL`, do nothing.
- `a` and `b` may point to the **same** object (`swap_int(&x, &x)`). The value must stay unchanged.
- Values cover the whole `int` range, including `INT_MIN` and `INT_MAX`. Signed overflow is undefined behavior and the judge runs with UBSan.

**How it is tested.** A hidden `main()` reads an array and a list of index pairs. For each pair `i j` it calls `swap_int(&arr[i], &arr[j])` and prints the array. An index of `-1` means "pass `NULL` for that argument".

**Input (read by the hidden harness)**
- Line 1: `n q`
- Line 2: `n` integers
- Next `q` lines: `i j` with `-1 <= i, j < n`

**Output**
- After each call, the array on one line, separated by single spaces.

**Example**
```
Input:
3 2
10 20 30
0 2
1 1

Output:
30 20 10
30 20 10
```
The second call swaps `arr[1]` with itself, which leaves it unchanged.
@@@ constraints_md
- `1 <= n <= 20`, `1 <= q <= 20`
- `INT_MIN <= arr[k] <= INT_MAX`
- `i == j` is allowed; `-1` means `NULL`.
@@@ starter_code
#include <stddef.h>

/* Exchange *a and *b. Must handle NULL and a == b. */
void swap_int(int *a, int *b)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stddef.h>

/*USER_CODE*/

#define GUARD_VAL 0x5A5A5A5A

int main(void)
{
    int arena[1 + 20 + 1];
    int n, q;
    if (scanf("%d %d", &n, &q) != 2) return 0;
    int *arr = arena + 1;
    arena[0] = GUARD_VAL;
    arr[n] = GUARD_VAL;
    for (int k = 0; k < n; k++)
        if (scanf("%d", &arr[k]) != 1) return 0;
    for (int t = 0; t < q; t++) {
        int i, j;
        if (scanf("%d %d", &i, &j) != 2) return 0;
        swap_int(i < 0 ? NULL : &arr[i], j < 0 ? NULL : &arr[j]);
        if (arena[0] != GUARD_VAL || arr[n] != GUARD_VAL) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
        for (int k = 0; k < n; k++) printf("%d%c", arr[k], k == n - 1 ? '\n' : ' ');
    }
    return 0;
}
@@@ sample_input
3 2
10 20 30
0 2
1 1
@@@ sample_output
30 20 10
30 20 10

@@@ sample_input
2 2
5 -7
0 -1
-1 1
@@@ sample_output
5 -7
5 -7

@@@ hidden_input
2 1
2147483647 -2147483648
0 1
@@@ hidden_output
-2147483648 2147483647

@@@ hidden_input
1 2
42
0 0
0 0
@@@ hidden_output
42
42

@@@ hidden_input
5 2
1 2 3 4 5
0 4
1 3
@@@ hidden_output
5 2 3 4 1
5 4 3 2 1

@@@ hidden_input
3 1
1 2 3
-1 -1
@@@ hidden_output
1 2 3

@@@ hidden_input
3 3
-2147483648 2147483647 2147483647
1 2
0 0
2 0
@@@ hidden_output
-2147483648 2147483647 2147483647
-2147483648 2147483647 2147483647
2147483647 2147483647 -2147483648

@@@ hidden_input
4 4
-1 0 1 2
3 0
0 3
2 2
1 -1
@@@ hidden_output
2 0 1 -1
-1 0 1 2
-1 0 1 2
-1 0 1 2

@@@ hint
Read both values through the pointers into a local temporary first, then write them back crosswise. Check for `NULL` before touching anything.
@@@ hint
Avoid the "clever" swaps. `*a ^= *b; *b ^= *a; *a ^= *b;` sets the value to 0 when `a == b`. `*a = *a + *b; ...` overflows for large values, which is undefined behavior. A plain temporary variable has neither problem.
@@@ solution_code
#include <stddef.h>

void swap_int(int *a, int *b)
{
    if (a == NULL || b == NULL)
        return;             /* defensive: nothing to swap */

    int tmp = *a;           /* works even when a == b: tmp, *a, *b are all the same value */
    *a = *b;
    *b = tmp;
}
@@@ explanation_md
**Approach.** The caller passes the addresses `&arr[i]` and `&arr[j]`. Dereferencing them lets the function read and write the caller's objects. Copy one value into a temporary, then write both back crosswise:

```
tmp = *a;   *a = *b;   *b = tmp;
```

If `a == b`, all three statements read and write the same object, so the value is unchanged. The `NULL` check comes first, because dereferencing `NULL` is undefined behavior (in practice a crash, or a HardFault on a Cortex-M).

**Complexity.** Time O(1), space O(1).

**Common mistakes**
- Writing `void swap(int a, int b)`. It swaps the function's own copies and the caller sees no change. This is the most common first-round interview trap.
- **XOR swap.** With `a == b`, the first `*a ^= *b` sets the shared object to 0, and the value is lost. It is also slower on modern CPUs than a temporary in a register.
- **Arithmetic swap** (`*a = *a + *b; *b = *a - *b; *a = *a - *b;`). It overflows for `INT_MAX + 1`. Signed overflow is undefined behavior, and UBSan reports it as a runtime error.
- Forgetting the `NULL` check, or checking only one of the two pointers.

**Interview follow-ups**
- Write a `SWAP(a, b)` macro. Why do you need `do { ... } while (0)`, and why is a macro that evaluates its arguments twice dangerous with `SWAP(x[i++], y)`?
- How would you swap two objects of *any* type? (Generic `void *` + `size` byte swap.)
- What does `restrict` promise the compiler, and why would `void swap_int(int *restrict a, int *restrict b)` make `swap_int(&x, &x)` undefined?
- MISRA C requires checking pointer parameters. Would you assert, return an error code, or document a precondition? What do you prefer in a safety-critical (ASIL) context?
