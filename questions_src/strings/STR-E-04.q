@@@ meta
id: STR-E-04
topic: Strings
difficulty: Easy
type: CODE
title: Anagram Check with a Frequency Table
tags: anagram, frequency-count, counting-array, fgets
@@@ statement_md
Two strings are **anagrams** if one can be rearranged to form the other.

For this check:
- **Spaces are ignored.**
- **Letters are case-insensitive** (`'D'` matches `'d'`).
- Every other character (digits, punctuation) counts and must match exactly.

So `"Dormitory"` and `"dirty room"` are anagrams, and `"CAN 2.0B"` and `"B0.2 NAC"` are anagrams too. Two empty strings are anagrams of each other.

Solve it in **O(n)** time with a fixed-size counting table. Sorting both strings (O(n log n)) also gives the right answer but misses the point of the exercise.

**Input**
- Line 1: `t`, the number of test cases.
- Then `2*t` lines: each test case is two lines, the first string and the second string. A line may be empty.

**Output**
- For each test case, `YES` if the two strings are anagrams under the rules above, otherwise `NO`.

**Example**
```
Input:
3
listen
silent
Dormitory
dirty room
aab
abb

Output:
YES
YES
NO
```
`"aab"` and `"abb"` use the same **set** of letters but not the same **counts**.
@@@ constraints_md
- `1 <= t <= 100`
- Each string has at most 1000 characters (printable ASCII and spaces).
- O(n) time, O(1) extra space (a table of 256 counters is O(1)).
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

static char a[1100], b[1100];

/* Return 1 if a and b are anagrams (spaces ignored, letters case-insensitive). */
static int is_anagram(const char *x, const char *y)
{
    /* TODO */
    (void)x; (void)y;
    return 0;
}

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
        read_line(a, sizeof a);
        read_line(b, sizeof b);
        puts(is_anagram(a, b) ? "YES" : "NO");
    }
    return 0;
}
@@@ sample_input
3
listen
silent
Dormitory
dirty room
aab
abb
@@@ sample_output
YES
YES
NO

@@@ sample_input
2
<<BLANK>>
<<BLANK>>
rat
car
@@@ sample_output
YES
NO

@@@ hidden_input
3
a
a
abc
abcd
aa
a
@@@ hidden_output
YES
NO
NO

@@@ hidden_input
2
Astronomer
Moon starer
CAN 2.0B
B0.2 NAC
@@@ hidden_output
YES
YES

@@@ hidden_input
3
   x
x
a b c
cba
12:34
43:21
@@@ hidden_output
YES
YES
YES

@@@ hidden_input
2
Dormitory!
dirty room
ECU-1
ecu+1
@@@ hidden_output
NO
NO

@@@ hidden_input
2
The quick brown fox jumps over the lazy dog 0123456789 THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG
god yzal eht revo spmuj xof nworb kciuq eht 9876543210 GOD YZAL EHT REVO SPMUJ XOF NWORB KCIUQ EHT
The quick brown fox jumps over the lazy dog 0123456789 THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG
god yzal eht revo spmuj xof nworb kciuq eht 9876543210 GOD YZAL EHT REVO SPMUJ XOF NWORB KCIUQ EHX
@@@ hidden_output
YES
NO

@@@ hint
Use one array `int count[256]`. Add 1 for every character of the first string and subtract 1 for every character of the second. They are anagrams exactly when every counter ends at zero.
@@@ hint
Skip `' '`, and normalise letters with `tolower((unsigned char)c)` before indexing. Index the table with an `unsigned char` value. A plain `char` above 127 is negative on x86-64 and would index before the array.
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

static char a[1100], b[1100];

static int is_anagram(const char *x, const char *y)
{
    int count[256] = {0};

    for (; *x; x++)
        if (*x != ' ')
            count[tolower((unsigned char)*x)]++;
    for (; *y; y++)
        if (*y != ' ')
            count[tolower((unsigned char)*y)]--;

    for (int i = 0; i < 256; i++)
        if (count[i] != 0)
            return 0;
    return 1;
}

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
        read_line(a, sizeof a);
        read_line(b, sizeof b);
        puts(is_anagram(a, b) ? "YES" : "NO");
    }
    return 0;
}
@@@ explanation_md
**Approach: one counting table.** Count characters up for the first string and down for the second. If the strings are permutations of each other, every increment is cancelled by a decrement, so all 256 counters end at zero. Spaces are skipped and letters are folded with `tolower` before counting.

Do **not** compare lengths first: `"dirty room"` (10 characters) and `"Dormitory"` (9) are anagrams once the space is ignored.

**Complexity.** Time O(n + m + 256), which is O(n). Space O(1): the table has a fixed 256 entries no matter how long the input is.

**Common mistakes**
- Using a `bool seen[256]` (a set) instead of counts. Then `"aab"` and `"abb"` are wrongly reported as anagrams.
- `count[c]` with a plain `char c`. For bytes above 127, `c` is negative on x86-64 and the index is out of bounds. Always cast to `unsigned char` first.
- Rejecting different lengths up front, which breaks the "spaces are ignored" rule.
- Using `scanf("%s")`. It stops at the first space and does not read empty lines.
- Sorting with `qsort`. It works, but it is O(n log n) and modifies or copies the input.

**Interview follow-ups**
- Group a list of words into anagram classes. (Use the sorted word or the 26-count signature as a hash key.)
- Find all start indices of anagrams of `p` inside `s` with a **sliding window** of counts in O(n).
- If the input is arbitrary Unicode text, a 256-entry table no longer works. What changes? (Decode code points and use a hash map, or normalise first.)
