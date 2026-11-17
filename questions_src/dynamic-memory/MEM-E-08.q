@@@ meta
id: MEM-E-08
topic: Dynamic Memory
difficulty: Easy
type: FUNCTION
title: Pascal's Triangle as a Jagged Heap Array
tags: 2d-array, array-of-pointers, jagged-array, malloc, free-order
@@@ statement_md
Build the first `n` rows of Pascal's triangle as a **jagged** 2D array on the heap. Use a table of `n` row pointers, where row `i` (0-based) is a separate block of exactly `i + 1` ints. Then write the matching destructor.

```c
int **pascal_rows(int n);
void free_pascal(int **rows, int n);
```

- `pascal_rows(n)` returns the row table, with `rows[i][j] = C(i, j)` for `0 <= j <= i`. It returns `NULL` if `n <= 0` or if any allocation fails. On failure it must release everything it already allocated.
- `free_pascal(rows, n)` releases every row and then the table. `free_pascal(NULL, n)` does nothing.

**How it is tested.** A hidden `main()` reads several values of `n`. For each one it calls `pascal_rows(n)` and prints the triangle (for `n <= 8`) or a summary of the last row (for larger `n`). It then calls **your** `free_pascal`. Any leaked row, double free, or write outside a row fails the test.

**Input (read by the hidden harness)**
- Whitespace-separated values of `n` until end of input.

**Output (printed by the harness)**
- `n <= 0`: `n=<n>: NULL`
- `1 <= n <= 8`: `n=<n>:`, then each row on its own line, values separated by spaces.
- `n > 8`: `n=<n>: last row has <n> values, middle=<rows[n-1][(n-1)/2]>, sum=<sum of last row>`

**Example**
```
Input:
4

Output:
n=4:
1
1 1
1 2 1
1 3 3 1
```
@@@ constraints_md
- `-5 <= n <= 31` (all values of row 30 fit in an `int`)
- Row `i` must hold exactly `i + 1` ints (the harness relies on it; writing more is a heap overflow).
- Use `malloc`/`calloc` and `free` only.
@@@ starter_code
#include <stdlib.h>

/* Row i has i + 1 entries: rows[i][j] = C(i, j). NULL if n <= 0 or out of memory. */
int **pascal_rows(int n)
{
    /* TODO */
    return NULL;
}

/* Free every row, then the row table. Must accept rows == NULL. */
void free_pascal(int **rows, int n)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>

/*USER_CODE*/

int main(void)
{
    int n;
    free_pascal(NULL, 3);                    /* must be a no-op */
    while (scanf("%d", &n) == 1) {
        int **t = pascal_rows(n);
        if (n <= 0) {
            if (t != NULL) {
                printf("n=%d: FAIL expected NULL\n", n);
                free_pascal(t, n);
            } else {
                printf("n=%d: NULL\n", n);
            }
            continue;
        }
        if (t == NULL) {
            printf("n=%d: unexpected NULL\n", n);
            continue;
        }
        if (n <= 8) {
            printf("n=%d:\n", n);
            for (int i = 0; i < n; i++)
                for (int j = 0; j <= i; j++)
                    printf("%d%c", t[i][j], j == i ? '\n' : ' ');
        } else {
            long long sum = 0;
            for (int j = 0; j < n; j++)
                sum += t[n - 1][j];
            printf("n=%d: last row has %d values, middle=%d, sum=%lld\n",
                   n, n, t[n - 1][(n - 1) / 2], sum);
        }
        free_pascal(t, n);
    }
    return 0;
}
@@@ sample_input
4
@@@ sample_output
n=4:
1
1 1
1 2 1
1 3 3 1

@@@ sample_input
1 0
@@@ sample_output
n=1:
1
n=0: NULL

@@@ hidden_input
-3
@@@ hidden_output
n=-3: NULL

@@@ hidden_input
2
@@@ hidden_output
n=2:
1
1 1

@@@ hidden_input
8
@@@ hidden_output
n=8:
1
1 1
1 2 1
1 3 3 1
1 4 6 4 1
1 5 10 10 5 1
1 6 15 20 15 6 1
1 7 21 35 35 21 7 1

@@@ hidden_input
9 10
@@@ hidden_output
n=9: last row has 9 values, middle=70, sum=256
n=10: last row has 10 values, middle=126, sum=512

@@@ hidden_input
31
@@@ hidden_output
n=31: last row has 31 values, middle=155117520, sum=1073741824

@@@ hidden_input
3 -1 5 20
@@@ hidden_output
n=3:
1
1 1
1 2 1
n=-1: NULL
n=5:
1
1 1
1 2 1
1 3 3 1
1 4 6 4 1
n=20: last row has 20 values, middle=92378, sum=524288

@@@ hint
Two levels of allocation: first `malloc(n * sizeof *rows)` for the table of `int *`, then one `malloc((i + 1) * sizeof **rows)` per row. Fill each row from the one above: `row[0] = row[i] = 1`, `row[j] = prev[j-1] + prev[j]`.
@@@ hint
Free in the **reverse** order of ownership: every `rows[i]` first, then `rows`. Freeing `rows` first and then reading `rows[i]` is a use-after-free. If row `k` fails to allocate, free rows `0..k-1` and the table before returning `NULL`.
@@@ solution_code
#include <stdlib.h>

void free_pascal(int **rows, int n);

/* Row i has i + 1 entries: rows[i][j] = C(i, j). NULL if n <= 0 or out of memory. */
int **pascal_rows(int n)
{
    if (n <= 0)
        return NULL;

    int **rows = malloc((size_t)n * sizeof *rows);       /* table of row pointers */
    if (rows == NULL)
        return NULL;

    for (int i = 0; i < n; i++) {
        rows[i] = malloc((size_t)(i + 1) * sizeof **rows); /* row i: exactly i + 1 ints */
        if (rows[i] == NULL) {
            free_pascal(rows, i);                         /* release rows 0..i-1 + table */
            return NULL;
        }
        rows[i][0] = 1;
        rows[i][i] = 1;
        for (int j = 1; j < i; j++)
            rows[i][j] = rows[i - 1][j - 1] + rows[i - 1][j];
    }
    return rows;
}

/* Free every row, then the row table. Must accept rows == NULL. */
void free_pascal(int **rows, int n)
{
    if (rows == NULL)
        return;
    for (int i = 0; i < n; i++)
        free(rows[i]);       /* the rows first ...            */
    free(rows);              /* ... then the table that owns them */
}
@@@ explanation_md
**Approach.** An "array of pointers" 2D array is a table of `n` row pointers, each pointing to its own heap block. Rows can have different lengths, which makes a **jagged** array. A plain `int a[n][m]` cannot express that.

```
rows ──► [ * ][ * ][ * ][ * ]
           │    │    │    └──► [1 3 3 1]
           │    │    └───────► [1 2 1]
           │    └────────────► [1 1]
           └─────────────────► [1]
```

Each row is computed from the previous one: `C(i, j) = C(i-1, j-1) + C(i-1, j)`, with 1 at both ends.

**Cleanup.** Ownership is two levels deep, so destruction must go inside-out: rows first, then the table. The constructor reuses the destructor on failure. `free_pascal(rows, i)` frees exactly the `i` rows that exist. This only works because rows `>= i` are never touched.

**Complexity.** Time O(n^2), space O(n^2) for about `n^2 / 2` ints, plus `n` pointers and `n + 1` allocations.

**Common mistakes**
- `malloc(n * sizeof(int))` for the table. A pointer is 8 bytes on 64-bit targets, so the table is half the needed size. Write `sizeof *rows` to let the compiler pick the right type.
- `free(rows)` before the rows: a use-after-free, because `rows[i]` is read from freed memory.
- Allocating every row with `n` ints "to be safe". That wastes half the memory and hides off-by-one bugs.
- No cleanup when a row allocation fails halfway, which leaks the earlier rows.

**Interview follow-ups**
- Allocate the whole triangle with **one** `malloc` (the table followed by all `n(n+1)/2` ints). What alignment issue appears if the elements were `double` and pointers were 4 bytes?
- Rows `0..30` fit in an `int`. How would you detect overflow for larger `n`?
- Can you produce only row `n` with O(n) memory, updating a single row in place? (Iterate `j` from right to left.)
