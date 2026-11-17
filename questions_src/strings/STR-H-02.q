@@@ meta
id: STR-H-02
topic: Strings
difficulty: Hard
type: FUNCTION
title: Parse a Modem AT+CSQ Response from a UART Buffer
tags: embedded, at-commands, modem, uart, response-parser, telematics, asked-in-automotive
@@@ statement_md
The telematics unit sends `AT+CSQ` (signal quality) to its LTE modem and collects the reply in a UART receive buffer. Write the parser that the modem driver calls whenever new bytes arrive:

```c
/* return codes - already defined by the hidden harness */
#define AT_OK          0
#define AT_ERROR       1
#define AT_CME_ERROR   2
#define AT_INCOMPLETE  3
#define AT_BAD_FORMAT  4

int at_parse_csq(const char *buf, int *rssi_dbm, int *ber, int *cme);
```

`buf` is everything received so far, as a NUL-terminated string. A typical complete reply, with command echo enabled, is
`"AT+CSQ\r\r\n+CSQ: 23,0\r\n\r\nOK\r\n"`.

**Rules**
1. A **line** is the text before a `"\r\n"`. Only complete lines count: a trailing fragment without `"\r\n"` (for example `"OK"` that is still arriving) is ignored.
2. Scan the complete lines in order. The **first final result code** decides the answer:
   - a line exactly `OK` -> see rule 3;
   - a line exactly `ERROR` -> return `AT_ERROR`;
   - a line starting with `+CME ERROR: ` -> return `AT_CME_ERROR`. Set `*cme` to the number if the rest is 1-3 decimal digits, otherwise to `-1` (verbose text such as `SIM not inserted`).
3. On `OK`, use the **last** line starting with `+CSQ: ` that came **before** the `OK`. It must be exactly `+CSQ: <rssi>,<ber>`, where both numbers have 1-2 decimal digits, `rssi` is in `0..31` or `99`, and `ber` is in `0..7` or `99`. Then set `*rssi_dbm = -113 + 2*rssi` (or `0` when `rssi == 99`, which means unknown), set `*ber = ber` and return `AT_OK`. If the line is missing or malformed, return `AT_BAD_FORMAT`.
4. All other lines (the echo, empty lines, unsolicited result codes such as `RING`, `+CREG: 1`, `+CMTI: "SM",3`) are ignored.
5. If no complete line is a final result code, return `AT_INCOMPLETE` (the driver waits for more bytes).
6. `buf == NULL` returns `AT_BAD_FORMAT`. `buf` must not be modified.

Write the output parameters only together with the return code they belong to.

**How it is tested.** For each buffer, a hidden `main()` calls your function and prints `OK rssi=<n>dBm ber=<b>` (or `rssi=unknown`), `ERROR`, `CME ERROR <n>`, `INCOMPLETE` or `BAD FORMAT`. It also checks that the buffer was not modified.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: the buffer as a C string literal in double quotes (escapes `\r`, `\n`, `\"`, `\\`), or `NULL`.

**Example**
```
Input:
4
"AT+CSQ\r\r\n+CSQ: 23,0\r\n\r\nOK\r\n"
"\r\nERROR\r\n"
"\r\n+CSQ: 23,0\r\n\r\nOK"
"\r\n+CME ERROR: 10\r\n"

Output:
OK rssi=-67dBm ber=0
ERROR
INCOMPLETE
CME ERROR 10
```
@@@ constraints_md
- `1 <= q <= 20`, each buffer has at most 400 bytes.
- `<string.h>` is allowed. The function must not modify `buf` and must not read past its terminator.
- O(n) time in the buffer length, O(1) extra space.
@@@ starter_code
#include <stddef.h>
#include <string.h>

/* AT_OK, AT_ERROR, AT_CME_ERROR, AT_INCOMPLETE, AT_BAD_FORMAT are defined by the harness. */
int at_parse_csq(const char *buf, int *rssi_dbm, int *ber, int *cme)
{
    /* TODO */
    (void)buf; (void)rssi_dbm; (void)ber; (void)cme;
    return AT_INCOMPLETE;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define AT_OK          0
#define AT_ERROR       1
#define AT_CME_ERROR   2
#define AT_INCOMPLETE  3
#define AT_BAD_FORMAT  4

/*USER_CODE*/

static char line[1024];
static char buf[512], copy[512];

/* decode a C-style quoted string: \r \n \" \\ */
static void unquote(const char *p, char *out, size_t cap)
{
    size_t n = 0;
    p = strchr(p, '"');
    if (!p) { out[0] = '\0'; return; }
    p++;
    while (*p && *p != '"') {
        char c = *p++;
        if (c == '\\' && *p) {
            char e = *p++;
            c = e == 'r' ? '\r' : e == 'n' ? '\n' : e;
        }
        if (n + 1 < cap) out[n++] = c;
    }
    out[n] = '\0';
}

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        const char *arg = NULL;
        if (strncmp(line, "NULL", 4) != 0) {
            unquote(line, buf, sizeof buf);
            memcpy(copy, buf, sizeof buf);
            arg = buf;
        }
        int rssi = 12345, ber = 12345, cme = 12345;
        int st = at_parse_csq(arg, &rssi, &ber, &cme);
        switch (st) {
        case AT_OK:
            if (rssi == 0) printf("OK rssi=unknown ber=%d\n", ber);
            else printf("OK rssi=%ddBm ber=%d\n", rssi, ber);
            break;
        case AT_ERROR:      printf("ERROR\n"); break;
        case AT_CME_ERROR:  printf("CME ERROR %d\n", cme); break;
        case AT_INCOMPLETE: printf("INCOMPLETE\n"); break;
        case AT_BAD_FORMAT: printf("BAD FORMAT\n"); break;
        default:            printf("UNKNOWN STATUS %d\n", st); break;
        }
        if (arg && memcmp(copy, buf, sizeof buf) != 0) printf("BUFFER MODIFIED\n");
    }
    return 0;
}
@@@ sample_input
4
"AT+CSQ\r\r\n+CSQ: 23,0\r\n\r\nOK\r\n"
"\r\nERROR\r\n"
"\r\n+CSQ: 23,0\r\n\r\nOK"
"\r\n+CME ERROR: 10\r\n"
@@@ sample_output
OK rssi=-67dBm ber=0
ERROR
INCOMPLETE
CME ERROR 10

@@@ sample_input
3
"\r\n+CSQ: 99,99\r\n\r\nOK\r\n"
""
NULL
@@@ sample_output
OK rssi=unknown ber=99
INCOMPLETE
BAD FORMAT

@@@ hidden_input
4
"\r\nRING\r\n\r\n+CSQ: 31,7\r\n\r\n+CREG: 1\r\n\r\nOK\r\n"
"\r\n+CMTI: \"SM\",3\r\n\r\n+CSQ: 0,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 1,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 05,00\r\n\r\nOK\r\n"
@@@ hidden_output
OK rssi=-51dBm ber=7
OK rssi=-113dBm ber=0
OK rssi=-111dBm ber=0
OK rssi=-103dBm ber=0

@@@ hidden_input
8
"\r\nOK\r\n"
"\r\n+CSQ: 32,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 2a,0\r\n\r\nOK\r\n"
"\r\n+CSQ:23,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 23,0,5\r\n\r\nOK\r\n"
"\r\n+CSQ: 23,8\r\n\r\nOK\r\n"
"\r\n+CSQ: 123,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 23,\r\n\r\nOK\r\n"
@@@ hidden_output
BAD FORMAT
BAD FORMAT
BAD FORMAT
BAD FORMAT
BAD FORMAT
BAD FORMAT
BAD FORMAT
BAD FORMAT

@@@ hidden_input
6
"\r\nOKAY\r\n"
"\r\nOK \r\n"
"\r\n+CME ERROR: 3\r\n\r\nOK\r\n"
"+CSQ: 23,0\r\nERROR\r\n"
"\r\n+CME ERROR: SIM not inserted\r\n"
"\r\n+CME ERROR: 0\r\n"
@@@ hidden_output
INCOMPLETE
INCOMPLETE
CME ERROR 3
ERROR
CME ERROR -1
CME ERROR 0

@@@ hidden_input
5
"\r\n+CSQ: 23,0\r\n\r\nOK\r"
"\r\n+CSQ: 23,0\r\n\r\nO"
"AT+CSQ\r"
"\r\n"
"\r\n+CSQ: 23,0\r\n\r\nERR"
@@@ hidden_output
INCOMPLETE
INCOMPLETE
INCOMPLETE
INCOMPLETE
INCOMPLETE

@@@ hidden_input
4
"\r\nOK\r\n\r\n+CSQ: 20,0\r\n"
"\r\n+CSQ: 10,0\r\n\r\n+CSQ: 20,1\r\n\r\nOK\r\n"
"\r\n+CSQ: 99,0\r\n\r\nOK\r\n"
"\r\n+CSQ: 15,99\r\n\r\nOK\r\n\r\n+CSQ: 1,1\r\n"
@@@ hidden_output
BAD FORMAT
OK rssi=-73dBm ber=1
OK rssi=unknown ber=0
OK rssi=-83dBm ber=99

@@@ hint
Walk the buffer line by line with `const char *eol = strstr(line, "\r\n")`. Each complete line is the range `[line, eol)`, and the next line starts at `eol + 2`. When `strstr` returns `NULL`, the rest is an incomplete fragment, so stop: the answer is `AT_INCOMPLETE` unless a final code was already found. Compare lines with `len == 2 && memcmp(line, "OK", 2) == 0`, never with `strstr(buf, "OK")`.
@@@ hint
While scanning, remember a pointer and length for the latest `+CSQ: ` payload. On `OK`, find the comma with `memchr`, then validate each side with a small helper that accepts only 1-2 digits and produces the value. The modem text is not NUL-terminated per line, so do not use `atoi`/`sscanf` on it directly: they would run into the next line.
@@@ solution_code
#include <stddef.h>
#include <string.h>

/* parse exactly 1..maxd decimal digits in s[0..len-1] */
static int parse_digits(const char *s, size_t len, size_t maxd, int *out)
{
    int v = 0;
    if (len == 0 || len > maxd)
        return 0;
    for (size_t i = 0; i < len; i++) {
        if (s[i] < '0' || s[i] > '9')
            return 0;
        v = v * 10 + (s[i] - '0');
    }
    *out = v;
    return 1;
}

int at_parse_csq(const char *buf, int *rssi_dbm, int *ber, int *cme)
{
    const char *csq = NULL;     /* payload after "+CSQ: " (not NUL-terminated) */
    size_t csq_len = 0;
    const char *line, *eol;

    if (buf == NULL)
        return AT_BAD_FORMAT;

    for (line = buf; (eol = strstr(line, "\r\n")) != NULL; line = eol + 2) {
        size_t len = (size_t)(eol - line);

        if (len == 2 && memcmp(line, "OK", 2) == 0) {
            const char *comma;
            int r, b;
            if (csq == NULL)
                return AT_BAD_FORMAT;
            comma = memchr(csq, ',', csq_len);
            if (comma == NULL)
                return AT_BAD_FORMAT;
            if (!parse_digits(csq, (size_t)(comma - csq), 2, &r) ||
                !parse_digits(comma + 1, csq_len - (size_t)(comma - csq) - 1, 2, &b))
                return AT_BAD_FORMAT;
            if ((r > 31 && r != 99) || (b > 7 && b != 99))
                return AT_BAD_FORMAT;
            *rssi_dbm = (r == 99) ? 0 : -113 + 2 * r;
            *ber = b;
            return AT_OK;
        }
        if (len == 5 && memcmp(line, "ERROR", 5) == 0)
            return AT_ERROR;
        if (len >= 12 && memcmp(line, "+CME ERROR: ", 12) == 0) {
            int code;
            *cme = parse_digits(line + 12, len - 12, 3, &code) ? code : -1;
            return AT_CME_ERROR;
        }
        if (len >= 6 && memcmp(line, "+CSQ: ", 6) == 0) {
            csq = line + 6;                 /* remember the latest one */
            csq_len = len - 6;
        }
        /* everything else: echo, blank line, URC -> ignore */
    }
    return AT_INCOMPLETE;                   /* no final result code yet */
}
@@@ explanation_md
**Approach: line-oriented scan without copying.** Each complete line is a `(pointer, length)` pair delimited by `"\r\n"`. The buffer is `const` and the lines are not NUL-terminated, so every comparison uses `memcmp` with an explicit length.
- Final result codes (`OK`, `ERROR`, `+CME ERROR: n`) end the scan. The **first** one wins.
- Information lines are remembered (`+CSQ: ` payload) or ignored (echo, URCs, blank lines).
- No final code yet means `AT_INCOMPLETE`. That is the normal state while the UART ISR is still filling the buffer, which is why a fragment such as `"OK"` without `"\r\n"` must not be accepted.

The `+CSQ` payload is validated strictly: exactly two numeric fields of 1-2 digits each, with legal ranges. Then it is converted with the 3GPP TS 27.007 mapping `dBm = -113 + 2 * rssi` (0 -> -113 dBm, 31 -> -51 dBm, 99 = not known).

**Complexity.** O(n) time: `strstr` for `"\r\n"` advances monotonically through the buffer, and each line is inspected once. O(1) extra space.

**Common mistakes**
- `strstr(buf, "OK")` to detect success. It matches `"OKAY"`, a `"+COPS: ...,\"BOOK\""` payload, or an `OK` that has not been terminated yet.
- Accepting the final line before its `"\r\n"` arrives. The driver then parses half a response.
- `atoi(csq)` or `sscanf(csq, "%d,%d")`: they accept `" 23"`, `"-5"` and `"23,0,5"`, and since the line is not NUL-terminated they read into the next line.
- Not ignoring URCs. Modems interleave `RING`, `+CREG` or `+CMTI` notifications with any response at any time.
- Writing into `buf` (for example `strtok` on it). The ISR may still be appending to it.

**Interview follow-ups**
- Bytes arrive in an ISR into a ring buffer. How would you turn this into an incremental state machine that never rescans old bytes?
- Add a timeout. What should the driver do when `AT_INCOMPLETE` persists for 300 ms, and how do you resynchronise with the modem (`AT\r` until `OK`)?
- Generalise it into `at_send(cmd, prefix, handler, timeout)`, a table-driven AT engine like the ones in production telematics stacks.
- How do you make sure a URC that arrives in the middle of your response (for example an incoming SMS) is not lost?
