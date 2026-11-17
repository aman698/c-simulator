@@@ meta
id: STR-H-03
topic: Strings
difficulty: Hard
type: FUNCTION
title: Parse a KEY=VALUE; Configuration String into a Fixed Table
tags: embedded, config-parser, key-value, trimming, input-validation, bounded-copy
@@@ statement_md
An ECU receives its calibration over a service interface as one text string, for example
`"CAN_BAUD=500000; NODE=0x7E0 ;MODE= low power"`. Parse it into a fixed table, with **no dynamic memory**:

```c
#define CFG_KEY_MAX 15
#define CFG_VAL_MAX 31
struct cfg_entry {
    char key[CFG_KEY_MAX + 1];
    char value[CFG_VAL_MAX + 1];
};                                   /* defined by the hidden harness */

int cfg_parse(const char *text, struct cfg_entry *out, int max_entries);
```

**Rules**
1. `text` is split at every `';'` into **segments**, numbered from 1. A text without `';'` is one segment.
2. A segment that is empty or contains only spaces/tabs is **skipped**.
3. Otherwise it must contain a `'='`. The **key** is the text before the first `'='`, the **value** everything after it. Both have leading and trailing spaces/tabs removed. Further `'='` characters belong to the value (`X=a=b` -> value `a=b`).
4. A key has **1..15** characters, each `A-Z`, `0-9` or `_`. A value has **0..31** characters and may contain inner spaces.
5. If a key appears again, its **value is replaced** and the entry keeps its original position.
6. A new key when the table already holds `max_entries` entries is an error.
7. On success, return the number of entries, stored in order of first appearance in `out[0..n-1]`, as NUL-terminated strings.
8. On the first invalid segment (rules 3, 4 or 6), return **`-k`**, where `k` is that segment's number. The contents of `out` do not matter then.
9. `text == NULL` is treated as an empty configuration (return `0`). Never modify `text`, and never write outside `out[0..max_entries-1]`.

**How it is tested.** A hidden `main()` calls your function with a table pre-filled with junk bytes and followed by one guard entry. It prints `n=<count>` and one `KEY=[value]` line per entry, or `ERROR segment <k>`. It also reports `OUT OF BOUNDS WRITE`, `TEXT MODIFIED` and `MISSING TERMINATOR` violations.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `max_entries "text"` (`\t` inside the quotes is a tab) or `max_entries NULL`.

**Example**
```
Input:
2
8 "BAUD=115200;NODE_ID=0x1A;MODE=normal"
8 "  BAUD = 500000 ; ;MODE= low power ;"

Output:
n=3
BAUD=[115200]
NODE_ID=[0x1A]
MODE=[normal]
n=2
BAUD=[500000]
MODE=[low power]
```
@@@ constraints_md
- `1 <= q <= 20`, `0 <= max_entries <= 16`, `text` has at most 1000 characters (printable ASCII and tabs; no `"`).
- No `malloc`. O(n * max_entries) time is fine. `strtok` cannot be used on a `const` string, and it would silently merge empty segments anyway.
@@@ starter_code
#include <stddef.h>
#include <string.h>

/* struct cfg_entry, CFG_KEY_MAX and CFG_VAL_MAX are defined by the harness. */
int cfg_parse(const char *text, struct cfg_entry *out, int max_entries)
{
    /* TODO */
    (void)text; (void)out; (void)max_entries;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define CFG_KEY_MAX 15
#define CFG_VAL_MAX 31
struct cfg_entry {
    char key[CFG_KEY_MAX + 1];
    char value[CFG_VAL_MAX + 1];
};

/*USER_CODE*/

static struct cfg_entry table[17];
static char line[1200], text[1100], copy[1100];

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        int max, used = 0;
        if (!fgets(line, sizeof line, stdin)) return 0;
        if (sscanf(line, "%d %n", &max, &used) != 1) return 0;
        const char *arg = NULL;
        const char *p = line + used;
        if (*p == '"') {
            size_t n = 0;
            for (p++; *p && *p != '"'; p++) {
                char c = *p;
                if (c == '\\' && p[1] == 't') { c = '\t'; p++; }
                text[n++] = c;
            }
            text[n] = '\0';
            memcpy(copy, text, n + 1);
            arg = text;
        }
        memset(table, 0xA5, sizeof table);
        int ret = cfg_parse(arg, table, max);
        const unsigned char *g = (const unsigned char *)&table[max];
        for (size_t k = 0; k < sizeof table[0]; k++) {
            if (g[k] != 0xA5) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        if (arg && strcmp(copy, text) != 0) printf("TEXT MODIFIED\n");
        if (ret < 0) {
            printf("ERROR segment %d\n", -ret);
            continue;
        }
        printf("n=%d\n", ret);
        for (int k = 0; k < ret && k < max; k++) {
            if (!memchr(table[k].key, '\0', sizeof table[k].key) ||
                !memchr(table[k].value, '\0', sizeof table[k].value)) {
                printf("MISSING TERMINATOR\n");
                break;
            }
            printf("%s=[%s]\n", table[k].key, table[k].value);
        }
    }
    return 0;
}
@@@ sample_input
2
8 "BAUD=115200;NODE_ID=0x1A;MODE=normal"
8 "  BAUD = 500000 ; ;MODE= low power ;"
@@@ sample_output
n=3
BAUD=[115200]
NODE_ID=[0x1A]
MODE=[normal]
n=2
BAUD=[500000]
MODE=[low power]

@@@ sample_input
4
8 ""
8 "BAUD115200"
8 "A=1;=5"
8 "A=1;b=2"
@@@ sample_output
n=0
ERROR segment 1
ERROR segment 2
ERROR segment 2

@@@ hidden_input
3
8 "BAUD=1;BAUD=2;X=3"
8 "DEBUG="
8 "X=a=b"
@@@ hidden_output
n=2
BAUD=[2]
X=[3]
n=1
DEBUG=[]
n=1
X=[a=b]

@@@ hidden_input
4
8 "ABCDEFGHIJKLMNO=1"
8 "ABCDEFGHIJKLMNOP=1"
8 "V=0123456789012345678901234567890"
8 "V=01234567890123456789012345678901"
@@@ hidden_output
n=1
ABCDEFGHIJKLMNO=[1]
ERROR segment 1
n=1
V=[0123456789012345678901234567890]
ERROR segment 1

@@@ hidden_input
4
2 "A=1;B=2;A=3"
2 "A=1;B=2;C=3"
0 "A=1"
0 " ; "
@@@ hidden_output
n=2
A=[3]
B=[2]
ERROR segment 3
ERROR segment 1
n=0

@@@ hidden_input
5
8 NULL
8 "\tA\t=\t1\t"
8 "A B=1"
8 "A=1;;;B=2"
8 "A=  "
@@@ hidden_output
n=0
n=1
A=[1]
ERROR segment 1
n=2
A=[1]
B=[2]
n=1
A=[]

@@@ hidden_input
3
8 "CAN_BAUD = 500000;LIN_BAUD=19200; NODE=0x7E0 ;DIAG= on ;NODE=0x7E8"
8 "=;"
8 "K=v;  ;  J  "
@@@ hidden_output
n=4
CAN_BAUD=[500000]
LIN_BAUD=[19200]
NODE=[0x7E8]
DIAG=[on]
ERROR segment 1
ERROR segment 3

@@@ hidden_input
2
8 "K1=a;K2=b;K3=c;K4=d;K5=e;K6=f;K7=g;K8=h;K9=i"
16 "K1=a;K2=b;K3=c;K4=d;K5=e;K6=f;K7=g;K8=h;K9=i;K1=z;   ;MSG = hello world ;"
@@@ hidden_output
ERROR segment 9
n=10
K1=[z]
K2=[b]
K3=[c]
K4=[d]
K5=[e]
K6=[f]
K7=[g]
K8=[h]
K9=[i]
MSG=[hello world]

@@@ hint
Work with `(start, end)` pointer pairs instead of copying segments. `strchr(p, ';')` gives the end of a segment, or use `p + strlen(p)` for the last one. Trim by moving `start` forward and `end` backward over blanks, and find the `'='` with `memchr(start, '=', end - start)`.
@@@ hint
Validate the key's length and characters and the value's length **before** writing anything. Then look the key up in `out[0..count-1]` (`strlen(out[j].key) == klen && memcmp(...) == 0`). Reuse that entry, or take a new one only if `count < max_entries`. Copy with `memcpy` plus an explicit `'\0'`. Keep a segment counter that increases for every segment, including skipped ones.
@@@ solution_code
#include <stddef.h>
#include <string.h>

static int is_blank(char c)
{
    return c == ' ' || c == '\t';
}

static int key_char_ok(char c)
{
    return (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
}

int cfg_parse(const char *text, struct cfg_entry *out, int max_entries)
{
    int count = 0, seg = 0;
    const char *p = text;

    if (text == NULL)
        return 0;

    for (;;) {
        const char *end = strchr(p, ';');
        if (end == NULL)
            end = p + strlen(p);
        seg++;

        const char *a = p, *b = end;            /* segment [a, b), trimmed */
        while (a < b && is_blank(*a)) a++;
        while (b > a && is_blank(b[-1])) b--;

        if (a < b) {
            const char *eq = memchr(a, '=', (size_t)(b - a));
            if (eq == NULL)
                return -seg;

            const char *ke = eq;                /* key [a, ke) */
            while (ke > a && is_blank(ke[-1])) ke--;
            size_t klen = (size_t)(ke - a);
            if (klen == 0 || klen > CFG_KEY_MAX)
                return -seg;
            for (size_t i = 0; i < klen; i++)
                if (!key_char_ok(a[i]))
                    return -seg;

            const char *vs = eq + 1;            /* value [vs, b) */
            while (vs < b && is_blank(*vs)) vs++;
            size_t vlen = (size_t)(b - vs);
            if (vlen > CFG_VAL_MAX)
                return -seg;

            int j;
            for (j = 0; j < count; j++)
                if (strlen(out[j].key) == klen && memcmp(out[j].key, a, klen) == 0)
                    break;
            if (j == count) {                   /* new key */
                if (count >= max_entries)
                    return -seg;
                memcpy(out[j].key, a, klen);
                out[j].key[klen] = '\0';
                count++;
            }
            memcpy(out[j].value, vs, vlen);
            out[j].value[vlen] = '\0';
        }

        if (*end == '\0')
            break;
        p = end + 1;
    }
    return count;
}
@@@ explanation_md
**Approach: a single pass over `(start, end)` slices.**
1. Find the segment end with `strchr(p, ';')`, or use the string end.
2. Trim the slice from both sides. If it is empty, skip it (but count it).
3. `memchr` finds the first `'='`. Trim the key slice on the right and the value slice on the left.
4. Validate everything: key length and characters, value length, table capacity. Only then write.
5. Look up the key (linear search, since `max_entries` is small). Update in place, or append.
6. Copy with `memcpy` and an explicit terminator. Every copy is bounded by lengths already checked against `CFG_KEY_MAX` and `CFG_VAL_MAX`.

Because nothing is written into `text`, the parser works on configuration stored in flash or received in a DMA buffer.

**Complexity.** Time O(n * max_entries) in the worst case (one key lookup per segment), O(n) for a table of constant size. Space O(1) beyond the caller's table.

**Common mistakes**
- `strtok(text, ";")`: it modifies the input (often a `const` string or flash), merges empty segments so the segment numbers in error reports are wrong, and is not reentrant.
- `strcpy(out[j].value, v)` or `sscanf("%[^=]=%s")` without width limits: a buffer overflow on a 32-character value. The harness's guard entry catches it.
- Trimming only one side, so `"BAUD = 500000"` produces the key `"BAUD "`.
- Splitting at the **last** `'='` instead of the first, which breaks `X=a=b`.
- Appending duplicates instead of replacing, or writing a new entry before checking `count < max_entries`.

**Interview follow-ups**
- Add typed access: `int cfg_get_u32(const struct cfg_entry *t, int n, const char *key, uint32_t *out)` with decimal and `0x` hex support and range checking.
- How would you protect the stored configuration against corruption in EEPROM? (CRC per record, A/B copies, a version field.)
- The table must be updated atomically: a half-applied configuration must never be used. How do you parse into a shadow table and then swap?
- What changes if values may be quoted (`MSG="a;b"`)? Sketch the state machine.
