@@@ meta
id: PTR-H-10
topic: Pointers
difficulty: Hard
type: FUNCTION
title: Zero-Copy TLV Parser That Never Reads Past the Buffer
tags: embedded, tlv, bounds-checking, zero-copy, big-endian, protocol-parsing
@@@ statement_md
Diagnostic and configuration payloads (DHCP options, BLE advertising data, UDS records) are often encoded as **Type-Length-Value** records. Implement a **zero-copy** parser: instead of copying values, each result points **into the input buffer**.

```c
struct tlv {
    uint8_t type;
    uint16_t len;
    const uint8_t *value;     /* points INTO buf */
};

int tlv_parse(const uint8_t *buf, size_t size,
              struct tlv *out, int max_out, size_t *err_off);
```

**Format** (records follow each other from offset 0):
- `0x00`: **PAD**, a single byte. Skip it; it is not reported.
- `0xFF`: **END**, a single byte. Stop parsing successfully, and ignore any bytes after it.
- any other type `T`: `T`, `len_hi`, `len_lo` (16-bit **big-endian** length), then `len` value bytes.

**Result**
- On success (end of buffer or END reached), return the number of records stored in `out[0..]`. `*err_off` is not modified.
- On error, return a negative code and store in `*err_off` the offset of the **first byte of the offending record** (if `err_off != NULL`). Check in this order:
  - `-1`: truncated header (a non-PAD/END type with fewer than 3 bytes left);
  - `-2`: the value runs past the end of the buffer;
  - `-3`: the record is complete, but `max_out` records are already stored.
- `buf` may be `NULL` only when `size == 0` (return 0). `out` may be `NULL` only when `max_out == 0`.
- The buffer is untrusted: **never read a byte outside `buf[0..size-1]`**. The harness allocates exactly `size` bytes, and AddressSanitizer is on. Also never form a pointer more than one past its end.

**How it is tested.** The harness prints `ret=R` (plus ` err_off=E` on error), then one line per record: `type=0xTT len=L off=O value=HEX`, where `O = value - buf` and `HEX` is `-` for an empty value.

**Input (read by the hidden harness)**
- Line 1: `size max_out`
- Line 2: `size` bytes in hex (absent when `size = 0`).

**Example**
```
Input:
12 4
01 00 02 AA BB 00 07 00 01 05 FF 99

Output:
ret=2
type=0x01 len=2 off=3 value=AABB
type=0x07 len=1 off=9 value=05
```
Offset 5 is PAD, and offset 10 is END, so `99` is ignored.
@@@ constraints_md
- `0 <= size <= 2000`, `0 <= max_out <= 100`.
- `len` may be up to `0xFFFF`, far beyond `size`.
- O(size) time, O(1) extra space; no copying of values.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>

struct tlv {
    uint8_t type;
    uint16_t len;
    const uint8_t *value;
};

int tlv_parse(const uint8_t *buf, size_t size,
              struct tlv *out, int max_out, size_t *err_off)
{
    /* TODO */
    (void)buf;
    (void)size;
    (void)out;
    (void)max_out;
    (void)err_off;
    return 0;
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>

/*USER_CODE*/

#define SENTINEL ((size_t)9999)

int main(void)
{
    int size, max_out;
    if (scanf("%d %d", &size, &max_out) != 2 || size < 0 || max_out < 0) return 0;
    uint8_t *buf = size > 0 ? malloc((size_t)size) : NULL;
    if (size > 0 && buf == NULL) return 0;
    for (int i = 0; i < size; i++) {
        unsigned v;
        if (scanf("%x", &v) != 1) {
            free(buf);
            return 0;
        }
        buf[i] = (uint8_t)v;
    }

    struct tlv *out = malloc(((size_t)max_out + 1) * sizeof *out);
    if (out == NULL) {
        free(buf);
        return 0;
    }
    memset(out, 0x5A, ((size_t)max_out + 1) * sizeof *out);
    struct tlv canary;
    memcpy(&canary, &out[max_out], sizeof canary);

    size_t err = SENTINEL;
    int r = tlv_parse(buf, (size_t)size, max_out > 0 ? out : NULL, max_out, &err);

    if (memcmp(&canary, &out[max_out], sizeof canary) != 0) {
        printf("OUT ARRAY OVERFLOW\n");
    } else if (r > max_out) {
        printf("TOO MANY RECORDS RETURNED\n");
    } else if (r >= 0 && err != SENTINEL) {
        printf("ERR_OFF MODIFIED ON SUCCESS\n");
    } else {
        printf("ret=%d", r);
        if (r < 0) printf(" err_off=%zu", err);
        printf("\n");
        for (int i = 0; i < r; i++) {
            uintptr_t b = (uintptr_t)buf, v = (uintptr_t)out[i].value;
            if (v < b || v - b > (size_t)size || out[i].len > (size_t)size - (v - b)) {
                printf("BAD VALUE POINTER\n");
                break;
            }
            printf("type=0x%02X len=%u off=%zu value=", (unsigned)out[i].type, (unsigned)out[i].len,
                   (size_t)(v - b));
            if (out[i].len == 0) printf("-");
            for (unsigned k = 0; k < out[i].len; k++) printf("%02X", (unsigned)out[i].value[k]);
            printf("\n");
        }
    }
    free(out);
    free(buf);
    return 0;
}
@@@ sample_input
12 4
01 00 02 AA BB 00 07 00 01 05 FF 99
@@@ sample_output
ret=2
type=0x01 len=2 off=3 value=AABB
type=0x07 len=1 off=9 value=05

@@@ sample_input
11 4
01 00 02 AA BB 00 07 00 03 01 02
@@@ sample_output
ret=-2 err_off=6

@@@ hidden_input
0 4
@@@ hidden_output
ret=0

@@@ hidden_input
4 4
02 00 00 05
@@@ hidden_output
ret=-1 err_off=3

@@@ hidden_input
3 1
09 00 00
@@@ hidden_output
ret=1
type=0x09 len=0 off=3 value=-

@@@ hidden_input
9 2
01 00 00 02 00 00 03 00 00
@@@ hidden_output
ret=-3 err_off=6

@@@ hidden_input
5 4
10 FF FF 00 00
@@@ hidden_output
ret=-2 err_off=0

@@@ hidden_input
6 0
00 00 FF 01 02 03
@@@ hidden_output
ret=0

@@@ hidden_input
4 0
05 00 01 7F
@@@ hidden_output
ret=-3 err_off=0

@@@ hidden_input
8 3
00 0A 00 01 01 0B 00 00
@@@ hidden_output
ret=2
type=0x0A len=1 off=4 value=01
type=0x0B len=0 off=8 value=-

@@@ hidden_input
2 1
01 00
@@@ hidden_output
ret=-1 err_off=0

@@@ hidden_input
7 2
20 01 00 41 42 43 44
@@@ hidden_output
ret=-2 err_off=0

@@@ hint
Walk with an **offset** `pos` (or a pointer `p` plus `end`) and always compare the **remaining** byte count `size - pos` with what you are about to read. Only read `buf[pos+1]` and `buf[pos+2]` after you have checked that `size - pos >= 3`.
@@@ hint
Assemble the length from bytes: `len = (uint16_t)((buf[pos+1] << 8) | buf[pos+2]);`. Never cast `buf + pos + 1` to `uint16_t *` (wrong byte order on x86, unaligned access, aliasing). Check `len > remaining - 3` instead of `pos + 3 + len > size` or `p + 3 + len > end`: the subtraction cannot overflow and forms no out-of-range pointer. Store `value = buf + pos + 3` (it may equal `buf + size` when `len == 0`).
@@@ solution_code
#include <stddef.h>
#include <stdint.h>

struct tlv {
    uint8_t type;
    uint16_t len;
    const uint8_t *value;
};

#define TLV_PAD 0x00u
#define TLV_END 0xFFu
#define TLV_HDR 3u

static int fail(size_t *err_off, size_t pos, int code)
{
    if (err_off != NULL)
        *err_off = pos;
    return code;
}

int tlv_parse(const uint8_t *buf, size_t size,
              struct tlv *out, int max_out, size_t *err_off)
{
    size_t pos = 0;
    int count = 0;

    if (buf == NULL || size == 0)
        return 0;

    while (pos < size) {
        const uint8_t type = buf[pos];
        if (type == TLV_PAD) {
            pos++;
            continue;
        }
        if (type == TLV_END)
            break;

        const size_t remaining = size - pos;            /* >= 1, never underflows */
        if (remaining < TLV_HDR)
            return fail(err_off, pos, -1);              /* header truncated */

        const uint16_t len = (uint16_t)((buf[pos + 1] << 8) | buf[pos + 2]);  /* big-endian, no cast */
        if (len > remaining - TLV_HDR)
            return fail(err_off, pos, -2);              /* value would overrun the buffer */
        if (count == max_out)
            return fail(err_off, pos, -3);              /* caller's array is full */

        out[count].type = type;
        out[count].len = len;
        out[count].value = buf + pos + TLV_HDR;         /* zero-copy: points into buf */
        count++;
        pos += TLV_HDR + (size_t)len;
    }
    return count;
}
@@@ explanation_md
**Approach.** Treat the input as hostile. Every read is preceded by a check that the byte exists, phrased as "how many bytes remain?":

```
pos ──► [T][Lh][Ll][ value ... ][T][Lh][Ll] ...
         |<----- remaining = size - pos ----->|
need 3 for the header, then len <= remaining - 3
```

- **Lengths from bytes, not casts.** `(buf[pos+1] << 8) | buf[pos+2]` is correct on any host endianness and has no alignment or strict-aliasing problems. `*(uint16_t *)(buf + pos + 1)` gives the wrong value on little-endian x86, faults on a Cortex-M0 when misaligned, and is undefined behavior.
- **Overflow-safe bounds.** `remaining - 3` cannot underflow once `remaining >= 3` has been checked. `pos + 3 + len > size` would be fine with `size_t` here, but the pointer version `p + 3 + len > end` is **undefined** as soon as the pointer goes beyond one past the end (C11 6.5.6p8), and a compiler may "optimise" such a check away. That has caused real CVEs.
- **Zero-copy.** `value` points into `buf`, so the parser uses no memory and no copying. The results are only valid while the caller keeps `buf` alive and unchanged.
- **Check order** follows the format: is the header present? does the value fit? is there room to store it?

**Complexity.** O(size) time: every byte is visited at most once. O(1) extra space.

**Common mistakes**
- Reading `buf[pos+1]`, `buf[pos+2]` before checking that 3 bytes remain. That is a 1-2 byte overread on a truncated buffer (ASan: heap-buffer-overflow).
- Treating PAD/END like normal records and reading a length for them.
- `if (pos + 3 + len > size)` with `pos`/`len` as `uint16_t`/`int`, which can wrap on 16-bit targets. Or the pointer form described above.
- Writing `out[max_out]`, one past the caller's array, before checking `count == max_out`.
- Copying values into a fixed `uint8_t value[255]` buffer. That loses the zero-copy property and truncates `len > 255` silently.

**Interview follow-ups**
- How would you parse **nested** TLVs (a value that is itself a TLV stream) without recursion on a small stack?
- The payload arrives in CAN-TP segments. How do you make the parser **incremental** (resume across chunks) without copying?
- Why is `len` 16-bit big-endian in so many protocols, and how would you write the `put_be16` counterpart for the encoder?
- Fuzz-test this function. Which libFuzzer harness would you write, and which sanitizers would you enable?
