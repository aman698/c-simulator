@@@ meta
id: STC-H-10
topic: Structures
difficulty: Hard
type: FIND_THE_BUG
title: CAN TX Queue Loses Messages After a Cancel (Stale Tail)
tags: embedded, linked-list, queue, tail-pointer, use-after-free, invariant, can-bus
@@@ statement_md
A CAN driver buffers outgoing messages in a FIFO linked list with **head and tail** pointers, so both push and pop are O(1). The application may also **cancel** a pending message by ID, for example when a newer value supersedes it.

```c
struct TxNode  { uint32_t id; uint8_t dlc; uint8_t data[8]; struct TxNode *next; };
struct TxQueue { struct TxNode *head, *tail; size_t count; };
```

Commands:
- `PUSH id dlc bytes`: append a message (prints nothing).
- `POP`: remove the oldest message and print `POP 0x<ID> [dlc] bytes`, or `POP EMPTY`.
- `CANCEL id`: remove the **first** (oldest) pending message with that ID; prints `CANCEL 0x<ID> -> 1` or `-> 0`.
- `SHOW`: prints `queue[<count>]: <ids>` (or `queue[0]: -`).

At exit the program prints `pending=<count>` and frees the queue.

**Symptoms.** Usually everything works. But after certain cancels, messages pushed later never appear in the queue (`SHOW` and `POP` miss them), and the judge reports **heap-use-after-free** or a **memory leak**. Push, pop and cancelling from the front or middle work correctly.

Find and fix the bug. Keep the output format.

**Example**
```
Input:
PUSH 100 1 AA
PUSH 200 1 BB
CANCEL 200
PUSH 300 1 CC
SHOW
POP
POP
POP

Output:
CANCEL 0x200 -> 1
queue[2]: 0x100 0x300
POP 0x100 [1] AA
POP 0x300 [1] CC
POP EMPTY
pending=0
```
@@@ constraints_md
- At most 500 commands; IDs `0x000 .. 0x7FF`; `0 <= dlc <= 8`.
- Every node must be freed exactly once; no access after free.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct TxNode {
    uint32_t       id;
    uint8_t        dlc;
    uint8_t        data[8];
    struct TxNode *next;
};

struct TxQueue {
    struct TxNode *head;
    struct TxNode *tail;
    size_t         count;
};

static int txq_push(struct TxQueue *q, uint32_t id, uint8_t dlc, const uint8_t *data)
{
    struct TxNode *n = malloc(sizeof *n);
    if (n == NULL)
        return -1;
    n->id = id;
    n->dlc = dlc;
    memcpy(n->data, data, sizeof n->data);
    n->next = NULL;
    if (q->tail != NULL)
        q->tail->next = n;
    else
        q->head = n;
    q->tail = n;
    q->count++;
    return 0;
}

static int txq_pop(struct TxQueue *q, struct TxNode *out)
{
    struct TxNode *n = q->head;
    if (n == NULL)
        return -1;
    *out = *n;
    q->head = n->next;
    if (q->head == NULL)
        q->tail = NULL;
    q->count--;
    free(n);
    return 0;
}

/* Remove the oldest pending message with this id. */
static int txq_cancel(struct TxQueue *q, uint32_t id)
{
    struct TxNode *prev = NULL;
    struct TxNode *cur = q->head;
    while (cur != NULL) {
        if (cur->id == id) {
            if (prev != NULL)
                prev->next = cur->next;
            else
                q->head = cur->next;
            q->count--;
            free(cur);
            return 1;
        }
        prev = cur;
        cur = cur->next;
    }
    return 0;
}

static void txq_flush(struct TxQueue *q)
{
    struct TxNode out;
    while (txq_pop(q, &out) == 0)
        ;
}

int main(void)
{
    struct TxQueue q = { NULL, NULL, 0 };
    char cmd[8];

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "PUSH") == 0) {
            unsigned id, dlc;
            uint8_t data[8] = { 0 };
            if (scanf("%x %u", &id, &dlc) != 2 || dlc > 8) break;
            for (unsigned i = 0; i < dlc; i++) {
                unsigned b;
                if (scanf("%x", &b) != 1) b = 0;
                data[i] = (uint8_t)b;
            }
            txq_push(&q, id, (uint8_t)dlc, data);
        } else if (strcmp(cmd, "POP") == 0) {
            struct TxNode m;
            if (txq_pop(&q, &m) != 0) {
                printf("POP EMPTY\n");
            } else {
                printf("POP 0x%03X [%u]", (unsigned)m.id, (unsigned)m.dlc);
                for (unsigned i = 0; i < m.dlc; i++) printf(" %02X", (unsigned)m.data[i]);
                printf("\n");
            }
        } else if (strcmp(cmd, "CANCEL") == 0) {
            unsigned id;
            if (scanf("%x", &id) != 1) break;
            printf("CANCEL 0x%03X -> %d\n", id, txq_cancel(&q, id));
        } else if (strcmp(cmd, "SHOW") == 0) {
            printf("queue[%u]:", (unsigned)q.count);
            if (q.head == NULL) printf(" -");
            for (const struct TxNode *p = q.head; p != NULL; p = p->next)
                printf(" 0x%03X", (unsigned)p->id);
            printf("\n");
        }
    }
    printf("pending=%u\n", (unsigned)q.count);
    txq_flush(&q);
    return 0;
}
@@@ sample_input
PUSH 100 1 AA
PUSH 200 1 BB
CANCEL 200
PUSH 300 1 CC
SHOW
POP
POP
POP
@@@ sample_output
CANCEL 0x200 -> 1
queue[2]: 0x100 0x300
POP 0x100 [1] AA
POP 0x300 [1] CC
POP EMPTY
pending=0

@@@ sample_input
PUSH 1 0
PUSH 2 0
PUSH 3 0
CANCEL 2
CANCEL 1
SHOW
CANCEL 9
@@@ sample_output
CANCEL 0x002 -> 1
CANCEL 0x001 -> 1
queue[1]: 0x003
CANCEL 0x009 -> 0
pending=1

@@@ hidden_input
PUSH 7 2 01 02
CANCEL 7
PUSH 8 1 03
SHOW
POP
@@@ hidden_output
CANCEL 0x007 -> 1
queue[1]: 0x008
POP 0x008 [1] 03
pending=0

@@@ hidden_input
PUSH 1 0
PUSH 2 0
PUSH 3 0
CANCEL 3
CANCEL 2
PUSH 4 0
SHOW
@@@ hidden_output
CANCEL 0x003 -> 1
CANCEL 0x002 -> 1
queue[2]: 0x001 0x004
pending=2

@@@ hidden_input
PUSH 10 8 01 02 03 04 05 06 07 08
POP
POP
PUSH 11 0
PUSH 12 0
POP
SHOW
@@@ hidden_output
POP 0x010 [8] 01 02 03 04 05 06 07 08
POP EMPTY
POP 0x011 [0]
queue[1]: 0x012
pending=1

@@@ hidden_input
PUSH 5 1 01
PUSH 5 1 02
CANCEL 5
SHOW
POP
CANCEL 5
@@@ hidden_output
CANCEL 0x005 -> 1
queue[1]: 0x005
POP 0x005 [1] 02
CANCEL 0x005 -> 0
pending=0

@@@ hidden_input
PUSH 7FF 0
PUSH 000 0
CANCEL 000
@@@ hidden_output
CANCEL 0x000 -> 1
pending=1

@@@ hidden_input
CANCEL 5
POP
SHOW
PUSH 3 1 59
PUSH 0 8 C0 F0 FB 0F 93 EF F3 A7
CANCEL 5
CANCEL 3
PUSH 5 2 07 2B
CANCEL 2
CANCEL 1
POP
PUSH 5 5 22 6D 99 55 61
PUSH 2 6 44 BF BA 62 EA D2
PUSH 2 0
PUSH 4 4 AD 0F 65 31
CANCEL 0
CANCEL 4
CANCEL 4
POP
PUSH 1 3 FC 7C FC
POP
POP
POP
PUSH 2 3 FC 18 68
PUSH 2 6 28 38 08 98 E8 93
PUSH 2 1 E0
PUSH 0 3 20 D0 C0
PUSH 2 1 00
SHOW
PUSH 3 1 CF
POP
CANCEL 2
SHOW
PUSH 2 6 78 48 D8 28 38 A3
POP
CANCEL 0
CANCEL 4
CANCEL 2
PUSH 0 2 6D CF
PUSH 0 5 E2 6A 52 B5 40
PUSH 3 3 13 47 6B
SHOW
SHOW
PUSH 1 0
POP
SHOW
CANCEL 1
SHOW
POP
PUSH 0 3 3F 9E AC
CANCEL 4
PUSH 5 7 9D 09 05 51 AD D9 95
POP
CANCEL 0
PUSH 4 2 54 F4
CANCEL 0
PUSH 2 8 5A 1D 89 85 6C 62 EA D2
PUSH 4 3 3A E2 05
SHOW
PUSH 1 2 05 EC
CANCEL 4
CANCEL 5
SHOW
PUSH 2 2 EC AC
POP
CANCEL 1
CANCEL 4
PUSH 2 2 A9 25
POP
CANCEL 4
CANCEL 1
PUSH 1 6 BA 62 EA 6D 99 55
SHOW
CANCEL 0
CANCEL 4
CANCEL 4
POP
PUSH 0 3 FE 56 CE
PUSH 0 0
POP
PUSH 1 7 CB 3A E2 6A 52 1A 42
SHOW
POP
PUSH 1 4 09 05 EC AC
PUSH 1 8 3F 03 77 DB 6F 73 27 CB
SHOW
PUSH 5 0
SHOW
CANCEL 3
POP
CANCEL 3
POP
CANCEL 4
POP
CANCEL 0
POP
PUSH 4 5 88 18 68 78 48
PUSH 0 1 08
CANCEL 2
CANCEL 4
CANCEL 5
PUSH 1 7 76 6E 06 59 15 21 3D
PUSH 5 2 E8 F8
PUSH 4 1 B8
SHOW
CANCEL 0
CANCEL 3
PUSH 3 3 C9 C5 AC
CANCEL 2
CANCEL 2
CANCEL 0
POP
PUSH 4 0
CANCEL 4
PUSH 1 1 08
PUSH 4 4 C8 F3 A7 E6
POP
CANCEL 4
CANCEL 4
POP
SHOW
POP
CANCEL 5
POP
PUSH 4 2 79 EB
PUSH 4 6 98 E8 F8 C8 F3 A7
SHOW
PUSH 1 6 4F D3 A2 2A 12 DA
POP
PUSH 5 1 35
PUSH 4 6 F3 A7 4B BA 62 EA
PUSH 2 0
POP
PUSH 3 7 55 61 7D 68 78 E3 0E
PUSH 1 7 E9 65 31 0D B9 90 80
SHOW
CANCEL 4
CANCEL 2
PUSH 2 3 16 8E A6
CANCEL 4
POP
POP
POP
PUSH 1 1 8C
CANCEL 2
POP
PUSH 1 1 78
PUSH 4 5 38 08 98 E8 F8
CANCEL 0
CANCEL 4
POP
PUSH 5 0
CANCEL 1
POP
SHOW
PUSH 2 3 B4 6F 73
SHOW
PUSH 5 8 E8 F8 C8 F3 A7 4C 8C 67
PUSH 0 6 F6 EE 86 3E 96 0E
CANCEL 3
PUSH 1 2 7D 69
SHOW
POP
PUSH 3 5 8B FA A2 2A 12
POP
POP
POP
PUSH 3 7 98 1E 2C EC AC 07 61
PUSH 1 7 C6 7E D6 4E 66 9E 76
PUSH 4 8 16 8E A6 DE B6 AE 46 FE
PUSH 4 0
PUSH 1 2 B8 88
CANCEL 0
PUSH 1 0
PUSH 2 3 21 3D 29
PUSH 3 7 F9 35 5C 5C 5C 5C F7
PUSH 2 1 64
POP
PUSH 5 6 52 1A DD 49 E0 C6
POP
CANCEL 0
SHOW
CANCEL 4
CANCEL 0
POP
CANCEL 2
CANCEL 3
PUSH 5 4 28 6E D8 28
POP
PUSH 0 6 C8 80 7D 3A DB A6
PUSH 2 8 E1 FD E9 65 31 35 C1 5D
CANCEL 2
POP
SHOW
SHOW
PUSH 5 5 FF EB 0D B9 F5
PUSH 1 6 84 FF C3 37 9B 2F
PUSH 1 3 5F A3 97
CANCEL 2
PUSH 4 7 91 ED 19 70 E0 2B 7F
CANCEL 1
CANCEL 4
CANCEL 3
CANCEL 2
POP
CANCEL 0
CANCEL 4
POP
PUSH 2 6 07 2B 1A 42 E5 E7
SHOW
POP
PUSH 0 5 50 40 70 E0 90
PUSH 0 4 D0 C0 F0 60
PUSH 2 5 A0 50 40 70 E0
PUSH 0 3 20 D0 5B
PUSH 3 0
PUSH 3 1 A0
CANCEL 1
POP
PUSH 0 3 72 55 98
PUSH 2 2 80 B0
PUSH 4 7 F0 60 AB C2 65 31 35
POP
PUSH 0 8 04 7F 79 87 AB FF C3 D2
CANCEL 0
POP
SHOW
PUSH 3 3 24 84 FF
PUSH 2 1 C4
PUSH 3 8 DB 6F 73 C2 CA 32 7A 22
PUSH 0 1 82
CANCEL 3
SHOW
CANCEL 2
SHOW
PUSH 4 2 B9 F5
CANCEL 4
CANCEL 1
SHOW
PUSH 5 8 FA A2 2A 12 DA 02 0A 0D
SHOW
PUSH 2 7 B7 52 1A 42 4A B2 FA
SHOW
PUSH 3 5 94 34 54 F4 14
CANCEL 5
CANCEL 1
POP
CANCEL 0
CANCEL 0
PUSH 2 4 FA A2 2A 12
CANCEL 4
PUSH 2 5 62 EA D2 9A 5D
PUSH 3 6 08 98 E8 93 C7 EB
PUSH 1 8 DB 6F 0E 26 5E 36 2E C6
PUSH 4 8 01 D4 74 0A 72 BA 62 EA
CANCEL 0
CANCEL 0
POP
PUSH 4 5 F5 81 B8 BE 16
CANCEL 2
PUSH 0 0
CANCEL 0
PUSH 2 4 1E F6 89 85
CANCEL 1
PUSH 4 7 D4 0F 93 C7 EB DA 02
PUSH 1 8 53 59 15 21 3D 29 A5 71
SHOW
PUSH 0 4 60 10 00 30
PUSH 5 0
PUSH 1 7 43 DF 24 84 FF C3 D2
PUSH 4 2 82 8A
PUSH 4 5 6A 52 1A 42 E5
CANCEL 0
POP
POP
SHOW
POP
CANCEL 0
CANCEL 4
PUSH 4 6 9D A4 3A B4 D4 74
PUSH 4 6 F3 A7 E6 54 F4 14
POP
SHOW
POP
PUSH 3 8 76 A4 3A E2 6A 52 1A 42
CANCEL 0
CANCEL 0
SHOW
SHOW
POP
PUSH 4 5 48 D8 28 38 08
POP
POP
CANCEL 2
PUSH 5 2 83 F7
PUSH 0 4 5B 8A B5 41
POP
CANCEL 0
POP
SHOW
SHOW
@@@ hidden_output
CANCEL 0x005 -> 0
POP EMPTY
queue[0]: -
CANCEL 0x005 -> 0
CANCEL 0x003 -> 1
CANCEL 0x002 -> 0
CANCEL 0x001 -> 0
POP 0x000 [8] C0 F0 FB 0F 93 EF F3 A7
CANCEL 0x000 -> 0
CANCEL 0x004 -> 1
CANCEL 0x004 -> 0
POP 0x005 [2] 07 2B
POP 0x005 [5] 22 6D 99 55 61
POP 0x002 [6] 44 BF BA 62 EA D2
POP 0x002 [0]
queue[6]: 0x001 0x002 0x002 0x002 0x000 0x002
POP 0x001 [3] FC 7C FC
CANCEL 0x002 -> 1
queue[5]: 0x002 0x002 0x000 0x002 0x003
POP 0x002 [6] 28 38 08 98 E8 93
CANCEL 0x000 -> 1
CANCEL 0x004 -> 0
CANCEL 0x002 -> 1
queue[6]: 0x002 0x003 0x002 0x000 0x000 0x003
queue[6]: 0x002 0x003 0x002 0x000 0x000 0x003
POP 0x002 [1] 00
queue[6]: 0x003 0x002 0x000 0x000 0x003 0x001
CANCEL 0x001 -> 1
queue[5]: 0x003 0x002 0x000 0x000 0x003
POP 0x003 [1] CF
CANCEL 0x004 -> 0
POP 0x002 [6] 78 48 D8 28 38 A3
CANCEL 0x000 -> 1
CANCEL 0x000 -> 1
queue[6]: 0x003 0x000 0x005 0x004 0x002 0x004
CANCEL 0x004 -> 1
CANCEL 0x005 -> 1
queue[5]: 0x003 0x000 0x002 0x004 0x001
POP 0x003 [3] 13 47 6B
CANCEL 0x001 -> 1
CANCEL 0x004 -> 1
POP 0x000 [3] 3F 9E AC
CANCEL 0x004 -> 0
CANCEL 0x001 -> 0
queue[4]: 0x002 0x002 0x002 0x001
CANCEL 0x000 -> 0
CANCEL 0x004 -> 0
CANCEL 0x004 -> 0
POP 0x002 [8] 5A 1D 89 85 6C 62 EA D2
POP 0x002 [2] EC AC
queue[5]: 0x002 0x001 0x000 0x000 0x001
POP 0x002 [2] A9 25
queue[6]: 0x001 0x000 0x000 0x001 0x001 0x001
queue[7]: 0x001 0x000 0x000 0x001 0x001 0x001 0x005
CANCEL 0x003 -> 0
POP 0x001 [6] BA 62 EA 6D 99 55
CANCEL 0x003 -> 0
POP 0x000 [3] FE 56 CE
CANCEL 0x004 -> 0
POP 0x000 [0]
CANCEL 0x000 -> 0
POP 0x001 [7] CB 3A E2 6A 52 1A 42
CANCEL 0x002 -> 0
CANCEL 0x004 -> 1
CANCEL 0x005 -> 1
queue[6]: 0x001 0x001 0x000 0x001 0x005 0x004
CANCEL 0x000 -> 1
CANCEL 0x003 -> 0
CANCEL 0x002 -> 0
CANCEL 0x002 -> 0
CANCEL 0x000 -> 0
POP 0x001 [4] 09 05 EC AC
CANCEL 0x004 -> 1
POP 0x001 [8] 3F 03 77 DB 6F 73 27 CB
CANCEL 0x004 -> 1
CANCEL 0x004 -> 1
POP 0x001 [7] 76 6E 06 59 15 21 3D
queue[3]: 0x005 0x003 0x001
POP 0x005 [2] E8 F8
CANCEL 0x005 -> 0
POP 0x003 [3] C9 C5 AC
queue[3]: 0x001 0x004 0x004
POP 0x001 [1] 08
POP 0x004 [2] 79 EB
queue[7]: 0x004 0x001 0x005 0x004 0x002 0x003 0x001
CANCEL 0x004 -> 1
CANCEL 0x002 -> 1
CANCEL 0x004 -> 1
POP 0x001 [6] 4F D3 A2 2A 12 DA
POP 0x005 [1] 35
POP 0x003 [7] 55 61 7D 68 78 E3 0E
CANCEL 0x002 -> 1
POP 0x001 [7] E9 65 31 0D B9 90 80
CANCEL 0x000 -> 0
CANCEL 0x004 -> 1
POP 0x001 [1] 8C
CANCEL 0x001 -> 1
POP 0x005 [0]
queue[0]: -
queue[1]: 0x002
CANCEL 0x003 -> 0
queue[4]: 0x002 0x005 0x000 0x001
POP 0x002 [3] B4 6F 73
POP 0x005 [8] E8 F8 C8 F3 A7 4C 8C 67
POP 0x000 [6] F6 EE 86 3E 96 0E
POP 0x001 [2] 7D 69
CANCEL 0x000 -> 0
POP 0x003 [5] 8B FA A2 2A 12
POP 0x003 [7] 98 1E 2C EC AC 07 61
CANCEL 0x000 -> 0
queue[9]: 0x001 0x004 0x004 0x001 0x001 0x002 0x003 0x002 0x005
CANCEL 0x004 -> 1
CANCEL 0x000 -> 0
POP 0x001 [7] C6 7E D6 4E 66 9E 76
CANCEL 0x002 -> 1
CANCEL 0x003 -> 1
POP 0x004 [0]
CANCEL 0x002 -> 1
POP 0x001 [2] B8 88
queue[5]: 0x001 0x005 0x005 0x000 0x002
queue[5]: 0x001 0x005 0x005 0x000 0x002
CANCEL 0x002 -> 1
CANCEL 0x001 -> 1
CANCEL 0x004 -> 1
CANCEL 0x003 -> 0
CANCEL 0x002 -> 0
POP 0x005 [6] 52 1A DD 49 E0 C6
CANCEL 0x000 -> 1
CANCEL 0x004 -> 0
POP 0x005 [4] 28 6E D8 28
queue[4]: 0x005 0x001 0x001 0x002
POP 0x005 [5] FF EB 0D B9 F5
CANCEL 0x001 -> 1
POP 0x001 [3] 5F A3 97
POP 0x002 [6] 07 2B 1A 42 E5 E7
CANCEL 0x000 -> 1
POP 0x000 [4] D0 C0 F0 60
queue[8]: 0x002 0x000 0x003 0x003 0x000 0x002 0x004 0x000
CANCEL 0x003 -> 1
queue[11]: 0x002 0x000 0x003 0x000 0x002 0x004 0x000 0x003 0x002 0x003 0x000
CANCEL 0x002 -> 1
queue[10]: 0x000 0x003 0x000 0x002 0x004 0x000 0x003 0x002 0x003 0x000
CANCEL 0x004 -> 1
CANCEL 0x001 -> 0
queue[10]: 0x000 0x003 0x000 0x002 0x000 0x003 0x002 0x003 0x000 0x004
queue[11]: 0x000 0x003 0x000 0x002 0x000 0x003 0x002 0x003 0x000 0x004 0x005
queue[12]: 0x000 0x003 0x000 0x002 0x000 0x003 0x002 0x003 0x000 0x004 0x005 0x002
CANCEL 0x005 -> 1
CANCEL 0x001 -> 0
POP 0x000 [3] 20 D0 5B
CANCEL 0x000 -> 1
CANCEL 0x000 -> 1
CANCEL 0x004 -> 1
CANCEL 0x000 -> 1
CANCEL 0x000 -> 0
POP 0x003 [1] A0
CANCEL 0x002 -> 1
CANCEL 0x000 -> 1
CANCEL 0x001 -> 1
queue[13]: 0x003 0x002 0x003 0x002 0x003 0x002 0x002 0x003 0x004 0x004 0x002 0x004 0x001
CANCEL 0x000 -> 1
POP 0x003 [3] 24 84 FF
POP 0x002 [1] C4
queue[15]: 0x003 0x002 0x003 0x002 0x002 0x003 0x004 0x004 0x002 0x004 0x001 0x005 0x001 0x004 0x004
POP 0x003 [8] DB 6F 73 C2 CA 32 7A 22
CANCEL 0x000 -> 0
CANCEL 0x004 -> 1
POP 0x002 [7] B7 52 1A 42 4A B2 FA
queue[14]: 0x003 0x002 0x002 0x003 0x004 0x002 0x004 0x001 0x005 0x001 0x004 0x004 0x004 0x004
POP 0x003 [5] 94 34 54 F4 14
CANCEL 0x000 -> 0
CANCEL 0x000 -> 0
queue[14]: 0x002 0x002 0x003 0x004 0x002 0x004 0x001 0x005 0x001 0x004 0x004 0x004 0x004 0x003
queue[14]: 0x002 0x002 0x003 0x004 0x002 0x004 0x001 0x005 0x001 0x004 0x004 0x004 0x004 0x003
POP 0x002 [4] FA A2 2A 12
POP 0x002 [5] 62 EA D2 9A 5D
POP 0x003 [6] 08 98 E8 93 C7 EB
CANCEL 0x002 -> 1
POP 0x004 [5] F5 81 B8 BE 16
CANCEL 0x000 -> 1
POP 0x004 [7] D4 0F 93 C7 EB DA 02
queue[10]: 0x001 0x005 0x001 0x004 0x004 0x004 0x004 0x003 0x004 0x005
queue[10]: 0x001 0x005 0x001 0x004 0x004 0x004 0x004 0x003 0x004 0x005
pending=10

@@@ hint
Write down the invariants of the queue: `head == NULL` exactly when `tail == NULL`, and `tail` is the last node reachable from `head`. Then check which function can break the second one.
@@@ hint
When `txq_cancel` removes the **last** node, `q->tail` still points at the freed node. The next `txq_push` writes `q->tail->next = n` into freed memory, and the new node is never linked. Add `if (q->tail == cur) q->tail = prev;` before the `free`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct TxNode {
    uint32_t       id;
    uint8_t        dlc;
    uint8_t        data[8];
    struct TxNode *next;
};

struct TxQueue {
    struct TxNode *head;
    struct TxNode *tail;
    size_t         count;
};

static int txq_push(struct TxQueue *q, uint32_t id, uint8_t dlc, const uint8_t *data)
{
    struct TxNode *n = malloc(sizeof *n);
    if (n == NULL)
        return -1;
    n->id = id;
    n->dlc = dlc;
    memcpy(n->data, data, sizeof n->data);
    n->next = NULL;
    if (q->tail != NULL)
        q->tail->next = n;
    else
        q->head = n;
    q->tail = n;
    q->count++;
    return 0;
}

static int txq_pop(struct TxQueue *q, struct TxNode *out)
{
    struct TxNode *n = q->head;
    if (n == NULL)
        return -1;
    *out = *n;
    q->head = n->next;
    if (q->head == NULL)
        q->tail = NULL;
    q->count--;
    free(n);
    return 0;
}

/* Remove the oldest pending message with this id. */
static int txq_cancel(struct TxQueue *q, uint32_t id)
{
    struct TxNode *prev = NULL;
    struct TxNode *cur = q->head;
    while (cur != NULL) {
        if (cur->id == id) {
            if (prev != NULL)
                prev->next = cur->next;
            else
                q->head = cur->next;
            if (q->tail == cur)          /* FIX: removing the last node -> tail moves back */
                q->tail = prev;          /* (NULL when the queue becomes empty)            */
            q->count--;
            free(cur);
            return 1;
        }
        prev = cur;
        cur = cur->next;
    }
    return 0;
}

static void txq_flush(struct TxQueue *q)
{
    struct TxNode out;
    while (txq_pop(q, &out) == 0)
        ;
}

int main(void)
{
    struct TxQueue q = { NULL, NULL, 0 };
    char cmd[8];

    while (scanf("%7s", cmd) == 1) {
        if (strcmp(cmd, "PUSH") == 0) {
            unsigned id, dlc;
            uint8_t data[8] = { 0 };
            if (scanf("%x %u", &id, &dlc) != 2 || dlc > 8) break;
            for (unsigned i = 0; i < dlc; i++) {
                unsigned b;
                if (scanf("%x", &b) != 1) b = 0;
                data[i] = (uint8_t)b;
            }
            txq_push(&q, id, (uint8_t)dlc, data);
        } else if (strcmp(cmd, "POP") == 0) {
            struct TxNode m;
            if (txq_pop(&q, &m) != 0) {
                printf("POP EMPTY\n");
            } else {
                printf("POP 0x%03X [%u]", (unsigned)m.id, (unsigned)m.dlc);
                for (unsigned i = 0; i < m.dlc; i++) printf(" %02X", (unsigned)m.data[i]);
                printf("\n");
            }
        } else if (strcmp(cmd, "CANCEL") == 0) {
            unsigned id;
            if (scanf("%x", &id) != 1) break;
            printf("CANCEL 0x%03X -> %d\n", id, txq_cancel(&q, id));
        } else if (strcmp(cmd, "SHOW") == 0) {
            printf("queue[%u]:", (unsigned)q.count);
            if (q.head == NULL) printf(" -");
            for (const struct TxNode *p = q.head; p != NULL; p = p->next)
                printf(" 0x%03X", (unsigned)p->id);
            printf("\n");
        }
    }
    printf("pending=%u\n", (unsigned)q.count);
    txq_flush(&q);
    return 0;
}
@@@ explanation_md
**Bug.** A head/tail queue has two invariants: (1) `head == NULL` if and only if `tail == NULL`, and (2) `tail` is the last node of the chain that starts at `head`. `txq_pop` keeps both. `txq_cancel` updates `head` (or `prev->next`) but **never `tail`**. When the cancelled message is the last one:

```
before: head -> [100] -> [200] <- tail       CANCEL 200
after:  head -> [100] -> NULL     tail -> (freed 200)
PUSH 300: tail->next = [300]   <- write into freed memory; [300] is unreachable from head
```

The new message is lost (wrong output), the write is a heap-use-after-free, and the unreachable node leaks. If the cancelled node was the **only** node, `head` becomes `NULL` but `tail` does not. That breaks invariant (1), so every later push vanishes.

**Fix.** Before freeing, `if (q->tail == cur) q->tail = prev;`. This also sets `tail = NULL` when the queue becomes empty, because `prev` is `NULL` then.

**Complexity.** Push and pop are O(1); cancel is O(n). Space O(n).

**Common mistakes**
- Fixing only the "queue became empty" case (`if (!q->head) q->tail = NULL;`). Cancelling the last of several messages still leaves a stale tail.
- Recomputing the tail by walking the whole list on every push. That is correct but turns push into O(n), which defeats the reason for having a tail.
- Forgetting `count--` in one of the removal paths, so the reported pending count drifts.

**Interview follow-ups**
- Rewrite `txq_cancel` with the `struct TxNode **pp` idiom. How do you keep `tail` correct without a `prev` pointer? (Keep `pp`. The new tail is the node containing `*pp`, or use a "pointer to last next field" design, `struct TxNode **tailp`.)
- Add `assert`-style checks of both invariants in a debug build. Where would you call them?
- A sentinel or circular design avoids the separate `tail` field. What does that cost?
- The TX-complete ISR pops while a task pushes and cancels. Which operations need a critical section, and could a lock-free single-producer/single-consumer ring replace the list?
