@@@ meta
id: STR-M-01
topic: Strings
difficulty: Medium
type: FUNCTION
title: Robust my_atoi with Overflow Clamping and Error Code
tags: embedded, atoi, integer-overflow, int-min, parsing, uart-command
@@@ statement_md
A UART service shell receives commands such as `SET SPEED -120` and must turn the numeric argument into an `int`. The standard `atoi` has **undefined behavior on overflow** and cannot report errors (`"0"` and `"abc"` both give 0). Write a safer replacement:

```c
int my_atoi(const char *s, int *err);
```

Parsing rules, in this order:
1. Skip leading whitespace: `' '`, `'\t'`, `'\n'`, `'\v'`, `'\f'`, `'\r'`.
2. Accept **one** optional sign, `'+'` or `'-'`.
3. Consume decimal digits `'0'..'9'` and stop at the first non-digit. Everything after it is ignored (`"12abc"` gives 12).
4. If no digit was consumed: return `0` with error **1** (also for `""`, `"+"`, `"-"`, `"- 5"` and `NULL`).
5. If the value is outside the `int` range, **clamp** it to `INT_MAX` or `INT_MIN` and set error **2**. Keep consuming digits, but never compute a value that overflows, because signed overflow is undefined behavior.
6. Otherwise set error **0**.

`err` may be `NULL`. In that case, return the same value and do not write the error code.

**How it is tested.** For each input line, a hidden `main()` calls `my_atoi(s, &err)` and prints `value err`. It also calls `my_atoi(s, NULL)` and prints `MISMATCH WITH NULL err` if the result differs.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: the string in double quotes (escapes `\t \n \v \f \r` allowed inside), or the word `NULL`.

**Output**
- One line per string: `value err`.

**Example**
```
Input:
4
"42"
"   -0012abc"
"+"
"2147483648"

Output:
42 0
-12 0
0 1
2147483647 2
```
@@@ constraints_md
- `1 <= q <= 30`, strings have at most 100 characters.
- `int` is 32 bits: `INT_MIN = -2147483648`, `INT_MAX = 2147483647`.
- Do not use `atoi`, `atol`, `atoll`, `strtol`, `strtoll`, `strtoul`, `strtoull` or `sscanf` (rejected at compile time).
- No undefined behavior: the judge runs with UBSan, which flags signed overflow.
@@@ starter_code
#include <limits.h>
#include <stddef.h>

/* err: 0 = ok, 1 = no digits, 2 = out of range (clamped). err may be NULL. */
int my_atoi(const char *s, int *err)
{
    /* TODO */
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
#include <stddef.h>

#define atoi(s) atoi_is_not_allowed_in_this_exercise
#define atol(s) atol_is_not_allowed_in_this_exercise
#define atoll(s) atoll_is_not_allowed_in_this_exercise
#define strtol(s, e, b) strtol_is_not_allowed_in_this_exercise
#define strtoll(s, e, b) strtoll_is_not_allowed_in_this_exercise
#define strtoul(s, e, b) strtoul_is_not_allowed_in_this_exercise
#define strtoull(s, e, b) strtoull_is_not_allowed_in_this_exercise
#define sscanf(...) sscanf_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef atoi
#undef atol
#undef atoll
#undef strtol
#undef strtoll
#undef strtoul
#undef strtoull
#undef sscanf

static int parse_quoted(const char *p, char *out, size_t cap)
{
    size_t n = 0;
    p = strchr(p, '"');
    if (!p) return 0;
    p++;
    while (*p && *p != '"') {
        int c = (unsigned char)*p++;
        if (c == '\\' && *p) {
            int e = (unsigned char)*p++;
            switch (e) {
            case 't': c = '\t'; break;
            case 'n': c = '\n'; break;
            case 'v': c = '\v'; break;
            case 'f': c = '\f'; break;
            case 'r': c = '\r'; break;
            default:  c = e;    break;
            }
        }
        if (n + 1 < cap) out[n++] = (char)c;
    }
    out[n] = '\0';
    return 1;
}

int main(void)
{
    char line[256], text[128];
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        const char *arg = NULL;
        if (strncmp(line, "NULL", 4) != 0) {
            parse_quoted(line, text, sizeof text);
            arg = text;
        }
        int err = -7;
        int v = my_atoi(arg, &err);
        int v2 = my_atoi(arg, NULL);
        printf("%d %d\n", v, err);
        if (v2 != v) printf("MISMATCH WITH NULL err\n");
    }
    return 0;
}
@@@ sample_input
4
"42"
"   -0012abc"
"+"
"2147483648"
@@@ sample_output
42 0
-12 0
0 1
2147483647 2

@@@ sample_input
3
""
"-2147483648"
NULL
@@@ sample_output
0 1
-2147483648 0
0 1

@@@ hidden_input
4
"-"
"+-5"
"- 5"
"abc"
@@@ hidden_output
0 1
0 1
0 1
0 1

@@@ hidden_input
4
"2147483647"
"-2147483649"
"99999999999999999999999"
"-99999999999999999999999"
@@@ hidden_output
2147483647 0
-2147483648 2
2147483647 2
-2147483648 2

@@@ hidden_input
4
"00000000000000000000042"
"-0"
"+0"
"0x1A"
@@@ hidden_output
42 0
0 0
0 0
0 0

@@@ hidden_input
3
"\t\n\v\f\r 15"
"  +7 apples"
"1 2"
@@@ hidden_output
15 0
7 0
1 0

@@@ hidden_input
4
"4294967296"
"3000000000"
"-4294967296"
"21474836470"
@@@ hidden_output
2147483647 2
2147483647 2
-2147483648 2
2147483647 2

@@@ hidden_input
3
"-000000000000002147483648xyz"
"12345678901234567890123456789012345678901234567890"
"   +2147483647   "
@@@ hidden_output
-2147483648 0
2147483647 2
2147483647 0

@@@ hint
Before every `value = value * 10 + d`, check that it cannot overflow: for a positive number, `value > (INT_MAX - d) / 10` means the next step would exceed `INT_MAX`.
@@@ hint
`-2147483648` is a valid `int`, but `2147483648` is not, so accumulating a positive value and negating it at the end fails for `INT_MIN`. Either accumulate **negatively** for a `'-'` sign (`value = value * 10 - d`, check against `(INT_MIN + d) / 10`), or accumulate in `unsigned`/`long long` and stop growing it once it passes the limit.
@@@ solution_code
#include <limits.h>
#include <stddef.h>

int my_atoi(const char *s, int *err)
{
    int value = 0;
    int e = 1;          /* "no digits" until we see one */
    int neg = 0;

    if (s == NULL) {
        if (err) *err = 1;
        return 0;
    }
    while (*s == ' ' || (*s >= '\t' && *s <= '\r'))   /* \t \n \v \f \r */
        s++;
    if (*s == '+' || *s == '-') {
        neg = (*s == '-');
        s++;
    }
    for (; *s >= '0' && *s <= '9'; s++) {
        int d = *s - '0';
        if (e == 1)
            e = 0;                      /* at least one digit */
        if (e == 2)
            continue;                   /* already clamped: just consume */
        if (!neg) {
            if (value > (INT_MAX - d) / 10) {
                value = INT_MAX;
                e = 2;
            } else {
                value = value * 10 + d;
            }
        } else {
            /* accumulate as a NEGATIVE number so INT_MIN is reachable */
            if (value < (INT_MIN + d) / 10) {
                value = INT_MIN;
                e = 2;
            } else {
                value = value * 10 - d;
            }
        }
    }
    if (err) *err = e;
    return value;
}
@@@ explanation_md
**Approach.** A small state machine: skip whitespace, read an optional sign, then accumulate digits with an **overflow check before every multiply-add**.

- Positive: `value * 10 + d <= INT_MAX` holds exactly when `value <= (INT_MAX - d) / 10`.
- Negative: accumulate downwards (`value * 10 - d`) and require `value >= (INT_MIN + d) / 10`. C division truncates toward zero, which for a negative numerator is exactly the ceiling we need.

Accumulating negatively avoids the classic `INT_MIN` trap. The magnitude `2147483648` does not fit in an `int`, so "parse positive, negate at the end" overflows exactly on the one valid input `-2147483648`. Once clamped, the loop keeps consuming digits without computing anything.

**Complexity.** Time O(n), one pass. Space O(1).

**Common mistakes**
- `result = result * 10 + d` with no check. Signed overflow is **undefined behavior**: UBSan reports it, and an optimiser may remove a later `if (result < 0)` overflow test.
- Accumulating in `long long` without stopping. `"99999999999999999999999"` overflows 64 bits as well.
- Accumulating in a 32-bit `unsigned` and checking afterwards. `"4294967296"` wraps to 0 and looks like a valid number.
- Detecting overflow by **counting digits** (more than 10 means overflow). `"00000000000000000000042"` is 42.
- Returning error 0 for `"+"`, `"-"`, or `"- 5"`. A sign without a digit is not a number.
- Treating `"0x1A"` as 26. Decimal parsing stops at `'x'` and the result is 0 with **no** error, exactly like `strtol(s, &end, 10)`. Callers that need "whole string must be numeric" must also check where parsing stopped (`end`).

**Interview follow-ups**
- Extend the API to return the end pointer (like `strtol`'s `endptr`) so the caller can reject trailing garbage such as `"12abc"`.
- Support hexadecimal `0x` prefixes and base auto-detection like `strtol(s, NULL, 0)`. What is the octal trap with `"010"`?
- Why does C11 7.22.1 say `atoi` has undefined behavior "if the value of the result cannot be represented", and why do MISRA C:2012 Rule 21.7 and CERT ERR34-C ban `atoi`/`atol` entirely?
- How would you parse a fixed-point value such as `"12.75"` into hundredths (1275) without floating point on an FPU-less MCU?
