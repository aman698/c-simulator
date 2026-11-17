@@@ meta
id: MEM-E-02
topic: Dynamic Memory
difficulty: Easy
type: FIND_THE_BUG
title: Path Joiner With an Off-by-One Allocation
tags: malloc, strlen, null-terminator, heap-overflow, off-by-one
@@@ statement_md
A diagnostic tool stores calibration files as `dir/file`. The helper `join_path()` builds the full path in a **new heap buffer**:

- if `dir` already ends with `/`, the result is `dir` followed by `file`;
- otherwise a single `/` is inserted between them.

`main()` reads `n` pairs, prints each joined path with its length and frees it.

On a desktop build without sanitizers, the output looks correct. Under the judge (AddressSanitizer, or the heap checker on Windows), most tests end with **Runtime Error: heap-buffer-overflow**. Find and fix the bug. Do not change the output format.

**Input**
- Line 1: `n`.
- Next `n` lines: two strings `dir file` (no spaces, each 1..100 characters).

**Output**
- For each pair: `<path> <length>`, where `<length>` is `strlen(path)`.

**Example**
```
Input:
2
/cal engine.bin
/nvm/ dtc.log

Output:
/cal/engine.bin 15
/nvm/dtc.log 12
```
@@@ constraints_md
- `0 <= n <= 1000`
- `1 <= strlen(dir), strlen(file) <= 100`
- Every block returned by `join_path()` must be freed (leak checking is always on).
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Returns a new heap string "dir/file" (no doubled '/'), or NULL on failure. */
static char *join_path(const char *dir, const char *file)
{
    size_t a = strlen(dir);
    size_t b = strlen(file);
    int need_sep = dir[a - 1] != '/';

    char *out = malloc(a + b + 1);
    if (out == NULL)
        return NULL;

    memcpy(out, dir, a);
    if (need_sep)
        out[a++] = '/';
    memcpy(out + a, file, b + 1); /* copies the terminating '\0' too */
    return out;
}

int main(void)
{
    int n;
    char dir[128], file[128];

    if (scanf("%d", &n) != 1)
        return 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%127s %127s", dir, file) != 2)
            break;
        char *path = join_path(dir, file);
        if (path == NULL)
            return 1;
        printf("%s %zu\n", path, strlen(path));
        free(path);
    }
    return 0;
}
@@@ sample_input
2
/cal engine.bin
/nvm/ dtc.log
@@@ sample_output
/cal/engine.bin 15
/nvm/dtc.log 12

@@@ sample_input
1
a b
@@@ sample_output
a/b 3

@@@ hidden_input
0
@@@ hidden_output

@@@ hidden_input
1
/ boot.img
@@@ hidden_output
/boot.img 9

@@@ hidden_input
3
x/ y
/a/b/ c.txt
logs/ 2024
@@@ hidden_output
x/y 3
/a/b/c.txt 10
logs/2024 9

@@@ hidden_input
3
ecu1 fw.hex
ecu2 cal.bin
/data/vehicle can.log
@@@ hidden_output
ecu1/fw.hex 11
ecu2/cal.bin 12
/data/vehicle/can.log 21

@@@ hidden_input
1
abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuv wxyz
@@@ hidden_output
abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuv/wxyz 105

@@@ hidden_input
2
// x
/// ///
@@@ hidden_output
//x 3
////// 6

@@@ hint
Count the bytes the result really needs: the characters of `dir`, the separator (sometimes), the characters of `file`, and one more thing that every C string ends with.
@@@ hint
`a + b + 1` covers the terminator **or** the `/`, not both. When a separator is inserted, the `'\0'` copied by the last `memcpy` lands one byte past the end of the block. Allocate `a + b + 2` (or `a + need_sep + b + 1`).
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Returns a new heap string "dir/file" (no doubled '/'), or NULL on failure. */
static char *join_path(const char *dir, const char *file)
{
    size_t a = strlen(dir);
    size_t b = strlen(file);
    int need_sep = dir[a - 1] != '/';

    char *out = malloc(a + (size_t)need_sep + b + 1); /* FIX: dir + optional '/' + file + '\0' */
    if (out == NULL)
        return NULL;

    memcpy(out, dir, a);
    if (need_sep)
        out[a++] = '/';
    memcpy(out + a, file, b + 1); /* copies the terminating '\0' too */
    return out;
}

int main(void)
{
    int n;
    char dir[128], file[128];

    if (scanf("%d", &n) != 1)
        return 0;
    for (int i = 0; i < n; i++) {
        if (scanf("%127s %127s", dir, file) != 2)
            break;
        char *path = join_path(dir, file);
        if (path == NULL)
            return 1;
        printf("%s %zu\n", path, strlen(path));
        free(path);
    }
    return 0;
}
@@@ explanation_md
**Bug.** The result needs `a` bytes for `dir`, 1 byte for the inserted `/`, `b` bytes for `file` **and 1 byte for `'\0'`**. The code allocates `a + b + 1`, which covers only one of the last two. When a separator is inserted, the final `memcpy(out + a, file, b + 1)` writes the terminator one byte past the block. That is a heap buffer overflow, which is undefined behavior.

Without sanitizers it usually "works": `malloc` rounds requests up to 16 bytes, so the stray `'\0'` often lands in unused slack. Change the lengths a little, and the same byte overwrites the next chunk's header. The crash then shows up in a later, unrelated `free()`. AddressSanitizer catches it at the faulty write. The Windows heap checker catches it when the block is freed. Inputs where `dir` already ends with `/` need exactly `a + b + 1` bytes, so they pass even with the bug.

**Fix.** Allocate `a + need_sep + b + 1` bytes. (`a + b + 2` is also correct; it wastes one byte when no separator is needed.)

**Complexity.** Time O(a + b) per path, space O(a + b) for the new string.

**Common mistakes**
- `malloc(strlen(s))` for a copy of `s`. This is the most common heap overflow in C code reviews. `strlen` does not count the terminator.
- Fixing the symptom by making the buffer "big enough" (`malloc(256)`). That hides the bug and fails for long inputs.
- Using `strcat` on a block from `malloc`. The block is not zeroed, so `strcat` first searches garbage for a `'\0'`.
- Testing only inputs where the arithmetic happens to fit (here, `dir` ending with `/`).

**Interview follow-ups**
- Write `join_path` with a single `snprintf`: call it once with `NULL, 0` to get the length, then allocate `len + 1`. What does the C standard guarantee about `snprintf`'s return value?
- Why does the program often not crash without sanitizers? Explain `malloc` size-class rounding and chunk headers.
- How would a MISRA-compliant ECU build paths without `malloc`? (Caller-provided fixed buffer plus a capacity argument, returning an error on truncation.)
