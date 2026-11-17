@@@ meta
id: PTR-M-07
topic: Pointers
difficulty: Medium
type: FIND_THE_BUG
title: Fixed-Point Temperature Formatter Returns a Dead Buffer
tags: dangling-pointer, stack-lifetime, return-local-address, fixed-point, string-formatting
@@@ statement_md
A battery-management ECU stores cell temperatures in **hundredths of a degree** (`int32_t`, so `-1234` means -12.34 degC). Before logging, each value is formatted as `[-]I.FF` by a small helper that builds the string **backwards**, starting from the last digit. This is common in embedded code because it needs no division by 10^k and no `sprintf`. The UART logger then assembles each record in a cleared line buffer and sends it.

The program reads `n` readings and logs:

```
T<i>: <formatted> degC      (one line per reading, i from 0)
min <formatted>
max <formatted>
```

For `n = 0` it prints only the line `no data`.

The formatter logic is correct: it handles 0, negative values and even `INT32_MIN` through an unsigned magnitude. The logger is correct too. Yet the log shows empty or garbage values, and sometimes the program crashes. The exact symptom changes with the compiler and the optimisation level. Find and fix the bug without changing the output format.

**Input**
- Line 1: `n`
- Line 2: `n` integers in `int32_t` range.

**Output**
- As described above.

**Example**
```
Input:
3
2150 -5 0

Output:
T0: 21.50 degC
T1: -0.05 degC
T2: 0.00 degC
min -0.05
max 21.50
```
@@@ constraints_md
- `0 <= n <= 1000`
- `INT32_MIN <= value <= INT32_MAX`
- Each formatted value is logged before the next one is formatted.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* Format a value in hundredths as "[-]I.FF", e.g. -1234 -> "-12.34". */
static const char *fmt_centi(int32_t v)
{
    char buf[16];
    char *p = buf + sizeof buf;
    uint32_t mag = v < 0 ? 0u - (uint32_t)v : (uint32_t)v;

    *--p = '\0';
    *--p = (char)('0' + mag % 10u); mag /= 10u;   /* hundredths */
    *--p = (char)('0' + mag % 10u); mag /= 10u;   /* tenths     */
    *--p = '.';
    do {                                          /* integer part, at least one digit */
        *--p = (char)('0' + mag % 10u);
        mag /= 10u;
    } while (mag != 0u);
    if (v < 0)
        *--p = '-';
    return p;
}

/* The UART logger assembles every record in a cleared line buffer, then sends it. */
static size_t append(char *dst, size_t n, size_t cap, const char *s)
{
    while (*s != '\0' && n + 1 < cap)
        dst[n++] = *s++;
    return n;
}

static void log_line(const char *prefix, const char *text, const char *suffix)
{
    char line[256];
    size_t n = 0;

    memset(line, 0, sizeof line);
    n = append(line, n, sizeof line, prefix);
    n = append(line, n, sizeof line, text);
    n = append(line, n, sizeof line, suffix);
    puts(line);
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    if (n <= 0) {
        printf("no data\n");
        return 0;
    }
    int32_t lo = INT32_MAX, hi = INT32_MIN;
    for (int i = 0; i < n; i++) {
        int v;
        if (scanf("%d", &v) != 1) return 0;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
        char prefix[16];
        snprintf(prefix, sizeof prefix, "T%d: ", i);
        log_line(prefix, fmt_centi(v), " degC");
    }
    log_line("min ", fmt_centi(lo), "");
    log_line("max ", fmt_centi(hi), "");
    return 0;
}
@@@ sample_input
3
2150 -5 0
@@@ sample_output
T0: 21.50 degC
T1: -0.05 degC
T2: 0.00 degC
min -0.05
max 21.50

@@@ sample_input
1
-4000
@@@ sample_output
T0: -40.00 degC
min -40.00
max -40.00

@@@ hidden_input
2
2147483647 -2147483648
@@@ hidden_output
T0: 21474836.47 degC
T1: -21474836.48 degC
min -21474836.48
max 21474836.47

@@@ hidden_input
0
@@@ hidden_output
no data

@@@ hidden_input
4
100 99 -100 -99
@@@ hidden_output
T0: 1.00 degC
T1: 0.99 degC
T2: -1.00 degC
T3: -0.99 degC
min -1.00
max 1.00

@@@ hidden_input
5
12345 12345 12345 12345 12345
@@@ hidden_output
T0: 123.45 degC
T1: 123.45 degC
T2: 123.45 degC
T3: 123.45 degC
T4: 123.45 degC
min 123.45
max 123.45

@@@ hidden_input
3
1 -1 10
@@@ hidden_output
T0: 0.01 degC
T1: -0.01 degC
T2: 0.10 degC
min -0.01
max 0.10

@@@ hidden_input
2
150000 -999
@@@ hidden_output
T0: 1500.00 degC
T1: -9.99 degC
min -9.99
max 1500.00

@@@ hint
Where does `buf` live, and what happens to that memory when `fmt_centi` returns? The returned `p` points *into* `buf`.
@@@ hint
`buf` is an automatic (stack) array. Its lifetime ends at the closing brace, and the very next function call, `log_line` with its own 256-byte `line` buffer, reuses that stack area and clears it. Give `buf` a lifetime that outlives the call (`static` storage), or let the caller pass in the buffer.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* Format a value in hundredths as "[-]I.FF", e.g. -1234 -> "-12.34". */
static const char *fmt_centi(int32_t v)
{
    static char buf[16];   /* FIX: static storage outlives the call (was an automatic array -> dangling pointer) */
    char *p = buf + sizeof buf;
    uint32_t mag = v < 0 ? 0u - (uint32_t)v : (uint32_t)v;

    *--p = '\0';
    *--p = (char)('0' + mag % 10u); mag /= 10u;   /* hundredths */
    *--p = (char)('0' + mag % 10u); mag /= 10u;   /* tenths     */
    *--p = '.';
    do {                                          /* integer part, at least one digit */
        *--p = (char)('0' + mag % 10u);
        mag /= 10u;
    } while (mag != 0u);
    if (v < 0)
        *--p = '-';
    return p;
}

/* The UART logger assembles every record in a cleared line buffer, then sends it. */
static size_t append(char *dst, size_t n, size_t cap, const char *s)
{
    while (*s != '\0' && n + 1 < cap)
        dst[n++] = *s++;
    return n;
}

static void log_line(const char *prefix, const char *text, const char *suffix)
{
    char line[256];
    size_t n = 0;

    memset(line, 0, sizeof line);
    n = append(line, n, sizeof line, prefix);
    n = append(line, n, sizeof line, text);
    n = append(line, n, sizeof line, suffix);
    puts(line);
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    if (n <= 0) {
        printf("no data\n");
        return 0;
    }
    int32_t lo = INT32_MAX, hi = INT32_MIN;
    for (int i = 0; i < n; i++) {
        int v;
        if (scanf("%d", &v) != 1) return 0;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
        char prefix[16];
        snprintf(prefix, sizeof prefix, "T%d: ", i);
        log_line(prefix, fmt_centi(v), " degC");
    }
    log_line("min ", fmt_centi(lo), "");
    log_line("max ", fmt_centi(hi), "");
    return 0;
}
@@@ explanation_md
**Bug.** `buf` has **automatic storage duration**: it lives in `fmt_centi`'s stack frame, and its lifetime ends when the function returns. The returned `p` points into that dead frame, so it is a *dangling pointer*. Using it is undefined behavior (C11 6.2.4p2: "the value of a pointer becomes indeterminate when the object it points to reaches the end of its lifetime").

In practice, `log_line` is called right afterwards. Its frame lands on the same stack addresses, and its `memset(line, 0, ...)` wipes the characters before `append` reads them. The value then comes out empty, or as garbage, or as a sanitizer report, depending on the frame layout. The compiler cannot warn, because the function returns `p`, not `buf` directly. With a plain `return buf;`, gcc warns (`-Wreturn-local-addr`) and even returns `NULL` on purpose.

**Fix.** Make the buffer outlive the call with `static char buf[16];`. Each value is logged before the next one is formatted, so one shared static buffer is enough.

**Complexity.** O(d) per value for d digits (at most 11), plus O(line length) for logging. O(1) space.

**Common mistakes**
- "It printed correctly on my machine, so it is fine." Stack reuse depends on the compiler, optimisation level, sanitizers and what is called next. In a variant that calls `printf` directly, gcc printed garbage while clang + ASan printed the right digits. That is exactly why this bug survives unit tests.
- The `static` fix is **not reentrant**. `printf("%s %s", fmt_centi(a), fmt_centi(b))` prints the same string twice, and calling it from an ISR and a task at the same time corrupts it. That is the same weakness as `asctime()` and `strtok()`.
- Fixing it with `malloc` in a periodic task. The caller now has to `free` every string, and in an ECU that is a leak waiting to happen (and often banned, MISRA Rule 21.3).

**Interview follow-ups**
- Redesign the API as `char *fmt_centi(int32_t v, char *out, size_t cap)` (caller-owned buffer). What should it return if `cap` is too small?
- Why does `0u - (uint32_t)v` work for `INT32_MIN`, while `-v` is undefined behavior?
- AddressSanitizer catches this only with `detect_stack_use_after_return=1`. How does that "fake stack" mode work?
- Which other standard functions return pointers to static storage, and why are they forbidden in multi-threaded or AUTOSAR code?
