@@@ meta
id: ENM-E-09
topic: Enums
difficulty: Easy
type: FUNCTION
title: Decode Module Error Codes From a Ranged Enum
tags: embedded, error-codes, explicit-values, enum-ranges, decode
@@@ statement_md
An ECU's basic software reports errors through one shared enum. Each driver owns a block of codes that starts at an explicit base value. The `*_BASE` and `*_END` enumerators are **markers, not error codes**. The judge already defines the enum, so do not redefine it:

```c
typedef enum {
    ERR_OK = 0,

    ERR_CAN_BASE = 0x100,   /* marker */
    ERR_CAN_TIMEOUT,        /* 0x101 */
    ERR_CAN_BUS_OFF,        /* 0x102 */
    ERR_CAN_CRC,            /* 0x103 */
    ERR_CAN_END,            /* 0x104 marker: one past the last CAN code */

    ERR_NVM_BASE = 0x200,
    ERR_NVM_WRITE_FAIL,     /* 0x201 */
    ERR_NVM_READ_FAIL,      /* 0x202 */
    ERR_NVM_END,            /* 0x203 */

    ERR_ADC_BASE = 0x300,
    ERR_ADC_RANGE,          /* 0x301 */
    ERR_ADC_STUCK,          /* 0x302 */
    ERR_ADC_OVERRUN,        /* 0x303 */
    ERR_ADC_TIMEOUT,        /* 0x304 */
    ERR_ADC_END             /* 0x305 */
} ErrCode;
```

Implement the decoder used by the diagnostic logger:

```c
int err_decode(int code, const char **module, const char **name);
```

- For a valid code, store the module name (`"CAN"`, `"NVM"` or `"ADC"`) in `*module` and the error name without its prefix (for example `"BUS_OFF"`, `"WRITE_FAIL"`, `"TIMEOUT"`) in `*name`, then return 1.
- `ERR_OK` is valid: module `"SYS"`, name `"OK"`.
- Every other value, including the `BASE`/`END` markers, the gaps between blocks and negative numbers, returns 0.
- If `module` or `name` is `NULL`, skip that output but still return the right value.

**How it is tested.** The hidden harness reads codes (decimal or `0x` hex) and prints `<token> -> MODULE/NAME` or `<token> -> INVALID`. A token that starts with `?` calls `err_decode(code, NULL, NULL)` and prints `valid` or `invalid`.

**Input (read by the hidden harness)**
- Line 1: `n`. Line 2: `n` tokens.

**Example**
```
Input:
4
0x102 0x201 0x104 0

Output:
0x102 -> CAN/BUS_OFF
0x201 -> NVM/WRITE_FAIL
0x104 -> INVALID
0 -> SYS/OK
```
@@@ constraints_md
- `1 <= n <= 50`
- Codes are any 32-bit `int`.
- Derive the valid ranges from the enum's `BASE`/`END` markers rather than hard-coding numbers like `0x103`.
@@@ starter_code
/*
 * Provided by the judge (do not redefine): typedef enum { ... } ErrCode;
 * with ERR_OK, ERR_CAN_BASE .. ERR_CAN_END, ERR_NVM_BASE .. ERR_NVM_END,
 * ERR_ADC_BASE .. ERR_ADC_END (see the statement).
 */
#include <stddef.h>

int err_decode(int code, const char **module, const char **name)
{
    /* TODO: return 1 and fill *module / *name for valid codes, 0 otherwise */
    (void)code;
    (void)module;
    (void)name;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stddef.h>

typedef enum {
    ERR_OK = 0,

    ERR_CAN_BASE = 0x100,
    ERR_CAN_TIMEOUT,
    ERR_CAN_BUS_OFF,
    ERR_CAN_CRC,
    ERR_CAN_END,

    ERR_NVM_BASE = 0x200,
    ERR_NVM_WRITE_FAIL,
    ERR_NVM_READ_FAIL,
    ERR_NVM_END,

    ERR_ADC_BASE = 0x300,
    ERR_ADC_RANGE,
    ERR_ADC_STUCK,
    ERR_ADC_OVERRUN,
    ERR_ADC_TIMEOUT,
    ERR_ADC_END
} ErrCode;

/*USER_CODE*/

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        char tok[32];
        int code;
        if (scanf("%31s", tok) != 1) return 0;
        int null_mode = tok[0] == '?';
        if (sscanf(tok + null_mode, "%i", &code) != 1) return 0;
        if (null_mode) {
            printf("%s -> %s\n", tok, err_decode(code, NULL, NULL) ? "valid" : "invalid");
            continue;
        }
        const char *mod = "(unset)";
        const char *nm = "(unset)";
        if (err_decode(code, &mod, &nm))
            printf("%s -> %s/%s\n", tok, mod ? mod : "(null)", nm ? nm : "(null)");
        else
            printf("%s -> INVALID\n", tok);
    }
    return 0;
}
@@@ sample_input
4
0x102 0x201 0x104 0
@@@ sample_output
0x102 -> CAN/BUS_OFF
0x201 -> NVM/WRITE_FAIL
0x104 -> INVALID
0 -> SYS/OK

@@@ sample_input
3
0x304 0x300 0x203
@@@ sample_output
0x304 -> ADC/TIMEOUT
0x300 -> INVALID
0x203 -> INVALID

@@@ hidden_input
5
0x101 0x103 0x301 0x302 0x303
@@@ hidden_output
0x101 -> CAN/TIMEOUT
0x103 -> CAN/CRC
0x301 -> ADC/RANGE
0x302 -> ADC/STUCK
0x303 -> ADC/OVERRUN

@@@ hidden_input
4
-1 0x100 0x1FF 0x305
@@@ hidden_output
-1 -> INVALID
0x100 -> INVALID
0x1FF -> INVALID
0x305 -> INVALID

@@@ hidden_input
3
0x202 257 770
@@@ hidden_output
0x202 -> NVM/READ_FAIL
257 -> CAN/TIMEOUT
770 -> ADC/STUCK

@@@ hidden_input
3
?0x102 ?0x105 ?0
@@@ hidden_output
?0x102 -> valid
?0x105 -> invalid
?0 -> valid

@@@ hidden_input
3
2147483647 -2147483648 0x10102
@@@ hidden_output
2147483647 -> INVALID
-2147483648 -> INVALID
0x10102 -> INVALID

@@@ hidden_input
2
0x200 0x201
@@@ hidden_output
0x200 -> INVALID
0x201 -> NVM/WRITE_FAIL

@@@ hint
A code belongs to the CAN block exactly when `ERR_CAN_BASE < code && code < ERR_CAN_END`. Both markers are excluded. Its position inside the block is `code - ERR_CAN_BASE - 1`, which can index a small string table.
@@@ hint
Describe each block with a small struct `{ base, end, module, names[] }` and loop over an array of three such entries. Write through `module`/`name` only after checking that they are not `NULL`.
@@@ solution_code
#include <stddef.h>

struct ErrBlock {
    int base;                    /* *_BASE marker (exclusive) */
    int end;                     /* *_END marker  (exclusive) */
    const char *module;
    const char *const *names;    /* names[code - base - 1]    */
};

static const char *const can_names[] = { "TIMEOUT", "BUS_OFF", "CRC" };
static const char *const nvm_names[] = { "WRITE_FAIL", "READ_FAIL" };
static const char *const adc_names[] = { "RANGE", "STUCK", "OVERRUN", "TIMEOUT" };

/* Each name table must match its enum block exactly. */
_Static_assert(sizeof can_names / sizeof can_names[0] == ERR_CAN_END - ERR_CAN_BASE - 1, "CAN names");
_Static_assert(sizeof nvm_names / sizeof nvm_names[0] == ERR_NVM_END - ERR_NVM_BASE - 1, "NVM names");
_Static_assert(sizeof adc_names / sizeof adc_names[0] == ERR_ADC_END - ERR_ADC_BASE - 1, "ADC names");

static const struct ErrBlock blocks[] = {
    { ERR_CAN_BASE, ERR_CAN_END, "CAN", can_names },
    { ERR_NVM_BASE, ERR_NVM_END, "NVM", nvm_names },
    { ERR_ADC_BASE, ERR_ADC_END, "ADC", adc_names },
};

int err_decode(int code, const char **module, const char **name)
{
    const char *m = NULL;
    const char *nm = NULL;

    if (code == ERR_OK) {
        m = "SYS";
        nm = "OK";
    } else {
        for (size_t i = 0; i < sizeof blocks / sizeof blocks[0]; i++) {
            if (code > blocks[i].base && code < blocks[i].end) {
                m = blocks[i].module;
                nm = blocks[i].names[code - blocks[i].base - 1];
                break;
            }
        }
        if (m == NULL)
            return 0;            /* marker, gap, negative, ... */
    }
    if (module) *module = m;
    if (name) *name = nm;
    return 1;
}
@@@ explanation_md
**Approach.** The enum uses explicit base values to give each module its own number range, and implicit `+1` numbering inside each block. The `BASE` and `END` enumerators bracket each block, so the valid codes are the **open** interval `(BASE, END)`. When someone adds `ERR_CAN_ARB_LOST` before `ERR_CAN_END`, the range grows automatically. The decoder describes each block once (`base`, `end`, module name, name table), loops over the three blocks and indexes the name table with `code - base - 1`. `_Static_assert`s tie each name table's length to its enum block, so adding a code without its name breaks the build instead of the log.

**Complexity.** Time O(B) per call (B = number of blocks, 3 here), space O(total number of codes) for the static tables.

**Common mistakes**
- Treating the markers as codes: `code >= ERR_CAN_BASE` or `code <= ERR_CAN_END` accepts `0x100`/`0x104`, and `names[-1]` or `names[3]` is an out-of-bounds read.
- Range-checking the whole enum with `code <= ERR_ADC_END`. The gaps `0x104..0x200` are not valid codes, even though they lie between enumerators.
- Casting an unknown `int` to `ErrCode` and switching on it without a `default`. Any value outside the listed cases silently does nothing.
- Writing through `module` / `name` without a `NULL` check.

**Interview follow-ups**
- AUTOSAR uses `Std_ReturnType` (`E_OK`/`E_NOT_OK`) plus Det error IDs per module. How does that compare with one global error enum?
- How would you pack module ID and error into a 16-bit value for an NVM error log, and decode it again? (`(module << 8) | error`, with validation of both parts.)
- Generate the enum blocks and the name tables from one X-macro list per module.
