@@@ meta
id: STR-E-03
topic: Strings
difficulty: Easy
type: CODE
title: Palindrome Check Ignoring Case and Punctuation
tags: palindrome, two-pointers, ctype, fgets
@@@ statement_md
For each input line, decide whether it is a **palindrome** when you look only at the **alphanumeric** characters (`A-Z`, `a-z`, `0-9`) and **ignore case**. Spaces, punctuation and every other character are skipped.

A line with no alphanumeric characters at all, including an empty line, counts as a palindrome.

Solve it with **two pointers** moving towards each other over the original line, using O(1) extra memory. Do not build a cleaned-up copy.

**Input**
- Line 1: `t`, the number of test lines.
- Next `t` lines: one string per line. A line may be empty and may contain spaces and punctuation.

**Output**
- For each line, `YES` if it is a palindrome under the rules above, otherwise `NO`.

**Example**
```
Input:
3
A man, a plan, a canal: Panama
race a car
0P

Output:
YES
NO
NO
```
`"0P"` is not a palindrome: lower-casing only changes letters, so `'0'` and `'p'` stay different.
@@@ constraints_md
- `1 <= t <= 100`
- Each line has at most 1000 characters (printable ASCII and spaces) followed by `'\n'`.
- O(1) extra memory besides the line buffer.
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

static char line[1100];

/* Return 1 if s is a palindrome considering only alphanumerics, ignoring case. */
static int is_palindrome(const char *s)
{
    /* TODO: two pointers */
    (void)s;
    return 0;
}

int main(void)
{
    int t;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &t) != 1) return 0;
    for (int i = 0; i < t; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\n")] = '\0';           /* strip the newline */
        puts(is_palindrome(line) ? "YES" : "NO");
    }
    return 0;
}
@@@ sample_input
3
A man, a plan, a canal: Panama
race a car
0P
@@@ sample_output
YES
NO
NO

@@@ sample_input
3
<<BLANK>>
.,!? --
x
@@@ sample_output
YES
YES
YES

@@@ hidden_input
4
Was it a car or a cat I saw?
No 'x' in Nixon
ab_a
abca
@@@ hidden_output
YES
YES
YES
NO

@@@ hidden_input
4
12321
1232 1
123 45
Step on no pets!
@@@ hidden_output
YES
YES
NO
YES

@@@ hidden_input
3
aA
Ab
  a
@@@ hidden_output
YES
NO
YES

@@@ hidden_input
2
ECU 1 UCE
CAN-NAC-x
@@@ hidden_output
YES
NO

@@@ hidden_input
2
abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA
abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!9876543210zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBB
@@@ hidden_output
YES
NO

@@@ hint
Put `i` at the start and `j` at the end. Move `i` forward while `s[i]` is not alphanumeric, and move `j` backward the same way. Then compare the two characters.
@@@ hint
Compare `tolower((unsigned char)s[i])` with `tolower((unsigned char)s[j])`. Make sure the skipping loops also check `i < j`, so a line with no alphanumerics, or with a single one, does not run past the other pointer.
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

static char line[1100];

static int is_palindrome(const char *s)
{
    size_t n = strlen(s);
    if (n == 0)
        return 1;
    size_t i = 0, j = n - 1;
    while (i < j) {
        while (i < j && !isalnum((unsigned char)s[i])) i++;
        while (i < j && !isalnum((unsigned char)s[j])) j--;
        if (tolower((unsigned char)s[i]) != tolower((unsigned char)s[j]))
            return 0;
        i++;
        if (j > 0) j--;     /* j is size_t: never step below 0 */
    }
    return 1;
}

int main(void)
{
    int t;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &t) != 1) return 0;
    for (int i = 0; i < t; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\n")] = '\0';
        puts(is_palindrome(line) ? "YES" : "NO");
    }
    return 0;
}
@@@ explanation_md
**Approach: two pointers.** Start `i` at the first character and `j` at the last. Skip non-alphanumeric characters from both sides, compare the two remaining characters case-insensitively, then move both pointers inwards. Stop when the pointers meet. Every character is examined at most once, and no cleaned copy of the line is built.

```
"A man, a plan, a canal: Panama"
 i                            j    'a' == 'a'
  i (skips ' ')              j     'm' == 'm' ...
```

**Complexity.** Time O(n) per line. Space O(1) beyond the line buffer.

**Common mistakes**
- `j = strlen(s) - 1` on an **empty** string. `strlen` returns `size_t`, so `0 - 1` wraps to `SIZE_MAX` and `s[j]` reads far out of bounds. Handle `n == 0` first, as the solution does, or use signed indices.
- Skip loops without `i < j`. For `".,!"` the left loop would run past the end of the string.
- Passing a plain `char` to `isalnum`/`tolower`. The `<ctype.h>` functions need a value that fits in `unsigned char` (or `EOF`). A negative `char` is undefined behavior and can index outside the internal lookup table.
- Treating `'0'` and `'P'` as equal. `tolower` only changes letters (the classic `"0P"` trap).
- Using `scanf("%s")`, which stops at the first space, instead of reading the whole line with `fgets`.

**Interview follow-ups**
- Return the length of the **longest palindromic substring** (expand around each center in O(n²), or Manacher's algorithm in O(n)).
- Check whether a **singly linked list** of characters is a palindrome in O(1) extra space. (Reverse the second half in place, compare, then restore.)
- Can you make it a palindrome by deleting **at most one** character? (Two pointers; on the first mismatch try skipping either side.)
