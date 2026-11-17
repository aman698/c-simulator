@@@ meta
id: STR-M-02
topic: Strings
difficulty: Medium
type: FUNCTION
title: my_itoa for Any Base from 2 to 36
tags: embedded, itoa, number-base, int-min, twos-complement, no-printf
@@@ statement_md
There is no `printf` on your bare-metal target, so the debug UART needs its own number formatter. Implement

```c
char *my_itoa(int value, char *buf, int base);
```

(`itoa` is not ISO C, and the Windows CRT already declares one, so the function is `my_itoa`.)

- `base` must be in `2..36`. Digits are `0-9` followed by **lowercase** `a-z`.
- **Base 10** is signed: negative numbers get a leading `'-'` (`-255` -> `"-255"`).
- **Every other base** prints the 32-bit two's-complement bit pattern as an unsigned number, the same as `printf("%x")` or `printf("%o")` would: `-1` in base 16 is `"ffffffff"`. This is what you want when you dump register values.
- No leading zeros, except that zero itself is `"0"`.
- The result is written to `buf`, which is NUL-terminated, and `buf` is returned.
- If `base` is invalid, write the empty string to `buf` and return `NULL`.
- `buf` always has room for **33** bytes (32 binary digits plus `'\0'`). Do not write beyond that.

**How it is tested.** A hidden `main()` gives you a 33-byte buffer pre-filled with `#` and surrounded by guard bytes. It prints `[buf]`, or `INVALID [buf]` when you return `NULL`. It also prints `BAD RETURN VALUE` and `OUT OF BOUNDS WRITE` when appropriate.

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: `value base`.

**Output**
- One line per conversion.

**Example**
```
Input:
4
255 16
-255 10
-1 16
10 1

Output:
[ff]
[-255]
[ffffffff]
INVALID []
```
@@@ constraints_md
- `1 <= q <= 30`
- `INT_MIN <= value <= INT_MAX` (32-bit `int`), `-100 <= base <= 100`.
- Do not use `sprintf`, `snprintf`, `vsprintf` or `vsnprintf` (rejected at compile time).
- No undefined behavior: the judge runs with UBSan (`-INT_MIN` overflows).
@@@ starter_code
#include <stddef.h>

char *my_itoa(int value, char *buf, int base)
{
    /* TODO */
    return buf;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <limits.h>

#define sprintf(...) sprintf_is_not_allowed_in_this_exercise
#define snprintf(...) snprintf_is_not_allowed_in_this_exercise
#define vsprintf(...) vsprintf_is_not_allowed_in_this_exercise
#define vsnprintf(...) vsnprintf_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef sprintf
#undef snprintf
#undef vsprintf
#undef vsnprintf

#define CAP 33
#define GUARD 16
#define CANARY 0x5A

static unsigned char arena[GUARD + CAP + GUARD];

int main(void)
{
    int q;
    if (scanf("%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        int value, base;
        if (scanf("%d %d", &value, &base) != 2) return 0;
        memset(arena, CANARY, sizeof arena);
        char *buf = (char *)arena + GUARD;
        memset(buf, '#', CAP);
        char *ret = my_itoa(value, buf, base);
        for (int k = 0; k < GUARD; k++) {
            if (arena[k] != CANARY || arena[GUARD + CAP + k] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        if (!memchr(buf, '\0', CAP)) {
            printf("MISSING TERMINATOR\n");
            continue;
        }
        int valid = base >= 2 && base <= 36;
        if (valid && ret != buf) printf("BAD RETURN VALUE\n");
        if (!valid && ret != NULL) printf("BAD RETURN VALUE (expected NULL)\n");
        printf("%s[%s]\n", ret == NULL ? "INVALID " : "", buf);
    }
    return 0;
}
@@@ sample_input
4
255 16
-255 10
-1 16
10 1
@@@ sample_output
[ff]
[-255]
[ffffffff]
INVALID []

@@@ sample_input
3
0 2
1000 8
35 36
@@@ sample_output
[0]
[1750]
[z]

@@@ hidden_input
3
-2147483648 10
2147483647 10
-7 10
@@@ hidden_output
[-2147483648]
[2147483647]
[-7]

@@@ hidden_input
4
-1 2
-2147483648 2
2147483647 2
1 2
@@@ hidden_output
[11111111111111111111111111111111]
[10000000000000000000000000000000]
[1111111111111111111111111111111]
[1]

@@@ hidden_input
4
-2147483648 16
48879 16
-10 8
36 36
@@@ hidden_output
[80000000]
[beef]
[37777777766]
[10]

@@@ hidden_input
4
10 37
4096 0
-5 -2
0 36
@@@ hidden_output
INVALID []
INVALID []
INVALID []
[0]

@@@ hidden_input
4
123456789 36
-2147483648 36
-1 36
7 7
@@@ hidden_output
[21i3v9]
[zik0zk]
[1z141z3]
[10]

@@@ hidden_input
2
-123 3
0 10
@@@ hidden_output
[102002022201221100021]
[0]

@@@ hint
Produce the digits with repeated `% base` and `/ base`. They come out **least significant first**, so either write them into the buffer and reverse it at the end, or fill a small temporary array from the back.
@@@ hint
Do all arithmetic on an `unsigned int` magnitude. For base 10 and a negative value, use `0u - (unsigned)value`, which is well defined even for `INT_MIN`. For the other bases, simply use `(unsigned)value`, which gives exactly the two's-complement bit pattern.
@@@ solution_code
#include <stddef.h>

char *my_itoa(int value, char *buf, int base)
{
    static const char digits[] = "0123456789abcdefghijklmnopqrstuvwxyz";
    unsigned int u;
    size_t n = 0;

    if (base < 2 || base > 36) {
        buf[0] = '\0';
        return NULL;
    }

    if (base == 10 && value < 0) {
        buf[n++] = '-';
        u = 0u - (unsigned int)value;   /* |INT_MIN| without signed overflow */
    } else {
        u = (unsigned int)value;        /* two's-complement pattern for other bases */
    }

    size_t start = n;                   /* first digit position (after a '-') */
    do {
        buf[n++] = digits[u % (unsigned int)base];
        u /= (unsigned int)base;
    } while (u != 0);                   /* do-while: 0 still produces "0" */
    buf[n] = '\0';

    for (size_t i = start, j = n - 1; i < j; i++, j--) {   /* digits were LSB-first */
        char t = buf[i];
        buf[i] = buf[j];
        buf[j] = t;
    }
    return buf;
}
@@@ explanation_md
**Approach.**
1. Validate the base.
2. Convert the value to an **unsigned magnitude**. For base 10 and `value < 0`, write `'-'` and take `0u - (unsigned)value`. For any other base, reinterpret the value as `unsigned`, which C defines as the value modulo 2^32, so `-1` becomes `0xFFFFFFFF`.
3. Emit digits with `% base` and `/ base` in a `do { } while` loop, so `0` still produces one digit.
4. The digits came out in reverse, so reverse them in place. Leave a leading `'-'` where it is.

**Why unsigned?** `-INT_MIN` does not fit in an `int`, so `value = -value` is signed overflow (undefined behavior; UBSan flags it). In practice it leaves `value` negative and `%` then produces negative digit indices. The unsigned negation `0u - (unsigned)value` is fully defined: for `INT_MIN` it yields 2147483648.

**Complexity.** Time O(log_base |value|), at most 32 iterations. Space O(1) besides the output buffer.

**Common mistakes**
- `if (value < 0) value = -value;` overflows for `INT_MIN`.
- A `while (u != 0)` loop instead of `do/while`, which turns `0` into an empty string.
- Reversing the whole buffer including the `'-'`, which gives `"552-"`.
- Printing negative numbers in base 16 as `"-ff"`. The specification, like `%x` and register dumps, wants the bit pattern `ffffff01`.
- Off-by-one buffer sizing. Base 2 of `-1` needs 32 digits **plus** the terminator, which is 33 bytes.
- Using `'a' + d - 10` but forgetting that digits 0..9 come from `'0'`. A lookup string `"0123...xyz"` avoids both branches.

**Interview follow-ups**
- Make it work for `int64_t` and `uint64_t`. How many bytes does base 2 need then?
- On a Cortex-M0, which has no hardware divider, `/ 10` and `% 10` are expensive library calls. How do compilers turn division by a constant into a multiply-and-shift, and when would you write that yourself?
- Add zero-padding to a fixed width (e.g. `"%08x"`) and an uppercase option without duplicating the digit loop.
- Write the inverse, `my_strtoi(const char *s, int base)`, with overflow detection.
