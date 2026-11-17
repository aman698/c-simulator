@@@ meta
id: ARR-M-06
topic: Arrays
difficulty: Medium
type: FUNCTION
title: Command Dispatcher With an Array of Function Pointers
tags: embedded, function-pointers, dispatch-table, bounds-check, const-table, uart
@@@ statement_md
A motor controller receives one-byte command IDs over UART. Instead of a large `switch`, the firmware uses a **dispatch table**: a `const` array of function pointers indexed by the command ID. Because it is `const`, the table is placed in flash and cannot be corrupted at run time.

The system already provides (you do not write these):

```c
typedef int32_t (*cmd_handler_t)(int32_t arg);
#define CMD_COUNT 8u

int32_t cmd_nop(int32_t arg);         /* ID 0 */
int32_t cmd_set_speed(int32_t arg);   /* ID 1 */
int32_t cmd_get_speed(int32_t arg);   /* ID 2 */
                                      /* ID 3: reserved, no handler */
int32_t cmd_stop(int32_t arg);        /* ID 4 */
int32_t cmd_set_ramp(int32_t arg);    /* ID 5 */
                                      /* ID 6: reserved, no handler */
int32_t cmd_get_status(int32_t arg);  /* ID 7 */

#define DISPATCH_OK          0
#define DISPATCH_E_RANGE   (-1)  /* cmd >= count          */
#define DISPATCH_E_NOHANDLER (-2)  /* table[cmd] == NULL  */
#define DISPATCH_E_PARAM   (-3)  /* table == NULL         */
```

Write two things:

1. The table, with **exactly** this declaration, and `NULL` in the reserved slots:
   ```c
   const cmd_handler_t g_cmd_table[CMD_COUNT] = { ... };
   ```
2. A generic dispatcher that works with **any** table:
   ```c
   int dispatch(const cmd_handler_t *table, size_t count,
                uint8_t cmd, int32_t arg, int32_t *result);
   ```
   Check the error cases in this order: `table == NULL`, then `cmd >= count`, then a `NULL` slot. On an error, return the error code, call nothing, and leave `*result` untouched. Otherwise call `table[cmd](arg)`, store its return value in `*result` (if `result` is not `NULL`; a `NULL` result means "execute and discard"), and return `DISPATCH_OK`.

**How it is tested.** The hidden `main()` first checks the type and contents of `g_cmd_table` (`table OK`). Then it runs a script of commands through `dispatch(g_cmd_table, CMD_COUNT, ...)`. The line `PROBE` makes it call `dispatch` with its own small test tables (holes, a smaller `count`, a `NULL` table) and print the codes.

**Input (read by the hidden harness)** Lines `cmd arg flag` (`flag` 1 = pass a result pointer, 0 = pass `NULL`), or `PROBE`.

**Output** `table OK`, then one line per script line: `rc=0 result=V`, or just `rc=R` (on error or with a `NULL` result).

**Example**
```
Input:
1 1500 1
3 0 1
9 0 1

Output:
table OK
rc=0 result=1500
rc=-2
rc=-1
```
@@@ constraints_md
- `0 <= cmd <= 255` (it comes off the wire: anything can arrive)
- `INT32_MIN <= arg <= INT32_MAX`
- `dispatch` is O(1): no searching, no `switch` on the command ID.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

/* cmd_handler_t, CMD_COUNT, the cmd_* handlers and the DISPATCH_* codes
 * are provided by the system (see the statement). */

const cmd_handler_t g_cmd_table[CMD_COUNT] = {
    /* TODO: one entry per command ID, NULL for the reserved IDs 3 and 6 */
    0
};

int dispatch(const cmd_handler_t *table, size_t count,
             uint8_t cmd, int32_t arg, int32_t *result)
{
    /* TODO */
    return DISPATCH_E_PARAM;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

typedef int32_t (*cmd_handler_t)(int32_t arg);
#define CMD_COUNT 8u

#define DISPATCH_OK            0
#define DISPATCH_E_RANGE     (-1)
#define DISPATCH_E_NOHANDLER (-2)
#define DISPATCH_E_PARAM     (-3)

static int32_t g_speed = 0;
static int32_t g_ramp = 100;

int32_t cmd_nop(int32_t arg) { (void)arg; return 0; }
int32_t cmd_set_speed(int32_t arg)
{
    if (arg > 3000) arg = 3000;
    if (arg < -3000) arg = -3000;
    g_speed = arg;
    return g_speed;
}
int32_t cmd_get_speed(int32_t arg) { (void)arg; return g_speed; }
int32_t cmd_stop(int32_t arg) { (void)arg; g_speed = 0; return 0; }
int32_t cmd_set_ramp(int32_t arg)
{
    if (arg < 1) arg = 1;
    if (arg > 1000) arg = 1000;
    g_ramp = arg;
    return g_ramp;
}
int32_t cmd_get_status(int32_t arg)
{
    (void)arg;
    return (g_speed != 0 ? 1 : 0) | (g_speed < 0 ? 2 : 0) | (g_ramp << 8);
}
int32_t probe_double(int32_t arg) { return arg * 2; }
int32_t probe_add100(int32_t arg) { return arg + 100; }

/*USER_CODE*/

#define RESULT_SENTINEL 0x7EADBEEF

static void probe_one(const cmd_handler_t *t, size_t count, uint8_t cmd, int32_t arg)
{
    int32_t r = RESULT_SENTINEL;
    int rc = dispatch(t, count, cmd, arg, &r);
    if (rc == DISPATCH_OK) printf(" %d/%d", rc, (int)r);
    else if (r != RESULT_SENTINEL) printf(" %d(result written!)", rc);
    else printf(" %d", rc);
}

int main(void)
{
    int is_const_table = _Generic(&g_cmd_table, const cmd_handler_t (*)[CMD_COUNT]: 1, default: 0);
    if (!is_const_table) {
        printf("g_cmd_table must be declared as: const cmd_handler_t g_cmd_table[CMD_COUNT]\n");
        return 0;
    }
    static const cmd_handler_t expect[CMD_COUNT] = {
        cmd_nop, cmd_set_speed, cmd_get_speed, NULL, cmd_stop, cmd_set_ramp, NULL, cmd_get_status
    };
    for (unsigned i = 0; i < CMD_COUNT; i++) {
        if (g_cmd_table[i] != expect[i]) {
            printf("table WRONG at slot %u\n", i);
            return 0;
        }
    }
    printf("table OK\n");

    char tok[16];
    while (scanf("%15s", tok) == 1) {
        if (strcmp(tok, "PROBE") == 0) {
            const cmd_handler_t small[3] = { probe_double, NULL, probe_add100 };
            printf("probe:");
            probe_one(small, 3, 0, 5);
            probe_one(small, 3, 1, 5);
            probe_one(small, 3, 2, 7);
            probe_one(small, 2, 2, 7);
            probe_one(NULL, 3, 0, 1);
            probe_one(small, 0, 0, 1);
            probe_one(NULL, 0, 0, 1);
            printf("\n");
            continue;
        }
        int cmd, flag;
        long long arg;
        if (sscanf(tok, "%d", &cmd) != 1 || scanf("%lld %d", &arg, &flag) != 2) return 0;
        if (cmd < 0 || cmd > 255) return 0;
        int32_t r = RESULT_SENTINEL;
        int rc = dispatch(g_cmd_table, CMD_COUNT, (uint8_t)cmd, (int32_t)arg, flag ? &r : NULL);
        if (rc == DISPATCH_OK && flag) printf("rc=0 result=%d\n", (int)r);
        else if (flag && r != RESULT_SENTINEL) printf("rc=%d (but *result was written)\n", rc);
        else printf("rc=%d\n", rc);
    }
    return 0;
}
@@@ sample_input
1 1500 1
3 0 1
9 0 1
@@@ sample_output
table OK
rc=0 result=1500
rc=-2
rc=-1

@@@ sample_input
PROBE
1 1500 1
2 0 1
7 0 1
@@@ sample_output
table OK
probe: 0/10 -2 0/107 -1 -3 -1 -3
rc=0 result=1500
rc=0 result=1500
rc=0 result=25601

@@@ hidden_input
255 0 1
8 0 1
6 0 1
0 0 1
@@@ hidden_output
table OK
rc=-1
rc=-1
rc=-2
rc=0 result=0

@@@ hidden_input
1 -5000 1
7 0 1
4 0 1
2 0 1
7 0 1
@@@ hidden_output
table OK
rc=0 result=-3000
rc=0 result=25603
rc=0 result=0
rc=0 result=0
rc=0 result=25600

@@@ hidden_input
PROBE
@@@ hidden_output
table OK
probe: 0/10 -2 0/107 -1 -3 -1 -3

@@@ hidden_input
1 2500 0
2 0 1
1 -2147483648 1
5 2147483647 1
5 -2147483648 0
7 0 1
@@@ hidden_output
table OK
rc=0
rc=0 result=2500
rc=0 result=-3000
rc=0 result=1000
rc=0
rc=0 result=259

@@@ hidden_input
3 0 0
6 1 0
128 0 0
@@@ hidden_output
table OK
rc=-2
rc=-2
rc=-1

@@@ hidden_input
5 50 1
1 3000 1
7 0 1
1 3001 1
4 0 0
7 0 1
200 7 1
7 0 1
@@@ hidden_output
table OK
rc=0 result=50
rc=0 result=3000
rc=0 result=12801
rc=0 result=3000
rc=0
rc=0 result=12800
rc=-1
rc=0 result=12800

@@@ hint
The array declaration reads inside out: `const cmd_handler_t g_cmd_table[CMD_COUNT]` is "an array of 8 const pointers to functions taking `int32_t` and returning `int32_t`". Initialise it with the function names in ID order. A function name decays to a pointer to that function, just as an array name decays to a pointer to its first element.
@@@ hint
In `dispatch`, validate before you index: check `table == NULL`, then `cmd >= count`, then `table[cmd] == NULL`. A `uint8_t` command can be 0..255, and indexing past the table reads some random constant from flash and **jumps to it**. Only then call `table[cmd](arg)`.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

const cmd_handler_t g_cmd_table[CMD_COUNT] = {
    [0] = cmd_nop,
    [1] = cmd_set_speed,
    [2] = cmd_get_speed,
    [3] = NULL,             /* reserved */
    [4] = cmd_stop,
    [5] = cmd_set_ramp,
    [6] = NULL,             /* reserved */
    [7] = cmd_get_status,
};

int dispatch(const cmd_handler_t *table, size_t count,
             uint8_t cmd, int32_t arg, int32_t *result)
{
    if (table == NULL)
        return DISPATCH_E_PARAM;
    if ((size_t)cmd >= count)            /* never index past the table */
        return DISPATCH_E_RANGE;

    cmd_handler_t h = table[cmd];
    if (h == NULL)                       /* hole in the table: never call NULL */
        return DISPATCH_E_NOHANDLER;

    int32_t r = h(arg);                  /* same as (*h)(arg) */
    if (result != NULL)
        *result = r;
    return DISPATCH_OK;
}
@@@ explanation_md
**Approach.** A dispatch table turns an O(cases) `switch` into one bounds check and one indirect call. Two things make it safe:

1. **Validate the index before using it.** The command byte comes from the outside world. With 8 entries, IDs `8..255` index past the table: the CPU loads a random word from flash and *branches to it*. That is a classic way for a fuzzed diagnostic interface to crash or take over an ECU.
2. **Handle holes.** Reserved IDs are `NULL` entries. Calling a null function pointer is undefined behavior; on Cortex-M it typically jumps to address 0, the vector table, and HardFaults.

Designated initializers (`[4] = cmd_stop`) keep the table readable and robust when IDs are not dense. Passing the table and its `count` as parameters makes the dispatcher reusable (one per protocol layer) and testable with mock tables, which is what the `PROBE` line does.

**Declaration syntax (an interview favourite).** Without the typedef the table is
```c
int32_t (*const g_cmd_table[8])(int32_t);
```
Read it inside out: `g_cmd_table` is an array of 8 const pointers to functions `(int32_t) -> int32_t`. The `const` after the `*` makes the **pointers** read-only, so the array can live in `.rodata`/flash.

**Complexity.** O(1) per command: a compare, a load and an indirect call. Space: one pointer per command ID.

**Common mistakes**
- `if (cmd > count)` instead of `>=`. ID 8 then reads `table[8]`, one past the end (UBSan: index out of bounds).
- Forgetting the `NULL` check for reserved slots.
- Writing `*result` on the error paths, or dereferencing a `NULL` `result`.
- Declaring the table non-`const`. It then lands in RAM, where a stray write (or an attacker) can redirect execution, and it costs RAM on a small MCU.
- Writing `const` in the wrong place: `const int32_t (*t[8])(int32_t)` is an array of pointers to functions returning `const int32_t`, which is not a constant table.

**Interview follow-ups**
- Write the declaration of `g_cmd_table` **without** a typedef, and a function that *returns* a pointer to such a handler. (`cmd_handler_t lookup(uint8_t id);` vs `int32_t (*lookup(uint8_t id))(int32_t);`)
- How would you implement a **state machine** as a 2D table `next_state[state][event]` plus an action table? What do you do with invalid (state, event) pairs?
- MISRA C:2012 Rule 11.1 and function pointers: why are casts between function-pointer types forbidden, and how do you pass different argument types to handlers? (A common signature with a `const void *` payload plus a length.)
- How do you make sure that no future developer adds a command without extending the table? (`_Static_assert(sizeof g_cmd_table / sizeof g_cmd_table[0] == CMD_COUNT, ...)`.)
