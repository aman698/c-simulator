@@@ meta
id: ENM-H-02
topic: Enums
difficulty: Hard
type: CODE
title: UDS Diagnostic Session Control With S3 Server Timeout
tags: embedded, uds, iso-14229, session-state-machine, timeout, asked-in-automotive
@@@ statement_md
Implement the session layer of a UDS (ISO 14229) server in an ECU. The server is in one of three sessions:

```c
typedef enum { SES_DEFAULT = 0x01, SES_PROGRAMMING = 0x02, SES_EXTENDED = 0x03 } UdsSession;
```

It starts in `DEFAULT` with vehicle speed 0.

**S3 server timer.** In a non-default session, if no request has been received for **5000 ms**, the server falls back to `DEFAULT`. Before handling **any** input line at time `t`: if the session is not `DEFAULT` and `t - t_last_request >= 5000`, switch to `DEFAULT` and print `<t_last_request + 5000>: S3 timeout -> DEFAULT`. Every `REQ` line, including ones answered with a negative response, sets `t_last_request = t` (after the S3 check).

**Services** (`b1` = SID, `n` = request length in bytes, `sub = b2 & 0x7F`, `SPR = b2 & 0x80` is the "suppress positive response" bit):

| SID | checks, in order (first failing check gives the NRC) | positive response |
|---|---|---|
| `10` DiagnosticSessionControl | `n == 2` else `13`; `sub` in {01,02,03} else `12`; target `PROGRAMMING` only from `EXTENDED` or `PROGRAMMING`, target `EXTENDED` not from `PROGRAMMING`, else `7E`; target `PROGRAMMING` needs speed == 0 else `22` | switch session; `50 <sub> 00 32 01 F4` |
| `3E` TesterPresent | `n == 2` else `13`; `sub == 00` else `12` | `7E 00` |
| `2E` WriteDataByIdentifier | session not `DEFAULT` else `7F`; `n >= 4` else `13` | `6E <b2> <b3>` |
| anything else | NRC `11` | |

- A negative response is printed as `<t>: 7F <SID> <NRC>`. It is printed even if the SPR bit is set.
- If `SPR` is set on `10` or `3E` and the request succeeds, the action still happens (session change, S3 reset) but **nothing is printed**.
- All bytes are printed as two uppercase hex digits.

**Input**
- Line 1: `q`. Next `q` lines, with non-decreasing `t` (ms), each one of:
  - `t REQ n b1 ... bn`: a request of `n` hex bytes;
  - `t SPEED v`: new vehicle speed (km/h);
  - `t TICK`: time passes (no request).

**Output**
- Response and timeout lines in order, then `final: <DEFAULT|PROGRAMMING|EXTENDED>`.

**Example**
```
Input:
6
0 REQ 2 10 03
1000 REQ 4 2E F1 90 41
4000 REQ 2 3E 00
8999 REQ 2 10 02
9000 TICK
14000 TICK

Output:
0: 50 03 00 32 01 F4
1000: 6E F1 90
4000: 7E 00
8999: 50 02 00 32 01 F4
13999: S3 timeout -> DEFAULT
final: DEFAULT
```
@@@ constraints_md
- `0 <= q <= 500`, `0 <= t <= 2*10^9`, `t` non-decreasing.
- `1 <= n <= 8`, bytes `00`..`FF`. `0 <= v <= 300`.
@@@ starter_code
#include <stdio.h>
#include <string.h>

typedef enum { SES_DEFAULT = 0x01, SES_PROGRAMMING = 0x02, SES_EXTENDED = 0x03 } UdsSession;

#define S3_TIMEOUT_MS 5000

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;

    UdsSession session = SES_DEFAULT;
    int speed = 0;
    int t_last = 0;

    for (int i = 0; i < q; i++) {
        int t;
        char kind[8];
        if (scanf("%d %7s", &t, kind) != 2) break;

        /* TODO: S3 check */

        if (strcmp(kind, "REQ") == 0) {
            int n;
            unsigned b[8] = { 0 };
            if (scanf("%d", &n) != 1) break;
            for (int k = 0; k < n; k++) scanf("%x", &b[k]);
            /* TODO: handle the request */
        } else if (strcmp(kind, "SPEED") == 0) {
            if (scanf("%d", &speed) != 1) break;
        }
    }
    printf("final: %s\n", session == SES_DEFAULT ? "DEFAULT" : session == SES_PROGRAMMING ? "PROGRAMMING" : "EXTENDED");
    (void)t_last;
    return 0;
}
@@@ sample_input
6
0 REQ 2 10 03
1000 REQ 4 2E F1 90 41
4000 REQ 2 3E 00
8999 REQ 2 10 02
9000 TICK
14000 TICK
@@@ sample_output
0: 50 03 00 32 01 F4
1000: 6E F1 90
4000: 7E 00
8999: 50 02 00 32 01 F4
13999: S3 timeout -> DEFAULT
final: DEFAULT

@@@ sample_input
7
0 REQ 2 10 02
10 REQ 3 2E F1 90
20 REQ 2 10 83
30 SPEED 20
40 REQ 2 10 02
50 REQ 1 10
60 REQ 2 22 F1
@@@ sample_output
0: 7F 10 7E
10: 7F 2E 7F
40: 7F 10 22
50: 7F 10 13
60: 7F 22 11
final: EXTENDED

@@@ hidden_input
3
100 REQ 2 10 03
5100 REQ 4 2E 01 02 03
5101 TICK
@@@ hidden_output
100: 50 03 00 32 01 F4
5100: S3 timeout -> DEFAULT
5100: 7F 2E 7F
final: DEFAULT

@@@ hidden_input
3
100 REQ 2 10 03
5099 REQ 4 2E 01 02 03
10098 TICK
@@@ hidden_output
100: 50 03 00 32 01 F4
5099: 6E 01 02
final: EXTENDED

@@@ hidden_input
5
0 REQ 2 10 03
4000 REQ 2 3E 80
8000 REQ 2 3E 80
12000 REQ 2 3E 00
17000 TICK
@@@ hidden_output
0: 50 03 00 32 01 F4
12000: 7E 00
17000: S3 timeout -> DEFAULT
final: DEFAULT

@@@ hidden_input
6
0 REQ 2 10 03
10 REQ 2 10 02
20 REQ 2 10 03
30 REQ 2 3E 01
40 REQ 2 10 04
50 REQ 2 10 01
@@@ hidden_output
0: 50 03 00 32 01 F4
10: 50 02 00 32 01 F4
20: 7F 10 7E
30: 7F 3E 12
40: 7F 10 12
50: 50 01 00 32 01 F4
final: DEFAULT

@@@ hidden_input
0
@@@ hidden_output
final: DEFAULT

@@@ hidden_input
5
0 REQ 2 10 03
4999 REQ 1 3E
9998 REQ 2 99 00
14997 TICK
14998 TICK
@@@ hidden_output
0: 50 03 00 32 01 F4
4999: 7F 3E 13
9998: 7F 99 11
14998: S3 timeout -> DEFAULT
final: DEFAULT

@@@ hidden_input
6
0 SPEED 50
10 REQ 2 10 03
20 REQ 2 10 03
30 SPEED 0
40 REQ 2 10 82
50 REQ 2 10 02
@@@ hidden_output
10: 50 03 00 32 01 F4
20: 50 03 00 32 01 F4
50: 50 02 00 32 01 F4
final: PROGRAMMING

@@@ hidden_input
3
1000000000 REQ 2 10 03
1000000001 REQ 3 2E F1 90
1000005001 REQ 2 3E 00
@@@ hidden_output
1000000000: 50 03 00 32 01 F4
1000000001: 7F 2E 13
1000005001: S3 timeout -> DEFAULT
1000005001: 7E 00
final: DEFAULT

@@@ hint
Structure each line as: (1) the S3 check, which depends only on the session and `t - t_last`; (2) if it is a request, set `t_last = t`; (3) dispatch on the SID; (4) inside each service, run the NRC checks in the given order with early `return`s from a helper function.
@@@ hint
Keep the session-transition rule as one small function, `int session_allowed(UdsSession from, int target)`. Remember that the SPR bit is masked off **before** the sub-function checks (`10 83` is a valid request for `EXTENDED`), and that NRCs are printed even when SPR is set.
@@@ solution_code
#include <stdio.h>
#include <string.h>

typedef enum { SES_DEFAULT = 0x01, SES_PROGRAMMING = 0x02, SES_EXTENDED = 0x03 } UdsSession;

#define S3_TIMEOUT_MS 5000
#define SPR_BIT 0x80u

static UdsSession session = SES_DEFAULT;
static int speed = 0;

static void nrc(int t, unsigned sid, unsigned code)
{
    printf("%d: 7F %02X %02X\n", t, sid, code);
}

static int session_allowed(UdsSession from, unsigned target)
{
    if (target == SES_PROGRAMMING) return from == SES_EXTENDED || from == SES_PROGRAMMING;
    if (target == SES_EXTENDED)    return from != SES_PROGRAMMING;
    return 1;                                   /* DEFAULT is always reachable */
}

static void handle_dsc(int t, int n, const unsigned *b)
{
    if (n != 2) { nrc(t, 0x10, 0x13); return; }
    unsigned sub = b[1] & 0x7Fu;
    if (sub < SES_DEFAULT || sub > SES_EXTENDED) { nrc(t, 0x10, 0x12); return; }
    if (!session_allowed(session, sub)) { nrc(t, 0x10, 0x7E); return; }
    if (sub == SES_PROGRAMMING && speed != 0) { nrc(t, 0x10, 0x22); return; }
    session = (UdsSession)sub;
    if (!(b[1] & SPR_BIT))
        printf("%d: 50 %02X 00 32 01 F4\n", t, sub);   /* P2 = 50 ms, P2* = 500 x 10 ms */
}

static void handle_tester_present(int t, int n, const unsigned *b)
{
    if (n != 2) { nrc(t, 0x3E, 0x13); return; }
    if ((b[1] & 0x7Fu) != 0) { nrc(t, 0x3E, 0x12); return; }
    if (!(b[1] & SPR_BIT))
        printf("%d: 7E 00\n", t);
}

static void handle_wdbi(int t, int n, const unsigned *b)
{
    if (session == SES_DEFAULT) { nrc(t, 0x2E, 0x7F); return; }
    if (n < 4) { nrc(t, 0x2E, 0x13); return; }
    printf("%d: 6E %02X %02X\n", t, b[1], b[2]);
}

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    int t_last = 0;

    for (int i = 0; i < q; i++) {
        int t;
        char kind[8];
        if (scanf("%d %7s", &t, kind) != 2) break;

        /* 1) S3: evaluated before anything else on this line */
        if (session != SES_DEFAULT && t - t_last >= S3_TIMEOUT_MS) {
            session = SES_DEFAULT;
            printf("%d: S3 timeout -> DEFAULT\n", t_last + S3_TIMEOUT_MS);
        }

        if (strcmp(kind, "REQ") == 0) {
            int n;
            unsigned b[8] = { 0 };
            if (scanf("%d", &n) != 1 || n < 1 || n > 8) break;
            for (int k = 0; k < n; k++)
                if (scanf("%x", &b[k]) != 1) return 0;

            t_last = t;                          /* 2) any request restarts S3 */
            switch (b[0]) {                      /* 3) dispatch on SID */
            case 0x10: handle_dsc(t, n, b); break;
            case 0x3E: handle_tester_present(t, n, b); break;
            case 0x2E: handle_wdbi(t, n, b); break;
            default:   nrc(t, b[0], 0x11); break;
            }
        } else if (strcmp(kind, "SPEED") == 0) {
            if (scanf("%d", &speed) != 1) break;
        }
        /* TICK: only lets time pass */
    }
    printf("final: %s\n", session == SES_DEFAULT ? "DEFAULT" : session == SES_PROGRAMMING ? "PROGRAMMING" : "EXTENDED");
    return 0;
}
@@@ explanation_md
**Approach.** Treat it as three layers, which is how real UDS stacks (for example AUTOSAR Dcm) are structured:
1. **Timer layer.** The S3 check runs before every input line and depends only on `session` and `t - t_last`. The timeout instant is `t_last + 5000`, and that is the time printed, not the time of the line that noticed it. "At least 5000 ms" means `>=`, so a request at exactly `t_last + 5000` is already handled in `DEFAULT` (hidden test: `2E` at 5100 gets `7F 2E 7F`).
2. **Dispatcher.** A `switch` on the SID, where unknown SIDs get `11`. Every request, positive or negative, restarts S3.
3. **Service handlers.** Each one runs its NRC checks in the specified order with early returns, so exactly one response line is produced. The session-transition matrix lives in one function (`session_allowed`), which is the piece an OEM changes most often.

Using the protocol values (`0x01..0x03`) as the enum values means the sub-function maps directly to `UdsSession` **after** it has been range-checked.

**Complexity.** Time O(q · n), space O(1).

**Common mistakes**
- Printing the timeout at the current line's time instead of `t_last + 5000`, or using `>` (one-off at the boundary).
- Restarting S3 only on positive responses or only on `3E`. Any received request restarts it.
- Forgetting to mask `0x80` before checking the sub-function, so `10 83` gets NRC `12`, or suppressing negative responses when SPR is set.
- Casting `b[1]` to `UdsSession` before validating it. `(UdsSession)0x04` is a perfectly representable but meaningless session.
- Applying S3 in `DEFAULT` (there is nothing to time out), or running the check only on `TICK` lines.

**Interview follow-ups**
- Security access (`27`) state must be reset on every session change. Where would you hook that in?
- What is `NRC 0x78` (response pending), and how does P2* interact with the S3 timer while a long `31` routine runs?
- On a real ECU, entering the programming session usually means a jump to the bootloader. How is that hand-over done safely (flags in no-init RAM, ECU reset)?
- How would you make the NRC check order data-driven so it matches ISO 14229-1 Figure 5 for every service?
