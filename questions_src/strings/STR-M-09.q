@@@ meta
id: STR-M-09
topic: Strings
difficulty: Medium
type: FIND_THE_BUG
title: my_strstr Misses Matches After a Partial Match
tags: embedded, strstr, substring-search, backtracking, uart-parser
@@@ statement_md
A modem driver scans the UART receive buffer for markers such as `"+CMTI:"` or `"OK"`. Since the target has no C library, the team wrote its own `my_strstr`. It returns a pointer to the **first** occurrence of `needle` in `hay`, or `NULL` if there is none. Like the standard `strstr`, an **empty needle** matches at position 0.

The function passes the team's quick tests (`"hello world"` / `"world"`). In the field, it **misses** markers when the buffer contains an almost-match just before the real one. For example, it reports no `"aab"` in `"aaab"`, and no `"issip"` in `"mississippi"`.

Find and fix the bug. The program prints the 0-based index of the first match, or `-1`.

**Input**
- Line 1: `t`, the number of queries.
- Then `t` pairs of lines: the haystack line, then the needle line. Either may be empty, and both may contain spaces.

**Output**
- For each query, the index of the first occurrence, or `-1`.

**Example**
```
Input:
2
hello world
world
mississippi
issip

Output:
6
4
```
@@@ constraints_md
- `1 <= t <= 50`
- Each line has at most 1000 printable ASCII characters.
- Do not replace `my_strstr` with the library `strstr`; fix the algorithm.
@@@ starter_code
#include <stdio.h>
#include <string.h>

/* First occurrence of needle in hay, or NULL. Empty needle matches at hay. */
static const char *my_strstr(const char *hay, const char *needle)
{
    const char *h = hay;
    const char *n = needle;
    const char *start = hay;

    if (*needle == '\0')
        return hay;

    while (*h != '\0') {
        if (*h == *n) {
            if (n == needle)
                start = h;          /* a candidate match begins here */
            n++;
            if (*n == '\0')
                return start;       /* whole needle matched */
        } else {
            n = needle;             /* mismatch: start matching the needle again */
        }
        h++;
    }
    return NULL;
}

static char hay[1100], needle[1100];

static void read_line(char *buf, int size)
{
    if (!fgets(buf, size, stdin)) buf[0] = '\0';
    buf[strcspn(buf, "\n")] = '\0';
}

int main(void)
{
    char tmp[32];
    int t;
    if (!fgets(tmp, sizeof tmp, stdin) || sscanf(tmp, "%d", &t) != 1) return 0;
    for (int i = 0; i < t; i++) {
        read_line(hay, sizeof hay);
        read_line(needle, sizeof needle);
        const char *p = my_strstr(hay, needle);
        printf("%d\n", p ? (int)(p - hay) : -1);
    }
    return 0;
}
@@@ sample_input
2
hello world
world
mississippi
issip
@@@ sample_output
6
4

@@@ sample_input
2
abc
<<BLANK>>
<<BLANK>>
a
@@@ sample_output
0
-1

@@@ hidden_input
2
aaab
aab
ababac
abac
@@@ hidden_output
1
2

@@@ hidden_input
3
aaaaaaaaab
aaab
x
x
abc
abcd
@@@ hidden_output
6
0
-1

@@@ hidden_input
2
CAN_ERR_CAN_OK
CAN_OK
+CM+CMT+CMTI: "SM",3
+CMTI:
@@@ hidden_output
8
7

@@@ hidden_input
2
<<BLANK>>
<<BLANK>>
OKOKOK
KO
@@@ hidden_output
0
1

@@@ hidden_input
3
abcabcabd
abcabd
no match here
xyz
the end
end
@@@ hidden_output
3
-1
4

@@@ hint
Trace `my_strstr("aaab", "aab")` by hand. After `"aa"` has matched, the third `'a'` mismatches against `'b'`. Where does the search continue in the haystack, and is the character that caused the mismatch ever compared with the **first** character of the needle?
@@@ hint
After a partial match fails, the next candidate start is `start + 1`, not the current position. On a mismatch while `n != needle`, set `h = start` and `n = needle`; the loop's `h++` then moves to `start + 1`.
@@@ solution_code
#include <stdio.h>
#include <string.h>

/* First occurrence of needle in hay, or NULL. Empty needle matches at hay. */
static const char *my_strstr(const char *hay, const char *needle)
{
    const char *h = hay;
    const char *n = needle;
    const char *start = hay;

    if (*needle == '\0')
        return hay;

    while (*h != '\0') {
        if (*h == *n) {
            if (n == needle)
                start = h;          /* a candidate match begins here */
            n++;
            if (*n == '\0')
                return start;       /* whole needle matched */
        } else if (n != needle) {
            h = start;              /* FIX: backtrack, retry from start + 1 (h++ below) */
            n = needle;
        }
        h++;
    }
    return NULL;
}

static char hay[1100], needle[1100];

static void read_line(char *buf, int size)
{
    if (!fgets(buf, size, stdin)) buf[0] = '\0';
    buf[strcspn(buf, "\n")] = '\0';
}

int main(void)
{
    char tmp[32];
    int t;
    if (!fgets(tmp, sizeof tmp, stdin) || sscanf(tmp, "%d", &t) != 1) return 0;
    for (int i = 0; i < t; i++) {
        read_line(hay, sizeof hay);
        read_line(needle, sizeof needle);
        const char *p = my_strstr(hay, needle);
        printf("%d\n", p ? (int)(p - hay) : -1);
    }
    return 0;
}
@@@ explanation_md
**Bug.** On a mismatch, the code resets the needle but keeps going from the **current** haystack position (`h++`). That has two consequences:
1. Candidate starts **inside** the failed partial match are never tried. In `"aaab"`, the match of `"aab"` at index 1 overlaps the failed attempt at index 0.
2. The character that caused the mismatch is never compared with `needle[0]`. In `"+CM+CMT+CMTI:"`, the `'+'` that breaks the `"+CM"` attempt is itself the start of the next attempt.

```
hay:    a a a b        needle: a a b
start=0 a a x          mismatch at h=2 ('a' vs 'b')
buggy:  resume at h=3 -> 'b' != 'a' -> NULL      (wrong)
fixed:  resume at start+1 = 1 -> a a b -> index 1
```

**Fix.** On a mismatch after a partial match, backtrack: `h = start; n = needle;`. The loop's `h++` then retries from `start + 1`. A mismatch on the first needle character needs no backtracking.

**Complexity.** The fixed brute-force search is O(n * m) in the worst case (`"aaaa...ab"` searched for `"aaab"`) and O(1) space. The buggy version is O(n), but only because it skips candidates.

**Common mistakes**
- Only resetting `n = needle;` on a mismatch. This is the bug above. It passes every test where the needle has no repeated prefix.
- Backtracking to `start` instead of `start + 1`, which loops forever on the same candidate.
- Forgetting that an empty needle matches at index 0. Many hand-written versions return `NULL` there, or crash when the haystack is empty too.
- Testing only with "nice" strings. Self-overlapping patterns such as `aab`, `abac` and `issip` are the ones that break naive searches.

**Interview follow-ups**
- Make it O(n + m) with **Knuth-Morris-Pratt**: the failure table tells you how far the needle can shift without re-reading the haystack. That matters for a UART stream you cannot rewind.
- The data arrives one byte at a time in an ISR. How would you detect `"\r\nOK\r\n"` incrementally with a tiny state machine instead of re-scanning the buffer?
- The receive buffer is a **ring buffer** that wraps around. How do you search across the wrap point without copying?
