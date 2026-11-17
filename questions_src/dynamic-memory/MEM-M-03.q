@@@ meta
id: MEM-M-03
topic: Dynamic Memory
difficulty: Medium
type: FUNCTION
title: Read a Line of Unknown Length From a UART Console
tags: embedded, realloc, unknown-length-input, growing-buffer, uart
@@@ statement_md
A service console on a telematics unit reads commands byte by byte from a UART. Commands have no length limit (a flashing script once sent a 150 KB line). A fixed `char buf[256]` silently truncates them. Implement a reader that grows its buffer as needed:

```c
int uart_getc(void);          /* provided: next byte (0..255), or -1 at end of stream */

char *read_line(size_t *len);
```

- Read bytes with `uart_getc()` until `'\n'` or end of stream. Return a **heap** string (from `malloc`/`realloc`) with the line's bytes, **without** the `'\n'`, NUL-terminated. The caller frees it.
- If `len` is not `NULL`, store the line length in `*len`.
- An empty line (just `'\n'`) returns `""`, not `NULL`.
- The last line may have no `'\n'` (stream ends right after it). It is still a line.
- If the stream is already at its end (no byte read), return `NULL`.
- If an allocation fails, free what you have and return `NULL`.
- No fixed maximum line length. `getline` is not available (it is POSIX, not C11).

**How it is tested.** The harness feeds a byte stream through `uart_getc()` and calls `read_line` until it returns `NULL`. On every other call it passes `len = NULL` and uses `strlen` itself. It frees every line.

**Input (read by the hidden harness)**
- `T` on the first line, followed by the stream: the rest of the input, ending with a `'\n'`.
- `U` on the first line, followed by the stream: the rest of the input, with the final `'\n'` removed (the last line is **unterminated**).
- `G <count> <maxlen> <seed> <T|U>`: the harness **generates** `count` lines of pseudo-random lengths `0..maxlen` and letters `a..z`, terminated or not.

**Output (printed by the harness)**
- Per line: `#<i> len=<n> "<line>"` if `n <= 40`, otherwise `#<i> len=<n> hash=<8 hex digits>` (a djb2 hash of the line).
- Finally: `lines=<count>`.

**Example**
```
Input:
T
AT+CGMI

OK

Output:
#1 len=7 "AT+CGMI"
#2 len=0 ""
#3 len=2 "OK"
lines=3
```
@@@ constraints_md
- Stream size up to 1,000,000 bytes; a single line can be longer than 150,000 bytes.
- Lines contain printable ASCII only (no `'\0'`, no `'\r'`).
- Grow geometrically (for example, double the capacity). Growing by one byte at a time is too slow for the long-line tests.
@@@ starter_code
#include <stddef.h>
#include <stdlib.h>

int uart_getc(void); /* provided by the harness: next byte or -1 at end of stream */

char *read_line(size_t *len)
{
    /* TODO */
    return NULL;
}
@@@ harness_code
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STREAM_MAX 1100000
static unsigned char g_stream[STREAM_MAX];
static size_t g_size;
static size_t g_pos;

int uart_getc(void)
{
    if (g_pos < g_size)
        return g_stream[g_pos++];
    return -1;
}

/*USER_CODE*/

static uint32_t djb2(const char *s, size_t n)
{
    uint32_t h = 5381u;
    for (size_t i = 0; i < n; i++)
        h = h * 33u + (unsigned char)s[i];
    return h;
}

int main(void)
{
    char mode[4];
    if (scanf("%3s", mode) != 1)
        return 0;

    if (mode[0] == 'G') {
        int count, maxlen;
        unsigned int seed;
        char term[4];
        if (scanf("%d %d %u %3s", &count, &maxlen, &seed, term) != 4)
            return 0;
        for (int i = 0; i < count; i++) {
            seed = seed * 1103515245u + 12345u;
            size_t n = (size_t)((seed >> 8) % (unsigned int)(maxlen + 1));
            for (size_t k = 0; k < n && g_size < STREAM_MAX - 1; k++) {
                seed = seed * 1103515245u + 12345u;
                g_stream[g_size++] = (unsigned char)('a' + (seed >> 16) % 26u);
            }
            if (i < count - 1 || term[0] == 'T')
                g_stream[g_size++] = '\n';
        }
    } else {
        int c = getchar();                       /* the '\n' after the mode letter */
        while (c != EOF && c != '\n')
            c = getchar();
        while ((c = getchar()) != EOF && g_size < STREAM_MAX)
            g_stream[g_size++] = (unsigned char)c;
        if (mode[0] == 'U' && g_size > 0 && g_stream[g_size - 1] == '\n')
            g_size--;                            /* make the last line unterminated */
    }

    int lines = 0;
    for (;;) {
        size_t n = 0;
        char *line = (lines % 2 == 0) ? read_line(&n) : read_line(NULL);
        if (line == NULL)
            break;
        lines++;
        if (lines % 2 == 0)
            n = strlen(line);
        else if (n != strlen(line))
            printf("FAIL: *len=%zu but strlen=%zu\n", n, strlen(line));
        if (n <= 40)
            printf("#%d len=%zu \"%s\"\n", lines, n, line);
        else
            printf("#%d len=%zu hash=%08X\n", lines, n, (unsigned int)djb2(line, n));
        free(line);
        if (lines > 100000)
            break;
    }
    if (g_pos != g_size)
        printf("FAIL: stream not fully consumed\n");
    printf("lines=%d\n", lines);
    return 0;
}
@@@ sample_input
T
AT+CGMI
<<BLANK>>
OK
@@@ sample_output
#1 len=7 "AT+CGMI"
#2 len=0 ""
#3 len=2 "OK"
lines=3

@@@ sample_input
U
partial
@@@ sample_output
#1 len=7 "partial"
lines=1

@@@ hidden_input
T
@@@ hidden_output
lines=0

@@@ hidden_input
U
a
<<BLANK>>
b
@@@ hidden_output
#1 len=1 "a"
#2 len=0 ""
#3 len=1 "b"
lines=3

@@@ hidden_input
T
<<BLANK>>
<<BLANK>>
@@@ hidden_output
#1 len=0 ""
#2 len=0 ""
lines=2

@@@ hidden_input
U
exactly forty characters long, honestly!
forty-one characters long, plus one byte!
@@@ hidden_output
#1 len=40 "exactly forty characters long, honestly!"
#2 len=41 hash=CB5CACBF
lines=2

@@@ hidden_input
G 40 3000 7 T
@@@ hidden_output
#1 len=613 hash=9D692934
#2 len=1476 hash=61AE6F5B
#3 len=1707 hash=663390AD
#4 len=850 hash=E37CCFF2
#5 len=2865 hash=FD04CC46
#6 len=1792 hash=066DF106
#7 len=76 hash=A60444CE
#8 len=1744 hash=5FE08924
#9 len=360 hash=46130BF1
#10 len=738 hash=31933903
#11 len=1500 hash=F4D984E7
#12 len=2001 hash=35864876
#13 len=919 hash=43EAF83F
#14 len=1401 hash=2DEF86F4
#15 len=991 hash=C7B9008D
#16 len=2752 hash=2F142BBA
#17 len=1069 hash=2C3346F2
#18 len=212 hash=637BDA78
#19 len=1521 hash=4826055D
#20 len=1437 hash=0B4404CF
#21 len=1924 hash=795D7169
#22 len=2177 hash=AE15895E
#23 len=2221 hash=2615AE5E
#24 len=1647 hash=C059E837
#25 len=160 hash=78E8BD99
#26 len=593 hash=61F04628
#27 len=2588 hash=C8CA838F
#28 len=2658 hash=B5429033
#29 len=2726 hash=E291D2AD
#30 len=253 hash=5C8B2E66
#31 len=2836 hash=B3D9B9CF
#32 len=264 hash=53569E63
#33 len=307 hash=8911B3D2
#34 len=1605 hash=719B8A8E
#35 len=1884 hash=693A56C0
#36 len=2842 hash=8DEC566B
#37 len=698 hash=68BA8E99
#38 len=2255 hash=BCFA7359
#39 len=2340 hash=EF2700F6
#40 len=1576 hash=3FFFCC5A
lines=40

@@@ hidden_input
G 3 200000 1 U
@@@ hidden_output
#1 len=110633 hash=5A16B362
#2 len=114312 hash=AFD3FDAE
#3 len=69976 hash=8451E3D0
lines=3

@@@ hidden_input
G 1 0 5 T
@@@ hidden_output
#1 len=0 ""
lines=1

@@@ hint
Keep `buf`, `len` and `cap`. Before storing a byte, make sure `len + 1 < cap` (room for the byte **and** the final `'\0'`). If not, grow with `realloc` into a temporary pointer and double `cap`.
@@@ hint
Track whether you read **any** byte: `NULL` only means "end of stream" when the very first `uart_getc()` returns `-1`. An empty line (first byte is `'\n'`) must still return a valid heap `""`. Start with a small capacity (16) so even an empty line gets a terminator.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

int uart_getc(void); /* provided by the harness: next byte or -1 at end of stream */

char *read_line(size_t *len)
{
    size_t cap = 16, n = 0;
    char *buf = malloc(cap);
    if (buf == NULL)
        return NULL;

    int c = uart_getc();
    if (c == -1) {                       /* nothing left: end of stream */
        free(buf);
        if (len != NULL)
            *len = 0;
        return NULL;
    }

    while (c != -1 && c != '\n') {
        if (n + 1 >= cap) {              /* keep room for the '\0' */
            if (cap > SIZE_MAX / 2) {
                free(buf);
                return NULL;
            }
            char *tmp = realloc(buf, cap * 2);
            if (tmp == NULL) {           /* do not lose (leak) the old block */
                free(buf);
                return NULL;
            }
            buf = tmp;
            cap *= 2;
        }
        buf[n++] = (char)c;
        c = uart_getc();
    }
    buf[n] = '\0';
    if (len != NULL)
        *len = n;
    return buf;
}
@@@ explanation_md
**Approach.** This is the textbook "read until delimiter into a growing buffer" loop:
1. Start with a small heap buffer (16 bytes).
2. Before appending a byte, ensure there is room for it **and** the terminator: `n + 1 < cap`. If not, double the capacity with `realloc` into a temporary pointer.
3. Stop at `'\n'` (not stored) or at end of stream. Terminate the string, report the length, and return it.
4. If the very first read is end of stream, free the buffer and return `NULL`. That is the only way the caller can tell "no more lines" from "an empty line".

```
stream:  A T + C G M I \n \n O K \n
calls:   "AT+CGMI"        ""   "OK"   NULL
```

**Complexity.** Time O(L) per line of length L: doubling makes the total bytes copied by `realloc` at most about 2L. Space is O(L), at most `2L + 16` bytes.

**Common mistakes**
- Returning `NULL` for an empty line. The caller then stops reading too early (here: wrong line count).
- Dropping the last line when the stream does not end with `'\n'` (common with files saved by some editors and with UART traffic cut short).
- `buf = realloc(buf, cap)`: on failure the old block is lost (leak), and the next write goes through `NULL`.
- Growing by 1 or by a fixed chunk: O(L^2) copying. The 200,000-byte lines then time out.
- No room for the terminator (`n < cap` instead of `n + 1 < cap`). A line whose length is exactly a power of two writes `'\0'` one byte past the block.
- Using `fgets` with a fixed buffer and assuming each call returns a whole line.

**Interview follow-ups**
- On an MCU you would never `realloc` per byte in an ISR. How do you split this into an ISR filling a ring buffer and a task assembling lines? Where does the maximum line length come from then?
- Add a hard limit (`max_len`) to protect against a malicious peer sending an endless line. What should the function return when the limit is hit?
- How would you implement POSIX `getline(char **lineptr, size_t *n, FILE *fp)` semantics, reusing the caller's buffer across calls to avoid an allocation per line?
