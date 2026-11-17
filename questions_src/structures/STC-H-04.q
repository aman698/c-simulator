@@@ meta
id: STC-H-04
topic: Structures
difficulty: Hard
type: FUNCTION
title: UDS Diagnostic Server with Negative Response Codes
tags: embedded, uds, iso-14229, diagnostics, state-machine, struct-state, asked-in-automotive
@@@ statement_md
Implement a small **UDS (ISO 14229) diagnostic server**. It parses one request, updates the ECU state held in a struct, and builds the response:

```c
struct UdsEcu {
    uint8_t  session;     /* 0x01 default, 0x02 programming, 0x03 extended   */
    uint8_t  unlocked;    /* 1 = security access granted                     */
    uint8_t  seed_sent;   /* 1 = a seed was sent and no key was tried yet    */
    uint8_t  speed_kph;   /* vehicle speed, set by the harness               */
    uint16_t seed;        /* seed returned by 27 01                          */
    uint32_t odometer;    /* DID 0x0101                                      */
    uint8_t  vin[17];     /* DID 0xF190                                      */
};

size_t uds_process(struct UdsEcu *ecu, const uint8_t *req, size_t len, uint8_t *rsp);
```

It returns the response length (0 = send nothing). A positive response starts with `SID + 0x40`. A negative response is exactly `7F <SID> <NRC>`. `rsp` has room for 64 bytes.

**Supported services**

| SID | service | sessions | sub-functions |
|---|---|---|---|
| `10` | DiagnosticSessionControl | all | `01`, `02`, `03` |
| `22` | ReadDataByIdentifier | all | - |
| `27` | SecurityAccess | extended (`03`) only | `01` requestSeed, `02` sendKey |
| `2E` | WriteDataByIdentifier | extended (`03`) only | - |
| `3E` | TesterPresent | all | `00` |

**Checks, in this exact order (stop at the first failure):**
1. `len == 0`: return 0.
2. SID not in the table: NRC `11` (serviceNotSupported).
3. SID not allowed in the current session: NRC `7F` (serviceNotSupportedInActiveSession).
4. Service has a sub-function and `len < 2`: NRC `13` (incorrectMessageLengthOrInvalidFormat).
5. Sub-function not supported: NRC `12`. For `10` and `3E`, bit 7 is the *suppressPosRspMsgIndicationBit* (SPRMIB) and the sub-function is `req[1] & 0x7F`. For `27`, the raw byte is used (`81` is unsupported).
6. `10 02` when the current session is default (`01`): NRC `7E` (subFunctionNotSupportedInActiveSession).
7. Length: `10`, `3E`, `27 01` need exactly 2 bytes; `27 02` exactly 4; `22` exactly 3; `2E` at least 3. Otherwise NRC `13`.
8. Service-specific checks:
   - `10 02`: `speed_kph != 0` gives NRC `22` (conditionsNotCorrect).
   - `22`: DID not in {`F190`, `0101`, `F186`, `0200`} gives `31` (requestOutOfRange). DID `0200` while locked gives `33` (securityAccessDenied).
   - `27 02`: no seed pending gives `24` (requestSequenceError). Key != `seed ^ 0x5A5A` gives `35` (invalidKey) and clears `seed_sent`.
   - `2E`: DID != `0101` gives `31`; `len != 7` gives `13`; locked gives `33`; `speed_kph != 0` gives `22`; new value < `odometer` gives `31`.

**Positive responses**
- `10 xx`: `50 xx 00 32 01 F4` (P2 = 50 ms, P2* = 5000 ms). Set `session`, and clear `unlocked` and `seed_sent`.
- `22`: `62 <DID> <data>`. `F190` = 17 VIN bytes; `0101` = odometer as 4 bytes big-endian; `F186` = 1 byte, the session; `0200` = `CA FE`.
- `27 01`: `67 01 <seed hi> <seed lo>` and set `seed_sent`. If already unlocked, reply `67 01 00 00` and do not set `seed_sent`.
- `27 02` (correct key, big-endian in `req[2..3]`): `67 02`, set `unlocked`, clear `seed_sent`.
- `2E 01 01 b3 b2 b1 b0`: store the big-endian value in `odometer`; reply `6E 01 01`.
- `3E 00`: `7E 00`.
- If SPRMIB was set (`10`/`3E`) and the outcome is **positive**, apply the effects but return 0. Negative responses are always sent.

**How it is tested.** The harness starts with `session=01`, locked, `seed=0x1234`, `odometer=123456`, `speed=0`, `vin="SIMVIN00000000042"`. Input lines are `REQ <hex bytes...>` (possibly no bytes) or `SPEED <km/h>`. For every `REQ` it prints `-> <response bytes>` or `-> (none)`. At the end it prints `state: session=SS unlocked=U odometer=N`.

**Example**
```
Input:
REQ 22 F1 90
REQ 10 03
REQ 27 01
REQ 27 02 48 6E
REQ 2E 01 01 00 01 E2 50
REQ 22 01 01

Output:
-> 62 F1 90 53 49 4D 56 49 4E 30 30 30 30 30 30 30 30 30 34 32
-> 50 03 00 32 01 F4
-> 67 01 12 34
-> 67 02
-> 6E 01 01
-> 62 01 01 00 01 E2 50
state: session=03 unlocked=1 odometer=123472
```
@@@ constraints_md
- Requests are 0..32 bytes; at most 100 lines per test.
- Never write more than 64 bytes to `rsp`, and do not read beyond `req[len-1]`.
- Treat `req` as read-only.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* Already defined by the judge:
 *
 * struct UdsEcu {
 *     uint8_t session, unlocked, seed_sent, speed_kph;
 *     uint16_t seed;
 *     uint32_t odometer;
 *     uint8_t vin[17];
 * };
 */

size_t uds_process(struct UdsEcu *ecu, const uint8_t *req, size_t len, uint8_t *rsp)
{
    /* TODO: follow the check order exactly */
    (void)ecu;
    (void)req;
    (void)len;
    (void)rsp;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

struct UdsEcu {
    uint8_t  session;
    uint8_t  unlocked;
    uint8_t  seed_sent;
    uint8_t  speed_kph;
    uint16_t seed;
    uint32_t odometer;
    uint8_t  vin[17];
};

/*USER_CODE*/

int main(void)
{
    struct UdsEcu ecu;
    char line[256];
    memset(&ecu, 0, sizeof ecu);
    ecu.session = 0x01;
    ecu.seed = 0x1234;
    ecu.odometer = 123456;
    memcpy(ecu.vin, "SIMVIN00000000042", 17);

    while (fgets(line, sizeof line, stdin)) {
        char cmd[8];
        int off = 0;
        if (sscanf(line, "%7s%n", cmd, &off) != 1) continue;
        if (strcmp(cmd, "SPEED") == 0) {
            unsigned v;
            if (sscanf(line + off, "%u", &v) == 1) ecu.speed_kph = (uint8_t)v;
            continue;
        }
        if (strcmp(cmd, "REQ") != 0) continue;
        uint8_t req[40];
        size_t len = 0;
        unsigned b;
        int used;
        const char *p = line + off;
        while (len < 32 && sscanf(p, "%x%n", &b, &used) == 1) {
            req[len++] = (uint8_t)b;
            p += used;
        }
        uint8_t *hreq = malloc(len ? len : 1);      /* exact-size heap copy: over-reads are caught */
        if (!hreq) return 0;
        memcpy(hreq, req, len);
        uint8_t rsp[64 + 16];
        memset(rsp, 0xA5, sizeof rsp);
        size_t n = uds_process(&ecu, len ? hreq : NULL, len, rsp);
        int canary_ok = 1;
        for (size_t i = 64; i < sizeof rsp; i++)
            if (rsp[i] != 0xA5) canary_ok = 0;
        int modified = memcmp(req, hreq, len) != 0;
        free(hreq);
        if (!canary_ok || n > 64) { printf("OUT OF BOUNDS WRITE\n"); return 0; }
        if (modified) printf("REQUEST MODIFIED\n");
        printf("->");
        if (n == 0) printf(" (none)");
        for (size_t i = 0; i < n; i++) printf(" %02X", (unsigned)rsp[i]);
        printf("\n");
    }
    printf("state: session=%02X unlocked=%u odometer=%u\n",
           (unsigned)ecu.session, (unsigned)ecu.unlocked, (unsigned)ecu.odometer);
    return 0;
}
@@@ sample_input
REQ 22 F1 90
REQ 10 03
REQ 27 01
REQ 27 02 48 6E
REQ 2E 01 01 00 01 E2 50
REQ 22 01 01
@@@ sample_output
-> 62 F1 90 53 49 4D 56 49 4E 30 30 30 30 30 30 30 30 30 34 32
-> 50 03 00 32 01 F4
-> 67 01 12 34
-> 67 02
-> 6E 01 01
-> 62 01 01 00 01 E2 50
state: session=03 unlocked=1 odometer=123472

@@@ sample_input
REQ 19 02 FF
REQ 27 01
REQ 10 02
REQ 10
REQ 10 04
REQ 3E 80
REQ
@@@ sample_output
-> 7F 19 11
-> 7F 27 7F
-> 7F 10 7E
-> 7F 10 13
-> 7F 10 12
-> (none)
-> (none)
state: session=01 unlocked=0 odometer=123456

@@@ hidden_input
REQ 22 F1
REQ 22 F1 90 00
REQ 3E 00 00
REQ 10 03 00
REQ 3E 01
REQ 10 05 00
REQ 22 12 34
REQ 22 02 00
REQ 22 F1 86
REQ 22
@@@ hidden_output
-> 7F 22 13
-> 7F 22 13
-> 7F 3E 13
-> 7F 10 13
-> 7F 3E 12
-> 7F 10 12
-> 7F 22 31
-> 7F 22 33
-> 62 F1 86 01
-> 7F 22 13
state: session=01 unlocked=0 odometer=123456

@@@ hidden_input
REQ 27 01
REQ 10 03
REQ 27 02 48 6E
REQ 27 01
REQ 27 02 00 00
REQ 27 02 48 6E
REQ 27 01
REQ 27 02 48 6E
REQ 27 01
REQ 22 02 00
REQ 10 03
REQ 22 02 00
REQ 27 03
REQ 27 81
REQ 27
REQ 27 01 00
REQ 27 02 48
@@@ hidden_output
-> 7F 27 7F
-> 50 03 00 32 01 F4
-> 7F 27 24
-> 67 01 12 34
-> 7F 27 35
-> 7F 27 24
-> 67 01 12 34
-> 67 02
-> 67 01 00 00
-> 62 02 00 CA FE
-> 50 03 00 32 01 F4
-> 7F 22 33
-> 7F 27 12
-> 7F 27 12
-> 7F 27 13
-> 7F 27 13
-> 7F 27 13
state: session=03 unlocked=0 odometer=123456

@@@ hidden_input
REQ 2E 01 01 00 01 E2 40
REQ 10 03
REQ 2E 01 01
REQ 2E F1 90 00 00 00 00
REQ 2E 01 01 00 01 E2 41
REQ 27 01
REQ 27 02 48 6E
SPEED 5
REQ 2E 01 01 00 01 E2 41
SPEED 0
REQ 2E 01 01 00 00 00 01
REQ 2E 01 01 00 01 E2 40
REQ 2E 01 01 FF FF FF FF
REQ 22 01 01
REQ 2E 01
@@@ hidden_output
-> 7F 2E 7F
-> 50 03 00 32 01 F4
-> 7F 2E 13
-> 7F 2E 31
-> 7F 2E 33
-> 67 01 12 34
-> 67 02
-> 7F 2E 22
-> 7F 2E 31
-> 6E 01 01
-> 6E 01 01
-> 62 01 01 FF FF FF FF
-> 7F 2E 13
state: session=03 unlocked=1 odometer=4294967295

@@@ hidden_input
REQ 10 03
SPEED 30
REQ 10 02
SPEED 0
REQ 10 02
REQ 27 01
REQ 10 82
REQ 22 F1 86
REQ 10 81
REQ 22 F1 86
REQ 10 02
@@@ hidden_output
-> 50 03 00 32 01 F4
-> 7F 10 22
-> 50 02 00 32 01 F4
-> 7F 27 7F
-> (none)
-> 62 F1 86 02
-> (none)
-> 62 F1 86 01
-> 7F 10 7E
state: session=01 unlocked=0 odometer=123456

@@@ hidden_input
REQ 3E 81
REQ 10 84
REQ 3E 00
REQ 3E 80 00
REQ 00
REQ FF 01
REQ 7F
REQ 2E
REQ 10 83
REQ 2E
REQ 2E 01
@@@ hidden_output
-> 7F 3E 12
-> 7F 10 12
-> 7E 00
-> 7F 3E 13
-> 7F 00 11
-> 7F FF 11
-> 7F 7F 11
-> 7F 2E 7F
-> (none)
-> 7F 2E 13
-> 7F 2E 13
state: session=03 unlocked=0 odometer=123456

@@@ hidden_input
REQ 10 03
REQ 27 01
REQ 27 02 48 6E
REQ 10 02
REQ 22 02 00
REQ 10 03
REQ 27 02 48 6E
REQ 22 F1 90
@@@ hidden_output
-> 50 03 00 32 01 F4
-> 67 01 12 34
-> 67 02
-> 50 02 00 32 01 F4
-> 7F 22 33
-> 50 03 00 32 01 F4
-> 7F 27 24
-> 62 F1 90 53 49 4D 56 49 4E 30 30 30 30 30 30 30 30 30 34 32
state: session=03 unlocked=0 odometer=123456

@@@ hint
Write one helper `static size_t nrc(uint8_t *rsp, uint8_t sid, uint8_t code)` that writes `7F sid code` and returns 3. Then code the checks top-down in exactly the listed order, using a `switch` on the SID only after the generic checks (steps 2 to 7).
@@@ hint
Keep `suppress = (sid == 0x10 || sid == 0x3E) && (req[1] & 0x80)` and `sub = req[1] & 0x7F` for those two services. Build the positive response, apply the state change, and only at the very end `return suppress ? 0 : n;`. Assemble big-endian values with shifts, never with `memcpy` of a `uint32_t`.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define NRC_SNS    0x11u   /* serviceNotSupported                     */
#define NRC_SFNS   0x12u   /* subFunctionNotSupported                 */
#define NRC_IMLOIF 0x13u   /* incorrectMessageLengthOrInvalidFormat   */
#define NRC_CNC    0x22u   /* conditionsNotCorrect                    */
#define NRC_RSE    0x24u   /* requestSequenceError                    */
#define NRC_ROOR   0x31u   /* requestOutOfRange                       */
#define NRC_SAD    0x33u   /* securityAccessDenied                    */
#define NRC_IK     0x35u   /* invalidKey                              */
#define NRC_SFNSIAS 0x7Eu  /* subFunctionNotSupportedInActiveSession  */
#define NRC_SNSIAS 0x7Fu   /* serviceNotSupportedInActiveSession      */

static size_t nrc(uint8_t *rsp, uint8_t sid, uint8_t code)
{
    rsp[0] = 0x7F;
    rsp[1] = sid;
    rsp[2] = code;
    return 3;
}

static void put_be32(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);  p[3] = (uint8_t)v;
}

size_t uds_process(struct UdsEcu *ecu, const uint8_t *req, size_t len, uint8_t *rsp)
{
    if (len == 0)
        return 0;                                            /* 1 */
    uint8_t sid = req[0];
    int has_sub = (sid == 0x10 || sid == 0x27 || sid == 0x3E);

    if (sid != 0x10 && sid != 0x22 && sid != 0x27 && sid != 0x2E && sid != 0x3E)
        return nrc(rsp, sid, NRC_SNS);                       /* 2 */
    if ((sid == 0x27 || sid == 0x2E) && ecu->session != 0x03)
        return nrc(rsp, sid, NRC_SNSIAS);                    /* 3 */
    if (has_sub && len < 2)
        return nrc(rsp, sid, NRC_IMLOIF);                    /* 4 */

    int suppress = 0;
    uint8_t sub = 0;
    if (has_sub) {
        sub = req[1];
        if (sid != 0x27) {                                   /* SPRMIB only for 10 / 3E */
            suppress = (sub & 0x80u) != 0;
            sub &= 0x7Fu;
        }
        int ok = (sid == 0x10) ? (sub >= 0x01 && sub <= 0x03)
               : (sid == 0x27) ? (sub == 0x01 || sub == 0x02)
               : (sub == 0x00);
        if (!ok)
            return nrc(rsp, sid, NRC_SFNS);                  /* 5 */
        if (sid == 0x10 && sub == 0x02 && ecu->session == 0x01)
            return nrc(rsp, sid, NRC_SFNSIAS);               /* 6 */
    }

    size_t need_exact = 0, need_min = 0;                     /* 7 */
    switch (sid) {
    case 0x10: case 0x3E: need_exact = 2; break;
    case 0x27: need_exact = (sub == 0x01) ? 2 : 4; break;
    case 0x22: need_exact = 3; break;
    case 0x2E: need_min = 3; break;
    }
    if ((need_exact && len != need_exact) || len < need_min)
        return nrc(rsp, sid, NRC_IMLOIF);

    size_t n = 0;                                            /* 8 */
    switch (sid) {
    case 0x10:
        if (sub == 0x02 && ecu->speed_kph != 0)
            return nrc(rsp, sid, NRC_CNC);
        ecu->session = sub;
        ecu->unlocked = 0;
        ecu->seed_sent = 0;
        rsp[0] = 0x50; rsp[1] = sub;
        rsp[2] = 0x00; rsp[3] = 0x32; rsp[4] = 0x01; rsp[5] = 0xF4;
        n = 6;
        break;

    case 0x22: {
        uint16_t did = (uint16_t)(req[1] << 8 | req[2]);
        rsp[0] = 0x62; rsp[1] = req[1]; rsp[2] = req[2];
        if (did == 0xF190) {
            memcpy(rsp + 3, ecu->vin, sizeof ecu->vin);
            n = 3 + sizeof ecu->vin;
        } else if (did == 0x0101) {
            put_be32(rsp + 3, ecu->odometer);
            n = 7;
        } else if (did == 0xF186) {
            rsp[3] = ecu->session;
            n = 4;
        } else if (did == 0x0200) {
            if (!ecu->unlocked)
                return nrc(rsp, sid, NRC_SAD);
            rsp[3] = 0xCA; rsp[4] = 0xFE;
            n = 5;
        } else {
            return nrc(rsp, sid, NRC_ROOR);
        }
        break;
    }

    case 0x27:
        if (sub == 0x01) {
            rsp[0] = 0x67; rsp[1] = 0x01;
            if (ecu->unlocked) {
                rsp[2] = 0; rsp[3] = 0;                      /* already unlocked: zero seed */
            } else {
                rsp[2] = (uint8_t)(ecu->seed >> 8); rsp[3] = (uint8_t)ecu->seed;
                ecu->seed_sent = 1;
            }
            n = 4;
        } else {
            if (!ecu->seed_sent)
                return nrc(rsp, sid, NRC_RSE);
            uint16_t key = (uint16_t)(req[2] << 8 | req[3]);
            ecu->seed_sent = 0;                              /* one attempt per seed */
            if (key != (uint16_t)(ecu->seed ^ 0x5A5Au))
                return nrc(rsp, sid, NRC_IK);
            ecu->unlocked = 1;
            rsp[0] = 0x67; rsp[1] = 0x02;
            n = 2;
        }
        break;

    case 0x2E: {
        uint16_t did = (uint16_t)(req[1] << 8 | req[2]);
        if (did != 0x0101)          return nrc(rsp, sid, NRC_ROOR);
        if (len != 7)               return nrc(rsp, sid, NRC_IMLOIF);
        if (!ecu->unlocked)         return nrc(rsp, sid, NRC_SAD);
        if (ecu->speed_kph != 0)    return nrc(rsp, sid, NRC_CNC);
        uint32_t v = (uint32_t)req[3] << 24 | (uint32_t)req[4] << 16 | (uint32_t)req[5] << 8 | req[6];
        if (v < ecu->odometer)      return nrc(rsp, sid, NRC_ROOR);
        ecu->odometer = v;
        rsp[0] = 0x6E; rsp[1] = req[1]; rsp[2] = req[2];
        n = 3;
        break;
    }

    case 0x3E:
        rsp[0] = 0x7E; rsp[1] = 0x00;
        n = 2;
        break;
    }
    return suppress ? 0 : n;
}
@@@ explanation_md
**Approach.** A UDS server is a **validation pipeline** followed by a dispatcher. The ISO 14229-1 "general server response behaviour" fixes the order of the generic checks: SID supported, then SID allowed in this session, then minimum length, then sub-function supported, then sub-function allowed in this session, then full length, then service-specific checks. Interviewers test this order deliberately. For example, `10 05 00` must answer `12`, not `13`, and `2E` alone in the default session must answer `7F`, not `13`.

The persistent state (session, security, pending seed, odometer) lives in one `struct UdsEcu`, so the function is re-entrant and easy to unit-test. All multi-byte values on the wire are **big-endian** and are assembled with shifts.

```
10 82  -> SPRMIB=1, sub=02: positive -> session=02, but no response is sent
27 02 00 00 (wrong key) -> 7F 27 35 and the seed is consumed: the next key without a new seed -> 7F 27 24
2E 01 01 00 00 00 01 (unlocked, speed 0) -> value below odometer -> 7F 2E 31
```

**Complexity.** O(len) per request (at most a 17-byte copy). Space O(1).

**Common mistakes**
- Checking the length before the sub-function (`10 05 00` must give `12`), or the session after the length.
- Applying SPRMIB to negative responses. Negatives are always sent.
- Forgetting that a positive `10 xx` re-locks security, even when you re-enter the same session.
- Leaving `seed_sent` set after a wrong key. That allows unlimited brute-force attempts per seed.
- Writing the odometer with `memcpy(&ecu->odometer, req + 3, 4)`. On a little-endian MCU, `00 01 E2 50` becomes 0x50E20100.
- Reading `req[1]` before checking `len >= 2`. For `REQ 10` the harness passes a 1-byte buffer.

**Interview follow-ups**
- How does a real ECU handle a request it cannot answer within P2 = 50 ms? (NRC `78` responsePending, then the final response within P2*.)
- What should happen after 3 wrong keys? (NRC `36` exceededNumberOfAttempts, then a delay timer with NRC `37` requiredTimeDelayNotExpired.)
- With **functional** addressing (`0x7DF`), which NRCs must be suppressed? (`11`, `12`, `31`, `7E`, `7F`.)
- How would you make the service table data-driven (array of `struct { sid; session_mask; handler; }`) instead of a `switch`?
