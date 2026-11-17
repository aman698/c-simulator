@@@ meta
id: STR-H-04
topic: Strings
difficulty: Hard
type: FUNCTION
title: Overflow-Safe DTC Report Formatting with snprintf
tags: embedded, snprintf, vsnprintf, truncation, buffer-overflow, diagnostics, misra
@@@ statement_md
A diagnostic task formats the stored trouble codes of an ECU into one text line for the service log. The log buffer has a fixed size and may be too small, so the formatter must **never overflow**, and it must tell the caller how long the full line *would* have been. This is the same contract as `snprintf`:

```c
struct dtc {
    char     sys;      /* 'P', 'C', 'B' or 'U'            */
    uint16_t code;     /* printed as 4 uppercase hex digits */
    uint8_t  status;   /* printed as 2 uppercase hex digits */
};                                  /* defined by the hidden harness */

int format_dtc_line(char *buf, size_t size, const char *ecu,
                    const struct dtc *list, int n);
```

**Full line format:** `<ecu>: <n> DTC`, followed by ` <sys><code>/<status>` for every entry, for example
`BCM: 2 DTC P0301/2F U0100/09`.

**Contract**
- Return the length of the **full** line (not counting `'\0'`), even when it did not fit. A return value `>= size` therefore means the line was truncated.
- Never write at or beyond `buf[size]`. If `size > 0`, `buf` must always end up NUL-terminated and hold the **first `size - 1` characters** of the full line.
- `size == 0` is legal (`buf` may be `NULL`). Nothing is written, and the full length is returned, so the caller can size a buffer.
- Return `-1` if `ecu == NULL`, `n < 0`, `list == NULL` while `n > 0`, or `buf == NULL` while `size > 0`.

**How it is tested.** A hidden `main()` passes a buffer of exactly `size` bytes, pre-filled with `#` and surrounded by guard bytes (`NULL` when `size == 0`). It prints `ret=<r> [<buf>]`, or only `ret=<r>` when `size == 0` or `r < 0`. It reports `OUT OF BOUNDS WRITE` or `MISSING TERMINATOR` violations.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `ecu size n` followed by `n` triples `sys code status` (code and status in hex). An `ecu` of `NULL` passes a null pointer.

**Example**
```
Input:
2
BCM 64 2 P 0301 2F U 0100 09
BCM 16 2 P 0301 2F U 0100 09

Output:
ret=28 [BCM: 2 DTC P0301/2F U0100/09]
ret=28 [BCM: 2 DTC P030]
```
@@@ constraints_md
- `1 <= q <= 20`, `0 <= size <= 2048`, `-1 <= n <= 16`, `ecu` has at most 40 characters.
- `snprintf`/`vsnprintf` are allowed. `sprintf`, `vsprintf`, `strcpy` and `strcat` are rejected at compile time.
- O(total length) time, O(1) extra space (no temporary line buffer).
@@@ starter_code
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

/* struct dtc is defined by the harness. */
int format_dtc_line(char *buf, size_t size, const char *ecu,
                    const struct dtc *list, int n)
{
    /* TODO */
    (void)buf; (void)size; (void)ecu; (void)list; (void)n;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

struct dtc {
    char     sys;
    uint16_t code;
    uint8_t  status;
};

#define sprintf(...) sprintf_is_not_allowed_in_this_exercise
#define vsprintf(...) vsprintf_is_not_allowed_in_this_exercise
#define strcpy(d, s) strcpy_is_not_allowed_in_this_exercise
#define strcat(d, s) strcat_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef sprintf
#undef vsprintf
#undef strcpy
#undef strcat

#define GUARD 16
#define CANARY 0x5A
#define MAXSZ 2048

static unsigned char arena[GUARD + MAXSZ + GUARD];
static char line[1024];

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        char ecu[64];
        int size, n, used = 0;
        struct dtc list[16];
        if (!fgets(line, sizeof line, stdin)) return 0;
        if (sscanf(line, "%63s %d %d%n", ecu, &size, &n, &used) != 3) return 0;
        const char *p = line + used;
        for (int k = 0; k < n && k < 16; k++) {
            char s;
            unsigned code, st;
            int u = 0;
            if (sscanf(p, " %c %x %x%n", &s, &code, &st, &u) != 3) return 0;
            p += u;
            list[k].sys = s;
            list[k].code = (uint16_t)code;
            list[k].status = (uint8_t)st;
        }
        memset(arena, CANARY, sizeof arena);
        char *buf = size > 0 ? (char *)arena + GUARD : NULL;
        if (buf) memset(buf, '#', (size_t)size);
        int ret = format_dtc_line(buf, (size_t)size, strcmp(ecu, "NULL") == 0 ? NULL : ecu, list, n);
        for (int k = 0; k < GUARD; k++) {
            if (arena[k] != CANARY || arena[GUARD + size + k] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        if (ret < 0 || size == 0) {
            printf("ret=%d\n", ret);
            continue;
        }
        if (!memchr(buf, '\0', (size_t)size)) {
            printf("ret=%d MISSING TERMINATOR\n", ret);
            continue;
        }
        printf("ret=%d [%s]\n", ret, buf);
    }
    return 0;
}
@@@ sample_input
2
BCM 64 2 P 0301 2F U 0100 09
BCM 16 2 P 0301 2F U 0100 09
@@@ sample_output
ret=28 [BCM: 2 DTC P0301/2F U0100/09]
ret=28 [BCM: 2 DTC P030]

@@@ sample_input
2
BCM 0 2 P 0301 2F U 0100 09
BCM 1 2 P 0301 2F U 0100 09
@@@ sample_output
ret=28
ret=28 []

@@@ hidden_input
3
ECM 32 0
BCM 28 2 P 0301 2F U 0100 09
BCM 29 2 P 0301 2F U 0100 09
@@@ hidden_output
ret=10 [ECM: 0 DTC]
ret=28 [BCM: 2 DTC P0301/2F U0100/0]
ret=28 [BCM: 2 DTC P0301/2F U0100/09]

@@@ hidden_input
2
BCM 11 2 P 0301 2F U 0100 09
BCM 12 2 P 0301 2F U 0100 09
@@@ hidden_output
ret=28 [BCM: 2 DTC]
ret=28 [BCM: 2 DTC ]

@@@ hidden_input
2
GW 40 16 P 0A0B 05 C 1B1C 2A B 2C2D 4F U 3D3E 74 P 4E4F 99 C 5F60 BE B 7071 E3 U 8182 08 P 9293 2D C A3A4 52 B B4B5 77 U C5C6 9C P D6D7 C1 C E7E8 E6 B F8F9 0B U 0A0A 30
GW 2048 16 P 0A0B 05 C 1B1C 2A B 2C2D 4F U 3D3E 74 P 4E4F 99 C 5F60 BE B 7071 E3 U 8182 08 P 9293 2D C A3A4 52 B B4B5 77 U C5C6 9C P D6D7 C1 C E7E8 E6 B F8F9 0B U 0A0A 30
@@@ hidden_output
ret=154 [GW: 16 DTC P0A0B/05 C1B1C/2A B2C2D/4F U]
ret=154 [GW: 16 DTC P0A0B/05 C1B1C/2A B2C2D/4F U3D3E/74 P4E4F/99 C5F60/BE B7071/E3 U8182/08 P9293/2D CA3A4/52 BB4B5/77 UC5C6/9C PD6D7/C1 CE7E8/E6 BF8F9/0B U0A0A/30]

@@@ hidden_input
3
NULL 32 1 P 0301 2F
ECM 32 -1
ABS 64 2 C FFFF FF B 0000 00
@@@ hidden_output
ret=-1
ret=-1
ret=28 [ABS: 2 DTC CFFFF/FF B0000/00]

@@@ hidden_input
2
INSTRUMENT_CLUSTER_HIGHLINE_FRONT_01 20 2 P 0301 2F U 0100 09
GW 0 16 P 0A0B 05 C 1B1C 2A B 2C2D 4F U 3D3E 74 P 4E4F 99 C 5F60 BE B 7071 E3 U 8182 08 P 9293 2D C A3A4 52 B B4B5 77 U C5C6 9C P D6D7 C1 C E7E8 E6 B F8F9 0B U 0A0A 30
@@@ hidden_output
ret=61 [INSTRUMENT_CLUSTER_]
ret=154

@@@ hint
Keep a running `size_t total` (the would-be length) and append each piece with `snprintf(buf + total, size - total, ...)`, adding its return value to `total`. Now ask yourself: what happens to `size - total` once a piece has been truncated and `total > size`?
@@@ hint
Once `total >= size` there is no room left: call `snprintf(NULL, 0, ...)` just to measure the piece. A tiny helper `static int append(char *buf, size_t size, size_t *total, const char *fmt, ...)` built on `vsnprintf` keeps that logic in one place. Check every return value for `< 0`.
@@@ solution_code
#include <stdio.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

/* Append formatted text at offset *total; *total tracks the would-be length. */
static int append(char *buf, size_t size, size_t *total, const char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    if (*total < size)
        r = vsnprintf(buf + *total, size - *total, fmt, ap);  /* writes, truncates, terminates */
    else
        r = vsnprintf(NULL, 0, fmt, ap);                       /* full: only measure */
    va_end(ap);
    if (r < 0)
        return -1;
    *total += (size_t)r;
    return 0;
}

int format_dtc_line(char *buf, size_t size, const char *ecu,
                    const struct dtc *list, int n)
{
    size_t total = 0;

    if (ecu == NULL || n < 0 || (list == NULL && n > 0) || (buf == NULL && size > 0))
        return -1;
    if (size > 0)
        buf[0] = '\0';

    if (append(buf, size, &total, "%s: %d DTC", ecu, n) != 0)
        return -1;
    for (int i = 0; i < n; i++)
        if (append(buf, size, &total, " %c%04X/%02X", list[i].sys,
                   (unsigned int)list[i].code, (unsigned int)list[i].status) != 0)
            return -1;
    return (int)total;
}
@@@ explanation_md
**Approach.** `snprintf(dst, room, ...)` has exactly the semantics we need for one piece: it writes at most `room - 1` characters plus a `'\0'`, and returns the length the piece *would* have had. The work is in chaining several pieces:

- Keep `total` as the would-be length so far. That is also the offset of the next piece in an unlimited buffer.
- While `total < size`, write at `buf + total` with room `size - total`. A truncated piece still terminates the buffer at `buf[size - 1]`.
- Once `total >= size`, **do not** compute `size - total`. With `size_t` it wraps to a huge number, and the next `snprintf` overflows the buffer. Measure with `vsnprintf(NULL, 0, ...)` instead.
- Return `total`, so callers can test `ret >= size` for truncation, or call with `size == 0` first to size a buffer exactly.

**Complexity.** O(L) time, where L is the full line length (pieces past the end are still formatted, just not stored). O(1) extra space.

**Common mistakes**
- `pos += snprintf(buf + pos, size - pos, ...)` in a loop. After the first truncation, `pos > size`, `size - pos` underflows to about 2^64, and the next call writes past the buffer. This is a real, frequently reported CVE pattern, and the guard bytes catch it.
- Returning the number of characters actually **stored** instead of the would-be length, which hides truncation from the caller.
- Using `strcat`/`sprintf` with a "big enough" buffer. A 16-DTC report from a long ECU name breaks any such assumption.
- Passing `list[i].code` (a `uint16_t`, promoted to `int`) to `%X`. Cast to `unsigned int` so the argument type matches the conversion exactly.
- Forgetting the `size == 0` / `buf == NULL` case, or writing `buf[0] = '\0'` when `size == 0`.

**Interview follow-ups**
- MISRA C:2012 Rule 21.6 bans `<stdio.h>` in production code. How would you implement a minimal bounded formatter (`%s`, `%d`, `%0NX`) yourself?
- Why is `vsnprintf` with the same `va_list` used twice undefined, and when do you need `va_copy`?
- How would you make the log line **atomic** for a UART DMA transfer: format into a local buffer first, or reserve space in the ring buffer and format in place?
- `snprintf` on newlib-nano pulls in about 10-20 KB of flash. Which formatting features would you drop on a 64 KB MCU?
