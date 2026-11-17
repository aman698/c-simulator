@@@ meta
id: STR-E-02
topic: Strings
difficulty: Easy
type: FUNCTION
title: my_strcmp and my_strncmp with Correct Byte Ordering
tags: strcmp, strncmp, unsigned-char, comparison, no-libc
@@@ statement_md
Implement the two comparison functions of a minimal C library:

```c
int my_strcmp(const char *a, const char *b);
int my_strncmp(const char *a, const char *b, size_t n);
```

Both return a **negative** value if `a` sorts before `b`, **zero** if they are equal, and a **positive** value if `a` sorts after `b`. The C standard defines the order:

- Compare character by character until the strings differ or a `'\0'` is reached.
- The sign of the result is the sign of the difference between the first pair of differing characters, **interpreted as `unsigned char`**. So the byte `0xE9` sorts *after* `'e'` (0x65), even though `char` is signed on x86-64.
- A string that is a proper prefix of the other sorts first (`"CAN" < "CANFD"`).
- `my_strncmp` compares **at most `n`** characters. It also stops at a `'\0'`. With `n == 0` the strings compare equal.

Firmware uses these functions everywhere, for example `my_strncmp(line, "$GPGGA", 6) == 0` to route NMEA sentences, or `my_strcmp(cmd, "RESET") == 0` in a UART command shell.

**How it is tested.** A hidden `main()` runs a list of comparisons and prints only the **sign** of your result (`-1`, `0` or `1`), so any magnitude is accepted.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `CMP "a" "b"` or `NCMP n "a" "b"`. Inside the quotes, `\xHH` stands for the byte with hex value `HH`, so bytes above 127 can be tested.

**Output**
- One line per comparison: the sign of the result.

**Example**
```
Input:
4
CMP "CAN" "CAN"
CMP "CAN" "CANFD"
CMP "LIN" "CAN"
NCMP 3 "$GPGGA" "$GPRMC"

Output:
0
-1
1
0
```
@@@ constraints_md
- `1 <= q <= 20`, strings have at most 100 bytes and never contain a `'\0'` byte inside.
- `0 <= n <= 1000` (`n` may be larger than both strings).
- Do not use `strcmp`, `strncmp`, `memcmp` or `strcoll` (rejected at compile time).
@@@ starter_code
#include <stddef.h>

int my_strcmp(const char *a, const char *b)
{
    /* TODO */
    return 0;
}

int my_strncmp(const char *a, const char *b, size_t n)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define strcmp(a, b) strcmp_is_not_allowed_in_this_exercise
#define strncmp(a, b, n) strncmp_is_not_allowed_in_this_exercise
#define memcmp(a, b, n) memcmp_is_not_allowed_in_this_exercise
#define strcoll(a, b) strcoll_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef strcmp
#undef strncmp
#undef memcmp
#undef strcoll

static int hexval(int c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return 0;
}

/* Parse "...." starting at *pp (skipping blanks); supports \xHH, \\ and \". */
static int parse_quoted(const char **pp, char *out, size_t cap)
{
    const char *p = *pp;
    size_t n = 0;
    while (*p == ' ') p++;
    if (*p != '"') return 0;
    p++;
    while (*p && *p != '"') {
        int c = (unsigned char)*p++;
        if (c == '\\' && *p) {
            int e = (unsigned char)*p++;
            if (e == 'x' && p[0] && p[1]) {
                c = hexval((unsigned char)p[0]) * 16 + hexval((unsigned char)p[1]);
                p += 2;
            } else {
                c = e;
            }
        }
        if (n + 1 < cap) out[n++] = (char)c;
    }
    if (*p != '"') return 0;
    out[n] = '\0';
    *pp = p + 1;
    return 1;
}

static int sign(int v) { return (v > 0) - (v < 0); }

int main(void)
{
    char line[512];
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char a[128], b[128];
        if (!fgets(line, sizeof line, stdin)) return 0;
        const char *p = line;
        if (strncmp(line, "NCMP", 4) == 0) {
            int consumed = 0;
            unsigned int n = 0;
            if (sscanf(line + 4, "%u%n", &n, &consumed) != 1) return 0;
            p = line + 4 + consumed;
            if (!parse_quoted(&p, a, sizeof a) || !parse_quoted(&p, b, sizeof b)) return 0;
            printf("%d\n", sign(my_strncmp(a, b, (size_t)n)));
        } else {
            p = line + 3;
            if (!parse_quoted(&p, a, sizeof a) || !parse_quoted(&p, b, sizeof b)) return 0;
            printf("%d\n", sign(my_strcmp(a, b)));
        }
    }
    return 0;
}
@@@ sample_input
4
CMP "CAN" "CAN"
CMP "CAN" "CANFD"
CMP "LIN" "CAN"
NCMP 3 "$GPGGA" "$GPRMC"
@@@ sample_output
0
-1
1
0

@@@ sample_input
3
CMP "" ""
CMP "a" ""
NCMP 0 "abc" "xyz"
@@@ sample_output
0
1
0

@@@ hidden_input
3
CMP "\xE9" "e"
CMP "abc\x80" "abc\x7F"
CMP "\x01" "\xFF"
@@@ hidden_output
1
1
-1

@@@ hidden_input
4
NCMP 10 "abc" "abc"
NCMP 4 "abc" "abd"
NCMP 5 "ab" "abc"
NCMP 1000 "RESET" "RESET!"
@@@ hidden_output
0
-1
-1
-1

@@@ hidden_input
3
CMP "Apple" "apple"
CMP "ab" "a"
CMP "" "z"
@@@ hidden_output
-1
1
-1

@@@ hidden_input
2
CMP "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789" "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456788"
CMP "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789" "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
@@@ hidden_output
1
0

@@@ hidden_input
4
NCMP 2 "\xC3\xA9" "\xC3\x41"
NCMP 1 "\xC3\xA9" "\xC3\x41"
NCMP 6 "$GPGGA,1" "$GPGGB,1"
NCMP 3 "x" "x"
@@@ hidden_output
1
0
-1
0

@@@ hidden_input
3
CMP "AT+CSQ" "AT+CREG"
CMP "OK" "OK "
CMP "ERROR" "OK"
@@@ hidden_output
1
-1
-1

@@@ hint
Walk both strings while the characters are equal **and** not `'\0'`. After the loop, the answer depends only on the two characters you stopped at.
@@@ hint
Return `(unsigned char)*a - (unsigned char)*b`. Both operands are promoted to `int`, so the subtraction cannot overflow, and the bytes are compared as 0..255 as the standard requires. For `my_strncmp`, count down `n` and return `0` as soon as it reaches zero.
@@@ solution_code
#include <stddef.h>

int my_strcmp(const char *a, const char *b)
{
    const unsigned char *x = (const unsigned char *)a;
    const unsigned char *y = (const unsigned char *)b;

    while (*x != '\0' && *x == *y) {
        x++;
        y++;
    }
    return (int)*x - (int)*y;   /* '\0' (0) sorts before every other byte */
}

int my_strncmp(const char *a, const char *b, size_t n)
{
    const unsigned char *x = (const unsigned char *)a;
    const unsigned char *y = (const unsigned char *)b;

    for (; n > 0; n--, x++, y++) {
        if (*x != *y)
            return (int)*x - (int)*y;
        if (*x == '\0')         /* both ended at the same place */
            return 0;
    }
    return 0;                   /* first n characters are equal */
}
@@@ explanation_md
**Approach.** Advance both pointers while the characters match and are not the terminator. The first mismatch, or the end of one string, decides the order. If one string ends first, its `'\0'` (value 0) is smaller than any real character, which is why a prefix sorts first.

The subtle part is **signedness**. The standard (C11 7.24.4p1) says the comparison uses the bytes as `unsigned char`. On x86-64 and most ARM ABIs for Linux, plain `char` is signed, so `0xE9` is `-23`. Subtracting plain `char`s would make `"\xE9" < "e"`, which is the wrong answer. Reading the bytes through `const unsigned char *` fixes it. The difference of two values in 0..255 always fits in an `int`.

**Complexity.** O(min(len(a), len(b))) time for `my_strcmp`, O(min(n, len)) for `my_strncmp`. Both use O(1) space.

**Common mistakes**
- Comparing plain `char`. This works for ASCII and fails for UTF-8 or Latin-1 bytes, or for binary protocol data stored in `char` buffers.
- Returning only `-1/0/1` is fine. But code that **relies** on the magnitude (`if (strcmp(a, b) == -1)`) is a bug, because the standard only guarantees the sign.
- `my_strncmp`: not stopping at `'\0'` when `n` is larger than the strings, which reads past the end of both buffers.
- `my_strncmp` with `n == 0`: the answer must be `0` without touching the strings.
- Writing `if (my_strcmp(a, b))` to mean "equal". A non-zero result means **different**.

**Interview follow-ups**
- Implement a case-insensitive `my_stricmp` portably (`strcasecmp` is POSIX, not ISO C). Where does `tolower` need a cast to `unsigned char`?
- Why can a byte-by-byte comparison be a security problem when checking a password or a MAC in a bootloader, and how does a **constant-time** comparison look?
- How would you compare two CAN frames (11-bit ID + up to 8 data bytes) that are not strings? (`memcmp` on the data, plus the length and ID fields; never on a struct with padding.)
