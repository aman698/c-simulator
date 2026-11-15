@@@ meta
id: MEM-E-01
topic: Dynamic Memory
difficulty: Easy
type: FIND_THE_BUG
title: Word Reverser That Leaks Every Word
tags: memory-leak, malloc, free, array-of-pointers
@@@ statement_md
The program below reads `n` words, stores a heap copy of each one in an array of `char *`, and prints the words in **reverse** order, one per line.

The output is correct, but the judge reports **Memory Leak** for every non-empty input. LeakSanitizer is always on for this topic.

Find and fix the bug so that every test passes with **no leaks**. Do not change the output format.

**Input**
- Line 1: `n`.
- Line 2: `n` words (each at most 63 characters, no spaces).

**Output**
- The words in reverse order, one per line. Print nothing when `n = 0`.
@@@ constraints_md
- `0 <= n <= 1000`
- Every block obtained from `malloc` must be released before `main` returns.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *dup_word(const char *w)
{
    size_t len = strlen(w);
    char *p = malloc(len + 1);
    if (!p) return NULL;
    memcpy(p, w, len + 1);
    return p;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n <= 0) return 0;

    char **words = malloc((size_t)n * sizeof *words);
    if (!words) return 1;

    char buf[64];
    for (int i = 0; i < n; i++) {
        if (scanf("%63s", buf) != 1) { n = i; break; }
        words[i] = dup_word(buf);
    }

    for (int i = n - 1; i >= 0; i--)
        printf("%s\n", words[i]);

    free(words);
    return 0;
}
@@@ sample_input
3
can lin flexray
@@@ sample_output
flexray
lin
can

@@@ sample_input
0
@@@ sample_output

@@@ hidden_input
1
ecu
@@@ hidden_output
ecu

@@@ hidden_input
5
a bb ccc dddd eeeee
@@@ hidden_output
eeeee
dddd
ccc
bb
a

@@@ hidden_input
4
same same same same
@@@ hidden_output
same
same
same
same

@@@ hidden_input
2
abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk x
@@@ hidden_output
x
abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk

@@@ hidden_input
6
ignition acc on crank run off
@@@ hidden_output
off
run
crank
on
acc
ignition

@@@ hint
Count the `malloc` calls. There is one for the array and one **per word**. Now count the `free` calls.
@@@ hint
Freeing the array of pointers does not free what the pointers point to. Free every `words[i]` before you free `words`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *dup_word(const char *w)
{
    size_t len = strlen(w);
    char *p = malloc(len + 1);
    if (!p) return NULL;
    memcpy(p, w, len + 1);
    return p;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n <= 0) return 0;

    char **words = malloc((size_t)n * sizeof *words);
    if (!words) return 1;

    char buf[64];
    for (int i = 0; i < n; i++) {
        if (scanf("%63s", buf) != 1) { n = i; break; }
        words[i] = dup_word(buf);
    }

    for (int i = n - 1; i >= 0; i--)
        printf("%s\n", words[i]);

    for (int i = 0; i < n; i++)   /* FIX: release every word ... */
        free(words[i]);
    free(words);                  /* ... then the array that held them */
    return 0;
}
@@@ explanation_md
**Bug.** The program makes `n + 1` allocations (one array plus one copy per word) but only one `free`. `free(words)` releases the array of pointers, not the strings those pointers refer to. Once `words` is freed, nothing references the strings, and LeakSanitizer reports them as *direct leaks*.

**Fix.** Free in reverse order of ownership: first each `words[i]`, then `words`. Freeing `words` first and then reading `words[i]` would be a use-after-free.

**Complexity.** Time O(total characters), space O(total characters). The fix adds an O(n) loop.

**Common mistakes**
- Freeing `words` first and then looping over `words[i]` (use-after-free).
- Freeing only `words[0]` or using `<` versus `<=` wrongly in the free loop (partial leak).
- Thinking "the OS reclaims memory at exit, so leaks don't matter". In an ECU, `main` never returns. A leak in a periodic task drains the heap until the first `malloc` failure, often hours into a test drive.

**Interview follow-ups**
- How does LeakSanitizer decide that a block is *leaked* (unreachable) rather than *still reachable*?
- Restructure this to make one allocation total (a single block holding the pointer array and all characters), so cleanup is one `free`.
- Why do MISRA C (Rule 21.3) and many automotive coding standards ban `malloc`/`free` after initialization, and what replaces them? (Static pools, fixed-block allocators.)
