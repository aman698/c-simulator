@@@ meta
id: STR-M-10
topic: Strings
difficulty: Medium
type: FIND_THE_BUG
title: ECU Identification Table with Run-On Fields
tags: embedded, strncpy, null-terminator, fixed-width-field, struct, diagnostics
@@@ statement_md
A gateway keeps an identification record for each ECU on the vehicle network: a short name, a part number and a software version. The records use fixed-size `char` fields, and the helper `copy_field()` is supposed to copy text into them **safely**:

- `name` holds at most **7** characters, `part_no` at most **11**. Longer input is **truncated**.
- Every field must always be a valid, NUL-terminated C string.

The table prints fine for most ECUs. But when a name or a part number is long, the printout shows **run-on text**. The gateway called `GATEWAY1` is listed as `GATEWAY15WK9-1234 5WK9-1234 v0.3` instead of `GATEWAY 5WK9-1234 v0.3`. Sometimes garbage characters or a crash follow.

Find and fix the bug.

**Input**
- Line 1: `n`, the number of ECUs.
- Next `n` lines: `name part_no version`, where `version` is a 16-bit number whose high byte is the major and low byte the minor version.

**Output**
- One line per ECU: `<name> <part_no> v<major>.<minor>`, using the stored (truncated) fields.

**Example**
```
Input:
2
BCM A2C12345 258
GATEWAY1 5WK9-1234 3

Output:
BCM A2C12345 v1.2
GATEWAY 5WK9-1234 v0.3
```
@@@ constraints_md
- `1 <= n <= 16`
- `name` and `part_no` have 1..31 characters (no spaces); `0 <= version <= 65535`.
- Keep the struct layout (`char name[8]; char part_no[12]; uint16_t sw_version;`).
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define MAX_ECUS 16

struct ecu_ident {
    char     name[8];       /* at most 7 characters + '\0'  */
    char     part_no[12];   /* at most 11 characters + '\0' */
    uint16_t sw_version;    /* major in the high byte, minor in the low byte */
};

static struct ecu_ident table[MAX_ECUS];

/* Copy src into a fixed-size field of `size` bytes, truncating if needed. */
static void copy_field(char *dst, const char *src, size_t size)
{
    strncpy(dst, src, size);
}

static void ident_set(struct ecu_ident *id, const char *name, const char *part, unsigned ver)
{
    copy_field(id->name, name, sizeof id->name);
    copy_field(id->part_no, part, sizeof id->part_no);
    id->sw_version = (uint16_t)ver;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 0 || n > MAX_ECUS) return 0;

    for (int i = 0; i < n; i++) {
        char name[32], part[32];
        unsigned ver;
        if (scanf("%31s %31s %u", name, part, &ver) != 3) return 0;
        ident_set(&table[i], name, part, ver);
    }
    for (int i = 0; i < n; i++)
        printf("%s %s v%u.%u\n", table[i].name, table[i].part_no,
               (unsigned)(table[i].sw_version >> 8), (unsigned)(table[i].sw_version & 0xFFu));
    return 0;
}
@@@ sample_input
2
BCM A2C12345 258
GATEWAY1 5WK9-1234 3
@@@ sample_output
BCM A2C12345 v1.2
GATEWAY 5WK9-1234 v0.3

@@@ sample_input
1
EPS 4G0909144 1024
@@@ sample_output
EPS 4G0909144 v4.0

@@@ hidden_input
3
ABS 10.0206-0001 772
SRS 610-12345-A0 513
TCM 0AM927769D 65535
@@@ hidden_output
ABS 10.0206-000 v3.4
SRS 610-12345-A v2.1
TCM 0AM927769D v255.255

@@@ hidden_input
2
CLUSTER 1K8920870 0
GATEWAY 3Q0907530A 257
@@@ hidden_output
CLUSTER 1K8920870 v0.0
GATEWAY 3Q0907530A v1.1

@@@ hidden_input
2
INSTRUMENT_CLUSTER_HIGHLINE 5G1920740B 1281
RADAR_FRONT_LEFT 2Q0907561CXYZ12345 4660
@@@ hidden_output
INSTRUM 5G1920740B v5.1
RADAR_F 2Q0907561CX v18.52
@@@ hidden_input
1
X Y 1
@@@ hidden_output
X Y v0.1

@@@ hidden_input
4
ECU_0001 PN-0000001 1
ECU_0002 PN-0000002 2
ECU_0003 PN-00000003 3
ECU_0004 PN-000000004 4
@@@ hidden_output
ECU_000 PN-0000001 v0.1
ECU_000 PN-0000002 v0.2
ECU_000 PN-00000003 v0.3
ECU_000 PN-00000000 v0.4

@@@ hint
Read the C standard's description of `strncpy(dst, src, n)` carefully. What does it write when `strlen(src) >= n`? Is there a `'\0'` among the bytes it writes?
@@@ hint
`strncpy` pads with zeros when `src` is short, but does **not** terminate when `src` fills the field. Copy at most `size - 1` characters and write `dst[size - 1] = '\0'` yourself (or use `snprintf(dst, size, "%s", src)`).
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define MAX_ECUS 16

struct ecu_ident {
    char     name[8];       /* at most 7 characters + '\0'  */
    char     part_no[12];   /* at most 11 characters + '\0' */
    uint16_t sw_version;    /* major in the high byte, minor in the low byte */
};

static struct ecu_ident table[MAX_ECUS];

/* Copy src into a fixed-size field of `size` bytes, truncating if needed. */
static void copy_field(char *dst, const char *src, size_t size)
{
    strncpy(dst, src, size - 1);
    dst[size - 1] = '\0';   /* FIX: strncpy leaves no terminator when src fills the field */
}

static void ident_set(struct ecu_ident *id, const char *name, const char *part, unsigned ver)
{
    copy_field(id->name, name, sizeof id->name);
    copy_field(id->part_no, part, sizeof id->part_no);
    id->sw_version = (uint16_t)ver;
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 0 || n > MAX_ECUS) return 0;

    for (int i = 0; i < n; i++) {
        char name[32], part[32];
        unsigned ver;
        if (scanf("%31s %31s %u", name, part, &ver) != 3) return 0;
        ident_set(&table[i], name, part, ver);
    }
    for (int i = 0; i < n; i++)
        printf("%s %s v%u.%u\n", table[i].name, table[i].part_no,
               (unsigned)(table[i].sw_version >> 8), (unsigned)(table[i].sw_version & 0xFFu));
    return 0;
}
@@@ explanation_md
**Bug.** `strncpy(dst, src, n)` copies **at most `n`** characters. If `src` is shorter, it pads the rest with `'\0'`. If `strlen(src) >= n`, it writes exactly `n` characters and **no terminator** (C11 7.24.2.4). With `n == sizeof field`, a long name fills all 8 bytes of `name[]`. `printf("%s")` then runs straight into `part_no[]`, which follows it in memory, and prints `GATEWAY15WK9-1234`. A full 12-byte `part_no` runs into `sw_version` and the next record, which is where the garbage and the occasional crash come from.

**Fix.** Copy at most `size - 1` characters and always terminate:

```c
strncpy(dst, src, size - 1);
dst[size - 1] = '\0';
```

`snprintf(dst, size, "%s", src)` is equivalent and also always terminates, but it is heavier on a small MCU.

**Complexity.** O(size) per field: `strncpy` always writes the whole field, including zero padding. Space O(1).

**Common mistakes**
- Believing `strncpy` is "the safe `strcpy`". It was designed for fixed-width, zero-padded records (old Unix directory entries), not for C strings.
- Fixing only `name` and leaving `part_no` with the same bug. The hidden tests use 12-character part numbers too.
- Using `strncat(dst, src, size)` instead. It always terminates, but `n` there means "characters to append", so `size` overflows the field by one.
- Relying on the zero-initialised `static` table to provide terminators. That only works until the first full-length string.

**Interview follow-ups**
- UDS DIDs such as `0xF187` (spare part number) and `0xF190` (VIN) are fixed-length and **not** NUL-terminated on the wire. How do you store and print such fields safely? (Use a length, `printf("%.*s", len, field)`, or an extra byte for the terminator.)
- Write a `strlcpy`-style function that returns the length it *tried* to create, so the caller can detect truncation.
- Why does `-Wstringop-truncation` warn on `strncpy(d, s, sizeof d)` but not here, where the size is passed through a helper parameter?
