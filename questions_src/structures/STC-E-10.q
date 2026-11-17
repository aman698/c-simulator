@@@ meta
id: STC-E-10
topic: Structures
difficulty: Easy
type: FIND_THE_BUG
title: Freeing a CAN ID List Reads Freed Nodes
tags: embedded, linked-list, use-after-free, free, can-bus
@@@ statement_md
A gateway builds a list of the **distinct** CAN IDs it has seen on a bus, in the order of first appearance. The program below reads `n` IDs, appends each new ID to a singly linked list (duplicates are skipped), prints the list and the number of distinct IDs, and then releases the list.

**Symptom.** The output is correct, but for every input with at least one ID the judge reports a **Runtime Error** (AddressSanitizer: `heap-use-after-free`). With `n = 0` the program passes.

Find and fix the bug without changing the output.

**Input**
- Line 1: `n`.
- Line 2: `n` CAN IDs in hex (absent when `n = 0`).

**Output**
- Line 1: the distinct IDs in order of first appearance, as `0x%03X`, separated by spaces (`NONE` if there are none).
- Line 2: `distinct=<count>`.

**Example**
```
Input:
6
1A0 7DF 1A0 3B2 7DF 100

Output:
0x1A0 0x7DF 0x3B2 0x100
distinct=4
```
@@@ constraints_md
- `0 <= n <= 2000`
- IDs are standard 11-bit IDs (`0x000 .. 0x7FF`).
- Every node must be freed exactly once, and no node may be accessed after it is freed.
@@@ starter_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct IdNode {
    uint16_t       id;
    struct IdNode *next;
};

/* Append id at the tail unless it is already in the list. Returns 1 if added. */
static int add_unique(struct IdNode **head, uint16_t id)
{
    struct IdNode **pp = head;
    while (*pp != NULL) {
        if ((*pp)->id == id)
            return 0;
        pp = &(*pp)->next;
    }
    struct IdNode *nd = malloc(sizeof *nd);
    if (nd == NULL)
        return 0;
    nd->id = id;
    nd->next = NULL;
    *pp = nd;
    return 1;
}

static void list_free(struct IdNode *head)
{
    for (struct IdNode *p = head; p != NULL; p = p->next)
        free(p);
}

int main(void)
{
    struct IdNode *head = NULL;
    int n, distinct = 0;

    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        unsigned id;
        if (scanf("%x", &id) != 1) break;
        distinct += add_unique(&head, (uint16_t)id);
    }

    if (head == NULL)
        printf("NONE");
    for (const struct IdNode *p = head; p != NULL; p = p->next)
        printf("%s0x%03X", p == head ? "" : " ", (unsigned)p->id);
    printf("\ndistinct=%d\n", distinct);

    list_free(head);
    return 0;
}
@@@ sample_input
6
1A0 7DF 1A0 3B2 7DF 100
@@@ sample_output
0x1A0 0x7DF 0x3B2 0x100
distinct=4

@@@ sample_input
0
@@@ sample_output
NONE
distinct=0

@@@ hidden_input
1
7FF
@@@ hidden_output
0x7FF
distinct=1

@@@ hidden_input
5
000 000 000 000 000
@@@ hidden_output
0x000
distinct=1

@@@ hidden_input
2
123 456
@@@ hidden_output
0x123 0x456
distinct=2

@@@ hidden_input
8
7E0 7E8 7E0 7E8 7DF 7E0 7E8 7DF
@@@ hidden_output
0x7E0 0x7E8 0x7DF
distinct=3

@@@ hidden_input
3
00A 00B 00C
@@@ hidden_output
0x00A 0x00B 0x00C
distinct=3

@@@ hidden_input
2000
100 10A 122 148 17C 1BE 20E 26C 2D8 352 3DA 470 514 5C6 686 178 254 33E 436 53C 650 196 2C6 404 550 6AA 236 3AC 530 6C2 286 434 5F0 1DE 3B6 59C 1B4 3B6 5C6 208 434 66E 2DA 530 1B8 42A 6AA 35C 5F8 2C6 57E 268 53C 242 532 254 560 29E 5C6 320 664 3DA 15E 4CC 26C 5F6 3B2 17C 530 316 10A 4E8 2F8 116 51E 358 1A0 5D2 436 2A8 128 592 42E 2D8 190 632 506 3E8 2D8 1D6 6BE 5D8 500 436 37A 2CC 22C 19A 116 67C 614 5BA 56E 530 500 4DE 4CA 4C4 4CC 4E2 506 538 578 5C6 622 68C 128 1AE 242 2E4 394 452 51E 5F8 104 1FA 2FE 410 530 65E 1BE 308 460 5C6 15E 2E0 470 60E 1DE 398 560 15A 33E 530 154 362 57E 1CC 404 64A 2C2 524 1B8 436 6C2 380 628 302 5C6 2BC 59C 2AE 5AA 2D8 5F0 33A 66E 3D4 148 4A6 236 5B0 35C 116 4BA 290 650 442 242 62C 448 272 686 4CC 320 182 5CE 44C 2D8 172 5F6 4AC 370 242 122 5EC 4E8 3F2 30A 230 164 682 5D2 530 49C 416 39E 334 2D8 28A 24A 218 1F4 1DE 1D6 1DC 1F0 212 242 280 2CC 326 38E 404 488 51A 5BA 668 148 212 2EA 3D0 4C4 5C6 6D6 218 344 47E 5C6 140 2A4 416 596 148 2E4 48E 646 230 404 5E6 1FA 3F8 604 242 46A 6A0 308 55A 1DE 44C 6C8 376 60E 2D8 58C 272 542 244 530 24E 556 290 5B4 30A 64A 3BC 13C 4A6 242 5C8 380 146 4F6 2D8 6A4 4A2 2AE 6A4 4CC 302 146 574 3D4 242 69A 524 3BC 262 116 5B4 484 362 24E 148 62C 542 466 398 2D8 226 182 6C8 640 5C6 55A 4FC 4AC 46A 436 410 3F8 3EE 3F2 404 424 452 48E 4D8 530 596 60A 68C 140 1DE 28A 344 40C 4E2 5C6 6B8 1DC 2EA 406 530 668 1D2 326 488 5F8 19A 326 4C0 668 242 406 5D8 1DC 3CA 5C6 1F4 40C 632 28A 4CC 140 39E 60A 2A8 530 1EA 48E 164 424 116 3F2 100 3F8 122 436 17C 4AC 20E 55A 2D8 640 3DA 182 514 2D8 686 466 254 62C 436 24E 650 484 2C6 116 550 3BC 236 69A 530 3D4 286 146 5F0 4CC 3B6 2AE 1B4 6A4 5C6 4F6 434 380 2DA 242 1B8 13C 6AA 64A 5F8 5B4 57E 556 53C 530 532 542 560 58C 5C6 60E 664 6C8 15E 1DE 26C 308 3B2 46A 530 604 10A 1FA 2F8 404 51E 646 1A0 2E4 436 596 128 2A4 42E 5C6 190 344 506 6D6 2D8 4C4 6BE 2EA 500 148 37A 5BA 22C 488 116 38E 614 2CC 56E 242 500 1F0 4CA 1D6 4CC 1F4 506 24A 578 2D8 622 39E 128 49C 242 5D2 394 164 51E 30A 104 4E8 2FE 122 530 370 1BE 5F6 460 2D8 15E 5CE 470 320 1DE 686 560 448 33E 242 154 650 57E 4BA 404 35C 2C2 236 1B8 148 6C2 66E 628 5F0 5C6 5AA 59C 59C 5AA 5C6 5F0 628 66E 6C2 148 1B8 236 2C2 35C 404 4BA 57E 650 154 242 33E 448 560 686 1DE 320 470 5CE 15E 2D8 460 5F6 1BE 370 530 122 2FE 4E8 104 30A 51E 164 394 5D2 242 49C 128 39E 622 2D8 578 24A 506 1F4 4CC 1D6 4CA 1F0 500 242 56E 2CC 614 38E 116 488 22C 5BA 37A 148 500 2EA 6BE 4C4 2D8 6D6 506 344 190 5C6 42E 2A4 128 596 436 2E4 1A0 646 51E 404 2F8 1FA 10A 604 530 46A 3B2 308 26C 1DE 15E 6C8 664 60E 5C6 58C 560 542 532 530 53C 556 57E 5B4 5F8 64A 6AA 13C 1B8 242 2DA 380 434 4F6 5C6 6A4 1B4 2AE 3B6 4CC 5F0 146 286 3D4 530 69A 236 3BC 550 116 2C6 484 650 24E 436 62C 254 466 686 2D8 514 182 3DA 640 2D8 55A 20E 4AC 17C 436 122 3F8 100 3F2 116 424 164 48E 1EA 530 2A8 60A 39E 140 4CC 28A 632 40C 1F4 5C6 3CA 1DC 5D8 406 242 668 4C0 326 19A 5F8 488 326 1D2 668 530 406 2EA 1DC 6B8 5C6 4E2 40C 344 28A 1DE 140 68C 60A 596 530 4D8 48E 452 424 404 3F2 3EE 3F8 410 436 46A 4AC 4FC 55A 5C6 640 6C8 182 226 2D8 398 466 542 62C 148 24E 362 484 5B4 116 262 3BC 524 69A 242 3D4 574 146 302 4CC 6A4 2AE 4A2 6A4 2D8 4F6 146 380 5C8 242 4A6 13C 3BC 64A 30A 5B4 290 556 24E 530 244 542 272 58C 2D8 60E 376 6C8 44C 1DE 55A 308 6A0 46A 242 604 3F8 1FA 5E6 404 230 646 48E 2E4 148 596 416 2A4 140 5C6 47E 344 218 6D6 5C6 4C4 3D0 2EA 212 148 668 5BA 51A 488 404 38E 326 2CC 280 242 212 1F0 1DC 1D6 1DE 1F4 218 24A 28A 2D8 334 39E 416 49C 530 5D2 682 164 230 30A 3F2 4E8 5EC 122 242 370 4AC 5F6 172 2D8 44C 5CE 182 320 4CC 686 272 448 62C 242 442 650 290 4BA 116 35C 5B0 236 4A6 148 3D4 66E 33A 5F0 2D8 5AA 2AE 59C 2BC 5C6 302 628 380 6C2 436 1B8 524 2C2 64A 404 1CC 57E 362 154 530 33E 15A 560 398 1DE 60E 470 2E0 15E 5C6 460 308 1BE 65E 530 410 2FE 1FA 104 5F8 51E 452 394 2E4 242 1AE 128 68C 622 5C6 578 538 506 4E2 4CC 4C4 4CA 4DE 500 530 56E 5BA 614 67C 116 19A 22C 2CC 37A 436 500 5D8 6BE 1D6 2D8 3E8 506 632 190 2D8 42E 592 128 2A8 436 5D2 1A0 358 51E 116 2F8 4E8 10A 316 530 17C 3B2 5F6 26C 4CC 15E 3DA 664 320 5C6 29E 560 254 532 242 53C 268 57E 2C6 5F8 35C 6AA 42A 1B8 530 2DA 66E 434 208 5C6 3B6 1B4 59C 3B6 1DE 5F0 434 286 6C2 530 3AC 236 6AA 550 404 2C6 196 650 53C 436 33E 254 178 686 5C6 514 470 3DA 352 2D8 26C 20E 1BE 17C 148 122 10A 100 104 116 136 164 1A0 1EA 242 2A8 31C 39E 42E 4CC 578 632 11E 1F4 2D8 3CA 4CA 5D8 118 242 37A 4C0 614 19A 30A 488 614 1D2 37A 530 118 2EA 4CA 6B8 2D8 4E2 11E 344 578 1DE 42E 68C 31C 596 242 4D8 1A0 452 136 404 104 3EE 10A 410 148 46A 1BE 4FC 26C 5C6 352 6C8 470 226 5C6 398 178 542 33E 148 53C 362 196 5B4 404 262 6AA 524 3AC 242 6C2 574 434 302 1DE 6A4 59C 4A2 3B6 2D8 208 146 66E 5C8 530 4A6 42A 3BC 35C 30A 2C6 290 268 24E 242 244 254 272 29E 2D8 320 376 3DA 44C 4CC 55A 5F6 6A0 17C 242 316 3F8 4E8 5E6 116 230 358 48E 5D2 148 2A8 416 592 140 2D8 47E 632 218 3E8 5C6 1D6 3D0 5D8 212 436 668 2CC 51A 19A 404 67C 326 5BA 280 530 212 4DE 1DC 4C4 1DE 4E2 218 538 28A 5C6 334 68C 416 1AE 530 2E4 682 452 230 5F8 3F2 1FA 5EC 410 242 65E 4AC 308 172 5C6 44C 2E0 182 60E 4CC 398 272 15A 62C 530 442 362 290 1CC 116 64A 5B0 524 4A6 436 3D4 380 33A 302 2D8 2BC 2AE 2AE 2BC 2D8 302 33A 380 3D4 436 4A6 524 5B0 64A 116 1CC 290 362 442 530 62C 15A 272 398 4CC 60E 182 2E0 44C 5C6 172 308 4AC 65E 242 410 5EC 1FA 3F2 5F8 230 452 682 2E4 530 1AE 416 68C 334 5C6 28A 538 218 4E2 1DE 4C4 1DC 4DE 212 530 280 5BA 326 67C 404 19A 51A 2CC 668 436 212 5D8 3D0 1D6 5C6 3E8 218 632 47E 2D8 140 592 416 2A8 148 5D2 48E 358 230 116 5E6 4E8 3F8 316 242 17C 6A0 5F6 55A 4CC 44C 3DA 376 320 2D8 29E 272 254 244 242 24E 268 290 2C6 30A 35C 3BC 42A 4A6 530 5C8 66E 146 208 2D8 3B6 4A2 59C 6A4 1DE 302 434 574 6C2 242 3AC 524 6AA 262 404 5B4 196 362 53C 148 33E 542 178 398 5C6 226 470 6C8 352 5C6 26C 4FC 1BE 46A 148 410 10A 3EE 104 404 136 452 1A0 4D8 242 596 31C 68C 42E 1DE 578 344 11E 4E2 2D8 6B8 4CA 2EA 118 530 37A 1D2 614 488 30A 19A 614 4C0 37A 242 118 5D8 4CA 3CA 2D8 1F4 11E 632 578 4CC 42E 39E 31C 2A8 242 1EA 1A0 164 136 116 104 100 10A 122 148 17C 1BE 20E 26C 2D8 352 3DA 470 514 5C6 686 178 254 33E 436 53C 650 196 2C6 404 550 6AA 236 3AC 530 6C2 286 434 5F0 1DE 3B6 59C 1B4 3B6 5C6 208 434 66E 2DA 530 1B8 42A 6AA 35C 5F8 2C6 57E 268 53C 242 532 254 560 29E 5C6 320 664 3DA 15E 4CC 26C 5F6 3B2 17C 530 316 10A 4E8 2F8 116 51E 358 1A0 5D2 436 2A8 128 592 42E 2D8 190 632 506 3E8 2D8 1D6 6BE 5D8 500 436 37A 2CC 22C 19A 116 67C 614 5BA 56E 530 500 4DE 4CA 4C4 4CC 4E2 506 538 578 5C6 622 68C 128 1AE 242 2E4 394 452 51E 5F8 104 1FA 2FE 410 530 65E 1BE 308 460 5C6 15E 2E0 470 60E 1DE 398 560 15A 33E 530 154 362 57E 1CC 404 64A 2C2 524 1B8 436 6C2 380 628 302 5C6 2BC 59C 2AE 5AA 2D8 5F0 33A 66E 3D4 148 4A6 236 5B0 35C 116 4BA 290 650 442 242 62C 448 272 686 4CC 320 182 5CE 44C 2D8 172 5F6 4AC 370 242 122 5EC 4E8 3F2 30A 230 164 682 5D2 530 49C 416 39E 334 2D8 28A 24A 218 1F4 1DE 1D6 1DC 1F0 212 242 280 2CC 326 38E 404 488 51A 5BA 668 148 212 2EA 3D0 4C4 5C6 6D6 218 344 47E 5C6 140 2A4 416 596 148 2E4 48E 646 230 404 5E6 1FA 3F8 604 242 46A 6A0 308 55A 1DE 44C 6C8 376 60E 2D8 58C 272 542 244 530 24E 556 290 5B4 30A 64A 3BC 13C 4A6 242 5C8 380 146 4F6 2D8 6A4 4A2 2AE 6A4 4CC 302 146 574 3D4 242 69A 524 3BC 262 116 5B4 484 362 24E 148 62C 542 466 398 2D8 226 182 6C8 640 5C6 55A 4FC 4AC 46A 436 410 3F8 3EE 3F2 404 424 452 48E 4D8 530 596 60A 68C 140 1DE 28A 344 40C 4E2 5C6 6B8 1DC 2EA 406 530 668 1D2 326 488 5F8 19A 326 4C0 668 242 406 5D8 1DC 3CA 5C6 1F4 40C 632 28A 4CC 140 39E 60A 2A8 530 1EA 48E 164 424 116 3F2 100 3F8 122 436 17C 4AC 20E 55A 2D8 640 3DA 182 514 2D8 686 466 254 62C 436 24E 650 484 2C6 116 550 3BC 236 69A 530 3D4 286 146 5F0 4CC 3B6 2AE 1B4 6A4 5C6 4F6 434 380 2DA 242 1B8 13C 6AA 64A 5F8 5B4 57E 556 53C 530 532 542 560 58C 5C6 60E 664 6C8 15E 1DE 26C 308 3B2 46A 530 604 10A 1FA 2F8 404 51E 646 1A0 2E4 436 596 128 2A4 42E 5C6 190 344 506 6D6 2D8 4C4 6BE 2EA 500 148 37A 5BA 22C 488 116 38E 614 2CC 56E 242 500 1F0 4CA 1D6 4CC 1F4 506 24A 578 2D8 622 39E 128 49C 242 5D2 394 164 51E 30A 104
@@@ hidden_output
0x100 0x10A 0x122 0x148 0x17C 0x1BE 0x20E 0x26C 0x2D8 0x352 0x3DA 0x470 0x514 0x5C6 0x686 0x178 0x254 0x33E 0x436 0x53C 0x650 0x196 0x2C6 0x404 0x550 0x6AA 0x236 0x3AC 0x530 0x6C2 0x286 0x434 0x5F0 0x1DE 0x3B6 0x59C 0x1B4 0x208 0x66E 0x2DA 0x1B8 0x42A 0x35C 0x5F8 0x57E 0x268 0x242 0x532 0x560 0x29E 0x320 0x664 0x15E 0x4CC 0x5F6 0x3B2 0x316 0x4E8 0x2F8 0x116 0x51E 0x358 0x1A0 0x5D2 0x2A8 0x128 0x592 0x42E 0x190 0x632 0x506 0x3E8 0x1D6 0x6BE 0x5D8 0x500 0x37A 0x2CC 0x22C 0x19A 0x67C 0x614 0x5BA 0x56E 0x4DE 0x4CA 0x4C4 0x4E2 0x538 0x578 0x622 0x68C 0x1AE 0x2E4 0x394 0x452 0x104 0x1FA 0x2FE 0x410 0x65E 0x308 0x460 0x2E0 0x60E 0x398 0x15A 0x154 0x362 0x1CC 0x64A 0x2C2 0x524 0x380 0x628 0x302 0x2BC 0x2AE 0x5AA 0x33A 0x3D4 0x4A6 0x5B0 0x4BA 0x290 0x442 0x62C 0x448 0x272 0x182 0x5CE 0x44C 0x172 0x4AC 0x370 0x5EC 0x3F2 0x30A 0x230 0x164 0x682 0x49C 0x416 0x39E 0x334 0x28A 0x24A 0x218 0x1F4 0x1DC 0x1F0 0x212 0x280 0x326 0x38E 0x488 0x51A 0x668 0x2EA 0x3D0 0x6D6 0x344 0x47E 0x140 0x2A4 0x596 0x48E 0x646 0x5E6 0x3F8 0x604 0x46A 0x6A0 0x55A 0x6C8 0x376 0x58C 0x542 0x244 0x24E 0x556 0x5B4 0x3BC 0x13C 0x5C8 0x146 0x4F6 0x6A4 0x4A2 0x574 0x69A 0x262 0x484 0x466 0x226 0x640 0x4FC 0x3EE 0x424 0x4D8 0x60A 0x40C 0x6B8 0x406 0x1D2 0x4C0 0x3CA 0x1EA 0x136 0x31C 0x11E 0x118
distinct=212

@@@ hint
Look at the `for` loop that releases the list. Which expression runs **after** `free(p)` in each iteration?
@@@ hint
The increment `p = p->next` reads a node that was just freed. Save the successor first: `struct IdNode *next = p->next; free(p); p = next;`.
@@@ solution_code
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct IdNode {
    uint16_t       id;
    struct IdNode *next;
};

/* Append id at the tail unless it is already in the list. Returns 1 if added. */
static int add_unique(struct IdNode **head, uint16_t id)
{
    struct IdNode **pp = head;
    while (*pp != NULL) {
        if ((*pp)->id == id)
            return 0;
        pp = &(*pp)->next;
    }
    struct IdNode *nd = malloc(sizeof *nd);
    if (nd == NULL)
        return 0;
    nd->id = id;
    nd->next = NULL;
    *pp = nd;
    return 1;
}

static void list_free(struct IdNode *head)
{
    struct IdNode *p = head;
    while (p != NULL) {
        struct IdNode *next = p->next;   /* FIX: read the link BEFORE freeing the node */
        free(p);
        p = next;
    }
}

int main(void)
{
    struct IdNode *head = NULL;
    int n, distinct = 0;

    if (scanf("%d", &n) != 1) return 0;
    for (int i = 0; i < n; i++) {
        unsigned id;
        if (scanf("%x", &id) != 1) break;
        distinct += add_unique(&head, (uint16_t)id);
    }

    if (head == NULL)
        printf("NONE");
    for (const struct IdNode *p = head; p != NULL; p = p->next)
        printf("%s0x%03X", p == head ? "" : " ", (unsigned)p->id);
    printf("\ndistinct=%d\n", distinct);

    list_free(head);
    return 0;
}
@@@ explanation_md
**Bug.** In `for (p = head; p != NULL; p = p->next) free(p);` the step expression `p = p->next` runs **after** the body. It reads `next` from the node that `free(p)` has just released. That is a use-after-free (C11 7.22.3p1: the lifetime of a freed object has ended, and any access to it is undefined).

Glibc without sanitizers usually still finds the old pointer in the freed chunk, so the bug survives testing. A different allocator, a debug heap (the judge fills freed memory with `0xDD`) or another thread that reuses the chunk turns it into a crash or a wild `free`.

**Fix.** Save the successor first, then free:
```c
while (p) { struct IdNode *next = p->next; free(p); p = next; }
```

**Complexity.** Time O(n) to free, O(n * d) overall for the duplicate check (d = distinct IDs). Space O(d).

**Common mistakes**
- Moving `free(p)` to after `p = p->next`. Now the wrong node is freed: the first node leaks and `free(NULL)` happens at the end.
- Setting `head = NULL` after freeing and believing that fixes it. It prevents a later dangling `head`, but it does not change the loop.
- Writing a recursive `list_free(p->next); free(p);`. It is correct, but it uses O(n) stack.

**Interview follow-ups**
- How does AddressSanitizer detect use-after-free? (Freed memory is poisoned in shadow memory and kept in a quarantine.)
- Write `list_free(struct IdNode **head)` so that the caller's pointer is set to `NULL` as well.
- If the nodes came from a fixed-size pool instead of `malloc`, how would you give the whole list back in O(1)? (Splice the list onto the pool's free list.)
- For 2048 possible standard IDs, what is a better structure than a list for "seen before?" (A 2048-bit bitmap: 256 bytes, O(1) test.)
