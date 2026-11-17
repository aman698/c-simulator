@@@ meta
id: STC-E-09
topic: Structures
difficulty: Easy
type: FIND_THE_BUG
title: Freeze-Frame Snapshots Overflow Their Heap Blocks
tags: embedded, sizeof, malloc, heap-overflow, struct-pointer
@@@ statement_md
When a DTC is set, an ECU stores a **freeze frame**: a snapshot of a few signals at that moment. The program below reads `n` snapshots, stores each in its own heap-allocated `struct Snapshot`, prints them, counts the overheated ones (coolant >= 105 °C) and frees everything.

**Symptom.** With `n = 0` it works. For every `n >= 1` the judge reports a **heap buffer overflow** (Runtime Error), although the printed values look plausible when run without sanitizers.

Find and fix the bug. Do not change the output format.

**Input**
- Line 1: `n`.
- Next `n` lines: `dtc rpm coolant speed gear tag`. `dtc` is 4 hex digits, `tag` is a word of at most 13 characters.

**Output**
- One line per snapshot, in input order: `P<dtc> rpm=<rpm> coolant=<c> speed=<s> gear=<g> tag=<tag>` (`dtc` printed as 4 uppercase hex digits).
- Last line: `snapshots=<n> hot=<count with coolant >= 105>`.

**Example**
```
Input:
2
0301 2500 96 88 4 misfire
0217 4100 112 130 5 overtemp

Output:
P0301 rpm=2500 coolant=96 speed=88 gear=4 tag=misfire
P0217 rpm=4100 coolant=112 speed=130 gear=5 tag=overtemp
snapshots=2 hot=1
```
@@@ constraints_md
- `0 <= n <= 64`
- `0 <= rpm <= 65535`, `-40 <= coolant <= 215`, `0 <= speed <= 255`, `0 <= gear <= 8`.
- Every allocated block must be freed.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct Snapshot {
    uint32_t dtc;
    uint16_t rpm;
    int16_t  coolant_c;
    uint8_t  speed_kph;
    uint8_t  gear;
    char     tag[14];
};

static struct Snapshot *snap_new(uint32_t dtc, int rpm, int coolant, int speed, int gear, const char *tag)
{
    struct Snapshot *s = malloc(sizeof s);
    if (s == NULL)
        return NULL;
    s->dtc = dtc;
    s->rpm = (uint16_t)rpm;
    s->coolant_c = (int16_t)coolant;
    s->speed_kph = (uint8_t)speed;
    s->gear = (uint8_t)gear;
    snprintf(s->tag, sizeof s->tag, "%s", tag);
    return s;
}

int main(void)
{
    struct Snapshot *snaps[64];
    int n, count = 0, hot = 0;

    if (scanf("%d", &n) != 1 || n < 0 || n > 64) return 0;
    for (int i = 0; i < n; i++) {
        unsigned dtc;
        int rpm, coolant, speed, gear;
        char tag[14];
        if (scanf("%x %d %d %d %d %13s", &dtc, &rpm, &coolant, &speed, &gear, tag) != 6) break;
        struct Snapshot *s = snap_new((uint32_t)dtc, rpm, coolant, speed, gear, tag);
        if (s == NULL) break;
        snaps[count++] = s;
    }

    for (int i = 0; i < count; i++) {
        const struct Snapshot *s = snaps[i];
        printf("P%04X rpm=%u coolant=%d speed=%u gear=%u tag=%s\n",
               (unsigned)s->dtc, (unsigned)s->rpm, s->coolant_c,
               (unsigned)s->speed_kph, (unsigned)s->gear, s->tag);
        if (s->coolant_c >= 105) hot++;
    }
    printf("snapshots=%d hot=%d\n", count, hot);

    for (int i = 0; i < count; i++)
        free(snaps[i]);
    return 0;
}
@@@ sample_input
2
0301 2500 96 88 4 misfire
0217 4100 112 130 5 overtemp
@@@ sample_output
P0301 rpm=2500 coolant=96 speed=88 gear=4 tag=misfire
P0217 rpm=4100 coolant=112 speed=130 gear=5 tag=overtemp
snapshots=2 hot=1

@@@ sample_input
0
@@@ sample_output
snapshots=0 hot=0

@@@ hidden_input
1
0118 800 -40 0 0 coldstart
@@@ hidden_output
P0118 rpm=800 coolant=-40 speed=0 gear=0 tag=coldstart
snapshots=1 hot=0

@@@ hidden_input
3
0217 6500 105 255 8 limit
0217 6500 104 255 8 limit
0128 65535 215 1 1 abcdefghijklm
@@@ hidden_output
P0217 rpm=6500 coolant=105 speed=255 gear=8 tag=limit
P0217 rpm=6500 coolant=104 speed=255 gear=8 tag=limit
P0128 rpm=65535 coolant=215 speed=1 gear=1 tag=abcdefghijklm
snapshots=3 hot=2

@@@ hidden_input
2
ABCD 0 0 0 0 x
ffff 1 -1 2 3 y
@@@ hidden_output
PABCD rpm=0 coolant=0 speed=0 gear=0 tag=x
PFFFF rpm=1 coolant=-1 speed=2 gear=3 tag=y
snapshots=2 hot=0

@@@ hidden_input
4
0300 3000 120 100 6 a
0301 3000 120 100 6 b
0302 3000 120 100 6 c
0303 3000 120 100 6 d
@@@ hidden_output
P0300 rpm=3000 coolant=120 speed=100 gear=6 tag=a
P0301 rpm=3000 coolant=120 speed=100 gear=6 tag=b
P0302 rpm=3000 coolant=120 speed=100 gear=6 tag=c
P0303 rpm=3000 coolant=120 speed=100 gear=6 tag=d
snapshots=4 hot=4

@@@ hidden_input
64
0100 0 -40 0 0 t0
0125 997 1 13 1 t1
014A 1994 42 26 2 t2
016F 2991 83 39 3 t3
0194 3988 124 52 4 t4
01B9 4985 165 65 5 t5
01DE 5982 206 78 6 t6
0203 6979 -9 91 7 t7
0228 7976 32 104 8 t8
024D 8973 73 117 0 t9
0272 9970 114 130 1 t10
0297 10967 155 143 2 t11
02BC 11964 196 156 3 t12
02E1 12961 -19 169 4 t13
0306 13958 22 182 5 t14
032B 14955 63 195 6 t15
0350 15952 104 208 7 t16
0375 16949 145 221 8 t17
039A 17946 186 234 0 t18
03BF 18943 -29 247 1 t19
03E4 19940 12 4 2 t20
0409 20937 53 17 3 t21
042E 21934 94 30 4 t22
0453 22931 135 43 5 t23
0478 23928 176 56 6 t24
049D 24925 -39 69 7 t25
04C2 25922 2 82 8 t26
04E7 26919 43 95 0 t27
050C 27916 84 108 1 t28
0531 28913 125 121 2 t29
0556 29910 166 134 3 t30
057B 30907 207 147 4 t31
05A0 31904 -8 160 5 t32
05C5 32901 33 173 6 t33
05EA 33898 74 186 7 t34
060F 34895 115 199 8 t35
0634 35892 156 212 0 t36
0659 36889 197 225 1 t37
067E 37886 -18 238 2 t38
06A3 38883 23 251 3 t39
06C8 39880 64 8 4 t40
06ED 40877 105 21 5 t41
0712 41874 146 34 6 t42
0737 42871 187 47 7 t43
075C 43868 -28 60 8 t44
0781 44865 13 73 0 t45
07A6 45862 54 86 1 t46
07CB 46859 95 99 2 t47
07F0 47856 136 112 3 t48
0815 48853 177 125 4 t49
083A 49850 -38 138 5 t50
085F 50847 3 151 6 t51
0884 51844 44 164 7 t52
08A9 52841 85 177 8 t53
08CE 53838 126 190 0 t54
08F3 54835 167 203 1 t55
0918 55832 208 216 2 t56
093D 56829 -7 229 3 t57
0962 57826 34 242 4 t58
0987 58823 75 255 5 t59
09AC 59820 116 12 6 t60
09D1 60817 157 25 7 t61
09F6 61814 198 38 8 t62
0A1B 62811 -17 51 0 t63
@@@ hidden_output
P0100 rpm=0 coolant=-40 speed=0 gear=0 tag=t0
P0125 rpm=997 coolant=1 speed=13 gear=1 tag=t1
P014A rpm=1994 coolant=42 speed=26 gear=2 tag=t2
P016F rpm=2991 coolant=83 speed=39 gear=3 tag=t3
P0194 rpm=3988 coolant=124 speed=52 gear=4 tag=t4
P01B9 rpm=4985 coolant=165 speed=65 gear=5 tag=t5
P01DE rpm=5982 coolant=206 speed=78 gear=6 tag=t6
P0203 rpm=6979 coolant=-9 speed=91 gear=7 tag=t7
P0228 rpm=7976 coolant=32 speed=104 gear=8 tag=t8
P024D rpm=8973 coolant=73 speed=117 gear=0 tag=t9
P0272 rpm=9970 coolant=114 speed=130 gear=1 tag=t10
P0297 rpm=10967 coolant=155 speed=143 gear=2 tag=t11
P02BC rpm=11964 coolant=196 speed=156 gear=3 tag=t12
P02E1 rpm=12961 coolant=-19 speed=169 gear=4 tag=t13
P0306 rpm=13958 coolant=22 speed=182 gear=5 tag=t14
P032B rpm=14955 coolant=63 speed=195 gear=6 tag=t15
P0350 rpm=15952 coolant=104 speed=208 gear=7 tag=t16
P0375 rpm=16949 coolant=145 speed=221 gear=8 tag=t17
P039A rpm=17946 coolant=186 speed=234 gear=0 tag=t18
P03BF rpm=18943 coolant=-29 speed=247 gear=1 tag=t19
P03E4 rpm=19940 coolant=12 speed=4 gear=2 tag=t20
P0409 rpm=20937 coolant=53 speed=17 gear=3 tag=t21
P042E rpm=21934 coolant=94 speed=30 gear=4 tag=t22
P0453 rpm=22931 coolant=135 speed=43 gear=5 tag=t23
P0478 rpm=23928 coolant=176 speed=56 gear=6 tag=t24
P049D rpm=24925 coolant=-39 speed=69 gear=7 tag=t25
P04C2 rpm=25922 coolant=2 speed=82 gear=8 tag=t26
P04E7 rpm=26919 coolant=43 speed=95 gear=0 tag=t27
P050C rpm=27916 coolant=84 speed=108 gear=1 tag=t28
P0531 rpm=28913 coolant=125 speed=121 gear=2 tag=t29
P0556 rpm=29910 coolant=166 speed=134 gear=3 tag=t30
P057B rpm=30907 coolant=207 speed=147 gear=4 tag=t31
P05A0 rpm=31904 coolant=-8 speed=160 gear=5 tag=t32
P05C5 rpm=32901 coolant=33 speed=173 gear=6 tag=t33
P05EA rpm=33898 coolant=74 speed=186 gear=7 tag=t34
P060F rpm=34895 coolant=115 speed=199 gear=8 tag=t35
P0634 rpm=35892 coolant=156 speed=212 gear=0 tag=t36
P0659 rpm=36889 coolant=197 speed=225 gear=1 tag=t37
P067E rpm=37886 coolant=-18 speed=238 gear=2 tag=t38
P06A3 rpm=38883 coolant=23 speed=251 gear=3 tag=t39
P06C8 rpm=39880 coolant=64 speed=8 gear=4 tag=t40
P06ED rpm=40877 coolant=105 speed=21 gear=5 tag=t41
P0712 rpm=41874 coolant=146 speed=34 gear=6 tag=t42
P0737 rpm=42871 coolant=187 speed=47 gear=7 tag=t43
P075C rpm=43868 coolant=-28 speed=60 gear=8 tag=t44
P0781 rpm=44865 coolant=13 speed=73 gear=0 tag=t45
P07A6 rpm=45862 coolant=54 speed=86 gear=1 tag=t46
P07CB rpm=46859 coolant=95 speed=99 gear=2 tag=t47
P07F0 rpm=47856 coolant=136 speed=112 gear=3 tag=t48
P0815 rpm=48853 coolant=177 speed=125 gear=4 tag=t49
P083A rpm=49850 coolant=-38 speed=138 gear=5 tag=t50
P085F rpm=50847 coolant=3 speed=151 gear=6 tag=t51
P0884 rpm=51844 coolant=44 speed=164 gear=7 tag=t52
P08A9 rpm=52841 coolant=85 speed=177 gear=8 tag=t53
P08CE rpm=53838 coolant=126 speed=190 gear=0 tag=t54
P08F3 rpm=54835 coolant=167 speed=203 gear=1 tag=t55
P0918 rpm=55832 coolant=208 speed=216 gear=2 tag=t56
P093D rpm=56829 coolant=-7 speed=229 gear=3 tag=t57
P0962 rpm=57826 coolant=34 speed=242 gear=4 tag=t58
P0987 rpm=58823 coolant=75 speed=255 gear=5 tag=t59
P09AC rpm=59820 coolant=116 speed=12 gear=6 tag=t60
P09D1 rpm=60817 coolant=157 speed=25 gear=7 tag=t61
P09F6 rpm=61814 coolant=198 speed=38 gear=8 tag=t62
P0A1B rpm=62811 coolant=-17 speed=51 gear=0 tag=t63
snapshots=64 hot=27

@@@ hint
`s` is a `struct Snapshot *`. What is `sizeof s` on a 64-bit machine, and what is `sizeof(struct Snapshot)`?
@@@ hint
Use the idiom `malloc(sizeof *s)`. It always allocates the size of the pointed-to type, even if the type of `s` changes later.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct Snapshot {
    uint32_t dtc;
    uint16_t rpm;
    int16_t  coolant_c;
    uint8_t  speed_kph;
    uint8_t  gear;
    char     tag[14];
};

static struct Snapshot *snap_new(uint32_t dtc, int rpm, int coolant, int speed, int gear, const char *tag)
{
    struct Snapshot *s = malloc(sizeof *s);   /* FIX: sizeof *s (24 bytes), not sizeof s (8-byte pointer) */
    if (s == NULL)
        return NULL;
    s->dtc = dtc;
    s->rpm = (uint16_t)rpm;
    s->coolant_c = (int16_t)coolant;
    s->speed_kph = (uint8_t)speed;
    s->gear = (uint8_t)gear;
    snprintf(s->tag, sizeof s->tag, "%s", tag);
    return s;
}

int main(void)
{
    struct Snapshot *snaps[64];
    int n, count = 0, hot = 0;

    if (scanf("%d", &n) != 1 || n < 0 || n > 64) return 0;
    for (int i = 0; i < n; i++) {
        unsigned dtc;
        int rpm, coolant, speed, gear;
        char tag[14];
        if (scanf("%x %d %d %d %d %13s", &dtc, &rpm, &coolant, &speed, &gear, tag) != 6) break;
        struct Snapshot *s = snap_new((uint32_t)dtc, rpm, coolant, speed, gear, tag);
        if (s == NULL) break;
        snaps[count++] = s;
    }

    for (int i = 0; i < count; i++) {
        const struct Snapshot *s = snaps[i];
        printf("P%04X rpm=%u coolant=%d speed=%u gear=%u tag=%s\n",
               (unsigned)s->dtc, (unsigned)s->rpm, s->coolant_c,
               (unsigned)s->speed_kph, (unsigned)s->gear, s->tag);
        if (s->coolant_c >= 105) hot++;
    }
    printf("snapshots=%d hot=%d\n", count, hot);

    for (int i = 0; i < count; i++)
        free(snaps[i]);
    return 0;
}
@@@ explanation_md
**Bug.** `malloc(sizeof s)` measures the **pointer** `s` (8 bytes on x86-64), not the struct it points to. `struct Snapshot` is 24 bytes:

| offset | member | size |
|---|---|---|
| 0 | `dtc` | 4 |
| 4 | `rpm` | 2 |
| 6 | `coolant_c` | 2 |
| 8 | `speed_kph` | 1 |
| 9 | `gear` | 1 |
| 10 | `tag[14]` | 14 |

Every write from `speed_kph` onward lands past the end of the 8-byte block. AddressSanitizer reports `heap-buffer-overflow` on the first such write. Without a sanitizer, the program overwrites the allocator's metadata or the next snapshot, and it fails much later in an unrelated place.

**Fix.** `malloc(sizeof *s)`. The expression `*s` is not evaluated; `sizeof` only uses its type. The idiom stays correct if someone later changes the type of `s`.

**Complexity.** Time O(n), space O(n).

**Common mistakes**
- `sizeof(struct Snapshot *)` is the same bug written differently.
- "Fixing" it with a hard-coded `malloc(24)`. That breaks silently when a member is added or the code is ported to a target with different alignment.
- Assuming the output proves the code correct. On glibc without sanitizers the 8-byte request gets a 24-byte usable chunk, so this bug can hide for years and then corrupt the heap on another libc or RTOS heap.

**Interview follow-ups**
- What does `sizeof` return for an array parameter `void f(struct Snapshot s[64])` inside `f`?
- Write a `NEW(T)` / `ALLOC_ARRAY(p, n)` macro that cannot get the size wrong and also checks `n * sizeof *p` for overflow.
- On an MCU without a heap, how would you store up to 64 freeze frames instead? (A static array plus a used-bitmap or a free-list pool.)
- Which tools catch this at compile time? (`-Wall` does not catch it; static analyzers such as clang-tidy `bugprone-sizeof-expression` and Coverity's SIZEOF_MISMATCH do.)
