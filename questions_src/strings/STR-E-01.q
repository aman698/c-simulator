@@@ meta
id: STR-E-01
topic: Strings
difficulty: Easy
type: FUNCTION
title: Bare-Metal my_strlen, my_strcpy and my_strcat
tags: embedded, strlen, strcpy, strcat, null-terminator, no-libc
@@@ statement_md
Your bootloader is linked **without the C library**, so you have to provide the three string primitives yourself:

```c
size_t my_strlen(const char *s);               /* length without the '\0'; my_strlen(NULL) == 0 */
char  *my_strcpy(char *dst, const char *src);  /* copy src (incl. '\0') to dst, return dst */
char  *my_strcat(char *dst, const char *src);  /* append src to the end of dst, return dst */
```

They must behave like the standard functions:
- `my_strlen` counts characters up to (not including) the terminating `'\0'`. As a defensive extension, `my_strlen(NULL)` returns `0`.
- `my_strcpy` copies every character of `src` **including** the terminating `'\0'`, and returns the original `dst`.
- `my_strcat` overwrites the `'\0'` of `dst` with the first character of `src`, copies the rest including the new `'\0'`, and returns the original `dst`.

`dst` is always large enough and never overlaps `src`.

**How it is tested.** A hidden `main()` owns a 64-byte destination buffer (initially the empty string) surrounded by guard bytes. It executes a list of commands and prints the result after each one. It reports `BAD RETURN VALUE` if you do not return `dst`, `MISSING TERMINATOR` if the buffer has no `'\0'`, and `OUT OF BOUNDS WRITE` if a guard byte changes. Before every copy, the bytes you are expected to overwrite are filled with `#`, so a missing terminator cannot hide behind an old one.

**Input (read by the hidden harness)**
- Line 1: `q`, the number of commands.
- Next `q` lines, each one of:
  - `LEN "text"` prints `my_strlen(text)`. `LEN NULL` passes a null pointer.
  - `CPY "text"` runs `my_strcpy(buf, text)` and prints `[buf]`.
  - `CAT "text"` runs `my_strcat(buf, text)` and prints `[buf]`.

**Output**
- One line per command, as described above.

**Example**
```
Input:
4
CPY "ECU"
CAT "_"
CAT "BRAKE"
LEN "hello world"

Output:
[ECU]
[ECU_]
[ECU_BRAKE]
11
```
@@@ constraints_md
- `1 <= q <= 20`
- `text` has at most 100 characters and contains no `"` character.
- The buffer content never exceeds 63 characters (it always fits with its `'\0'`).
- Do not use any `<string.h>` function (`strlen`, `strcpy`, `strcat`, `strncpy`, `strncat`, `memcpy`, `memmove` are rejected at compile time).
@@@ starter_code
#include <stddef.h>

size_t my_strlen(const char *s)
{
    /* TODO: count characters up to '\0'; return 0 for NULL */
    return 0;
}

char *my_strcpy(char *dst, const char *src)
{
    /* TODO: copy src including its '\0'; return dst */
    return dst;
}

char *my_strcat(char *dst, const char *src)
{
    /* TODO: append src at the end of dst; return dst */
    return dst;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define strlen(s) strlen_is_not_allowed_in_this_exercise
#define strcpy(d, s) strcpy_is_not_allowed_in_this_exercise
#define strcat(d, s) strcat_is_not_allowed_in_this_exercise
#define strncpy(d, s, n) strncpy_is_not_allowed_in_this_exercise
#define strncat(d, s, n) strncat_is_not_allowed_in_this_exercise
#define memcpy(d, s, n) memcpy_is_not_allowed_in_this_exercise
#define memmove(d, s, n) memmove_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef strlen
#undef strcpy
#undef strcat
#undef strncpy
#undef strncat
#undef memcpy
#undef memmove

#define CAP 64
#define GUARD 16
#define CANARY 0x5A

static unsigned char arena[GUARD + CAP + GUARD];

static int guards_ok(void)
{
    for (int i = 0; i < GUARD; i++)
        if (arena[i] != CANARY || arena[GUARD + CAP + i] != CANARY)
            return 0;
    return 1;
}

/* Extract the text between the first and the last '"' of the line. */
static int quoted_arg(const char *line, char *out, size_t cap)
{
    const char *a = strchr(line, '"');
    const char *b = strrchr(line, '"');
    if (!a || a == b) return 0;
    size_t n = (size_t)(b - a - 1);
    if (n >= cap) n = cap - 1;
    memcpy(out, a + 1, n);
    out[n] = '\0';
    return 1;
}

int main(void)
{
    char line[256];
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;

    memset(arena, CANARY, sizeof arena);
    char *buf = (char *)arena + GUARD;
    memset(buf, '#', CAP);
    buf[0] = '\0';

    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        line[strcspn(line, "\r\n")] = '\0';
        char arg[128];
        if (strncmp(line, "LEN NULL", 8) == 0) {
            printf("%zu\n", my_strlen(NULL));
            continue;
        }
        if (!quoted_arg(line, arg, sizeof arg)) return 0;
        if (strncmp(line, "LEN", 3) == 0) {
            printf("%zu\n", my_strlen(arg));
            continue;
        }
        char *ret;
        if (strncmp(line, "CPY", 3) == 0) {
            memset(buf, '#', CAP);                       /* no stale terminator */
            ret = my_strcpy(buf, arg);
        } else {
            const char *z = memchr(buf, '\0', CAP);
            size_t cur = z ? (size_t)(z - buf) : CAP - 1;
            memset(buf + cur + 1, '#', CAP - cur - 1);   /* only the old '\0' remains */
            ret = my_strcat(buf, arg);
        }
        if (!guards_ok()) {
            printf("OUT OF BOUNDS WRITE\n");
            return 0;
        }
        if (ret != buf) printf("BAD RETURN VALUE\n");
        if (!memchr(buf, '\0', CAP)) {
            printf("MISSING TERMINATOR\n");
            return 0;
        }
        printf("[%s]\n", buf);
    }
    return 0;
}
@@@ sample_input
4
CPY "ECU"
CAT "_"
CAT "BRAKE"
LEN "hello world"
@@@ sample_output
[ECU]
[ECU_]
[ECU_BRAKE]
11

@@@ sample_input
3
LEN ""
CPY ""
CAT "x"
@@@ sample_output
0
[]
[x]

@@@ hidden_input
2
LEN NULL
LEN "a"
@@@ hidden_output
0
1

@@@ hidden_input
3
CPY "INSTRUMENT_CLUSTER"
CPY "ab"
CAT "c"
@@@ hidden_output
[INSTRUMENT_CLUSTER]
[ab]
[abc]

@@@ hidden_input
2
CPY "0123456789abcdef0123456789abcdef"
CAT "ghijklmnopqrstuvwxyzABCDEFGHIJK"
@@@ hidden_output
[0123456789abcdef0123456789abcdef]
[0123456789abcdef0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJK]

@@@ hidden_input
4
CPY "CAN"
CAT ""
CAT "|LIN"
CAT "|FlexRay"
@@@ hidden_output
[CAN]
[CAN]
[CAN|LIN]
[CAN|LIN|FlexRay]

@@@ hidden_input
3
LEN "  two  spaces  "
LEN "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
LEN " "
@@@ hidden_output
15
100
1

@@@ hidden_input
5
CAT "a"
CAT "b"
CAT "c"
CPY "reset"
CAT ""
@@@ hidden_output
[a]
[ab]
[abc]
[reset]
[reset]

@@@ hint
`my_strlen` is a loop that walks a pointer (or an index) until it reaches `'\0'`. For `my_strcpy`, remember that the terminator is part of what you copy. A `do { ... } while` loop or `while ((*d++ = *s++) != '\0')` handles that.
@@@ hint
`my_strcat` is "find the end of `dst`, then `my_strcpy` from there". Keep the original `dst` in a variable so you can return it after advancing your working pointer.
@@@ solution_code
#include <stddef.h>

size_t my_strlen(const char *s)
{
    const char *p = s;
    if (s == NULL)
        return 0;
    while (*p != '\0')
        p++;
    return (size_t)(p - s);
}

char *my_strcpy(char *dst, const char *src)
{
    char *d = dst;
    while ((*d++ = *src++) != '\0')
        ;                       /* the '\0' is copied by the last iteration */
    return dst;
}

char *my_strcat(char *dst, const char *src)
{
    char *d = dst;
    while (*d != '\0')          /* find the current terminator ... */
        d++;
    while ((*d++ = *src++) != '\0')
        ;                       /* ... and overwrite it with src */
    return dst;
}
@@@ explanation_md
**Approach.** A C string is just a run of `char` ended by `'\0'`. All three functions are pointer walks:
- `my_strlen`: advance until `*p == '\0'` and return `p - s`. Pointer subtraction gives a `ptrdiff_t`, so cast it to `size_t`.
- `my_strcpy`: `while ((*d++ = *s++) != '\0');` copies a character, then tests the character it just copied. The loop therefore stops **after** copying the terminator.
- `my_strcat`: walk `d` to the existing `'\0'`, then do the same copy loop from there.

Both copy functions return the **original** `dst`. That is what makes chaining such as `my_strcat(my_strcpy(buf, "ECU"), "_1")` work.

**Complexity.** `my_strlen` and `my_strcpy` are O(n) time. `my_strcat` is O(len(dst) + len(src)). All three use O(1) extra space.

**Common mistakes**
- Stopping the copy loop **before** the terminator (`while (*s) *d++ = *s++;` without a final `*d = '\0'`). The harness pre-fills the buffer with `#`, so this shows up immediately. On real hardware the old buffer contents often hide the bug.
- Returning the advanced pointer `d` instead of `dst`.
- Using `int` for the length. Strings longer than `INT_MAX` are possible on 64-bit targets, and the standard return type is `size_t`.
- Calling `my_strcat` in a loop to build a long string. Each call re-scans `dst` from the start, so building n pieces costs O(n²) ("Schlemiel the painter"). Keep a pointer to the current end instead.

**Interview follow-ups**
- Why is `strcpy` banned by MISRA C and most automotive coding guidelines, and what would you use instead? (Bounded copies with an explicit destination size, such as `snprintf` or a custom `strlcpy`-like function.)
- How would you write a word-at-a-time `strlen` that reads 4 or 8 bytes per iteration? What is the bit trick to detect a zero byte inside a word, and why must the reads be aligned?
- What does the standard say about `strcpy` with overlapping buffers? (Undefined behavior.)
- `my_strlen(NULL)` returns 0 here. Is that a good idea in production code, or does it hide bugs?
