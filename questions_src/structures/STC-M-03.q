@@@ meta
id: STC-M-03
topic: Structures
difficulty: Medium
type: CODE
title: Reorder Struct Members to Minimize Padding
tags: embedded, struct-padding, alignment, sizeof, packed, memory-optimization
@@@ statement_md
Your ECU stores 2000 copies of a configuration record in RAM, so every padding byte matters. Write a tool that, given the member list of a struct, computes:

1. `sizeof` with the members in **declared** order (natural alignment, x86-64 System V),
2. `sizeof` after **reordering** the members to minimize size,
3. the size with `__attribute__((packed))` (no padding at all),

and prints the reordered member list.

**Type table** (size / alignment in bytes):

| types | size | align |
|---|---|---|
| `char`, `bool`, `int8_t`, `uint8_t` | 1 | 1 |
| `int16_t`, `uint16_t` | 2 | 2 |
| `int32_t`, `uint32_t`, `float` | 4 | 4 |
| `int64_t`, `uint64_t`, `double`, `ptr` | 8 | 8 |

A member may be an array, `name[count]`. Its size is `count * size`, and its alignment is the element alignment.

**Layout rules.** Each member is placed at the next offset that is a multiple of its alignment. The struct size is the end of the last member rounded up to a multiple of the **largest** member alignment. `padding = size - sum of member sizes`.

**Reordering rule.** Sort the members by alignment, **largest first**. Members with equal alignment keep their declared order (stable). This order always reaches the minimum possible size.

**Input**
- Line 1: `n`.
- Next `n` lines: `type name` or `type name[count]`.

**Output**
```
declared: size=<S1> padding=<P1>
reordered: size=<S2> padding=<P2>
packed: size=<S3>
order: <name1> <name2> ...
```
Names are printed without the `[count]` suffix.

**Example**
```
Input:
5
char tag
int32_t value
char flag
double scale
uint16_t crc

Output:
declared: size=32 padding=16
reordered: size=16 padding=0
packed: size=16
order: scale value crc tag flag
```
@@@ constraints_md
- `1 <= n <= 32`
- Names are unique, at most 15 characters, `[A-Za-z_][A-Za-z0-9_]*`.
- `1 <= count <= 64` for arrays.
- Only the types in the table appear.
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct Member {
    char name[48];
    int  size;     /* total bytes (count * element size) */
    int  align;    /* element alignment                  */
};

static const struct { const char *type; int size; } TYPES[] = {
    { "char", 1 }, { "bool", 1 }, { "int8_t", 1 }, { "uint8_t", 1 },
    { "int16_t", 2 }, { "uint16_t", 2 },
    { "int32_t", 4 }, { "uint32_t", 4 }, { "float", 4 },
    { "int64_t", 8 }, { "uint64_t", 8 }, { "double", 8 }, { "ptr", 8 },
};

static struct Member m[32];

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 1 || n > 32) return 0;
    for (int i = 0; i < n; i++) {
        char type[16], decl[48];
        if (scanf("%15s %47s", type, decl) != 2) return 0;
        int elem = 0;
        for (size_t t = 0; t < sizeof TYPES / sizeof TYPES[0]; t++)
            if (strcmp(type, TYPES[t].type) == 0) elem = TYPES[t].size;
        int count = 1;
        char *br = strchr(decl, '[');
        if (br) { count = atoi(br + 1); *br = '\0'; }
        snprintf(m[i].name, sizeof m[i].name, "%s", decl);
        m[i].size = elem * count;
        m[i].align = elem;
    }

    /* TODO: declared layout, reordered layout, packed size, order */
    return 0;
}
@@@ sample_input
5
char tag
int32_t value
char flag
double scale
uint16_t crc
@@@ sample_output
declared: size=32 padding=16
reordered: size=16 padding=0
packed: size=16
order: scale value crc tag flag

@@@ sample_input
1
char c
@@@ sample_output
declared: size=1 padding=0
reordered: size=1 padding=0
packed: size=1
order: c

@@@ hidden_input
3
uint8_t data[8]
uint32_t id
uint8_t dlc
@@@ hidden_output
declared: size=16 padding=3
reordered: size=16 padding=3
packed: size=13
order: id data dlc

@@@ hidden_input
5
char a
double b
char c
double d
char e
@@@ hidden_output
declared: size=40 padding=21
reordered: size=24 padding=5
packed: size=19
order: b d a c e

@@@ hidden_input
4
bool valid
ptr next
int16_t samples[3]
float gain
@@@ hidden_output
declared: size=32 padding=13
reordered: size=24 padding=5
packed: size=19
order: next gain samples valid

@@@ hidden_input
3
uint16_t a
uint16_t b
uint16_t c
@@@ hidden_output
declared: size=6 padding=0
reordered: size=6 padding=0
packed: size=6
order: a b c

@@@ hidden_input
3
double x
int32_t y
char z
@@@ hidden_output
declared: size=16 padding=3
reordered: size=16 padding=3
packed: size=13
order: x y z

@@@ hidden_input
3
char name[17]
uint32_t crc
uint8_t ver
@@@ hidden_output
declared: size=28 padding=6
reordered: size=24 padding=2
packed: size=22
order: crc name ver

@@@ hidden_input
6
uint8_t flags
uint64_t vin_hash
int16_t temp
uint8_t mode
int32_t odo
uint8_t gear
@@@ hidden_output
declared: size=32 padding=15
reordered: size=24 padding=7
packed: size=17
order: vin_hash odo temp flags mode gear

@@@ hidden_input
32
char m0
uint16_t m1
uint64_t m2
int8_t m3[5]
uint32_t m4
ptr m5
int16_t m6
int64_t m7[2]
bool m8
int32_t m9
double m10
uint8_t m11[6]
float m12
char m13
uint16_t m14
uint64_t m15[3]
int8_t m16
uint32_t m17
ptr m18
int16_t m19[7]
int64_t m20
bool m21
int32_t m22
double m23[4]
uint8_t m24
float m25
char m26
uint16_t m27[8]
uint64_t m28
int8_t m29
uint32_t m30
ptr m31[5]
@@@ hidden_output
declared: size=288 padding=45
reordered: size=248 padding=5
packed: size=243
order: m2 m5 m7 m10 m15 m18 m20 m23 m28 m31 m4 m9 m12 m17 m22 m25 m30 m1 m6 m14 m19 m27 m0 m3 m8 m11 m13 m16 m21 m24 m26 m29

@@@ hint
Write one function `int layout(const struct Member *v, const int *order, int n)`: keep `off`, align it with `off = (off + a - 1) / a * a`, add the size, and track the largest alignment. Round the final `off` up to that alignment.
@@@ hint
For the reordered layout, build an index array sorted by alignment descending with a **stable** method: an insertion sort, or four passes for alignment 8, 4, 2, 1. `qsort` is not stable. With no gaps between members, only tail padding can remain.
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct Member {
    char name[48];
    int  size;     /* total bytes (count * element size) */
    int  align;    /* element alignment                  */
};

static const struct { const char *type; int size; } TYPES[] = {
    { "char", 1 }, { "bool", 1 }, { "int8_t", 1 }, { "uint8_t", 1 },
    { "int16_t", 2 }, { "uint16_t", 2 },
    { "int32_t", 4 }, { "uint32_t", 4 }, { "float", 4 },
    { "int64_t", 8 }, { "uint64_t", 8 }, { "double", 8 }, { "ptr", 8 },
};

static struct Member m[32];

static int round_up(int x, int a) { return (x + a - 1) / a * a; }

/* sizeof a struct whose members appear in the order given by idx[] */
static int layout(const int *idx, int n)
{
    int off = 0, max_align = 1;
    for (int k = 0; k < n; k++) {
        const struct Member *p = &m[idx[k]];
        off = round_up(off, p->align);     /* internal padding before the member */
        off += p->size;
        if (p->align > max_align) max_align = p->align;
    }
    return round_up(off, max_align);       /* tail padding: arrays of the struct stay aligned */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 1 || n > 32) return 0;
    for (int i = 0; i < n; i++) {
        char type[16], decl[48];
        if (scanf("%15s %47s", type, decl) != 2) return 0;
        int elem = 0;
        for (size_t t = 0; t < sizeof TYPES / sizeof TYPES[0]; t++)
            if (strcmp(type, TYPES[t].type) == 0) elem = TYPES[t].size;
        int count = 1;
        char *br = strchr(decl, '[');
        if (br) { count = atoi(br + 1); *br = '\0'; }
        snprintf(m[i].name, sizeof m[i].name, "%s", decl);
        m[i].size = elem * count;
        m[i].align = elem;
    }

    int declared[32], sorted[32], k = 0, sum = 0;
    for (int i = 0; i < n; i++) {
        declared[i] = i;
        sum += m[i].size;
    }
    /* stable "sort" by alignment, largest first: one pass per alignment class */
    for (int a = 8; a >= 1; a /= 2)
        for (int i = 0; i < n; i++)
            if (m[i].align == a) sorted[k++] = i;

    int s1 = layout(declared, n);
    int s2 = layout(sorted, n);
    printf("declared: size=%d padding=%d\n", s1, s1 - sum);
    printf("reordered: size=%d padding=%d\n", s2, s2 - sum);
    printf("packed: size=%d\n", sum);
    printf("order:");
    for (int i = 0; i < n; i++) printf(" %s", m[sorted[i]].name);
    printf("\n");
    return 0;
}
@@@ explanation_md
**Approach.** Simulate what the compiler does:
```
off = 0
for each member:  off = round_up(off, align); off += size
size = round_up(off, max_align)
```
**Why largest-alignment-first is optimal.** Every size is a multiple of its own alignment, and all alignments are powers of two. After a block of 8-aligned members, `off` is a multiple of 8, so a 4-aligned member fits with no gap. The same holds going down to 2 and 1. There is no internal padding at all, only tail padding up to `max_align`. No order can do better, because any size must be at least the sum and a multiple of `max_align`.

```
declared:  tag . . . value value value value flag . . . . . . . scale x8 crc crc . . . . . .   = 32
reordered: scale x8 | value x4 | crc x2 | tag | flag                                           = 16
```

**Complexity.** Time O(n) (4 passes over at most 32 members), space O(n).

**Common mistakes**
- Forgetting **tail padding** (CAN frame: 13 bytes of data, but `sizeof` is 16).
- Rounding the final size to the alignment of the *last* member instead of the *largest*.
- Using an array's total size as its alignment (`char name[17]` is 1-aligned, not 17- or 16-aligned).
- Sorting with `qsort`, which is not stable, so equal-alignment members come out in a platform-dependent order.
- Thinking `packed` is free. Members become misaligned, so every access on a Cortex-M0 is several byte loads, and taking `&member` creates a misaligned pointer.

**Interview follow-ups**
- When should you **not** reorder? (Wire or NVM formats and register maps have a fixed layout, and grouping hot fields in one cache line can matter more than size.)
- How do you lock the layout at compile time? (`_Static_assert(sizeof(struct X) == 24, "...")` and `_Static_assert(offsetof(struct X, crc) == 20, "...")`.)
- What changes on a 32-bit ARM target (AAPCS), where `double` and `int64_t` are still 8-aligned but pointers are 4 bytes?
- `-Wpadded` warns about every padding byte. Would you enable it in a production build?
