@@@ meta
id: MEM-E-10
topic: Dynamic Memory
difficulty: Easy
type: FUNCTION
title: Frame Buffer Create/Destroy With Partial-Failure Cleanup
tags: embedded, constructor-destructor, malloc-failure, ownership, free-null
@@@ statement_md
A diagnostic stack assembles outgoing frames in a small heap object. The object is a header struct that **owns** a separate payload buffer. Implement the classic create/append/destroy trio:

```c
struct frame_buf {
    uint8_t *data;   /* payload buffer of cap bytes */
    size_t len;      /* bytes used */
    size_t cap;      /* bytes available */
};

struct frame_buf *fb_create(size_t cap);
int  fb_append(struct frame_buf *fb, uint8_t byte);
void fb_destroy(struct frame_buf *fb);
```

**Allocate only through `xmalloc(size)`**, which the harness provides. It behaves exactly like `malloc`, but the harness can make a chosen call fail. Release memory with `free()`.

- `fb_create(cap)`: if `cap == 0`, return `NULL` without allocating. Otherwise allocate the struct, then the `cap`-byte payload, set `len = 0`, and return the struct. If **either** allocation fails, return `NULL` **without leaking** anything allocated so far.
- `fb_append(fb, byte)`: if `fb` is `NULL` or full, return `-1`. Otherwise store the byte at `data[len++]` and return `0`.
- `fb_destroy(fb)`: release the payload, then the struct. `fb_destroy(NULL)` must do nothing (just like `free(NULL)`).

**Input (read by the hidden harness)**
- Line 1: `fail <k>`. The `k`-th call to `xmalloc` (counting from 1 over the whole test) returns `NULL`. `k = 0` means no failure.
- Then one operation per line:
  - `C <cap>`: `fb = fb_create(cap)`. The harness prints `create <cap>: ok` or `create <cap>: NULL`.
  - `A <hex byte>`: append. Prints `append XX: ok` or `append XX: full`.
  - `P`: prints `len=<len> cap=<cap> data=<bytes as %02X separated by spaces>` (or `no buffer`).
  - `D`: `fb_destroy(fb); fb = NULL;` and prints `destroyed`.

**Example**
```
Input:
fail 0
C 2
A 7E
A 01
A FF
P
D

Output:
create 2: ok
append 7E: ok
append 01: ok
append FF: full
len=2 cap=2 data=7E 01
destroyed
```
@@@ constraints_md
- `0 <= cap <= 4096`, at most 100 operations.
- Every test ends with the buffer destroyed (or never created). Any leaked block fails the test.
- Do not call `malloc`/`calloc` directly. Use `xmalloc` so the failure tests can reach your error paths.
@@@ starter_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

void *xmalloc(size_t size); /* provided by the harness: like malloc, may fail on demand */

struct frame_buf {
    uint8_t *data;
    size_t len;
    size_t cap;
};

struct frame_buf *fb_create(size_t cap)
{
    /* TODO */
    return NULL;
}

int fb_append(struct frame_buf *fb, uint8_t byte)
{
    /* TODO */
    return -1;
}

void fb_destroy(struct frame_buf *fb)
{
    /* TODO */
}
@@@ harness_code
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

static int g_calls;
static int g_fail_at;

void *xmalloc(size_t size)
{
    g_calls++;
    if (g_calls == g_fail_at)
        return NULL;
    return malloc(size);
}

/*USER_CODE*/

int main(void)
{
    char op[8];
    struct frame_buf *fb = NULL;

    if (scanf("%7s %d", op, &g_fail_at) != 2)
        return 0;
    fb_destroy(NULL);                       /* must be a no-op */
    if (fb_append(NULL, 0x00) != -1)
        printf("FAIL: fb_append(NULL, ...) must return -1\n");

    while (scanf("%7s", op) == 1) {
        if (op[0] == 'C') {
            unsigned int cap;
            if (scanf("%u", &cap) != 1)
                break;
            if (fb != NULL) {               /* tests never do this, but stay leak-free */
                fb_destroy(fb);
                fb = NULL;
            }
            fb = fb_create(cap);
            printf("create %u: %s\n", cap, fb ? "ok" : "NULL");
            if (fb != NULL && (fb->len != 0 || fb->cap != cap || fb->data == NULL))
                printf("FAIL: bad initial state\n");
        } else if (op[0] == 'A') {
            unsigned int b;
            if (scanf("%x", &b) != 1)
                break;
            printf("append %02X: %s\n", b, fb_append(fb, (uint8_t)b) == 0 ? "ok" : "full");
        } else if (op[0] == 'P') {
            if (fb == NULL) {
                printf("no buffer\n");
                continue;
            }
            printf("len=%zu cap=%zu data=", fb->len, fb->cap);
            for (size_t i = 0; i < fb->len; i++)
                printf("%s%02X", i ? " " : "", fb->data[i]);
            printf("\n");
        } else if (op[0] == 'D') {
            fb_destroy(fb);
            fb = NULL;
            printf("destroyed\n");
        }
    }
    if (fb != NULL)
        fb_destroy(fb);
    return 0;
}
@@@ sample_input
fail 0
C 2
A 7E
A 01
A FF
P
D
@@@ sample_output
create 2: ok
append 7E: ok
append 01: ok
append FF: full
len=2 cap=2 data=7E 01
destroyed

@@@ sample_input
fail 2
C 8
P
A 10
D
@@@ sample_output
create 8: NULL
no buffer
append 10: full
destroyed

@@@ hidden_input
fail 1
C 8
C 4
A AB
P
D
@@@ hidden_output
create 8: NULL
create 4: ok
append AB: ok
len=1 cap=4 data=AB
destroyed

@@@ hidden_input
fail 0
C 0
A 01
P
D
@@@ hidden_output
create 0: NULL
append 01: full
no buffer
destroyed

@@@ hidden_input
fail 4
C 3
A 00
D
C 5
A 11
P
D
@@@ hidden_output
create 3: ok
append 00: ok
destroyed
create 5: NULL
append 11: full
no buffer
destroyed

@@@ hidden_input
fail 3
C 1
A 5A
A A5
P
D
C 2
P
D
@@@ hidden_output
create 1: ok
append 5A: ok
append A5: full
len=1 cap=1 data=5A
destroyed
create 2: NULL
no buffer
destroyed

@@@ hidden_input
fail 0
C 4096
A DE
A AD
A BE
A EF
P
D
D
@@@ hidden_output
create 4096: ok
append DE: ok
append AD: ok
append BE: ok
append EF: ok
len=4 cap=4096 data=DE AD BE EF
destroyed
destroyed

@@@ hint
Two allocations means two failure points. If the struct allocation fails, there is nothing to clean up. If the **payload** allocation fails, the struct you already hold must be freed before you return `NULL`.
@@@ hint
The destructor mirrors the constructor in reverse: `free(fb->data)` first, then `free(fb)`. Start it with `if (fb == NULL) return;`. Freeing the struct first and then reading `fb->data` is a use-after-free.
@@@ solution_code
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

void *xmalloc(size_t size); /* provided by the harness: like malloc, may fail on demand */

struct frame_buf {
    uint8_t *data;
    size_t len;
    size_t cap;
};

struct frame_buf *fb_create(size_t cap)
{
    if (cap == 0)
        return NULL;                      /* reject; never depend on malloc(0) */

    struct frame_buf *fb = xmalloc(sizeof *fb);
    if (fb == NULL)
        return NULL;                      /* nothing to undo yet */

    fb->data = xmalloc(cap);
    if (fb->data == NULL) {
        free(fb);                         /* undo the first allocation */
        return NULL;
    }
    fb->len = 0;
    fb->cap = cap;
    return fb;
}

int fb_append(struct frame_buf *fb, uint8_t byte)
{
    if (fb == NULL || fb->len >= fb->cap)
        return -1;
    fb->data[fb->len++] = byte;
    return 0;
}

void fb_destroy(struct frame_buf *fb)
{
    if (fb == NULL)
        return;
    free(fb->data);                       /* inner resource first ... */
    free(fb);                             /* ... then the owner       */
}
@@@ explanation_md
**Approach.** The constructor acquires resources in order: struct, then payload. Each failure point releases exactly what was acquired before it. The destructor releases them in **reverse** order, and like `free(NULL)` it accepts `NULL`. That lets callers write `fb_destroy(fb)` unconditionally on every error path.

```
fb_create:   fb = xmalloc(hdr)  ──fail──► return NULL
             fb->data = xmalloc(cap) ──fail──► free(fb); return NULL
fb_destroy:  free(fb->data); free(fb);
```

**Complexity.** All operations are O(1) time. Space is O(cap) plus the header.

**Common mistakes**
- Returning `NULL` when the payload allocation fails without freeing the struct. This is the most common leak in constructors, and it only shows up under memory pressure, so normal tests never catch it.
- `free(fb); free(fb->data);`: reads `fb->data` from freed memory.
- Not handling `fb == NULL` in the destructor, which forces every caller to add a check.
- Treating `cap == 0` as valid and calling `malloc(0)`. Its result is implementation-defined (`NULL` or a unique pointer), so behavior would differ between platforms.

**Interview follow-ups**
- Allocate the header and payload in **one** block using a flexible array member (`uint8_t data[];`). What do you gain (one failure point, one `free`, better locality) and what do you lose?
- With five resources, how does the `goto cleanup` ladder pattern keep error handling linear? Why do many automotive coding guidelines (and MISRA Rule 15.1, advisory) still argue about `goto`?
- MISRA C:2012 Rule 21.3 bans `malloc`/`free`. How would you provide `fb_create` in a MISRA project? (A static pool of `frame_buf` objects with fixed-size payloads.)
