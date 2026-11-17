@@@ meta
id: STC-M-06
topic: Structures
difficulty: Medium
type: FUNCTION
title: Sort an RTOS Task Table with a Multi-Key Comparator
tags: embedded, array-of-structs, qsort, comparator, rtos, scheduling
@@@ statement_md
At start-up, an RTOS configuration tool sorts the task table to assign priorities. Write the `qsort` comparator

```c
struct Task {
    char     name[16];
    uint8_t  prio;        /* higher value = more important */
    uint16_t period_ms;
    uint32_t wcet_us;     /* worst-case execution time      */
};

int task_cmp(const void *a, const void *b);
```

that orders tasks by:
1. `prio` **descending**,
2. then `period_ms` **ascending** (rate-monotonic: faster tasks first),
3. then `wcet_us` **descending**,
4. then `name` **ascending** (`strcmp` order). Names are unique, so the order is total.

`task_cmp` must return a negative value, zero or a positive value, and it must be **consistent**: `cmp(a, b)` and `cmp(b, a)` have opposite signs, and `cmp(a, a) == 0`. `struct Task` is already defined by the judge.

**How it is tested.** The hidden harness reads the table, checks the comparator on every pair of tasks for consistency (printing `INCONSISTENT COMPARATOR` on failure), then calls `qsort(tasks, n, sizeof tasks[0], task_cmp)` and prints the result.

**Input**
- Line 1: `n`.
- Next `n` lines: `name prio period_ms wcet_us`.

**Output**
- One line per task in sorted order: `name prio period_ms wcet_us`, or `EMPTY` if `n = 0`.

**Example**
```
Input:
5
CanRx 5 10 300
Diag 1 100 2000
Brake 7 5 150
Logger 1 100 2000
Lights 5 10 800

Output:
Brake 7 5 150
Lights 5 10 800
CanRx 5 10 300
Diag 1 100 2000
Logger 1 100 2000
```
@@@ constraints_md
- `0 <= n <= 200`
- `0 <= prio <= 255`, `1 <= period_ms <= 65535`, `0 <= wcet_us <= 4294967295`.
- Names: 1..15 printable characters without spaces, unique.
@@@ starter_code
#include <stdint.h>
#include <string.h>

/* Already defined by the judge:
 *
 * struct Task { char name[16]; uint8_t prio; uint16_t period_ms; uint32_t wcet_us; };
 */

int task_cmp(const void *a, const void *b)
{
    const struct Task *x = a;
    const struct Task *y = b;
    /* TODO: prio desc, period asc, wcet desc, name asc */
    (void)x;
    (void)y;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct Task {
    char     name[16];
    uint8_t  prio;
    uint16_t period_ms;
    uint32_t wcet_us;
};

/*USER_CODE*/

static int sgn(int v) { return (v > 0) - (v < 0); }

static struct Task tasks[200];

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 0 || n > 200) return 0;
    for (int i = 0; i < n; i++) {
        unsigned prio, period, wcet;
        memset(&tasks[i], 0, sizeof tasks[i]);
        if (scanf("%15s %u %u %u", tasks[i].name, &prio, &period, &wcet) != 4) return 0;
        tasks[i].prio = (uint8_t)prio;
        tasks[i].period_ms = (uint16_t)period;
        tasks[i].wcet_us = (uint32_t)wcet;
    }
    if (n == 0) {
        printf("EMPTY\n");
        return 0;
    }
    for (int i = 0; i < n; i++) {
        if (task_cmp(&tasks[i], &tasks[i]) != 0) {
            printf("INCONSISTENT COMPARATOR\n");
            return 0;
        }
        for (int j = i + 1; j < n; j++) {
            int ab = sgn(task_cmp(&tasks[i], &tasks[j]));
            int ba = sgn(task_cmp(&tasks[j], &tasks[i]));
            if (ab != -ba || ab == 0) {
                printf("INCONSISTENT COMPARATOR\n");
                return 0;
            }
        }
    }
    qsort(tasks, (size_t)n, sizeof tasks[0], task_cmp);
    for (int i = 0; i < n; i++)
        printf("%s %u %u %u\n", tasks[i].name, (unsigned)tasks[i].prio,
               (unsigned)tasks[i].period_ms, (unsigned)tasks[i].wcet_us);
    return 0;
}
@@@ sample_input
5
CanRx 5 10 300
Diag 1 100 2000
Brake 7 5 150
Logger 1 100 2000
Lights 5 10 800
@@@ sample_output
Brake 7 5 150
Lights 5 10 800
CanRx 5 10 300
Diag 1 100 2000
Logger 1 100 2000

@@@ sample_input
1
Idle 0 65535 0
@@@ sample_output
Idle 0 65535 0

@@@ hidden_input
0
@@@ hidden_output
EMPTY

@@@ hidden_input
3
A 3 20 4000000000
B 3 20 1
C 3 20 2147483648
@@@ hidden_output
A 3 20 4000000000
C 3 20 2147483648
B 3 20 1

@@@ hidden_input
4
Low 0 1 10
High 255 65535 10
Mid 128 1 10
Mid2 128 65535 10
@@@ hidden_output
High 255 65535 10
Mid 128 1 10
Mid2 128 65535 10
Low 0 1 10

@@@ hidden_input
4
abc 1 1 1
ab 1 1 1
ABC 1 1 1
b 1 1 1
@@@ hidden_output
ABC 1 1 1
ab 1 1 1
abc 1 1 1
b 1 1 1

@@@ hidden_input
6
T5 9 50 4294967295
T4 9 50 4294967295
T3 9 50 4294967295
T2 9 50 4294967295
T1 9 50 4294967295
T0 9 50 4294967295
@@@ hidden_output
T0 9 50 4294967295
T1 9 50 4294967295
T2 9 50 4294967295
T3 9 50 4294967295
T4 9 50 4294967295
T5 9 50 4294967295

@@@ hidden_input
5
x 2 40000 0
y 2 30000 0
z 2 50000 4294967295
w 2 30000 4294967295
v 2 1 0
@@@ hidden_output
v 2 1 0
w 2 30000 4294967295
y 2 30000 0
x 2 40000 0
z 2 50000 4294967295

@@@ hidden_input
200
J000 0 10 0
J073 120 70 2147483647
J146 240 60 1000
J019 60 50 4294967295
J092 180 40 2147483648
J165 0 30 1
J038 120 20 0
J111 240 10 2147483647
J184 60 70 1000
J057 180 60 4294967295
J130 0 50 2147483648
J003 120 40 1
J076 240 30 0
J149 60 20 2147483647
J022 180 10 1000
J095 0 70 4294967295
J168 120 60 2147483648
J041 240 50 1
J114 60 40 0
J187 180 30 2147483647
J060 0 20 1000
J133 120 10 4294967295
J006 240 70 2147483648
J079 60 60 1
J152 180 50 0
J025 0 40 2147483647
J098 120 30 1000
J171 240 20 4294967295
J044 60 10 2147483648
J117 180 70 1
J190 0 60 0
J063 120 50 2147483647
J136 240 40 1000
J009 60 30 4294967295
J082 180 20 2147483648
J155 0 10 1
J028 120 70 0
J101 240 60 2147483647
J174 60 50 1000
J047 180 40 4294967295
J120 0 30 2147483648
J193 120 20 1
J066 240 10 0
J139 60 70 2147483647
J012 180 60 1000
J085 0 50 4294967295
J158 120 40 2147483648
J031 240 30 1
J104 60 20 0
J177 180 10 2147483647
J050 0 70 1000
J123 120 60 4294967295
J196 240 50 2147483648
J069 60 40 1
J142 180 30 0
J015 0 20 2147483647
J088 120 10 1000
J161 240 70 4294967295
J034 60 60 2147483648
J107 180 50 1
J180 0 40 0
J053 120 30 2147483647
J126 240 20 1000
J199 60 10 4294967295
J072 180 70 2147483648
J145 0 60 1
J018 120 50 0
J091 240 40 2147483647
J164 60 30 1000
J037 180 20 4294967295
J110 0 10 2147483648
J183 120 70 1
J056 240 60 0
J129 60 50 2147483647
J002 180 40 1000
J075 0 30 4294967295
J148 120 20 2147483648
J021 240 10 1
J094 60 70 0
J167 180 60 2147483647
J040 0 50 1000
J113 120 40 4294967295
J186 240 30 2147483648
J059 60 20 1
J132 180 10 0
J005 0 70 2147483647
J078 120 60 1000
J151 240 50 4294967295
J024 60 40 2147483648
J097 180 30 1
J170 0 20 0
J043 120 10 2147483647
J116 240 70 1000
J189 60 60 4294967295
J062 180 50 2147483648
J135 0 40 1
J008 120 30 0
J081 240 20 2147483647
J154 60 10 1000
J027 180 70 4294967295
J100 0 60 2147483648
J173 120 50 1
J046 240 40 0
J119 60 30 2147483647
J192 180 20 1000
J065 0 10 4294967295
J138 120 70 2147483648
J011 240 60 1
J084 60 50 0
J157 180 40 2147483647
J030 0 30 1000
J103 120 20 4294967295
J176 240 10 2147483648
J049 60 70 1
J122 180 60 0
J195 0 50 2147483647
J068 120 40 1000
J141 240 30 4294967295
J014 60 20 2147483648
J087 180 10 1
J160 0 70 0
J033 120 60 2147483647
J106 240 50 1000
J179 60 40 4294967295
J052 180 30 2147483648
J125 0 20 1
J198 120 10 0
J071 240 70 2147483647
J144 60 60 1000
J017 180 50 4294967295
J090 0 40 2147483648
J163 120 30 1
J036 240 20 0
J109 60 10 2147483647
J182 180 70 1000
J055 0 60 4294967295
J128 120 50 2147483648
J001 240 40 1
J074 60 30 0
J147 180 20 2147483647
J020 0 10 1000
J093 120 70 4294967295
J166 240 60 2147483648
J039 60 50 1
J112 180 40 0
J185 0 30 2147483647
J058 120 20 1000
J131 240 10 4294967295
J004 60 70 2147483648
J077 180 60 1
J150 0 50 0
J023 120 40 2147483647
J096 240 30 1000
J169 60 20 4294967295
J042 180 10 2147483648
J115 0 70 1
J188 120 60 0
J061 240 50 2147483647
J134 60 40 1000
J007 180 30 4294967295
J080 0 20 2147483648
J153 120 10 1
J026 240 70 0
J099 60 60 2147483647
J172 180 50 1000
J045 0 40 4294967295
J118 120 30 2147483648
J191 240 20 1
J064 60 10 0
J137 180 70 2147483647
J010 0 60 1000
J083 120 50 4294967295
J156 240 40 2147483648
J029 60 30 1
J102 180 20 0
J175 0 10 2147483647
J048 120 70 1000
J121 240 60 4294967295
J194 60 50 2147483648
J067 180 40 1
J140 0 30 0
J013 120 20 2147483647
J086 240 10 1000
J159 60 70 4294967295
J032 180 60 2147483648
J105 0 50 1
J178 120 40 0
J051 240 30 2147483647
J124 60 20 1000
J197 180 10 4294967295
J070 0 70 2147483648
J143 120 60 1
J016 240 50 0
J089 60 40 2147483647
J162 180 30 1000
J035 0 20 4294967295
J108 120 10 2147483648
J181 240 70 1
J054 60 60 0
J127 180 50 2147483647
@@@ hidden_output
J131 240 10 4294967295
J176 240 10 2147483648
J111 240 10 2147483647
J086 240 10 1000
J021 240 10 1
J066 240 10 0
J171 240 20 4294967295
J081 240 20 2147483647
J126 240 20 1000
J191 240 20 1
J036 240 20 0
J141 240 30 4294967295
J186 240 30 2147483648
J051 240 30 2147483647
J096 240 30 1000
J031 240 30 1
J076 240 30 0
J156 240 40 2147483648
J091 240 40 2147483647
J136 240 40 1000
J001 240 40 1
J046 240 40 0
J151 240 50 4294967295
J196 240 50 2147483648
J061 240 50 2147483647
J106 240 50 1000
J041 240 50 1
J016 240 50 0
J121 240 60 4294967295
J166 240 60 2147483648
J101 240 60 2147483647
J146 240 60 1000
J011 240 60 1
J056 240 60 0
J161 240 70 4294967295
J006 240 70 2147483648
J071 240 70 2147483647
J116 240 70 1000
J181 240 70 1
J026 240 70 0
J197 180 10 4294967295
J042 180 10 2147483648
J177 180 10 2147483647
J022 180 10 1000
J087 180 10 1
J132 180 10 0
J037 180 20 4294967295
J082 180 20 2147483648
J147 180 20 2147483647
J192 180 20 1000
J102 180 20 0
J007 180 30 4294967295
J052 180 30 2147483648
J187 180 30 2147483647
J162 180 30 1000
J097 180 30 1
J142 180 30 0
J047 180 40 4294967295
J092 180 40 2147483648
J157 180 40 2147483647
J002 180 40 1000
J067 180 40 1
J112 180 40 0
J017 180 50 4294967295
J062 180 50 2147483648
J127 180 50 2147483647
J172 180 50 1000
J107 180 50 1
J152 180 50 0
J057 180 60 4294967295
J032 180 60 2147483648
J167 180 60 2147483647
J012 180 60 1000
J077 180 60 1
J122 180 60 0
J027 180 70 4294967295
J072 180 70 2147483648
J137 180 70 2147483647
J182 180 70 1000
J117 180 70 1
J133 120 10 4294967295
J108 120 10 2147483648
J043 120 10 2147483647
J088 120 10 1000
J153 120 10 1
J198 120 10 0
J103 120 20 4294967295
J148 120 20 2147483648
J013 120 20 2147483647
J058 120 20 1000
J193 120 20 1
J038 120 20 0
J118 120 30 2147483648
J053 120 30 2147483647
J098 120 30 1000
J163 120 30 1
J008 120 30 0
J113 120 40 4294967295
J158 120 40 2147483648
J023 120 40 2147483647
J068 120 40 1000
J003 120 40 1
J178 120 40 0
J083 120 50 4294967295
J128 120 50 2147483648
J063 120 50 2147483647
J173 120 50 1
J018 120 50 0
J123 120 60 4294967295
J168 120 60 2147483648
J033 120 60 2147483647
J078 120 60 1000
J143 120 60 1
J188 120 60 0
J093 120 70 4294967295
J138 120 70 2147483648
J073 120 70 2147483647
J048 120 70 1000
J183 120 70 1
J028 120 70 0
J199 60 10 4294967295
J044 60 10 2147483648
J109 60 10 2147483647
J154 60 10 1000
J064 60 10 0
J169 60 20 4294967295
J014 60 20 2147483648
J149 60 20 2147483647
J124 60 20 1000
J059 60 20 1
J104 60 20 0
J009 60 30 4294967295
J119 60 30 2147483647
J164 60 30 1000
J029 60 30 1
J074 60 30 0
J179 60 40 4294967295
J024 60 40 2147483648
J089 60 40 2147483647
J134 60 40 1000
J069 60 40 1
J114 60 40 0
J019 60 50 4294967295
J194 60 50 2147483648
J129 60 50 2147483647
J174 60 50 1000
J039 60 50 1
J084 60 50 0
J189 60 60 4294967295
J034 60 60 2147483648
J099 60 60 2147483647
J144 60 60 1000
J079 60 60 1
J054 60 60 0
J159 60 70 4294967295
J004 60 70 2147483648
J139 60 70 2147483647
J184 60 70 1000
J049 60 70 1
J094 60 70 0
J065 0 10 4294967295
J110 0 10 2147483648
J175 0 10 2147483647
J020 0 10 1000
J155 0 10 1
J000 0 10 0
J035 0 20 4294967295
J080 0 20 2147483648
J015 0 20 2147483647
J060 0 20 1000
J125 0 20 1
J170 0 20 0
J075 0 30 4294967295
J120 0 30 2147483648
J185 0 30 2147483647
J030 0 30 1000
J165 0 30 1
J140 0 30 0
J045 0 40 4294967295
J090 0 40 2147483648
J025 0 40 2147483647
J135 0 40 1
J180 0 40 0
J085 0 50 4294967295
J130 0 50 2147483648
J195 0 50 2147483647
J040 0 50 1000
J105 0 50 1
J150 0 50 0
J055 0 60 4294967295
J100 0 60 2147483648
J010 0 60 1000
J145 0 60 1
J190 0 60 0
J095 0 70 4294967295
J070 0 70 2147483648
J005 0 70 2147483647
J050 0 70 1000
J115 0 70 1
J160 0 70 0

@@@ hint
Compare one key at a time and return as soon as the keys differ: `if (x->prio != y->prio) return x->prio > y->prio ? -1 : 1;`. The `?:` form never overflows.
@@@ hint
Do not write `return y->wcet_us - x->wcet_us;`. The `uint32_t` difference wraps, and converting it to `int` gives the wrong sign for values 2^31 apart. Use comparisons for every key, and finish with `strcmp(x->name, y->name)`.
@@@ solution_code
#include <stdint.h>
#include <string.h>

int task_cmp(const void *a, const void *b)
{
    const struct Task *x = a;
    const struct Task *y = b;

    if (x->prio != y->prio)                 /* 1. prio: higher first     */
        return x->prio > y->prio ? -1 : 1;
    if (x->period_ms != y->period_ms)       /* 2. period: shorter first  */
        return x->period_ms < y->period_ms ? -1 : 1;
    if (x->wcet_us != y->wcet_us)           /* 3. wcet: longer first     */
        return x->wcet_us > y->wcet_us ? -1 : 1;   /* no subtraction: uint32_t would wrap */
    return strcmp(x->name, y->name);        /* 4. unique tie-breaker     */
}
@@@ explanation_md
**Approach.** A multi-key comparator is a chain of "if this key differs, decide". `qsort` hands you `const void *` pointers to the **array elements**, so cast them to `const struct Task *`, not `struct Task **`. Sorting an array of structs moves whole structs (28 bytes each) around in memory, which is fine for 200 entries.

Why the last key matters: `qsort` is **not stable**, and glibc and the Windows CRT order equal elements differently. A unique final key (the name) makes the order total, so the output is the same on every platform.

**Complexity.** O(n log n) comparisons, each O(1) except the `strcmp` (O(name length)). Space O(1) extra besides `qsort`'s own.

**Common mistakes**
- **Subtraction comparators.** `return (int)(y->wcet_us - x->wcet_us);` with 4000000000 vs 1 gives `3999999999`, which becomes a negative `int` and reverses the order. `a->prio - b->prio` is safe only because `uint8_t` promotes to `int`. Mixing both styles is how bugs creep in.
- Reversing a direction. Priority is descending, period ascending, WCET descending.
- Returning only `-1`/`1` and never `0`, or returning `x < y` (0 or 1). That breaks the consistency `qsort` relies on and can even make it read out of bounds in some implementations.
- Casting `a` to `struct Task **` as you would when sorting an array of pointers.

**Interview follow-ups**
- How would you make the sort stable without a unique key? (Add the original index as the last key, or use a merge sort.)
- The table has 2000 entries and the structs are 128 bytes each. Why might you sort an array of pointers or indices instead?
- After sorting, compute the CPU utilization `sum(wcet / period)` and check the Liu and Layland bound `n(2^(1/n) - 1)` with fixed-point math only.
- How would you write a `bsearch` comparator that finds a task by name in a table sorted by name?
