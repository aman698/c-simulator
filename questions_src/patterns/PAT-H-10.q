@@@ meta
id: PAT-H-10
topic: C Patterns
difficulty: Hard
type: FIND_THE_BUG
title: Bootloader Progress Bar That Corrupts the Heap
tags: embedded, bootloader, heap-buffer-overflow, sprintf, buffer-sizing, progress-bar
@@@ statement_md
A PC flashing tool talks to an ECU bootloader and prints a **progress bar** after every transferred block. For an image of `total` bytes and a bar `width` characters wide, an update with `written` bytes prints

```
[<filled x '#'><(width - filled) x '.'>] <pct, width 3>% (<written>/<total>)
```

with `written` clamped to `total`, `pct = floor(written * 100 / total)` and `filled = floor(written * width / total)`. If `total < 1`, `width < 1` or `width > 60`, the tool prints only `ERR`.

**Expected for a 64 KB image, `width = 20`**
```
[....................]   0% (0/65536)
[#####...............]  25% (16384/65536)
[##########..........]  50% (32768/65536)
[####################] 100% (65536/65536)
```

**Symptom.** With the 64 KB test images, the output is always correct. With the 1 MB production image, the sanitizer reports a **heap-buffer-overflow** (on Windows the heap checker reports a corrupted block when it is freed), and the judge shows **Runtime Error**. Find and fix the bug. The output format must not change.

**Input**
- Line 1: `total width`.
- Line 2: `k`, then `k` values of `written`.

**Output**
- One line per update, or `ERR`. The judge ignores trailing spaces and trailing blank lines.
@@@ constraints_md
- `-10 <= total <= 2147483647`, `-10 <= width <= 100`
- `1 <= k <= 20`, `0 <= written <= 2147483647`
- 64-bit intermediates are needed for `written * 100` and `written * width`.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    long long total;
    int width, k;
    if (scanf("%lld %d", &total, &width) != 2) return 0;
    if (total < 1 || width < 1 || width > 60) {
        printf("ERR\n");
        return 0;
    }
    if (scanf("%d", &k) != 1) return 0;

    size_t cap = (size_t)width + 24;        /* '[' + bar + ']' + status text */
    char *line = malloc(cap);
    if (!line) return 1;

    for (int u = 0; u < k; u++) {
        long long written;
        if (scanf("%lld", &written) != 1) break;
        if (written > total)
            written = total;

        int pct = (int)(written * 100 / total);
        int filled = (int)(written * width / total);

        int pos = 0;
        line[pos++] = '[';
        for (int i = 0; i < width; i++)
            line[pos++] = (i < filled) ? '#' : '.';
        line[pos++] = ']';
        sprintf(line + pos, " %3d%% (%lld/%lld)", pct, written, total);
        puts(line);
    }
    free(line);
    return 0;
}
@@@ sample_input
65536 20
4 0 16384 32768 65536
@@@ sample_output
[....................]   0% (0/65536)
[#####...............]  25% (16384/65536)
[##########..........]  50% (32768/65536)
[####################] 100% (65536/65536)

@@@ sample_input
1000 10
3 1 999 1500
@@@ sample_output
[..........]   0% (1/1000)
[#########.]  99% (999/1000)
[##########] 100% (1000/1000)

@@@ hidden_input
0 20
1 0
@@@ hidden_output
ERR

@@@ hidden_input
65536 61
1 0
@@@ hidden_output
ERR

@@@ hidden_input
65536 0
1 0
@@@ hidden_output
ERR

@@@ hidden_input
1048576 32
5 0 104857 524288 1048575 1048576
@@@ hidden_output
[................................]   0% (0/1048576)
[###.............................]   9% (104857/1048576)
[################................]  50% (524288/1048576)
[###############################.]  99% (1048575/1048576)
[################################] 100% (1048576/1048576)

@@@ hidden_input
2147483647 60
4 1 1073741823 2147483646 2147483647
@@@ hidden_output
[............................................................]   0% (1/2147483647)
[#############################...............................]  49% (1073741823/2147483647)
[###########################################################.]  99% (2147483646/2147483647)
[############################################################] 100% (2147483647/2147483647)

@@@ hidden_input
1 1
2 0 1
@@@ hidden_output
[.]   0% (0/1)
[#] 100% (1/1)

@@@ hidden_input
3 7
2 1 2
@@@ hidden_output
[##.....]  33% (1/3)
[####...]  66% (2/3)

@@@ hidden_input
65535 60
3 4095 32767 65534
@@@ hidden_output
[###.........................................................]   6% (4095/65535)
[#############################...............................]  49% (32767/65535)
[###########################################################.]  99% (65534/65535)

@@@ hint
Count the bytes this program writes into `line` for the longest possible status text, including the terminating `'\0'` that `sprintf` always appends. Which part of that length depends on the size of the image?
@@@ hint
`" 100% ("` is 7 characters, then up to 10 + 1 + 10 digits/slash, then `")"` and `'\0'`: up to 30 bytes after the bar, but only 24 were reserved for both brackets **and** the text. With a 7-digit total and a 6-digit `written`, `sprintf` already writes one byte past the block. Size the buffer for the worst case, e.g. with `sizeof " 100% (2147483647/2147483647)"`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    long long total;
    int width, k;
    if (scanf("%lld %d", &total, &width) != 2) return 0;
    if (total < 1 || width < 1 || width > 60) {
        printf("ERR\n");
        return 0;
    }
    if (scanf("%d", &k) != 1) return 0;

    /* FIX: '[' + bar + ']' + the longest status text including '\0' (sizeof counts it) */
    size_t cap = (size_t)width + 2 + sizeof " 100% (2147483647/2147483647)";
    char *line = malloc(cap);
    if (!line) return 1;

    for (int u = 0; u < k; u++) {
        long long written;
        if (scanf("%lld", &written) != 1) break;
        if (written > total)
            written = total;

        int pct = (int)(written * 100 / total);
        int filled = (int)(written * width / total);

        int pos = 0;
        line[pos++] = '[';
        for (int i = 0; i < width; i++)
            line[pos++] = (i < filled) ? '#' : '.';
        line[pos++] = ']';
        sprintf(line + pos, " %3d%% (%lld/%lld)", pct, written, total);
        puts(line);
    }
    free(line);
    return 0;
}
@@@ explanation_md
**Bug.** The line buffer holds `width + 24` bytes, but in the worst case it must hold
`1 ('[') + width + 1 (']') + 7 (" 100% (") + d1 + 1 ('/') + d2 + 1 (')') + 1 ('\0') = width + 12 + d1 + d2`,
where `d1`, `d2` are the digit counts of `written` and `total`. That fits only while `d1 + d2 <= 12`. A 64 KB image has `d1 + d2 <= 10`, so every test passed. A 1 MB image (`total = 1048576`, 7 digits) overflows as soon as `written` has 6 digits: `sprintf` writes the closing `)` or the terminating `'\0'` past the end of the `malloc` block. That is a classic "worked in the lab, crashed with the production image" bug. Without a sanitizer it silently corrupts the heap metadata or a neighbouring object.

**Fix.** Size the buffer for the **worst case**, and let the compiler count: `sizeof " 100% (2147483647/2147483647)"` is 30 (29 characters plus `'\0'`), so `cap = width + 2 + 30`. Even better, use `snprintf(line + pos, cap - pos, ...)` so that the formatter can never write past `cap`, and check its return value for truncation.

**Complexity.** Time O(k * width), space O(width).

**Common mistakes**
- Forgetting the terminating `'\0'` in the size calculation (the most common off-by-one in C string handling).
- Sizing for "typical" numbers instead of the type's maximum (`INT_MAX`/`LLONG_MAX` digits plus sign).
- "Fixing" it with a bigger magic number (`+ 64`) without documenting why it is enough.
- Replacing `sprintf` with `snprintf(line + pos, 24, ...)`. That passes a size the buffer does not actually have, so the overflow can still happen.
- Computing `written * 100` in `int` (overflow for `written > 21474836`). This code is correct there because `written` is `long long`.

**Interview follow-ups**
- Why do many embedded coding standards ban `sprintf` in favour of `snprintf`, and what does `snprintf` return when the output is truncated?
- How would you find the required size at run time? (`int need = snprintf(NULL, 0, fmt, ...);`)
- On the target side, the bootloader must not use `malloc` at all. How would you print the same status into a fixed static buffer, and how would you prove at compile time that it is large enough (`_Static_assert` with `sizeof`)?
- How do ASan redzones detect this one-byte overflow, and why might a plain glibc build only crash much later, in an unrelated `free`?
