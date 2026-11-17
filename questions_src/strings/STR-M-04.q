@@@ meta
id: STR-M-04
topic: Strings
difficulty: Medium
type: FUNCTION
title: In-Place Run-Length Compression (aaabb to a3b2)
tags: run-length-encoding, compression, in-place, read-write-pointers, embedded
@@@ statement_md
A data logger squeezes repetitive status strings before writing them to flash. Implement **run-length encoding in place**:

```c
size_t rle_compress(char *s);
```

- Every run of **k >= 2** identical characters is replaced by the character followed by `k` in decimal: `"aaabb"` -> `"a3b2"`. A count can have several digits: twelve `a`s become `"a12"`.
- A run of length **1** is kept as the bare character: `"abc"` stays `"abc"`.
- Spaces and punctuation are ordinary characters. The input never contains digits, so the output is unambiguous.
- Compress **inside `s`**, write the new `'\0'`, and return the new length.
- `rle_compress(NULL)` returns `0`.

Because single characters stay single, the output is never longer than the input, so no extra buffer is needed. Use O(1) extra memory.

**How it is tested.** A hidden `main()` copies each test string into a buffer with guard bytes, calls your function and prints `[result] len`. It reports `BAD LENGTH` if the return value does not match the string, and `OUT OF BOUNDS WRITE` if you write outside the original string.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: a string in double quotes, or `NULL`.

**Output**
- One line per string: `[compressed] len`, or `NULL -> 0`.

**Example**
```
Input:
3
"aaabb"
"abc"
"aaaaaaaaaaaab"

Output:
[a3b2] 4
[abc] 3
[a12b] 4
```
@@@ constraints_md
- `1 <= q <= 20`
- Each string has at most 5000 printable ASCII characters, **no digits** and no `"`.
- O(n) time, O(1) extra space. Do not use `sprintf`/`snprintf` (rejected at compile time); write the digits yourself.
@@@ starter_code
#include <stddef.h>

size_t rle_compress(char *s)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define sprintf(...) sprintf_is_not_allowed_in_this_exercise
#define snprintf(...) snprintf_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef sprintf
#undef snprintf

#define CAP 5100
#define GUARD 16
#define CANARY 0xA5

static unsigned char arena[GUARD + CAP + GUARD];
static char line[CAP + 64];

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        if (strncmp(line, "NULL", 4) == 0) {
            printf("NULL -> %zu\n", rle_compress(NULL));
            continue;
        }
        char *a = strchr(line, '"');
        char *b = strrchr(line, '"');
        if (!a || a == b) return 0;
        size_t len = (size_t)(b - a - 1);
        memset(arena, CANARY, sizeof arena);
        char *buf = (char *)arena + GUARD;
        memcpy(buf, a + 1, len);
        buf[len] = '\0';
        size_t ret = rle_compress(buf);
        for (size_t k = 0; k < GUARD; k++) {
            if (arena[k] != CANARY || (unsigned char)buf[len + 1 + k] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        if (!memchr(buf, '\0', len + 1)) {
            printf("MISSING TERMINATOR\n");
            return 0;
        }
        printf("[%s] %zu\n", buf, ret);
        if (ret != strlen(buf)) printf("BAD LENGTH\n");
    }
    return 0;
}
@@@ sample_input
3
"aaabb"
"abc"
"aaaaaaaaaaaab"
@@@ sample_output
[a3b2] 4
[abc] 3
[a12b] 4

@@@ sample_input
3
""
"a"
NULL
@@@ sample_output
[] 0
[a] 1
NULL -> 0

@@@ hidden_input
3
"aabbaa"
"abbbbbbbbbbc"
"AAaa"
@@@ hidden_output
[a2b2a2] 6
[ab10c] 5
[A2a2] 4

@@@ hidden_input
3
"  "
"!!!??"
"x y  z"
@@@ hidden_output
[ 2] 2
[!3?2] 4
[x y 2z] 6

@@@ hidden_input
1
"WWWWWWWWWWWWBWWWWWWWWWWWWBBBWWWWWWWWWWWWWWWWWWWWWWWWBWWWWWWWWWWWWWW"
@@@ hidden_output
[W12BW12B3W24BW14] 16

@@@ hidden_input
2
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy"
@@@ hidden_output
[x100] 4
[x99y] 4

@@@ hidden_input
1
"zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
@@@ hidden_output
[z5000] 5

@@@ hidden_input
1
"aaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb   cccYY--bbbbXXX-a--YYccaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbb___                                                                                                            aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbaa_----------------------------------------------------------------------------------------------------______________________________________________________________________________________________________________________!!!!aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaXccYY!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!XXZZZ-------------------------------------------------------------------------------------YYYYYYYYYYYYYYY__aaaaaaa  bbXXXZ b---ZZYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!XXXX---aaaaaaaaaaaaaaaaaaaaaaaaa----!! XXbbZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ---------------------------------------------------------------------------------------------------------------------------------------------bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb______________________________________________________________________________________________________________________________________ccc---ccc!!-----------bbbXXXbb---bbc a!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!_______________________________________________________________________________________________________________________________ZZ------------------------------------------------------------------------------------------------------------------------ZZZc!!!ZZccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc!!YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYbbb_________________________________________________________________________________________________________________aaaZZZcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc-----------------------------------------------------------------------------------------------------------------YY!!!---XXXXXXXXXXXX                   ---                                                                                                                            bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbYYYYYY---  ZZZYYY-!!!ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXcccXXaac!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ZZZZZZZZZZZZZZZZ___Y___-ZZZXXbbbXX!!!YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccY--a !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb!!!ZZZ  --XXXccccc___YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa____________________!cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc_XXXYXXXaaaZcccc bbZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY                                                                                                                       ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
@@@ hidden_output
[a6c53b39 3c3Y2-2b4X3-a-2Y2c2a125b6_3 108a143-b3Z120b113a2_-100_118!4a52Xc2Y2!62X2Z3-85Y15_2a7 2b2X3Z b-3Z2Y79!122X4-3a25-4!2 X2b2Z145-141b127_134c3-3c3!2-11b3X3b2-3b2c a!50_127Z2-120Z3c!3Z2c99!2Y147b3_113a3Z3c66-113Y2!3-3X12 19-3 124b108Y6-3 2Z3Y3-!3Z127X117c3X2a2c!138 Z16_3Y_3-Z3X2b3X2!3Y107c73Y-2a !110 b81!3Z3 2-2X3c5_3Y66a55_20!c212_X3YX3a3Zc4 b2Z112Y182 119Z89] 366

@@@ hint
Use a read index `r` and a write index `w`. At the start of each run, remember the character, then advance `r` to the end of the run to get its length `k`. Only then write the character and, if `k >= 2`, its digits at `w`.
@@@ hint
Writing at `w` is safe because a run of length `k` produces at most `k` output characters (1 + number of digits of `k` <= `k` for `k >= 2`), so `w` never passes `r`. To emit the digits of `k` without `sprintf`, fill a tiny local `char tmp[12]` backwards with `k % 10`, then copy it forwards.
@@@ solution_code
#include <stddef.h>

size_t rle_compress(char *s)
{
    size_t r = 0, w = 0;

    if (s == NULL)
        return 0;

    while (s[r] != '\0') {
        char c = s[r];
        size_t k = 0;
        while (s[r] == c) {         /* measure the whole run first */
            r++;
            k++;
        }
        s[w++] = c;
        if (k >= 2) {
            char tmp[24];
            size_t n = 0;
            while (k > 0) {         /* digits come out LSB-first */
                tmp[n++] = (char)('0' + k % 10);
                k /= 10;
            }
            while (n > 0)
                s[w++] = tmp[--n];  /* 1 + digits(k) <= k, so w <= r */
        }
    }
    s[w] = '\0';
    return w;
}
@@@ explanation_md
**Approach: measure the run, then write.** The read index `r` scans a whole run of the same character and counts it. Only after that does the write index `w` emit the character and, for `k >= 2`, the decimal digits of `k`.

Why in place is safe: a run occupies `k` input characters and produces `1` character (k = 1) or `1 + digits(k)` characters (k >= 2). Since `1 + digits(k) <= k` for every `k >= 2` (2 -> "c2", 10 -> "c10"), the output of a run always fits inside the run's own input space, so `w <= r` at every step.

Digits are produced least-significant first (`k % 10`) into a small fixed array and then copied in the right order. 24 bytes is enough for any `size_t`.

**Complexity.** Time O(n): every input character is read once and every output character written once. Space O(1).

**Common mistakes**
- Writing the count while the run is still being scanned, or writing `"a1"` for single characters. The "always write the count" variant can **grow** the string (`"abc"` -> `"a1b1c1"`) and overflows an in-place buffer. The harness catches that.
- Handling only one-digit counts (`'0' + k`). For `k = 12` that writes `'<'`.
- Comparing `s[r] == s[r + 1]` and reading one past the terminator at the end of the string.
- Forgetting the final `'\0'`, so the uncompressed tail is still printed.

**Interview follow-ups**
- Write the matching decompressor. Why can it **not** run in place in general, and how do you compute the exact output size first?
- The classic CTCI variant returns the original string when the compressed form is not shorter. How would you decide that **before** modifying the buffer?
- Real loggers compress bytes, not text, so counts and data can collide. How do PackBits or the TIFF/BMP RLE formats encode literal runs versus repeated runs?
