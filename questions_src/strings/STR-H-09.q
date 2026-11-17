@@@ meta
id: STR-H-09
topic: Strings
difficulty: Hard
type: FIND_THE_BUG
title: Base64 Decoder That Crashes on Non-ASCII Payloads
tags: embedded, base64, sign-extension, lookup-table, char-signedness, telematics, security
@@@ statement_md
A telematics unit receives configuration blobs from the backend as **Base64** text and decodes them before use. The decoder:
- builds a 256-entry reverse lookup table (`-1` for characters outside the Base64 alphabet `A-Z a-z 0-9 + /`);
- requires the length to be a multiple of 4;
- allows `'='` padding only in the last group, only in the last one or two positions, and with nothing but `'='` after it;
- returns the number of decoded bytes, or `-1` for invalid input.

The decoder passed all its tests with real backend messages. Then a corrupted message arrived containing bytes **above 127** (a UTF-8 `é`, or line noise). Instead of reporting `INVALID`, the unit **crashed or accepted garbage**, depending on the build. The judge reports a **Runtime Error** (UndefinedBehaviorSanitizer: index out of bounds) for such input.

Find and fix the bug, so that every non-alphabet byte is simply reported as `INVALID`.

**Input**
- Line 1: `n`.
- Next `n` lines: one Base64 string each (may be empty; may contain arbitrary bytes, including UTF-8 characters).

**Output**
- For each line: the decoded bytes as uppercase hex separated by spaces, `(empty)` for zero bytes, or `INVALID`.

**Example**
```
Input:
3
SGVsbG8=
QUJD
SGVsbG8

Output:
48 65 6C 6C 6F
41 42 43
INVALID
```
@@@ constraints_md
- `1 <= n <= 50`, each line has at most 400 bytes.
- Keep the table-driven design. The fix is a one-line change.
@@@ starter_code
#include <stdio.h>
#include <string.h>

static signed char b64_val[256];

static void b64_init(void)
{
    const char *alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    memset(b64_val, -1, sizeof b64_val);
    for (int i = 0; i < 64; i++)
        b64_val[(unsigned char)alpha[i]] = (signed char)i;
}

/* Decode s into out. Returns the number of bytes, or -1 if s is not valid Base64. */
static int b64_decode(const char *s, unsigned char *out)
{
    size_t len = strlen(s);
    int n = 0;

    if (len % 4 != 0)
        return -1;
    for (size_t i = 0; i < len; i += 4) {
        int v[4], pad = 0;
        for (int k = 0; k < 4; k++) {
            int c = s[i + k];
            if (c == '=') {
                if (i + 4 != len || k < 2)      /* '=' only at the end of the last group */
                    return -1;
                pad++;
                v[k] = 0;
                continue;
            }
            if (pad)                            /* data after padding */
                return -1;
            v[k] = b64_val[c];
            if (v[k] < 0)                       /* not a Base64 character */
                return -1;
        }
        unsigned int triple = ((unsigned int)v[0] << 18) | ((unsigned int)v[1] << 12) |
                              ((unsigned int)v[2] << 6) | (unsigned int)v[3];
        out[n++] = (unsigned char)(triple >> 16);
        if (pad < 2) out[n++] = (unsigned char)(triple >> 8);
        if (pad < 1) out[n++] = (unsigned char)triple;
    }
    return n;
}

int main(void)
{
    static char line[512];
    static unsigned char out[400];
    int n;

    b64_init();
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        int len = b64_decode(line, out);
        if (len < 0) {
            puts("INVALID");
        } else if (len == 0) {
            puts("(empty)");
        } else {
            for (int k = 0; k < len; k++)
                printf(k ? " %02X" : "%02X", out[k]);
            putchar('\n');
        }
    }
    return 0;
}
@@@ sample_input
3
SGVsbG8=
QUJD
SGVsbG8
@@@ sample_output
48 65 6C 6C 6F
41 42 43
INVALID

@@@ sample_input
2
<<BLANK>>
SGV=bG8=
@@@ sample_output
(empty)
INVALID

@@@ hidden_input
3
Qé=
TWFu
TWE=
@@@ hidden_output
INVALID
4D 61 6E
4D 61

@@@ hidden_input
3
AAAAéé
IvGQMUhH
ÿÿÿÿ
@@@ hidden_output
INVALID
22 F1 90 31 48 47
INVALID

@@@ hidden_input
5
TQ==
A===
====
AB=C
ab-_
@@@ hidden_output
4D
INVALID
INVALID
INVALID
INVALID

@@@ hidden_input
4
AAAA
////
+/+/
SGV sbG8
@@@ hidden_output
00 00 00
FF FF FF
FB FF BF
INVALID

@@@ hidden_input
2
E1yl7jeAyRJbpO02f8gRWqPsNX7HEFmi6zR9xg9YoeozfMUOV6DpMnvEDVaf6DF6wwxVnucwecILVJ3mL3jBClOc5S53wAlSm+Qtdr8IUZrjLHW+B1CZ4it0vQZPmOEqc7wFTpfgKXK7BE2W3yhxugNMld4ncLkCS5TdJm+4AUqT3CVutwBJktskbbb/SJHaI2y1/keQ2SJrtP1Gj9gharP8RY7XIGmy+0SN1h9osfpDjNUeZ7D5QovUHWav+EGK0xxlrvdAidIbZK32P4jRGmOs9T6H0Bliq/Q9hs8YYarz
E1yl7jeAyRJbpO02f8gRWqPsNX7HEFmi6zR9xg9YoeozfMUOV6DpMnvEDVaf6DF6wwxVnucwecILVJ3mL3jBClOc5S53wAlSm+Qtdr8IUZrjLHW+B1CZ4it0vQZPmOEqc7wFTpfgKXK7BE2W3yhxugNMld4ncLkCS5TdJm+4AUqT3CVutwBJktskbbb/SJHaI2y1/keQ2SJrtP1Gj9gharP8RY7XIGmy+0SN1h9osfpDjNUeZ7D5QovUHWav+EGK0xxlrvdAidIbZK32P4jRGmOs9T6H0Bliq/Q9hs8YYarzü==
@@@ hidden_output
13 5C A5 EE 37 80 C9 12 5B A4 ED 36 7F C8 11 5A A3 EC 35 7E C7 10 59 A2 EB 34 7D C6 0F 58 A1 EA 33 7C C5 0E 57 A0 E9 32 7B C4 0D 56 9F E8 31 7A C3 0C 55 9E E7 30 79 C2 0B 54 9D E6 2F 78 C1 0A 53 9C E5 2E 77 C0 09 52 9B E4 2D 76 BF 08 51 9A E3 2C 75 BE 07 50 99 E2 2B 74 BD 06 4F 98 E1 2A 73 BC 05 4E 97 E0 29 72 BB 04 4D 96 DF 28 71 BA 03 4C 95 DE 27 70 B9 02 4B 94 DD 26 6F B8 01 4A 93 DC 25 6E B7 00 49 92 DB 24 6D B6 FF 48 91 DA 23 6C B5 FE 47 90 D9 22 6B B4 FD 46 8F D8 21 6A B3 FC 45 8E D7 20 69 B2 FB 44 8D D6 1F 68 B1 FA 43 8C D5 1E 67 B0 F9 42 8B D4 1D 66 AF F8 41 8A D3 1C 65 AE F7 40 89 D2 1B 64 AD F6 3F 88 D1 1A 63 AC F5 3E 87 D0 19 62 AB F4 3D 86 CF 18 61 AA F3
INVALID

@@@ hint
The table has 256 entries, indexed by the character value. Which values can `int c = s[i + k];` take when `s[i + k]` is the byte `0xC3` on x86-64? Remember that plain `char` is signed there.
@@@ hint
Assigning a `char` to an `int` keeps its **signed** value (`0xC3` becomes `-61`), so the table is indexed with a negative number, which is out of bounds. Convert through `unsigned char` first: `int c = (unsigned char)s[i + k];`.
@@@ solution_code
#include <stdio.h>
#include <string.h>

static signed char b64_val[256];

static void b64_init(void)
{
    const char *alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    memset(b64_val, -1, sizeof b64_val);
    for (int i = 0; i < 64; i++)
        b64_val[(unsigned char)alpha[i]] = (signed char)i;
}

/* Decode s into out. Returns the number of bytes, or -1 if s is not valid Base64. */
static int b64_decode(const char *s, unsigned char *out)
{
    size_t len = strlen(s);
    int n = 0;

    if (len % 4 != 0)
        return -1;
    for (size_t i = 0; i < len; i += 4) {
        int v[4], pad = 0;
        for (int k = 0; k < 4; k++) {
            int c = (unsigned char)s[i + k];   /* FIX: 0..255, never a negative table index */
            if (c == '=') {
                if (i + 4 != len || k < 2)      /* '=' only at the end of the last group */
                    return -1;
                pad++;
                v[k] = 0;
                continue;
            }
            if (pad)                            /* data after padding */
                return -1;
            v[k] = b64_val[c];
            if (v[k] < 0)                       /* not a Base64 character */
                return -1;
        }
        unsigned int triple = ((unsigned int)v[0] << 18) | ((unsigned int)v[1] << 12) |
                              ((unsigned int)v[2] << 6) | (unsigned int)v[3];
        out[n++] = (unsigned char)(triple >> 16);
        if (pad < 2) out[n++] = (unsigned char)(triple >> 8);
        if (pad < 1) out[n++] = (unsigned char)triple;
    }
    return n;
}

int main(void)
{
    static char line[512];
    static unsigned char out[400];
    int n;

    b64_init();
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        if (!fgets(line, sizeof line, stdin)) line[0] = '\0';
        line[strcspn(line, "\r\n")] = '\0';
        int len = b64_decode(line, out);
        if (len < 0) {
            puts("INVALID");
        } else if (len == 0) {
            puts("(empty)");
        } else {
            for (int k = 0; k < len; k++)
                printf(k ? " %02X" : "%02X", out[k]);
            putchar('\n');
        }
    }
    return 0;
}
@@@ explanation_md
**Bug: sign extension of `char` into a table index.** `int c = s[i + k];` looks harmless, because `c` is an `int`. But on x86-64 plain `char` is **signed**, so the byte `0xC3` (the first byte of UTF-8 `é`) is the value `-61`, and the conversion to `int` preserves it. `b64_val[c]` then reads `b64_val[-61]`: 61 bytes **before** the table.
- With sanitizers, that is an immediate out-of-bounds report (Runtime Error).
- Without them, the code reads whatever lies before the table in `.bss`. If that byte happens to be `>= 0`, the garbage character is **accepted** as valid Base64 data, which is a security problem for a telematics unit that trusts decoded configuration.

ASCII test vectors never trigger it, which is why it survived testing.

**Fix.** Convert through `unsigned char` before indexing: `int c = (unsigned char)s[i + k];`. Every byte then maps to 0..255, non-alphabet bytes hit a `-1` entry, and the input is rejected cleanly.

**Complexity.** O(n) time, one table lookup per character. O(1) extra space: a 256-byte table (could be `static const` in flash).

**Common mistakes**
- "Fixing" it with `if (c < 0) return -1;`. That works here, but it treats the symptom; the right habit is to always index tables through `unsigned char` / `uint8_t`.
- Declaring the buffer as `char *` for binary or protocol data. Use `uint8_t *`, so the type itself prevents the bug.
- Calling `isalnum(c)` or other `<ctype.h>` functions with a negative `char`: the same bug inside the C library (undefined behavior, typically a negative index into its internal table).
- Assuming that an `int` variable "is big enough" and therefore safe: the value was already negative when it left the `char`.

**Interview follow-ups**
- Write the encoder. How do you compute the exact output size `4 * ((n + 2) / 3)` and avoid overflow for large `n`?
- Strict decoders also reject non-canonical input such as `"QR=="`, where the unused low bits are not zero. Why does that matter for signatures and MACs?
- How would you make the decoder constant-time, so that the position of the first invalid character cannot leak through timing (relevant when decoding secret keys)?
- Where else does `char` sign extension bite in embedded code? (CRC tables `crc_table[crc ^ *p]`, hex dumps, `getchar()` stored in `char` compared with `EOF`.)
