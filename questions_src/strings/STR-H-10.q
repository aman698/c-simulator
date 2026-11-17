@@@ meta
id: STR-H-10
topic: Strings
difficulty: Hard
type: FIND_THE_BUG
title: CAN Gateway Routing Table Loses Every Route but the First
tags: embedded, strtok, reentrancy, hidden-state, can, gateway, parsing
@@@ statement_md
A CAN gateway reads its routing table from a configuration string. Each route maps a CAN identifier (hex) to the list of output channels it is forwarded to:

```
0x100:1,2;0x200:3;0x7DF:1,2,3
```

Routes are separated by `';'`, the ID and the channel list by `':'`, and channels by `','`. A route may have no channel list (`0x7E0` or `0x7E0:`), which means "do not forward". Empty routes (`;;`) are ignored.

The parser was split into a clean helper, `parse_route()`, and a loop over the routes. Each helper works perfectly when tested on its own. Yet on the vehicle, **only the first route of every configuration line is installed**, and the others are silently dropped.

Find and fix the bug. The output format must stay the same.

**Input**
- Line 1: `n`, the number of configuration lines.
- Next `n` lines: one routing configuration each (no spaces).

**Output**
- For each route, in order: `0x<ID> -> <ch> <ch> ...`, with the ID printed by `%03X`.
- After each configuration line: a line `--`.

**Example**
```
Input:
1
0x100:1,2;0x200:3;0x7DF:1,2,3

Output:
0x100 -> 1 2
0x200 -> 3
0x7DF -> 1 2 3
--
```
@@@ constraints_md
- `1 <= n <= 20`, each line has at most 400 characters and at most 32 routes.
- IDs are valid hex numbers up to `0x1FFFFFFF`; channels are integers `0..15`.
- `strtok_r` is POSIX, not ISO C, and is not available here.
@@@ starter_code
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_ROUTES 32

/* "0x100:1,2" -> prints "0x100 -> 1 2" */
static void parse_route(char *route)
{
    char *id = strtok(route, ":");
    if (id == NULL)
        return;
    printf("0x%03X ->", (unsigned int)strtoul(id, NULL, 16));
    for (char *ch = strtok(NULL, ","); ch != NULL; ch = strtok(NULL, ","))
        printf(" %d", atoi(ch));
    putchar('\n');
}

int main(void)
{
    char line[512];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';

        for (char *r = strtok(line, ";"); r != NULL; r = strtok(NULL, ";"))
            parse_route(r);
        puts("--");
    }
    return 0;
}
@@@ sample_input
1
0x100:1,2;0x200:3;0x7DF:1,2,3
@@@ sample_output
0x100 -> 1 2
0x200 -> 3
0x7DF -> 1 2 3
--

@@@ sample_input
1
0x18F:2
@@@ sample_output
0x18F -> 2
--

@@@ hidden_input
2
0x7E0;0x7E8:1
0x7E0:;0x7E8:0,15
@@@ hidden_output
0x7E0 ->
0x7E8 -> 1
--
0x7E0 ->
0x7E8 -> 0 15
--

@@@ hidden_input
1
;;0x100:1;;;0x101:2;
@@@ hidden_output
0x100 -> 1
0x101 -> 2
--

@@@ hidden_input
3
0x1:1
0x2:2;0x3:3
<<BLANK>>
@@@ hidden_output
0x001 -> 1
--
0x002 -> 2
0x003 -> 3
--
--

@@@ hidden_input
1
0x18FEF100:1,2,3,4;0x0CF00400:5;0x18FEEE00:6,7
@@@ hidden_output
0x18FEF100 -> 1 2 3 4
0xCF00400 -> 5
0x18FEEE00 -> 6 7
--

@@@ hidden_input
1
0x303:14;0x22e:13,2;0x4fb:9,13;0x7df;0x51e:;0x603:9;0x794;0x723:6;0x5d9:11,1;0x5f9:3;0x15b;0x217:5,5;0x2c6:7;0x218:;0x645:9,10;0x770:0;0x79b:14,0;0x423:10,6;0x5ad:2;0x12c:15;0x793:;0x685:9;0x171;0x285:;0x5b2:;0x403;0x21c:;0x7b4:2,3;0x3a8;0x67f:15;0x696:9;0x702:
@@@ hidden_output
0x303 -> 14
0x22E -> 13 2
0x4FB -> 9 13
0x7DF ->
0x51E ->
0x603 -> 9
0x794 ->
0x723 -> 6
0x5D9 -> 11 1
0x5F9 -> 3
0x15B ->
0x217 -> 5 5
0x2C6 -> 7
0x218 ->
0x645 -> 9 10
0x770 -> 0
0x79B -> 14 0
0x423 -> 10 6
0x5AD -> 2
0x12C -> 15
0x793 ->
0x685 -> 9
0x171 ->
0x285 ->
0x5B2 ->
0x403 ->
0x21C ->
0x7B4 -> 2 3
0x3A8 ->
0x67F -> 15
0x696 -> 9
0x702 ->
--

@@@ hint
`strtok` keeps its position in a single hidden `static` pointer that is shared by **every** caller in the program. What does that pointer contain when `parse_route()` returns and the loop in `main` calls `strtok(NULL, ";")`?
@@@ hint
The inner `strtok` calls inside `parse_route()` overwrite the outer scan's state, so the outer call resumes at the end of the first route and returns `NULL`. Finish the outer tokenization first (collect the route pointers into an array), then call `parse_route()` on each of them.
@@@ solution_code
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_ROUTES 32

/* "0x100:1,2" -> prints "0x100 -> 1 2" */
static void parse_route(char *route)
{
    char *id = strtok(route, ":");
    if (id == NULL)
        return;
    printf("0x%03X ->", (unsigned int)strtoul(id, NULL, 16));
    for (char *ch = strtok(NULL, ","); ch != NULL; ch = strtok(NULL, ","))
        printf(" %d", atoi(ch));
    putchar('\n');
}

int main(void)
{
    char line[512];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;

    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';

        /* FIX: strtok has ONE hidden state. Finish the outer scan first ... */
        char *routes[MAX_ROUTES];
        int nr = 0;
        for (char *r = strtok(line, ";"); r != NULL && nr < MAX_ROUTES; r = strtok(NULL, ";"))
            routes[nr++] = r;
        /* ... then let parse_route() run its own strtok scans on each route. */
        for (int k = 0; k < nr; k++)
            parse_route(routes[k]);
        puts("--");
    }
    return 0;
}
@@@ explanation_md
**Bug: nested use of a non-reentrant function.** `strtok` remembers where to continue in one hidden `static` pointer that the whole program shares. The sequence is:

1. `main`: `strtok(line, ";")` cuts out `"0x100:1,2"` and saves "continue at `0x200...`".
2. `parse_route`: `strtok(route, ":")` **starts a new scan** and overwrites the saved position. Its loop runs until `strtok(NULL, ",")` returns `NULL`, which leaves the hidden pointer at the end of the first route.
3. `main`: `strtok(NULL, ";")` resumes from there, finds the end of the string, and returns `NULL`. The loop ends after one route.

Each function is correct in isolation. The bug only exists in their combination, which is why unit tests of `parse_route()` never showed it.

**Fix.** Do not interleave two `strtok` scans. Collect all route pointers first (the outer scan finishes completely), then parse each route. Alternatives:
- A reentrant tokenizer with caller-owned state (`strtok_r` on POSIX, `strtok_s` in C11 Annex K), or a small `my_strtok_r` of your own.
- Splitting the inner part manually with `strchr`.

**Complexity.** O(L) time per line: every character is visited by one outer and at most one inner scan. O(R) extra space for the array of route pointers (R <= 32).

**Common mistakes**
- Looking for the bug inside `parse_route()` or in the number parsing. The code is fine locally; the shared state is the problem.
- "Fixing" it by copying each route into a temporary buffer before calling `parse_route()`. The copy does not help: the inner `strtok` calls still overwrite the hidden pointer.
- Using `strtok` in code that can be called from two RTOS tasks or from an ISR. Even without nesting, concurrent callers corrupt each other's scans.
- Forgetting that `strtok` merges empty fields. That is acceptable here (`;;` is defined as ignorable), but wrong for formats such as NMEA or CSV.

**Interview follow-ups**
- Which other standard functions have hidden static state and the same reentrancy problem? (`asctime`, `localtime`, `gmtime`, `rand`, `strerror` on some libcs.) What are their reentrant replacements?
- Rewrite the parser **without** modifying the input string, so the configuration can stay in flash as `const char *`.
- The gateway must validate the whole table before applying any route (all or nothing). How would you restructure the parser into separate validate and apply phases?
