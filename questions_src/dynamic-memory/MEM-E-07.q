@@@ meta
id: MEM-E-07
topic: Dynamic Memory
difficulty: Easy
type: FUNCTION
title: Implement my_strdup
tags: strdup, malloc, strings, ownership, asked-in-automotive
@@@ statement_md
`strdup` is not part of ISO C11 (it was only added in C23). Many embedded toolchains do not provide it, and MISRA projects often forbid POSIX extensions. Implement your own:

```c
char *my_strdup(const char *s);
```

- Return a pointer to a **new heap block** (from `malloc`) holding an exact copy of `s`, including the terminating `'\0'`.
- The copy must be **independent**: changing the original later must not change the copy.
- If `s` is `NULL`, return `NULL` (do not crash).
- If `malloc` fails, return `NULL`.
- The caller owns the result and releases it with `free()`.

`strdup` is not available in this exercise.

**How it is tested.** A hidden `main()` reads lines. A line consisting of exactly `NULL` means "call `my_strdup(NULL)`". For every other line it calls `my_strdup(line)`, overwrites the original buffer with `#` characters, and prints the copy with its length. Then it frees the copy. Writing even one byte past the block, or leaking it, fails the test.

**Input (read by the hidden harness)**
- Up to 50 lines, each at most 200 characters (possibly empty).

**Output**
- Per line: `[<copy>] <strlen(copy)>`, or `(null)` when `my_strdup` returned `NULL`.

**Example**
```
Input:
VIN=WDB1234
NULL

Output:
[VIN=WDB1234] 11
(null)
```
@@@ constraints_md
- `0 <= strlen(s) <= 200`
- Allocate exactly `strlen(s) + 1` bytes (anything less is a heap overflow).
- Do not use `strdup`/`strndup`. `strlen`/`memcpy` are fine.
@@@ starter_code
#include <stdlib.h>
#include <string.h>

/* Return a new heap copy of s (caller frees), or NULL if s is NULL or malloc fails. */
char *my_strdup(const char *s)
{
    /* TODO */
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define strdup strdup_is_not_allowed_in_this_exercise
#define strndup strndup_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef strdup
#undef strndup

int main(void)
{
    char line[256];
    while (fgets(line, sizeof line, stdin) != NULL) {
        size_t n = strlen(line);
        if (n > 0 && line[n - 1] == '\n')
            line[--n] = '\0';

        if (strcmp(line, "NULL") == 0) {
            char *r = my_strdup(NULL);
            if (r == NULL) {
                printf("(null)\n");
            } else {
                printf("FAIL: expected NULL for a NULL argument\n");
                free(r);
            }
            continue;
        }

        char *copy = my_strdup(line);
        if (copy == NULL) {
            printf("(null)\n");
            continue;
        }
        if (copy == line) {
            printf("FAIL: returned the original buffer, not a copy\n");
            continue;
        }
        memset(line, '#', n);             /* the copy must not change */
        printf("[%s] %zu\n", copy, strlen(copy));
        free(copy);
    }
    return 0;
}
@@@ sample_input
VIN=WDB1234
NULL
@@@ sample_output
[VIN=WDB1234] 11
(null)

@@@ sample_input
a
@@@ sample_output
[a] 1

@@@ hidden_input
<<BLANK>>
@@@ hidden_output
[] 0

@@@ hidden_input
ECU_SW_VERSION 3.14.159
<<BLANK>>
NULL
x
@@@ hidden_output
[ECU_SW_VERSION 3.14.159] 23
[] 0
(null)
[x] 1

@@@ hidden_input
NULL
NULL
@@@ hidden_output
(null)
(null)

@@@ hidden_input
abcdefghijklmnop
abcdefghijklmnopq
abcdefghijklmno
@@@ hidden_output
[abcdefghijklmnop] 16
[abcdefghijklmnopq] 17
[abcdefghijklmno] 15

@@@ hidden_input
01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
@@@ hidden_output
[01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789] 200

@@@ hidden_input
  two leading spaces
NULLX
@@@ hidden_output
[  two leading spaces] 20
[NULLX] 5

@@@ hint
Measure the string first (`strlen`), then allocate. How many bytes does a string of length `n` occupy in memory?
@@@ hint
`malloc(len + 1)` (the `+ 1` is for `'\0'`), check for `NULL`, then `memcpy(p, s, len + 1)` copies the terminator too. Handle `s == NULL` before calling `strlen`, because `strlen(NULL)` is undefined behavior.
@@@ solution_code
#include <stdlib.h>
#include <string.h>

/* Return a new heap copy of s (caller frees), or NULL if s is NULL or malloc fails. */
char *my_strdup(const char *s)
{
    if (s == NULL)
        return NULL;

    size_t len = strlen(s);
    char *p = malloc(len + 1);       /* + 1 for the terminating '\0' */
    if (p == NULL)
        return NULL;

    memcpy(p, s, len + 1);           /* copies the '\0' as well */
    return p;
}
@@@ explanation_md
**Approach.** Get the length, allocate `len + 1` bytes, copy `len + 1` bytes (the terminator included), and return the new block. Check both `NULL` cases: a `NULL` argument and a failed `malloc`.

```
s:  'V' 'I' 'N' '\0'       strlen = 3
p:  [ V | I | N | \0 ]     malloc(3 + 1)
```

`memcpy` with the known length is faster than `strcpy`, which searches for the terminator again. Both are correct here.

**Complexity.** Time O(n), space O(n) for the copy.

**Common mistakes**
- `malloc(strlen(s))`: one byte short. The terminator overflows the block. ASan reports `heap-buffer-overflow WRITE of size 1`.
- `malloc(sizeof(s))`: that is the size of a **pointer** (8), not of the string.
- Returning `s` itself, or a pointer to a local array. Neither is an independent heap copy.
- Calling `strlen(s)` before the `NULL` check.
- Not documenting ownership. Every caller must `free()` the result, and in an ECU's cyclic task, forgetting that drains the heap.

**Interview follow-ups**
- Implement `my_strndup(s, n)`, which copies at most `n` characters and always terminates the result. Why can it not use `strlen(s)` when `s` might not be terminated?
- Implement it without any `<string.h>` function.
- C23 finally added `strdup`/`strndup`. Why did the committee resist them for decades? (Hidden allocation in a "string" function, and the ownership burden on the caller.)
