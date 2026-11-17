@@@ meta
id: ENM-E-08
topic: Enums
difficulty: Easy
type: FIND_THE_BUG
title: Seat-Belt Reminder That Misses Unbuckled Passengers
tags: embedded, bit-flags, enum-flags, bitmask, seat-belt-reminder
@@@ statement_md
The seat-belt reminder (SBR) function receives two bitmasks per CAN frame: which seats are **occupied** (from the seat mats) and which belts are **buckled**. One bit per seat:

```c
typedef enum {
    SEAT_DRIVER    = 1u << 0,
    SEAT_PASSENGER = 1u << 1,
    SEAT_REAR_L    = 1u << 2,
    SEAT_REAR_C    = 1u << 3,
    SEAT_REAR_R    = 1u << 4
} SeatFlag;
```

Intended behaviour for each frame:
- The driver seat has no mat sensor and is **always** treated as occupied.
- A seat is *unbuckled* if it is occupied and its belt is not buckled. Bits above bit 4 are noise and must be ignored.
- If no seat is unbuckled, print `OK`.
- Otherwise print `UNBUCKLED:` followed by the unbuckled seat names in bit order (`DRIVER PASSENGER REAR_L REAR_C REAR_R`). If `speed >= 25` km/h, append ` CHIME`.

Validation reports that the warning works when the driver is alone, but as soon as there are passengers, unbuckled occupants are no longer reported. Find and fix the bug.

**Input**
- Line 1: `n`, the number of frames.
- Next `n` lines: `occupied buckled speed`. The two masks are in hex (no `0x`), the speed is decimal.

**Output**
- One line per frame as described above.

**Example**
```
Input:
1
02 01 10

Output:
UNBUCKLED: PASSENGER
```
@@@ constraints_md
- `1 <= n <= 100`
- Masks are `00`..`FF`, `0 <= speed <= 250`.
- Keep the structure of the program. The fix is one expression.
@@@ starter_code
#include <stdio.h>

typedef enum {
    SEAT_DRIVER    = 1u << 0,
    SEAT_PASSENGER = 1u << 1,
    SEAT_REAR_L    = 1u << 2,
    SEAT_REAR_C    = 1u << 3,
    SEAT_REAR_R    = 1u << 4
} SeatFlag;

#define SEAT_COUNT 5

static const SeatFlag seats[SEAT_COUNT] = {
    SEAT_DRIVER, SEAT_PASSENGER, SEAT_REAR_L, SEAT_REAR_C, SEAT_REAR_R
};
static const char *const seat_name[SEAT_COUNT] = {
    "DRIVER", "PASSENGER", "REAR_L", "REAR_C", "REAR_R"
};

static int seat_unbuckled(unsigned occupied, unsigned buckled, SeatFlag seat)
{
    return (occupied == seat) && !(buckled & seat);
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int f = 0; f < n; f++) {
        unsigned occupied, buckled;
        int speed;
        if (scanf("%x %x %d", &occupied, &buckled, &speed) != 3) break;

        occupied |= SEAT_DRIVER;            /* no mat sensor: always occupied */

        int any = 0;
        for (int i = 0; i < SEAT_COUNT; i++) {
            if (seat_unbuckled(occupied, buckled, seats[i])) {
                printf("%s %s", any ? "" : "UNBUCKLED:", seat_name[i]);
                any = 1;
            }
        }
        if (!any)
            printf("OK\n");
        else
            printf("%s\n", speed >= 25 ? " CHIME" : "");
    }
    return 0;
}
@@@ sample_input
2
00 00 30
01 01 50
@@@ sample_output
UNBUCKLED: DRIVER CHIME
OK

@@@ sample_input
1
02 01 10
@@@ sample_output
UNBUCKLED: PASSENGER

@@@ hidden_input
1
1F 00 25
@@@ hidden_output
UNBUCKLED: DRIVER PASSENGER REAR_L REAR_C REAR_R CHIME

@@@ hidden_input
1
1F 1F 120
@@@ hidden_output
OK

@@@ hidden_input
1
05 01 24
@@@ hidden_output
UNBUCKLED: REAR_L

@@@ hidden_input
1
00 1F 80
@@@ hidden_output
OK

@@@ hidden_input
3
08 00 0
18 08 60
10 11 60
@@@ hidden_output
UNBUCKLED: DRIVER REAR_C
UNBUCKLED: DRIVER REAR_R CHIME
OK

@@@ hidden_input
2
E0 E1 40
FF 00 40
@@@ hidden_output
OK
UNBUCKLED: DRIVER PASSENGER REAR_L REAR_C REAR_R CHIME

@@@ hint
Take the failing example by hand: `occupied` becomes `0x03` (driver + passenger). For `seat = SEAT_PASSENGER` (`0x02`), what does each half of the condition in `seat_unbuckled` evaluate to?
@@@ hint
`==` asks whether the **whole mask** equals one flag. To ask "is this flag's bit set in the mask?", use `&`. The buckled check already does that.
@@@ solution_code
#include <stdio.h>

typedef enum {
    SEAT_DRIVER    = 1u << 0,
    SEAT_PASSENGER = 1u << 1,
    SEAT_REAR_L    = 1u << 2,
    SEAT_REAR_C    = 1u << 3,
    SEAT_REAR_R    = 1u << 4
} SeatFlag;

#define SEAT_COUNT 5

static const SeatFlag seats[SEAT_COUNT] = {
    SEAT_DRIVER, SEAT_PASSENGER, SEAT_REAR_L, SEAT_REAR_C, SEAT_REAR_R
};
static const char *const seat_name[SEAT_COUNT] = {
    "DRIVER", "PASSENGER", "REAR_L", "REAR_C", "REAR_R"
};

static int seat_unbuckled(unsigned occupied, unsigned buckled, SeatFlag seat)
{
    return (occupied & seat) && !(buckled & seat);   /* FIX: test the bit with &, not the whole mask with == */
}

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1) return 0;

    for (int f = 0; f < n; f++) {
        unsigned occupied, buckled;
        int speed;
        if (scanf("%x %x %d", &occupied, &buckled, &speed) != 3) break;

        occupied |= SEAT_DRIVER;            /* no mat sensor: always occupied */

        int any = 0;
        for (int i = 0; i < SEAT_COUNT; i++) {
            if (seat_unbuckled(occupied, buckled, seats[i])) {
                printf("%s %s", any ? "" : "UNBUCKLED:", seat_name[i]);
                any = 1;
            }
        }
        if (!any)
            printf("OK\n");
        else
            printf("%s\n", speed >= 25 ? " CHIME" : "");
    }
    return 0;
}
@@@ explanation_md
**Bug.** `occupied == seat` is true only when the occupied mask contains **exactly** that one seat and nothing else. Because the driver bit is always forced on, `occupied` equals a single flag only when the driver is alone. With any passenger present, `0x03 == SEAT_PASSENGER` (`0x02`) and `0x03 == SEAT_DRIVER` (`0x01`) are both false, and every unbuckled occupant goes unreported. That is a safety-relevant silent failure.

**Fix.** Test membership with a bitwise AND: `(occupied & seat)`. It is non-zero exactly when that seat's bit is set, whatever the other bits are. The buckled check on the same line was already written correctly, which shows the inconsistency.

**Complexity.** Time O(n * SEAT_COUNT), space O(1).

**Common mistakes**
- `==` instead of `&` for a flag test. This is the bug here, and it passes every single-flag test case, which is why it survives unit tests.
- `&&` instead of `&`: `occupied && seat` is true whenever both are non-zero, so every seat would be reported as occupied.
- Testing several flags at once with `(mask & (A | B))` when you meant "both": that is true if **either** is set. "All of them" is `(mask & (A | B)) == (A | B)`.
- Forgetting that noise bits (`E0`) must be masked away when comparing whole masks. Testing individual bits with `&` ignores them for free.

**Interview follow-ups**
- Compute the whole unbuckled set in one expression, without a loop. (`occupied & ~buckled & SEAT_ALL_MASK`)
- Euro NCAP requires the chime to escalate after a time and to re-trigger when a belt is unbuckled while driving. Sketch the state machine you would add.
- Why do you think the flags are `1u << n` (unsigned) rather than `1 << n`? When does the difference matter?
