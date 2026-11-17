@@@ meta
id: ENM-E-05
topic: Enums
difficulty: Easy
type: FUNCTION
title: Door-Ajar Bit-Flag Enum Mask Update
tags: embedded, bit-flags, enum-flags, bitmask, body-control-module
@@@ statement_md
A body control module (BCM) keeps the open/closed state of six closures in one bitmask. The judge already defines these types, so do not redefine them:

```c
typedef enum {
    DOOR_FL    = 1u << 0,   /* front left  */
    DOOR_FR    = 1u << 1,   /* front right */
    DOOR_RL    = 1u << 2,   /* rear left   */
    DOOR_RR    = 1u << 3,   /* rear right  */
    DOOR_TRUNK = 1u << 4,
    DOOR_HOOD  = 1u << 5
} DoorFlag;

#define DOOR_ALL_MASK 0x3Fu   /* OR of all six flags */

typedef enum { DOOR_OPENED, DOOR_CLOSED, DOOR_TOGGLE } DoorAction;
```

Implement

```c
unsigned door_update(unsigned mask, DoorFlag door, DoorAction act);
```

It returns the new mask after applying `act` to the one closure `door`:
- `DOOR_OPENED` sets that closure's bit.
- `DOOR_CLOSED` clears that closure's bit.
- `DOOR_TOGGLE` flips that closure's bit.

Robustness rules (the values come from a gateway message and may be garbage):
- `door` must be **exactly one** of the six flags. A value of 0, a combination of several flags (such as `DOOR_FL | DOOR_FR`) or any bit outside `DOOR_ALL_MASK` leaves the mask **unchanged**.
- Any other `act` value leaves the mask unchanged.
- Bits of `mask` that the operation does not touch, including bits above bit 5, must be returned unchanged.

**How it is tested.** The hidden harness reads an initial mask and a list of operations. After each `door_update` call it prints the mask in hex and the names of the open closures.

**Input (read by the hidden harness)**
- Line 1: the initial mask in hex (no `0x`) and the number of operations `q`.
- Next `q` lines: `ACT DOOR`, where `ACT` is `O` (opened), `C` (closed), `T` (toggle) or `X` (an invalid action value), and `DOOR` is `FL FR RL RR TRUNK HOOD` or `#<int>` for a raw flag value.

**Output**
- After each operation: `mask=0x<2+ hex digits> open: <names in bit order>`, or `open: none`.

**Example**
```
Input:
00 4
O FL
O RL
C FL
T TRUNK

Output:
mask=0x01 open: FL
mask=0x05 open: FL RL
mask=0x04 open: RL
mask=0x14 open: RL TRUNK
```
@@@ constraints_md
- `1 <= q <= 50`
- Raw flag values `#<int>` may be 0, negative, combinations of flags or undefined bits.
- Do not use a lookup table of all 64 masks. Use bitwise operators.
@@@ starter_code
/*
 * Provided by the judge (do not redefine):
 *   typedef enum { DOOR_FL = 1u << 0, DOOR_FR = 1u << 1, DOOR_RL = 1u << 2,
 *                  DOOR_RR = 1u << 3, DOOR_TRUNK = 1u << 4, DOOR_HOOD = 1u << 5 } DoorFlag;
 *   #define DOOR_ALL_MASK 0x3Fu
 *   typedef enum { DOOR_OPENED, DOOR_CLOSED, DOOR_TOGGLE } DoorAction;
 */
unsigned door_update(unsigned mask, DoorFlag door, DoorAction act)
{
    /* TODO: validate door, then set / clear / toggle its bit */
    (void)door;
    (void)act;
    return mask;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>

typedef enum {
    DOOR_FL    = 1u << 0,
    DOOR_FR    = 1u << 1,
    DOOR_RL    = 1u << 2,
    DOOR_RR    = 1u << 3,
    DOOR_TRUNK = 1u << 4,
    DOOR_HOOD  = 1u << 5
} DoorFlag;

#define DOOR_ALL_MASK 0x3Fu

typedef enum { DOOR_OPENED, DOOR_CLOSED, DOOR_TOGGLE } DoorAction;

/*USER_CODE*/

static const char *const h_names[6] = { "FL", "FR", "RL", "RR", "TRUNK", "HOOD" };

static int parse_door(const char *tok, int *out)
{
    if (tok[0] == '#') return sscanf(tok + 1, "%d", out) == 1;
    for (int i = 0; i < 6; i++)
        if (strcmp(tok, h_names[i]) == 0) { *out = 1 << i; return 1; }
    return 0;
}

int main(void)
{
    unsigned mask;
    int q;
    if (scanf("%x %d", &mask, &q) != 2) return 0;
    for (int i = 0; i < q; i++) {
        char act_tok[8], door_tok[24];
        int door_raw;
        if (scanf("%7s %23s", act_tok, door_tok) != 2) return 0;
        if (!parse_door(door_tok, &door_raw)) return 0;
        int act_raw = act_tok[0] == 'O' ? 0 : act_tok[0] == 'C' ? 1 : act_tok[0] == 'T' ? 2 : 7;
        mask = door_update(mask, (DoorFlag)door_raw, (DoorAction)act_raw);
        printf("mask=0x%02X open:", mask);
        int any = 0;
        for (int b = 0; b < 6; b++)
            if (mask & (1u << b)) { printf(" %s", h_names[b]); any = 1; }
        printf("%s\n", any ? "" : " none");
    }
    return 0;
}
@@@ sample_input
00 4
O FL
O RL
C FL
T TRUNK
@@@ sample_output
mask=0x01 open: FL
mask=0x05 open: FL RL
mask=0x04 open: RL
mask=0x14 open: RL TRUNK

@@@ sample_input
03 3
O #3
C #0
T HOOD
@@@ sample_output
mask=0x03 open: FL FR
mask=0x03 open: FL FR
mask=0x23 open: FL FR HOOD

@@@ hidden_input
00 3
C RR
O RR
O RR
@@@ hidden_output
mask=0x00 open: none
mask=0x08 open: RR
mask=0x08 open: RR

@@@ hidden_input
3F 2
X FL
C HOOD
@@@ hidden_output
mask=0x3F open: FL FR RL RR TRUNK HOOD
mask=0x1F open: FL FR RL RR TRUNK

@@@ hidden_input
01 3
O #64
T #-1
C #1
@@@ hidden_output
mask=0x01 open: FL
mask=0x01 open: FL
mask=0x00 open: none

@@@ hidden_input
C0 2
O FR
T FR
@@@ hidden_output
mask=0xC2 open: FR
mask=0xC0 open: none

@@@ hidden_input
00 6
T FL
T FR
T RL
T RR
T TRUNK
T HOOD
@@@ hidden_output
mask=0x01 open: FL
mask=0x03 open: FL FR
mask=0x07 open: FL FR RL
mask=0x0F open: FL FR RL RR
mask=0x1F open: FL FR RL RR TRUNK
mask=0x3F open: FL FR RL RR TRUNK HOOD

@@@ hidden_input
10 3
O #48
C TRUNK
T #32
@@@ hidden_output
mask=0x10 open: TRUNK
mask=0x00 open: none
mask=0x20 open: HOOD

@@@ hint
Set with `mask | bit`, clear with `mask & ~bit`, toggle with `mask ^ bit`. Never use `+` or `-` on flags, because adding a bit that is already set carries into the next flag.
@@@ hint
`bit` is exactly one flag when it is non-zero, has a single bit set (`(bit & (bit - 1)) == 0`) and lies inside `DOOR_ALL_MASK`. Work on an `unsigned` copy of `door`.
@@@ solution_code
unsigned door_update(unsigned mask, DoorFlag door, DoorAction act)
{
    unsigned bit = (unsigned)door;

    /* exactly one bit, and it must be one of the six defined closures */
    if (bit == 0u || (bit & (bit - 1u)) != 0u || (bit & ~DOOR_ALL_MASK) != 0u)
        return mask;

    switch (act) {
    case DOOR_OPENED: return mask | bit;    /* set    */
    case DOOR_CLOSED: return mask & ~bit;   /* clear  */
    case DOOR_TOGGLE: return mask ^ bit;    /* flip   */
    default:          return mask;          /* corrupted action value */
    }
}
@@@ explanation_md
**Approach.** Give each flag enumerator its own bit (`1u << n`), so any set of closures fits in one integer and combines with `|`. The three operations are the standard bit idioms: set `m | b`, clear `m & ~b`, toggle `m ^ b`. They touch only bit `b`, so foreign bits (here bits 6 and 7 of `0xC0`) survive.

The input is untrusted, so validate it first. A flag-type enum variable can hold combinations (`DOOR_FL | DOOR_FR` = 3), zero, or garbage (`-1` becomes `0xFFFFFFFF`). `bit & (bit - 1)` clears the lowest set bit, so it is zero exactly when at most one bit was set. Together with `bit != 0` and `bit & ~DOOR_ALL_MASK == 0` this accepts exactly the six defined flags.

**Complexity.** Time O(1), space O(1).

**Common mistakes**
- `mask + bit` / `mask - bit` instead of `|` / `& ~`. Opening an already-open door then carries into the next bit and "opens" a different door.
- `mask & !bit` instead of `mask & ~bit`. `!bit` is 0 for any non-zero bit, so this clears **every** door.
- Using `~bit` on a narrower type. With a `uint8_t mask`, `~bit` is computed in `int` and must be truncated back. Using `unsigned` throughout avoids surprises.
- Accepting combined values like `#3`. A single bad gateway frame then opens or closes two doors at once.

**Interview follow-ups**
- How do you count the open doors in the mask? (Popcount: a loop of `m &= m - 1`, or `__builtin_popcount`.)
- The mask is updated from a CAN RX interrupt and read from a 10 ms task. What can go wrong with `g_mask |= bit` on a Cortex-M, and how do you fix it? (Read-modify-write race: use a critical section or the bit-band alias.)
- Why are flag enums usually written with `1u << n` rather than plain decimal values, and what happens if you need bit 31? (`1u << 31` does not fit in `int`, and an enumerator must be representable as an `int` in C11.)
