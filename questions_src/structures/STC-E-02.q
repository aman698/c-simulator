@@@ meta
id: STC-E-02
topic: Structures
difficulty: Easy
type: PREDICT_OUTPUT
title: Struct by Value vs Array by Pointer
tags: embedded, pass-by-value, struct-copy, array-decay, calibration
@@@ statement_md
A calibration module keeps its gains both in a plain array and inside a struct. Three helper functions try to change them.

What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

struct Calib {
    int gain;
    int offs[3];
};

static void bump_array(int offs[3])        { offs[0] += 10; }
static void bump_copy(struct Calib c)      { c.gain += 10; c.offs[1] += 10; }
static void bump_ptr(struct Calib *c)      { c->gain += 100; c->offs[2] += 100; }

int main(void)
{
    struct Calib a = { 1, { 2, 3, 4 } };
    struct Calib b;

    bump_array(a.offs);
    bump_copy(a);
    printf("%d %d %d %d\n", a.gain, a.offs[0], a.offs[1], a.offs[2]);

    b = a;
    b.offs[0] = 0;
    bump_ptr(&b);
    printf("%d %d %d\n", a.offs[0], b.gain, b.offs[2]);

    printf("%zu %zu\n", sizeof a, sizeof a.offs);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, System V ABI, `int` = 4 bytes.
- The array parameter `int offs[3]` is adjusted by the compiler to `int *offs`.
@@@ starter_code
#include <stdio.h>

struct Calib {
    int gain;
    int offs[3];
};

static void bump_array(int offs[3])        { offs[0] += 10; }
static void bump_copy(struct Calib c)      { c.gain += 10; c.offs[1] += 10; }
static void bump_ptr(struct Calib *c)      { c->gain += 100; c->offs[2] += 100; }

int main(void)
{
    struct Calib a = { 1, { 2, 3, 4 } };
    struct Calib b;

    bump_array(a.offs);
    bump_copy(a);
    printf("%d %d %d %d\n", a.gain, a.offs[0], a.offs[1], a.offs[2]);

    b = a;
    b.offs[0] = 0;
    bump_ptr(&b);
    printf("%d %d %d\n", a.offs[0], b.gain, b.offs[2]);

    printf("%zu %zu\n", sizeof a, sizeof a.offs);
    return 0;
}
@@@ predict_answer
1 12 3 4
12 101 104
16 12
@@@ hint
An array argument decays to a pointer to its first element, so the callee writes into the caller's array. A struct argument is copied as a whole, including any arrays inside it.
@@@ hint
`b = a;` copies all 16 bytes, including `offs[3]`. After that, `a` and `b` are independent objects. Only `bump_ptr` receives an address, so only `b` changes there.
@@@ solution_code
#include <stdio.h>

struct Calib {
    int gain;
    int offs[3];
};                                   /* 4 + 3*4 = 16 bytes, no padding */

/* `int offs[3]` in a parameter list really means `int *offs`:
 * this writes straight into the caller's array. */
static void bump_array(int offs[3])        { offs[0] += 10; }

/* The whole struct, embedded array included, is copied into `c`.
 * Both changes are made to the copy and vanish on return. */
static void bump_copy(struct Calib c)      { c.gain += 10; c.offs[1] += 10; }

/* Pointer: changes the caller's object. */
static void bump_ptr(struct Calib *c)      { c->gain += 100; c->offs[2] += 100; }

int main(void)
{
    struct Calib a = { 1, { 2, 3, 4 } };
    struct Calib b;

    bump_array(a.offs);          /* a.offs[0]: 2 -> 12 (array decayed)      */
    bump_copy(a);                /* no visible effect on a                   */
    printf("%d %d %d %d\n", a.gain, a.offs[0], a.offs[1], a.offs[2]);  /* 1 12 3 4 */

    b = a;                       /* deep copy of the array member: 16 bytes  */
    b.offs[0] = 0;               /* a.offs[0] stays 12                       */
    bump_ptr(&b);                /* b.gain 1 -> 101, b.offs[2] 4 -> 104      */
    printf("%d %d %d\n", a.offs[0], b.gain, b.offs[2]);                 /* 12 101 104 */

    /* sizeof a struct includes the whole array; sizeof a.offs is the array
     * (12), not a pointer, because a.offs here is not a function parameter. */
    printf("%zu %zu\n", sizeof a, sizeof a.offs);                       /* 16 12 */
    return 0;
}
@@@ explanation_md
**Answer**
```
1 12 3 4
12 101 104
16 12
```

**Approach.** Track which functions receive a **copy** and which receive an **address**.

| call | what is passed | effect on the caller |
|---|---|---|
| `bump_array(a.offs)` | `&a.offs[0]` (array decays to `int *`) | `a.offs[0]` becomes 12 |
| `bump_copy(a)` | a 16-byte copy of `a`, array included | none |
| `b = a` | memberwise copy of all 16 bytes | `b` is an independent object |
| `bump_ptr(&b)` | address of `b` | `b.gain = 101`, `b.offs[2] = 104` |

C never passes arrays by value, but an array **wrapped in a struct** is copied with the struct. Some code bases use this deliberately: `struct { uint8_t data[8]; }` can be returned from a function and assigned with `=`.

**Complexity.** Passing by value costs O(sizeof(struct)) time and stack per call. On x86-64 a 16-byte struct is passed in two registers, but a larger struct is copied onto the stack. On a Cortex-M with a 1-2 KB task stack, passing a 200-byte struct by value on every call can overflow the stack. Passing by pointer is O(1).

**Common mistakes**
- Expecting `bump_copy` to change `a`. The callee only sees a copy.
- Expecting `bump_array` *not* to change `a`. In a parameter list, `int offs[3]` is just `int *offs`. The `3` is ignored, and `sizeof offs` inside the function would be 8.
- Thinking `b = a` makes `b.offs` point at `a.offs`. Arrays inside structs are copied element by element. Only **pointer** members are shallow-copied.
- Answering `8` for `sizeof a.offs`. That would be true only inside a function where `offs` is a parameter.

**Interview follow-ups**
- When would you pass a struct by value on purpose in embedded code? (Small immutable configs that fit in registers; this avoids aliasing and gives the callee its own snapshot.)
- How do you get the speed of a pointer and still promise not to modify the struct? (`const struct Calib *`.)
- If `struct Calib` had a `float *table` member, what would `b = a` copy, and what goes wrong if both `a` and `b` later `free(table)`?
- Why does MISRA C discourage array-typed parameters such as `int offs[3]`? (They suggest a size that the compiler does not enforce.)
