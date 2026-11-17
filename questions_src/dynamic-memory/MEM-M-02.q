@@@ meta
id: MEM-M-02
topic: Dynamic Memory
difficulty: Medium
type: FUNCTION
title: Dynamic String Builder That Survives Self-Append
tags: string-builder, realloc, aliasing, use-after-free, ownership-transfer
@@@ statement_md
Implement a growable string builder, the kind you write for a diagnostic logger or a JSON/UDS report generator:

```c
struct sbuf {
    char  *buf;   /* NUL-terminated when non-NULL; NULL when empty and never grown */
    size_t len;   /* strlen(buf) */
    size_t cap;   /* bytes allocated for buf (including the '\0') */
};

int   sb_append(struct sbuf *sb, const char *s);   /* 0 ok, -1 out of memory */
int   sb_append_char(struct sbuf *sb, char c);
int   sb_append_int(struct sbuf *sb, int v);       /* decimal, e.g. -42 */
char *sb_detach(struct sbuf *sb);                  /* hand the string to the caller */
void  sb_free(struct sbuf *sb);
```

Rules:
- A builder starts as `{NULL, 0, 0}`.
- **Capacity policy.** When appending `k` characters needs `len + k + 1 > cap`, the new capacity starts from `cap` (or **16** if `cap == 0`) and doubles until `len + k + 1 <= newcap`. Never shrink.
- **Aliasing.** `s` may point **into the builder's own buffer**: `sb_append(sb, sb->buf)` doubles the string, and `sb_append(sb, sb->buf + 3)` appends its own tail. This must work even when the append makes the buffer move.
- `sb_append_int` must handle `INT_MIN`.
- `sb_detach` returns the heap string and resets the builder to `{NULL, 0, 0}`. The caller now owns the string and frees it. For an empty builder it returns a new heap string `""` (never `NULL` unless out of memory).
- `sb_free` releases the buffer and resets the builder.

**Input (read by the hidden harness)**, one operation per line:
- `S <text>`: `sb_append(&sb, text)` (the text is the rest of the line and may contain spaces).
- `C <ch>`: `sb_append_char`. `I <v>`: `sb_append_int`.
- `SELF`: `sb_append(&sb, sb.buf)`. `TAIL <k>`: `sb_append(&sb, sb.buf + k)` (`0 <= k <= len`).
- `P`: prints `len=<len> cap=<cap> "<string>"`. Strings longer than 60 characters are shown as the first 20 characters, `...`, and the last 20.
- `D`: detaches and prints `detached "<string>"` (same abbreviation), then the harness frees it.

**Example**
```
Input:
S CAN
C _
I 1024
P
SELF
P
D
P

Output:
len=8 cap=16 "CAN_1024"
len=16 cap=32 "CAN_1024CAN_1024"
detached "CAN_1024CAN_1024"
len=0 cap=0 ""
```
@@@ constraints_md
- At most 100 operations, final length at most 1,000,000 characters.
- `SELF`/`TAIL` are only used when `sb.buf != NULL`.
- Text lines are at most 200 characters, printable ASCII.
- Leak checking is on: the harness frees detached strings and calls `sb_free` at the end.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct sbuf {
    char *buf;
    size_t len;
    size_t cap;
};

int sb_append(struct sbuf *sb, const char *s)
{
    /* TODO: grow (16, then x2) if needed; s may point into sb->buf! */
    return -1;
}

int sb_append_char(struct sbuf *sb, char c)
{
    /* TODO */
    return -1;
}

int sb_append_int(struct sbuf *sb, int v)
{
    /* TODO */
    return -1;
}

char *sb_detach(struct sbuf *sb)
{
    /* TODO */
    return NULL;
}

void sb_free(struct sbuf *sb)
{
    /* TODO */
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*USER_CODE*/

static void show(const char *s, size_t len)
{
    if (len > 60)
        printf("\"%.20s...%s\"\n", s, s + len - 20);
    else
        printf("\"%s\"\n", s);
}

int main(void)
{
    struct sbuf sb = { NULL, 0, 0 };
    char line[256];

    while (fgets(line, sizeof line, stdin) != NULL) {
        size_t n = strlen(line);
        if (n > 0 && line[n - 1] == '\n')
            line[--n] = '\0';
        int rc = 0;
        if (strncmp(line, "SELF", 4) == 0) {
            rc = sb_append(&sb, sb.buf);
        } else if (strncmp(line, "TAIL ", 5) == 0) {
            size_t k = (size_t)strtoul(line + 5, NULL, 10);
            rc = sb_append(&sb, sb.buf + k);
        } else if (strncmp(line, "S ", 2) == 0) {
            rc = sb_append(&sb, line + 2);
        } else if (strncmp(line, "C ", 2) == 0) {
            rc = sb_append_char(&sb, line[2]);
        } else if (strncmp(line, "I ", 2) == 0) {
            rc = sb_append_int(&sb, atoi(line + 2));
        } else if (strcmp(line, "P") == 0) {
            printf("len=%zu cap=%zu ", sb.len, sb.cap);
            show(sb.buf ? sb.buf : "", sb.len);
        } else if (strcmp(line, "D") == 0) {
            char *s = sb_detach(&sb);
            if (s == NULL) {
                printf("detached NULL\n");
            } else {
                printf("detached ");
                show(s, strlen(s));
                free(s);
            }
            if (sb.buf != NULL || sb.len != 0 || sb.cap != 0)
                printf("FAIL: builder not reset after detach\n");
        }
        if (rc != 0)
            printf("append failed\n");
        if (sb.buf != NULL && (strlen(sb.buf) != sb.len || sb.len >= sb.cap))
            printf("FAIL: inconsistent len/cap/terminator\n");
    }
    sb_free(&sb);
    if (sb.buf != NULL || sb.len != 0 || sb.cap != 0)
        printf("FAIL: builder not reset by sb_free\n");
    return 0;
}
@@@ sample_input
S CAN
C _
I 1024
P
SELF
P
D
P
@@@ sample_output
len=8 cap=16 "CAN_1024"
len=16 cap=32 "CAN_1024CAN_1024"
detached "CAN_1024CAN_1024"
len=0 cap=0 ""

@@@ sample_input
D
I -2147483648
P
@@@ sample_output
detached ""
len=11 cap=16 "-2147483648"

@@@ hidden_input
S 123456789012345
P
C x
P
I 0
I 2147483647
P
@@@ hidden_output
len=15 cap=16 "123456789012345"
len=16 cap=32 "123456789012345x"
len=27 cap=32 "123456789012345x02147483647"

@@@ hidden_input
S abcdefgh
TAIL 4
P
TAIL 12
P
SELF
P
@@@ hidden_output
len=12 cap=16 "abcdefghefgh"
len=12 cap=16 "abcdefghefgh"
len=24 cap=32 "abcdefghefghabcdefghefgh"

@@@ hidden_input
S x
TAIL 0
TAIL 1
SELF
SELF
SELF
SELF
SELF
SELF
P
D
@@@ hidden_output
len=192 cap=256 "xxxxxxxxxxxxxxxxxxxx...xxxxxxxxxxxxxxxxxxxx"
detached "xxxxxxxxxxxxxxxxxxxx...xxxxxxxxxxxxxxxxxxxx"

@@@ hidden_input
S ECU 7: DTC=
I -1
C ;
S  ok
P
TAIL 4
P
D
S again
P
@@@ hidden_output
len=17 cap=32 "ECU 7: DTC=-1; ok"
len=30 cap=32 "ECU 7: DTC=-1; ok7: DTC=-1; ok"
detached "ECU 7: DTC=-1; ok7: DTC=-1; ok"
len=5 cap=16 "again"

@@@ hidden_input
S 0123456789
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
SELF
P
TAIL 655350
P
@@@ hidden_output
len=655360 cap=1048576 "01234567890123456789...01234567890123456789"
len=655370 cap=1048576 "01234567890123456789...01234567890123456789"

@@@ hint
Never write `sb->buf = realloc(sb->buf, ...)` directly. Grow into a temporary pointer, and only commit it (`buf`, `cap`) after success. Measure `strlen(s)` **before** growing.
@@@ hint
If `s` points into `sb->buf`, a moving `realloc` frees the block `s` points to, and copying from `s` afterwards is a use-after-free. Either remember the offset `s - sb->buf` and rebuild `s` after the move, or grow with `malloc` + copy old contents + append `s` + `free(old)`, so the old buffer stays alive until you are done reading from it.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct sbuf {
    char *buf;
    size_t len;
    size_t cap;
};

/* Append n bytes from src (src may point into sb->buf). */
static int sb_append_n(struct sbuf *sb, const char *src, size_t n)
{
    size_t need = sb->len + n + 1;
    if (need < n)
        return -1;                                  /* size_t overflow */
    if (need > sb->cap) {
        size_t newcap = sb->cap ? sb->cap : 16;
        while (newcap < need) {
            if (newcap > SIZE_MAX / 2)
                return -1;
            newcap *= 2;
        }
        /* malloc + copy + free(old): the old buffer (which src may point into)
           stays valid until we have finished reading from it */
        char *nb = malloc(newcap);
        if (nb == NULL)
            return -1;
        if (sb->buf != NULL)
            memcpy(nb, sb->buf, sb->len);
        memcpy(nb + sb->len, src, n);
        nb[sb->len + n] = '\0';
        free(sb->buf);
        sb->buf = nb;
        sb->cap = newcap;
        sb->len += n;
        return 0;
    }
    memmove(sb->buf + sb->len, src, n);             /* no growth: src stays valid */
    sb->len += n;
    sb->buf[sb->len] = '\0';
    return 0;
}

int sb_append(struct sbuf *sb, const char *s)
{
    if (s == NULL)
        return -1;
    return sb_append_n(sb, s, strlen(s));            /* measure before any growth */
}

int sb_append_char(struct sbuf *sb, char c)
{
    return sb_append_n(sb, &c, 1);
}

int sb_append_int(struct sbuf *sb, int v)
{
    char tmp[16];
    int i = (int)sizeof tmp;
    unsigned int u = v < 0 ? 0u - (unsigned int)v : (unsigned int)v;   /* INT_MIN-safe */
    do {
        tmp[--i] = (char)('0' + u % 10u);
        u /= 10u;
    } while (u != 0u);
    if (v < 0)
        tmp[--i] = '-';
    return sb_append_n(sb, tmp + i, sizeof tmp - (size_t)i);
}

char *sb_detach(struct sbuf *sb)
{
    char *s = sb->buf;
    if (s == NULL) {
        s = malloc(1);                               /* empty builder: hand out "" */
        if (s == NULL)
            return NULL;
        s[0] = '\0';
    }
    sb->buf = NULL;                                  /* ownership moves to the caller */
    sb->len = 0;
    sb->cap = 0;
    return s;
}

void sb_free(struct sbuf *sb)
{
    free(sb->buf);
    sb->buf = NULL;
    sb->len = 0;
    sb->cap = 0;
}
@@@ explanation_md
**Approach.** Every append funnels into one helper, `sb_append_n(src, n)`:
1. Compute `need = len + n + 1`, with overflow checks. If it fits, `memmove` the bytes in and re-terminate.
2. Otherwise compute the new capacity (16, then doubling), allocate the new block, copy the old contents and then `src`, and **only then** free the old block.

**The self-append trap.** `sb_append(sb, sb->buf)` passes a pointer into the block that is about to be resized. With the obvious code:
```c
char *p = realloc(sb->buf, newcap);   /* may move: the old block is freed */
memcpy(p + len, s, n);                /* s points into the OLD block -> use-after-free */
```
Whether `realloc` moves depends on the allocator. On glibc a small block often grows in place and the bug hides. Under ASan, or the Windows heap checker, `realloc` always moves, and you get `heap-use-after-free` or garbage. Two correct fixes:
- remember `off = s - sb->buf` when `s` lies inside the buffer, and use `p + off` after the `realloc`; or
- (used here) `malloc` the new block, copy everything, then `free` the old one, so `s` stays valid throughout.

Use `memmove`, not `memcpy`, for the no-growth path, because `TAIL k` copies from the same buffer. The ranges happen not to overlap, but `memmove` costs nothing and documents the aliasing.

**Detach = ownership transfer.** After `sb_detach` the builder forgets the pointer (`buf = NULL`). Otherwise a later `sb_free` would free the caller's string a second time, a double free.

**Complexity.** Appends are amortized O(k) for k appended characters, because doubling copies each byte O(1) times on average. Space is O(len), with `cap < 2 * (len + 1)` once the buffer has grown past 16.

**Common mistakes**
- Calling `strlen(s)` **after** the realloc, which reads the freed old block.
- `sb->buf = realloc(sb->buf, ...)`: a failed realloc leaks the buffer and loses the string.
- `INT_MIN`: `-v` overflows (UB). Negate in `unsigned`, or let `snprintf` do it.
- Capacity off-by-one: forgetting the `+ 1` for `'\0'`, so a 16-character string in a 16-byte buffer overflows.
- `sb_detach` that returns `buf` but does not reset the builder (a double free later).

**Interview follow-ups**
- Add `sb_appendf(sb, fmt, ...)` using `vsnprintf` twice: once to measure, once to write. Why do you need `va_copy`?
- How would you build this on an ECU without a heap? (A caller-provided fixed buffer, a truncation flag, and `snprintf`-style return values.)
- Is comparing `s >= sb->buf && s < sb->buf + sb->cap` well-defined in ISO C when `s` points to a different object? (Strictly no; relational comparison of unrelated pointers is UB. Compare `uintptr_t` values instead, or use the malloc+free approach.)
