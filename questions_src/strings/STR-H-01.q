@@@ meta
id: STR-H-01
topic: Strings
difficulty: Hard
type: CODE
title: NMEA $GPGGA Parser with Checksum Validation
tags: embedded, nmea, gps, checksum, xor, fixed-point, parsing, asked-in-automotive
@@@ statement_md
A telematics unit receives NMEA 0183 sentences from its GPS module over UART. Write the parser that validates each sentence and extracts the position fix from **GGA** sentences, using **integer arithmetic only** (the MCU has no FPU).

A sentence looks like this:
```
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
 \___/ \____/ \______/ | \_______/ | | \/ \_/ \___/
 addr   time    lat   N/S   lon   E/W q sats hdop alt
```

Process each line with these rules, **in this order**, and print exactly one result line:

1. **Format.** The line must start with `'$'` and contain a `'*'`. The first `'*'` must be followed by **exactly two hex digits** (upper or lower case), and then the line must end. Otherwise print `ERROR FORMAT`.
2. **Checksum.** XOR all characters **strictly between** `'$'` and `'*'`. If the result differs from the two hex digits, print `ERROR CHECKSUM calc=XX recv=YY`, both values as two **uppercase** hex digits.
3. **Sentence type.** The address is the text between `'$'` and the first `','`. If it is not exactly 5 characters ending in `GGA` (any talker: `GP`, `GN`, `GL`, ...), print `SKIP <address>`.
4. **Fields.** Split the rest on `','` and **keep empty fields** (`",,"` is an empty field). A GGA needs at least 9 fields (time, lat, N/S, lon, E/W, quality, satellites, HDOP, altitude). If there are fewer, print `ERROR FIELDS`.
5. **No fix.** If the quality field (6th) is empty or `0`, print `NOFIX hh:mm:ss`, taken from the first 6 digits of the time field (any `.ss` fraction is ignored).
6. **Fix.** Otherwise print
   `FIX hh:mm:ss <lat> <lon> q=<quality> sats=<satellites> alt=<altitude>`
   - Latitude is `ddmm.m...` (2 degree digits) and longitude `dddmm.m...` (3 degree digits). The minutes have 1 to 5 decimals.
   - Convert to decimal degrees = degrees + minutes / 60, **truncated** to micro-degrees (six decimals), using integers only. Print it as `D.DDDDDD`, with a leading `-` for `S` and `W` (unless the value is exactly 0).
   - `satellites` is printed as a plain integer (`08` -> `8`). `quality` and `altitude` are copied as they appear.

Worked conversion: `4807.038,N` -> 48 degrees + 7.038 minutes. 7.038 min = 703800 units of 10^-5 min, and 703800 / 6 = 117300 micro-degrees, so the result is `48.117300`. `01131.000,E` -> 11 + 3100000/6 = 11 + 516666 (truncated) -> `11.516666`.

**Input**
- Line 1: `n`, the number of lines.
- Next `n` lines: one candidate sentence each (possibly empty or malformed).

**Output**
- One result line per input line.

**Example**
```
Input:
3
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*48

Output:
FIX 12:35:19 48.117300 11.516666 q=1 sats=8 alt=545.4
SKIP GPRMC
ERROR CHECKSUM calc=47 recv=48
```
@@@ constraints_md
- `1 <= n <= 100`, each line has at most 100 characters.
- In GGA sentences that pass rules 1-4, the time field has at least 6 digits. When quality is non-zero, latitude, longitude, hemispheres, satellites and altitude are present and well formed.
- No floating point is needed (or wanted).
@@@ starter_code
#include <stdio.h>
#include <string.h>

/* Validate one NMEA sentence and print exactly one result line. */
static void process(char *line)
{
    /* TODO: format -> checksum -> type -> fields -> NOFIX / FIX */
    (void)line;
    puts("ERROR FORMAT");
}

int main(void)
{
    char line[160];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        process(line);
    }
    return 0;
}
@@@ sample_input
3
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*48
@@@ sample_output
FIX 12:35:19 48.117300 11.516666 q=1 sats=8 alt=545.4
SKIP GPRMC
ERROR CHECKSUM calc=47 recv=48

@@@ sample_input
2
$GPGGA,002153.000,,,,,0,00,,,M,,M,,*7D
$GPGGA,123519,4807.038,N
@@@ sample_output
NOFIX 00:21:53
ERROR FORMAT

@@@ hidden_input
2
$GNGGA,091530.00,3352.1280,S,15112.5960,E,2,12,0.7,35.2,M,22.0,M,,*52
$GPGGA,154500,4042.7680,N,07400.3600,W,1,05,1.5,10.0,M,-34.2,M,,*40
@@@ hidden_output
FIX 09:15:30 -33.868800 151.209933 q=2 sats=12 alt=35.2
FIX 15:45:00 40.712800 -74.006000 q=1 sats=5 alt=10.0

@@@ hidden_input
5
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*4
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*4G
GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47X
<<BLANK>>
@@@ hidden_output
ERROR FORMAT
ERROR FORMAT
ERROR FORMAT
ERROR FORMAT
ERROR FORMAT

@@@ hidden_input
3
$GPGGA,000000,0000.000,N,00000.000,E,1,03,2.0,0.0,M,0.0,M,,*73
$GPGGA,235959.99,8959.99999,S,18000.0000,W,1,04,9.9,-12.5,M,0.0,M,,*70
$GPGGA,101010,4807.03812,N,01131.0,E,6,12,0.5,1.0,M,0.0,M,,*72
@@@ hidden_output
FIX 00:00:00 0.000000 0.000000 q=1 sats=3 alt=0.0
FIX 23:59:59 -89.999999 -180.000000 q=1 sats=4 alt=-12.5
FIX 10:10:10 48.117302 11.516666 q=6 sats=12 alt=1.0

@@@ hidden_input
4
$GPGSV,3,1,11,03,03,111,00,04,15,270,00,06,01,010,00,13,06,292,00*74
$GGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*50
$GPGGA,123519,4807.038,N*27
$GPGGA,120000,,,,,,00,,,M,,M,,*55
@@@ hidden_output
SKIP GPGSV
SKIP GGA
ERROR FIELDS
NOFIX 12:00:00

@@@ hidden_input
5
$GPGGA,071228.00,1259.5918,N,07735.7215,E,1,09,0.86,920.3,M,-86.4,M,,*77
$GPGGA,071229.00,1259.5918,N,07735.7215,E,1,09,0.86,920.3,M,-86.4,M,,*ab
$GPGGA,071230.00,1259.5920,N,07735.7216,E,2,10,0.80,920.1,M,-86.4,M,,*79
$GPRMC,071230.00,A,1259.5920,N,07735.7216,E,0.02,,161126,,,D*46
$GPGGA,071231.00,1259.5921,N,07735.7216,E,0,10,0.80,920.1,M,-86.4,M,,*7b
@@@ hidden_output
FIX 07:12:28 12.993196 77.595358 q=1 sats=9 alt=920.3
ERROR CHECKSUM calc=76 recv=AB
FIX 07:12:30 12.993200 77.595360 q=2 sats=10 alt=920.1
SKIP GPRMC
NOFIX 07:12:31

@@@ hint
Do the cheap structural checks first: `'$'` at index 0, `strchr(line, '*')`, then exactly two hex digits and the end of the line. Read `star[2]` only if `star[1]` was a hex digit, so you never read past the terminator. The checksum is just `sum ^= c` over `line + 1 .. star - 1`.
@@@ hint
Do **not** use `strtok` for the fields: it merges `",,"` and shifts every later field. Walk the string with `strchr(p, ',')`, replace each comma with `'\0'` and store a pointer per field. For the coordinates, read the minutes as an integer in units of 10^-5 (pad the decimals to 5 digits). Then micro-degrees = `deg * 1000000 + minutes_e5 / 6`, printed with `"%d.%06d"`.
@@@ solution_code
#include <stdio.h>
#include <string.h>

#define MAX_FIELDS 24

static int hexval(int c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* "ddmm.mmmmm" (deg_digits = 2) or "dddmm.mmmmm" (3) -> micro-degrees, truncated */
static int to_microdeg(const char *f, int deg_digits)
{
    int deg = 0, mm, frac = 0, nd = 0, i;

    for (i = 0; i < deg_digits; i++)
        deg = deg * 10 + (f[i] - '0');
    mm = (f[i] - '0') * 10 + (f[i + 1] - '0');
    i += 2;
    if (f[i] == '.')
        for (i++; f[i] >= '0' && f[i] <= '9' && nd < 5; i++, nd++)
            frac = frac * 10 + (f[i] - '0');
    for (; nd < 5; nd++)
        frac *= 10;                                 /* minutes in units of 1e-5 */
    return deg * 1000000 + (mm * 100000 + frac) / 6; /* (min/60) * 1e6 = min_e5 / 6 */
}

static void print_coord(const char *f, int deg_digits, const char *hemi)
{
    int micro = to_microdeg(f, deg_digits);
    int neg = (hemi[0] == 'S' || hemi[0] == 'W') && micro != 0;
    printf(" %s%d.%06d", neg ? "-" : "", micro / 1000000, micro % 1000000);
}

static void process(char *line)
{
    char *field[MAX_FIELDS];
    int nf = 0, hi, lo;
    unsigned int sum = 0;
    char *star, *p, *comma;

    /* 1. format */
    if (line[0] != '$' || (star = strchr(line, '*')) == NULL) {
        puts("ERROR FORMAT");
        return;
    }
    hi = hexval((unsigned char)star[1]);
    lo = hi < 0 ? -1 : hexval((unsigned char)star[2]);   /* never read past '\0' */
    if (hi < 0 || lo < 0 || star[3] != '\0') {
        puts("ERROR FORMAT");
        return;
    }

    /* 2. checksum: XOR strictly between '$' and '*' */
    for (p = line + 1; p < star; p++)
        sum ^= (unsigned char)*p;
    if (sum != (unsigned int)(hi * 16 + lo)) {
        printf("ERROR CHECKSUM calc=%02X recv=%02X\n", sum, (unsigned int)(hi * 16 + lo));
        return;
    }
    *star = '\0';

    /* 3. sentence type */
    comma = strchr(line + 1, ',');
    if (comma)
        *comma = '\0';
    if (strlen(line + 1) != 5 || strcmp(line + 3, "GGA") != 0) {
        printf("SKIP %s\n", line + 1);
        return;
    }

    /* 4. split on ',' keeping empty fields (strtok would merge ",,") */
    for (p = comma ? comma + 1 : NULL; p != NULL && nf < MAX_FIELDS; ) {
        field[nf++] = p;
        comma = strchr(p, ',');
        if (comma) {
            *comma = '\0';
            p = comma + 1;
        } else {
            p = NULL;
        }
    }
    if (nf < 9) {
        puts("ERROR FIELDS");
        return;
    }

    /* 5./6. fix or no fix */
    const char *t = field[0];
    if (field[5][0] == '\0' || strcmp(field[5], "0") == 0) {
        printf("NOFIX %.2s:%.2s:%.2s\n", t, t + 2, t + 4);
        return;
    }
    int sats = 0;
    for (p = field[6]; *p >= '0' && *p <= '9'; p++)
        sats = sats * 10 + (*p - '0');
    printf("FIX %.2s:%.2s:%.2s", t, t + 2, t + 4);
    print_coord(field[1], 2, field[2]);
    print_coord(field[3], 3, field[4]);
    printf(" q=%s sats=%d alt=%s\n", field[5], sats, field[8]);
}

int main(void)
{
    char line[160];
    int n;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        process(line);
    }
    return 0;
}
@@@ explanation_md
**Approach: a validation pipeline, cheapest checks first.**
1. **Structure.** `'$'` at index 0, then `strchr(line, '*')`, then exactly two hex digits and the end of the line. The digits are read one at a time, so a short line like `"...*4"` never causes a read past the terminator.
2. **Checksum.** XOR every byte between `'$'` and `'*'`, then compare with `hi * 16 + lo`. Converting the received digits to a number makes upper and lower case irrelevant.
3. **Address.** Cut the string at the first `','`. Accept any 5-character address ending in `GGA` (`GPGGA`, `GNGGA`, `GLGGA`).
4. **Fields.** Split on `','` **without** collapsing empty fields. A no-fix GGA is `$GPGGA,002153.000,,,,,0,00,,,M,,M,,*7D`, and with `strtok` the quality field `0` would land in slot 0.
5. **Fixed-point conversion.** Minutes are parsed as an integer in units of 10^-5 (`7.038` -> `703800`). Then degrees = minutes / 60, so micro-degrees = `min_e5 * 10^6 / (60 * 10^5) = min_e5 / 6`. The maximum value, `180 * 10^6 + 5999999 / 6`, fits easily in a 32-bit `int`.

**Complexity.** O(L) time per sentence (one checksum pass, one split pass), O(1) extra space: the line is split in place and field pointers live in a fixed array.

**Common mistakes**
- Including `'$'` or `'*'` in the XOR, or comparing the checksum as text with `strcmp` (fails for lowercase `*7b`).
- Using `strtok(line, ",")`. Empty fields vanish, and the field indexes of every no-fix sentence shift.
- `atof` + `double` + `printf("%.6f")`. It works on a PC, but pulls in a large soft-float library on an FPU-less MCU, and rounds instead of truncating.
- Reading `star[2]` and `star[3]` unconditionally. For `"...*4"` that reads past the terminator.
- Treating the 2-digit latitude degrees and the 3-digit longitude degrees the same (`01131.000` is 11 degrees, not 113).
- `sats=08` printed with a leading zero, or parsed with `atoi("08")`, which happens to work. Hand-written base-auto parsers like `strtol(s, NULL, 0)` read `08` as an invalid octal number.

**Interview follow-ups**
- Bytes arrive one at a time in a UART ISR. Design a state machine that assembles sentences into a ring buffer, computes the XOR **incrementally**, and hands complete, verified sentences to a task.
- How would you also handle `$GPRMC` (date, speed, course) without duplicating the field splitter? (A table of sentence handlers indexed by address.)
- How do you detect a GPS receiver that keeps sending valid sentences with a frozen time field?
- Convert the micro-degree position to a CAN signal with a factor of 1e-7 deg/bit in a signed 32-bit field. What range does that give, and is there an overflow risk?
