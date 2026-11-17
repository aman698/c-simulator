@@@ meta
id: ARR-E-08
topic: Arrays
difficulty: Easy
type: PREDICT_OUTPUT
title: Designated Initializers and 2[a] Indexing
tags: array-initialization, designated-initializer, subscript-commutativity, zero-fill
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

int main(void)
{
    int a[6] = {10, 20, [4] = 50, 60};
    int b[] = {1, 2, 3, [7] = 8};
    int c[4] = {[1] = 5, [1] = 7, 9};
    char s[8] = "CAN";
    int *p = a + 1;

    printf("%d %d %d %d\n", 2[a], a[3], *(a + 4), a[5]);
    printf("%zu %d %d\n", sizeof b / sizeof b[0], b[6], 2[b]);
    printf("%d %d %d\n", p[-1], 3[p], (int)s[5]);
    printf("%d %d %d\n", c[1], c[2], c[3]);
    printf("%c%c\n", "CAN-FD"[4], 5["CAN-FD"]);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, C11.
- The program compiles. `gcc -Wextra` warns about one line (`-Woverride-init`); warnings do not stop compilation.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    int a[6] = {10, 20, [4] = 50, 60};
    int b[] = {1, 2, 3, [7] = 8};
    int c[4] = {[1] = 5, [1] = 7, 9};
    char s[8] = "CAN";
    int *p = a + 1;

    printf("%d %d %d %d\n", 2[a], a[3], *(a + 4), a[5]);
    printf("%zu %d %d\n", sizeof b / sizeof b[0], b[6], 2[b]);
    printf("%d %d %d\n", p[-1], 3[p], (int)s[5]);
    printf("%d %d %d\n", c[1], c[2], c[3]);
    printf("%c%c\n", "CAN-FD"[4], 5["CAN-FD"]);
    return 0;
}
@@@ predict_answer
0 0 50 60
8 0 3
10 50 0
7 9 0
FD
@@@ hint
`x[i]` is defined as `*((x) + (i))`, and addition is commutative. Also: once an array has an initializer, every element it does not mention is set to zero.
@@@ hint
After a designator `[k] = v`, the next plain initializer goes to index `k + 1`. If the same index is initialised twice, the **last** value wins. An unsized array gets its length from the highest index initialised.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    int a[6] = {10, 20, [4] = 50, 60};   /* {10, 20, 0, 0, 50, 60}: 60 lands in [5] */
    int b[] = {1, 2, 3, [7] = 8};        /* highest index 7 -> 8 elements: {1,2,3,0,0,0,0,8} */
    int c[4] = {[1] = 5, [1] = 7, 9};    /* [1]=7 overrides 5, then 9 goes to [2]: {0,7,9,0} */
    char s[8] = "CAN";                   /* {'C','A','N',0,0,0,0,0} */
    int *p = a + 1;                      /* p points at a[1] */

    printf("%d %d %d %d\n", 2[a], a[3], *(a + 4), a[5]);       /* 0 0 50 60 */
    printf("%zu %d %d\n", sizeof b / sizeof b[0], b[6], 2[b]); /* 8 0 3 */
    printf("%d %d %d\n", p[-1], 3[p], (int)s[5]);              /* a[0]=10, a[4]=50, 0 */
    printf("%d %d %d\n", c[1], c[2], c[3]);                    /* 7 9 0 */
    printf("%c%c\n", "CAN-FD"[4], 5["CAN-FD"]);                /* 'F' 'D' */
    return 0;
}
@@@ explanation_md
**Answer:**
```
0 0 50 60
8 0 3
10 50 0
7 9 0
FD
```

**Rules used**
- **Subscripting is pointer arithmetic.** `E1[E2]` is defined as `*((E1) + (E2))` (C11 6.5.2.1p2). So `2[a] == a[2]`, `3[p] == *(p + 3) == a[4]`, and a string literal is just an array: `5["CAN-FD"] == 'D'`.
- **Negative subscripts are fine through a pointer into the middle** of an array: `p[-1]` is `a[0]`, because it stays inside `a`.
- **Partial initialisation zero-fills** every element that is not mentioned, as if it had static storage (C11 6.7.9p21). The same applies to `char s[8] = "CAN"`: bytes 3..7 are all `'\0'`.
- **Designators move the "cursor".** After `[4] = 50`, the next initializer `60` goes to `[5]` (C11 6.7.9p17).
- **Unsized arrays** take their length from the largest index initialised: `[7]` means 8 elements.
- **Later initialisers override earlier ones** for the same element: `[1] = 5, [1] = 7` leaves 7 (C11 6.7.9p19). `-Woverride-init` warns about this, and in real code it usually means a copy-paste error in a lookup table.

**Complexity.** N/A. All of this is resolved at compile time; static tables like these cost no start-up code when they are `const` and live in flash.

**Common mistakes**
- Thinking `60` goes to index 2 (right after `20`). Designators reposition the cursor.
- Expecting uninitialised elements of a *partially* initialised local array to be garbage. They are guaranteed zero. A local array with **no** initializer at all is garbage.
- Counting `b` as 4 elements because there are 4 initializers.

**Interview follow-ups**
- Why are designated initializers popular for lookup tables indexed by an `enum` (e.g. `[DTC_OVERTEMP] = 0x1234`)? What happens if someone adds an enum value in the middle?
- Does `int x[100] = {0};` cost anything at run time for a local array? For a `static` one? (Local: the compiler emits a clear, a `memset`. Static: the array goes in `.bss` and the startup code zeroes it.)
- Is `int a[3] = {1, 2, 3, 4};` an error or a warning? (A constraint violation: excess initializers. gcc only warns, which is why `-Werror` matters.)
