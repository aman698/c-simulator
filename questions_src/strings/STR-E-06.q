@@@ meta
id: STR-E-06
topic: Strings
difficulty: Easy
type: FUNCTION
title: Remove Duplicate Characters In Place
tags: remove-duplicates, in-place, read-write-pointers, lookup-table, unsigned-char
@@@ statement_md
Implement

```c
size_t remove_duplicates(char *s);
```

The function removes every character that has **already appeared earlier** in the string, keeping the **first** occurrence of each character in its original order. It works **in place**: compact the string inside its own buffer, write the new `'\0'`, and return the new length.

- Comparison is byte-exact and case-sensitive (`'A'` and `'a'` are different; a space is a character like any other).
- The string may contain any byte value from 1 to 255, including bytes above 127 (UTF-8 or Latin-1 text).
- `remove_duplicates(NULL)` returns `0` and does nothing.
- O(n) time and O(1) extra memory (a fixed table of 256 entries is fine). No second buffer and no `malloc`.

**How it is tested.** A hidden `main()` copies each test string into a buffer surrounded by guard bytes, calls your function, and prints `[result] len`. Bytes outside printable ASCII are printed as `\xHH`. It prints `BAD LENGTH` if the returned length does not match the string, and `OUT OF BOUNDS WRITE` if you write outside the string's bytes.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: a string in double quotes (`\xHH` in the quotes stands for one byte), or the word `NULL`.

**Output**
- One line per string: `[result] len`, or `NULL -> 0` for the null pointer.

**Example**
```
Input:
3
"programming"
"aaaa"
"Hello, World!"

Output:
[progamin] 8
[a] 1
[Helo, Wrd!] 10
```
@@@ constraints_md
- `1 <= q <= 20`
- Each string has at most 2000 bytes.
- In place, O(n) time, O(1) extra space.
@@@ starter_code
#include <stddef.h>

/* Keep the first occurrence of every character; compact in place; return the new length. */
size_t remove_duplicates(char *s)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

/*USER_CODE*/

#define CAP 2100
#define GUARD 16
#define CANARY 0xA5

static unsigned char arena[GUARD + CAP + GUARD];
static char line[8500];
static char text[CAP];

static int hexval(int c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return 0;
}

static size_t parse_quoted(const char *p, char *out, size_t cap)
{
    size_t n = 0;
    p = strchr(p, '"');
    if (!p) return 0;
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
    out[n] = '\0';
    return n;
}

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        if (strncmp(line, "NULL", 4) == 0) {
            printf("NULL -> %zu\n", remove_duplicates(NULL));
            continue;
        }
        size_t len = parse_quoted(line, text, sizeof text);
        memset(arena, CANARY, sizeof arena);
        char *buf = (char *)arena + GUARD;
        memcpy(buf, text, len + 1);
        size_t ret = remove_duplicates(buf);
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
        size_t real = strlen(buf);
        putchar('[');
        for (size_t k = 0; k < real; k++) {
            unsigned char c = (unsigned char)buf[k];
            if (c >= 32 && c < 127) putchar(c);
            else printf("\\x%02X", c);
        }
        printf("] %zu\n", ret);
        if (ret != real) printf("BAD LENGTH\n");
    }
    return 0;
}
@@@ sample_input
3
"programming"
"aaaa"
"Hello, World!"
@@@ sample_output
[progamin] 8
[a] 1
[Helo, Wrd!] 10

@@@ sample_input
2
""
NULL
@@@ sample_output
[] 0
NULL -> 0

@@@ hidden_input
3
"abc"
"x"
"AaAa"
@@@ hidden_output
[abc] 3
[x] 1
[Aa] 2

@@@ hidden_input
2
" a  b "
"CAN CAN-FD LIN"
@@@ hidden_output
[ ab] 3
[CAN -FDLI] 9

@@@ hidden_input
3
"\xE9t\xE9"
"caf\xC3\xA9 caf\xC3\xA8"
"\xFF\x80\xFF\x80\x7F"
@@@ hidden_output
[\xE9t] 2
[caf\xC3\xA9 \xA8] 7
[\xFF\x80\x7F] 3

@@@ hidden_input
1
"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdef"
@@@ hidden_output
[0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ] 62

@@@ hidden_input
1
"zwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxurolifczwtqnkhebyvspmjgdaxuroli"
@@@ hidden_output
[zwtqnkhebyvspmjgdaxurolifc] 26

@@@ hint
Use two indices over the same buffer: `r` reads every character, `w` is where the next **kept** character goes. Because `w <= r` at all times, writing never overwrites a character you still have to read.
@@@ hint
Keep a table `unsigned char seen[256] = {0}`. For each byte `c = (unsigned char)s[r]`: if `!seen[c]`, mark it and copy it to `s[w++]`. At the end write `s[w] = '\0'` and return `w`.
@@@ solution_code
#include <stddef.h>

size_t remove_duplicates(char *s)
{
    unsigned char seen[256] = {0};
    size_t w = 0;

    if (s == NULL)
        return 0;

    for (size_t r = 0; s[r] != '\0'; r++) {
        unsigned char c = (unsigned char)s[r];   /* never index with a signed char */
        if (!seen[c]) {
            seen[c] = 1;
            s[w++] = s[r];                       /* w <= r: safe in place */
        }
    }
    s[w] = '\0';
    return w;
}
@@@ explanation_md
**Approach: read/write pointers plus a "seen" table.** This is the same compaction pattern used to filter an array in place. The read index `r` visits every byte. The write index `w` only advances for bytes that are kept. Since `w` never overtakes `r`, the buffer can be shared, and no temporary copy is needed.

```
"programming"
 r: p r o g r a m m i n g
 kept: p r o g . a m . i n .   ->  "progamin", len 8
```

**Complexity.** Time O(n), one pass. Space O(1): the 256-byte table does not grow with the input.

**Common mistakes**
- `seen[s[r]]` with a plain `char`. For the byte `0xE9`, the index is `-23` on x86-64. That is out-of-bounds memory access, and the hidden UTF-8 tests catch it. Convert to `unsigned char` first.
- Forgetting the final `s[w] = '\0'`. The old tail of the string then stays visible.
- Shifting the rest of the string left every time a duplicate is found (a `memmove` per duplicate). That is O(n²).
- An O(n²) approach that searches `s[0..w-1]` for each character. It works here only because the output holds at most 256 distinct bytes, but it does not generalise.
- Treating `'A'` and `'a'` as duplicates when the specification says the comparison is case-sensitive.

**Interview follow-ups**
- Remove only **adjacent** duplicates (`"aaabcc"` -> `"abc"`). This needs no table at all. (Compare with the previously written character.)
- Keep characters that appear **exactly once** in the whole string. (Two passes: count first, then compact.)
- On a small MCU, 256 bytes of stack for `seen` may be too much. Use a 256-**bit** bitmap (32 bytes) with `seen[c >> 3] & (1u << (c & 7))`.
