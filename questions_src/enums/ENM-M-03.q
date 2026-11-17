@@@ meta
id: ENM-M-03
topic: Enums
difficulty: Medium
type: FUNCTION
title: X-Macro Generated UDS Negative Response Code Table
tags: embedded, x-macro, uds, enum-to-string, stringification, asked-in-automotive
@@@ statement_md
A UDS (ISO 14229) diagnostic stack needs the negative response codes (NRCs) in three forms: as an enum, as a count, and as printable names for the trace log. Keeping three hand-written lists in sync is a classic source of bugs, so the project keeps **one** X-macro list. The judge defines it:

```c
#define UDS_NRC_LIST(X)                                  \
    X(GENERAL_REJECT,                       0x10)        \
    X(SERVICE_NOT_SUPPORTED,                0x11)        \
    X(SUBFUNCTION_NOT_SUPPORTED,            0x12)        \
    X(INCORRECT_MESSAGE_LENGTH,             0x13)        \
    X(BUSY_REPEAT_REQUEST,                  0x21)        \
    X(CONDITIONS_NOT_CORRECT,               0x22)        \
    X(REQUEST_SEQUENCE_ERROR,               0x24)        \
    X(REQUEST_OUT_OF_RANGE,                 0x31)        \
    X(SECURITY_ACCESS_DENIED,               0x33)        \
    X(INVALID_KEY,                          0x35)        \
    X(EXCEEDED_NUMBER_OF_ATTEMPTS,          0x36)        \
    X(RESPONSE_PENDING,                     0x78)        \
    X(SUBFUNCTION_NOT_SUPPORTED_IN_SESSION, 0x7E)        \
    X(SERVICE_NOT_SUPPORTED_IN_SESSION,     0x7F)        \
    /* ...plus two OEM-specific entries in the judge's copy */
```

**The judge's list has two more entries at the end that are not shown here.** Everything you write must be **generated** from `UDS_NRC_LIST`, so new entries are picked up automatically.

The starter already generates the enum (`NRC_GENERAL_REJECT = 0x10`, ...). You must:
1. Replace the placeholder `NRC_COUNT` with an integer constant that equals the number of entries in `UDS_NRC_LIST`, computed by the preprocessor from the list.
2. Generate a name table from the list, using `#` stringification. The name of `X(CONDITIONS_NOT_CORRECT, 0x22)` is `"CONDITIONS_NOT_CORRECT"`.
3. Implement `const char *nrc_name(int code);`. It returns the name for a listed NRC value, or `"UNKNOWN"` for any other `int`, including negative values and values above `0xFF`.

**How it is tested.** The hidden harness prints `count=<NRC_COUNT>` and then, for each input token, `<token> <nrc_name(value)>`.

**Input (read by the hidden harness)**
- Line 1: `n`. Line 2: `n` codes (decimal or `0x` hex).

**Example**
```
Input:
3
0x22 0x31 0x7F

Output:
count=16
0x22 CONDITIONS_NOT_CORRECT
0x31 REQUEST_OUT_OF_RANGE
0x7F SERVICE_NOT_SUPPORTED_IN_SESSION
```
@@@ constraints_md
- `1 <= n <= 50`
- Do not copy any NRC name or value by hand. Use only `UDS_NRC_LIST`.
- No dynamic memory.
@@@ starter_code
#include <stddef.h>

/* The judge provides UDS_NRC_LIST(X) (see the statement). */

/* 1) enum generated from the list (given) */
#define NRC_AS_ENUM(name, value) NRC_##name = value,
typedef enum { UDS_NRC_LIST(NRC_AS_ENUM) } UdsNrc;
#undef NRC_AS_ENUM

/* 2) TODO: generate NRC_COUNT from the list (placeholder value below is wrong) */
enum { NRC_COUNT = 0 };

/* 3) TODO: generate a { value, "NAME" } table from the list */

const char *nrc_name(int code)
{
    /* TODO */
    (void)code;
    return "UNKNOWN";
}
@@@ harness_code
#include <stdio.h>
#include <stddef.h>

#define UDS_NRC_LIST(X)                                  \
    X(GENERAL_REJECT,                       0x10)        \
    X(SERVICE_NOT_SUPPORTED,                0x11)        \
    X(SUBFUNCTION_NOT_SUPPORTED,            0x12)        \
    X(INCORRECT_MESSAGE_LENGTH,             0x13)        \
    X(BUSY_REPEAT_REQUEST,                  0x21)        \
    X(CONDITIONS_NOT_CORRECT,               0x22)        \
    X(REQUEST_SEQUENCE_ERROR,               0x24)        \
    X(REQUEST_OUT_OF_RANGE,                 0x31)        \
    X(SECURITY_ACCESS_DENIED,               0x33)        \
    X(INVALID_KEY,                          0x35)        \
    X(EXCEEDED_NUMBER_OF_ATTEMPTS,          0x36)        \
    X(RESPONSE_PENDING,                     0x78)        \
    X(SUBFUNCTION_NOT_SUPPORTED_IN_SESSION, 0x7E)        \
    X(SERVICE_NOT_SUPPORTED_IN_SESSION,     0x7F)        \
    X(VOLTAGE_TOO_HIGH,                     0x92)        \
    X(VOLTAGE_TOO_LOW,                      0x93)

/*USER_CODE*/

_Static_assert(NRC_CONDITIONS_NOT_CORRECT == 0x22, "enum must be generated from UDS_NRC_LIST");
_Static_assert(NRC_VOLTAGE_TOO_LOW == 0x93, "enum must be generated from UDS_NRC_LIST");

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    printf("count=%d\n", (int)NRC_COUNT);
    for (int i = 0; i < n; i++) {
        char tok[32];
        int code;
        if (scanf("%31s", tok) != 1 || sscanf(tok, "%i", &code) != 1) return 0;
        const char *s = nrc_name(code);
        printf("%s %s\n", tok, s ? s : "(null)");
    }
    return 0;
}
@@@ sample_input
3
0x22 0x31 0x7F
@@@ sample_output
count=16
0x22 CONDITIONS_NOT_CORRECT
0x31 REQUEST_OUT_OF_RANGE
0x7F SERVICE_NOT_SUPPORTED_IN_SESSION

@@@ sample_input
2
0x00 0x99
@@@ sample_output
count=16
0x00 UNKNOWN
0x99 UNKNOWN

@@@ hidden_input
2
0x92 0x93
@@@ hidden_output
count=16
0x92 VOLTAGE_TOO_HIGH
0x93 VOLTAGE_TOO_LOW

@@@ hidden_input
3
0x10 0x13 0x78
@@@ hidden_output
count=16
0x10 GENERAL_REJECT
0x13 INCORRECT_MESSAGE_LENGTH
0x78 RESPONSE_PENDING

@@@ hidden_input
4
0x122 -1 256 0x7E
@@@ hidden_output
count=16
0x122 UNKNOWN
-1 UNKNOWN
256 UNKNOWN
0x7E SUBFUNCTION_NOT_SUPPORTED_IN_SESSION

@@@ hidden_input
5
0x11 0x12 0x21 0x24 0x33
@@@ hidden_output
count=16
0x11 SERVICE_NOT_SUPPORTED
0x12 SUBFUNCTION_NOT_SUPPORTED
0x21 BUSY_REPEAT_REQUEST
0x24 REQUEST_SEQUENCE_ERROR
0x33 SECURITY_ACCESS_DENIED

@@@ hidden_input
3
0x35 0x36 0x23
@@@ hidden_output
count=16
0x35 INVALID_KEY
0x36 EXCEEDED_NUMBER_OF_ATTEMPTS
0x23 UNKNOWN

@@@ hidden_input
1
2147483647
@@@ hidden_output
count=16
2147483647 UNKNOWN

@@@ hint
An X-macro list is "called" with a macro of your choice that says what one entry expands to. For the count, make every entry expand to `+ 1`: `enum { NRC_COUNT = 0 UDS_NRC_LIST(NRC_PLUS_ONE) };`.
@@@ hint
For the table, define `#define NRC_AS_ENTRY(name, value) { value, #name },` and write `static const struct NrcEntry tbl[] = { UDS_NRC_LIST(NRC_AS_ENTRY) };`. `#name` turns the macro argument into a string literal. Then search the table for `code`.
@@@ solution_code
#include <stddef.h>

/* 1) enum generated from the list */
#define NRC_AS_ENUM(name, value) NRC_##name = value,
typedef enum { UDS_NRC_LIST(NRC_AS_ENUM) } UdsNrc;
#undef NRC_AS_ENUM

/* 2) count: every entry expands to "+ 1" -> 0 + 1 + 1 + ... */
#define NRC_PLUS_ONE(name, value) + 1
enum { NRC_COUNT = 0 UDS_NRC_LIST(NRC_PLUS_ONE) };
#undef NRC_PLUS_ONE

/* 3) value -> name table, names produced by stringification */
struct NrcEntry {
    int code;
    const char *name;
};

#define NRC_AS_ENTRY(name, value) { value, #name },
static const struct NrcEntry nrc_table[] = { UDS_NRC_LIST(NRC_AS_ENTRY) };
#undef NRC_AS_ENTRY

_Static_assert(sizeof nrc_table / sizeof nrc_table[0] == NRC_COUNT, "table and count out of sync");

const char *nrc_name(int code)
{
    for (size_t i = 0; i < sizeof nrc_table / sizeof nrc_table[0]; i++)
        if (nrc_table[i].code == code)
            return nrc_table[i].name;
    return "UNKNOWN";
}
@@@ explanation_md
**Approach.** An **X-macro** is a list macro that takes another macro, `X`, as a parameter and applies it to every entry. Each time you expand the list you pass a different `X`, so one list of facts produces several pieces of code:

| expansion | `X(name, value)` becomes | result |
|---|---|---|
| enum | `NRC_##name = value,` | `NRC_CONDITIONS_NOT_CORRECT = 0x22,` ... |
| count | `+ 1` | `0 + 1 + 1 + ... ` = 16 |
| table | `{ value, #name },` | `{ 0x22, "CONDITIONS_NOT_CORRECT" },` ... |

`##` pastes tokens (`NRC_` + `GENERAL_REJECT`), and `#` turns an argument into a string literal. Because the hidden list has two extra OEM entries (0x92 and 0x93), hand-copied names or a hard-coded `14` fail, while generated code picks them up for free. The lookup is a linear search over 16 entries. With sparse 8-bit codes you could instead generate a 256-entry array with designated initializers (`[value] = #name,`), range-check `0..255` and map `NULL` to `"UNKNOWN"`, giving O(1).

**Complexity.** Time O(N) per lookup (N = 16), or O(1) with the 256-entry variant. Space O(N) static.

**Common mistakes**
- Indexing the table directly with the NRC value: `nrc_table[0x22]` is far out of bounds, because the values are sparse while the table is dense.
- Writing `NRC_COUNT` as the last enumerator of the value enum. With explicit values it becomes `0x93 + 1 = 0x94`, not 16.
- Forgetting the commas in the expansion macro, or leaving a trailing `\` on the last list line, which swallows the next source line.
- Not `#undef`-ing helper macros, so a later `X`-style macro with the same name clashes.
- Returning `NULL` for unknown codes, which crashes a `printf("%s")` in the logger.

**Interview follow-ups**
- Generate a `switch`-based `nrc_name` from the same list. Which form lets the compiler detect duplicate NRC values? (The `switch`: duplicate `case` labels are a compile error.)
- Where else would you use X-macros in an ECU? (DID tables, DTC lists, state names, CAN signal databases, error counters.)
- Some teams ban X-macros in favour of code generators (Python/Jinja from ARXML or ODX). What are the trade-offs?
