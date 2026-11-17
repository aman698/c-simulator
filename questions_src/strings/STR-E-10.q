@@@ meta
id: STR-E-10
topic: Strings
difficulty: Easy
type: FIND_THE_BUG
title: Cluster Display Text with Stale Characters
tags: embedded, null-terminator, static-buffer, toupper, display
@@@ statement_md
An instrument cluster has a 16-character text field. The function `to_display()` converts a warning message to **upper case**, **truncates** it to at most 16 characters, and returns a pointer to its internal static buffer. The program prints the display text for every message it receives.

The first message is always shown correctly. But after a long message, a **shorter** one shows leftover characters from the previous message: `"door open"` followed by `"abs"` is displayed as `ABSR OPEN`.

Find and fix the bug. Keep the static buffer; the caller prints the text before the next call.

**Input**
- Line 1: `n`.
- Next `n` lines: one message per line (may contain spaces; may be empty).

**Output**
- For each message, the display text in square brackets: `[TEXT]`.

**Example**
```
Input:
2
door open
abs

Output:
[DOOR OPEN]
[ABS]
```
@@@ constraints_md
- `1 <= n <= 100`
- Each message has at most 100 printable ASCII characters.
- The display shows at most `DISPLAY_MAX = 16` characters.
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define DISPLAY_MAX 16

/* Upper-case copy of s, truncated to DISPLAY_MAX characters.
 * Returns a pointer to a static buffer that is valid until the next call. */
static const char *to_display(const char *s)
{
    static char out[DISPLAY_MAX + 1];
    size_t i;

    for (i = 0; s[i] != '\0' && i < DISPLAY_MAX; i++)
        out[i] = (char)toupper((unsigned char)s[i]);

    return out;
}

int main(void)
{
    char line[128];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;

    for (int k = 0; k < n; k++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\n")] = '\0';
        printf("[%s]\n", to_display(line));
    }
    return 0;
}
@@@ sample_input
2
door open
abs
@@@ sample_output
[DOOR OPEN]
[ABS]

@@@ sample_input
1
check engine
@@@ sample_output
[CHECK ENGINE]

@@@ hidden_input
3
low tyre pressure front left
oil
<<BLANK>>
@@@ hidden_output
[LOW TYRE PRESSUR]
[OIL]
[]

@@@ hidden_input
2
abs
door open
@@@ hidden_output
[ABS]
[DOOR OPEN]

@@@ hidden_input
3
exactly16chars!!
service due
esp off
@@@ hidden_output
[EXACTLY16CHARS!!]
[SERVICE DUE]
[ESP OFF]

@@@ hidden_input
4
x
xy
xyz
w
@@@ hidden_output
[X]
[XY]
[XYZ]
[W]

@@@ hidden_input
3
battery 12.1v
fuel 5%
eco mode
@@@ hidden_output
[BATTERY 12.1V]
[FUEL 5%]
[ECO MODE]

@@@ hint
`out` is `static`, so it starts as all zeros and **keeps its contents between calls**. Which byte tells `printf("%s")` where the text ends, and who writes it on the second call?
@@@ hint
The loop copies the characters but never writes a `'\0'`. On the first call the zero-initialised buffer hides this. After the loop, `i` is exactly where the terminator belongs: add `out[i] = '\0';`.
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define DISPLAY_MAX 16

/* Upper-case copy of s, truncated to DISPLAY_MAX characters.
 * Returns a pointer to a static buffer that is valid until the next call. */
static const char *to_display(const char *s)
{
    static char out[DISPLAY_MAX + 1];
    size_t i;

    for (i = 0; s[i] != '\0' && i < DISPLAY_MAX; i++)
        out[i] = (char)toupper((unsigned char)s[i]);
    out[i] = '\0';                     /* FIX: terminate the (possibly truncated) copy */

    return out;
}

int main(void)
{
    char line[128];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;

    for (int k = 0; k < n; k++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\n")] = '\0';
        printf("[%s]\n", to_display(line));
    }
    return 0;
}
@@@ explanation_md
**Bug.** The copy loop never writes a terminating `'\0'`. On the first call this is hidden because a `static` array is zero-initialised, so the byte after the text is already 0. From the second call on, the buffer still holds the previous message. A shorter message overwrites only its own characters, and `printf("%s")` keeps printing the old tail until it finds the old terminator:

```
after "door open": D O O R _ O P E N \0 ...
after "abs":       A B S R _ O P E N \0 ...   -> "ABSR OPEN"
```

**Fix.** After the loop, `i` is the number of characters copied (at most 16), so `out[i] = '\0';` terminates both normal and truncated text. The buffer has `DISPLAY_MAX + 1` bytes, so index 16 is valid.

**Complexity.** O(min(n, 16)) time per message, O(1) space (one static 17-byte buffer).

**Common mistakes**
- Testing with only one message, or always from long to short in a fresh process. The bug needs a long message **followed by** a shorter one.
- "Fixing" it with `memset(out, 0, sizeof out)` at the top of every call. It works, but it hides the real rule: every function that produces a string must write its own terminator.
- Sizing the buffer `DISPLAY_MAX` instead of `DISPLAY_MAX + 1`. A 16-character message then has nowhere to put its `'\0'`.

**Interview follow-ups**
- Functions that return a pointer to a `static` buffer are not **reentrant**. What goes wrong if `to_display()` is called from both a 10 ms task and an ISR, or twice in one `printf` argument list? How would you change the API? (Caller-provided buffer plus size.)
- How would you right-align or centre the text in the 16-character field without a second buffer?
- The display controller expects exactly 16 bytes padded with spaces and **no** terminator. How would you write that frame safely?
