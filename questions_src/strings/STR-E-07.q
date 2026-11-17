@@@ meta
id: STR-E-07
topic: Strings
difficulty: Easy
type: PREDICT_OUTPUT
title: sizeof vs strlen on Arrays, Pointers and Literals
tags: sizeof, strlen, array-decay, string-literal, embedded-nul
@@@ statement_md
What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes, `size_t` = 8 bytes**.

```c
#include <stdio.h>
#include <string.h>

int main(void)
{
    char a[] = "CAN";
    char b[10] = "LIN";
    const char *p = "FlexRay";
    char c[] = "AB\0CD";

    printf("%zu %zu\n", sizeof a, strlen(a));
    printf("%zu %zu\n", sizeof b, strlen(b));
    printf("%zu %zu\n", sizeof p, strlen(p));
    printf("%zu %zu\n", sizeof c, strlen(c));
    printf("%zu\n", sizeof "ECU");
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, LP64 data model (`sizeof(char *) == 8`).
@@@ starter_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    char a[] = "CAN";
    char b[10] = "LIN";
    const char *p = "FlexRay";
    char c[] = "AB\0CD";

    printf("%zu %zu\n", sizeof a, strlen(a));
    printf("%zu %zu\n", sizeof b, strlen(b));
    printf("%zu %zu\n", sizeof p, strlen(p));
    printf("%zu %zu\n", sizeof c, strlen(c));
    printf("%zu\n", sizeof "ECU");
    return 0;
}
@@@ predict_answer
4 3
10 3
8 7
6 2
4
@@@ hint
`sizeof` is evaluated at compile time from the **type**: for an array it is the number of bytes in the array, including the terminator. For a pointer it is the size of the pointer itself. `strlen` runs at run time and counts bytes up to the first `'\0'`.
@@@ hint
`"AB\0CD"` is an array of 6 chars: `A B \0 C D \0`. The compiler always appends its own terminator, even when you write one inside the literal.
@@@ solution_code
#include <stdio.h>
#include <string.h>

int main(void)
{
    char a[] = "CAN";           /* char[4]: 'C' 'A' 'N' '\0'                      */
    char b[10] = "LIN";         /* char[10]: "LIN" + 7 zero bytes                  */
    const char *p = "FlexRay";  /* a pointer (8 bytes) to a char[8] literal        */
    char c[] = "AB\0CD";        /* char[6]: 'A' 'B' '\0' 'C' 'D' '\0'              */

    printf("%zu %zu\n", sizeof a, strlen(a));   /* 4 3  - size counts the '\0'      */
    printf("%zu %zu\n", sizeof b, strlen(b));   /* 10 3 - declared size, not content */
    printf("%zu %zu\n", sizeof p, strlen(p));   /* 8 7  - size of the POINTER        */
    printf("%zu %zu\n", sizeof c, strlen(c));   /* 6 2  - strlen stops at first '\0' */
    printf("%zu\n", sizeof "ECU");              /* 4    - a literal is a char[4]     */
    return 0;
}
@@@ explanation_md
**Answer**
```
4 3
10 3
8 7
6 2
4
```

| expression | type | `sizeof` | `strlen` | why |
|---|---|---|---|---|
| `a` | `char[4]` | 4 | 3 | the size includes the implicit `'\0'` |
| `b` | `char[10]` | 10 | 3 | the declared size wins; the rest is zero-filled |
| `p` | `const char *` | 8 | 7 | `sizeof` of a pointer is the pointer size, not the string's |
| `c` | `char[6]` | 6 | 2 | `strlen` stops at the embedded `'\0'` |
| `"ECU"` | `char[4]` | 4 | - | a string literal is an array, so `sizeof` sees all of it |

`sizeof` is a compile-time operator that looks only at the **type**. `strlen` is a run-time function that scans for `'\0'`. They agree only by coincidence, never by design.

**Complexity.** `sizeof` costs nothing at run time (it is a constant). `strlen` is O(n) on every call.

**Common mistakes**
- Expecting `sizeof p` to be 8 because `"FlexRay"` has 7 letters plus `'\0'`. The answer is 8 here, but only because pointers are 8 bytes on x86-64. On a 32-bit Cortex-M it prints `4 7`.
- Forgetting that `sizeof` counts the terminator, so `sizeof a == strlen(a) + 1` for `char a[] = "..."`.
- Thinking a `'\0'` inside a literal shortens the array. It only shortens what `strlen` and `printf("%s")` see.
- Using `sizeof buf` inside a function that received `char buf[]` as a parameter. The parameter is really a `char *`, so the result is 8, not the caller's buffer size.

**Interview follow-ups**
- Why does `void f(char s[100]) { printf("%zu", sizeof s); }` print 8, and how do you pass the buffer size safely? (Pass it as a separate `size_t` parameter.)
- Write a macro `ARRAY_SIZE(x)` and explain why it silently gives wrong results on a pointer. (Some compilers can reject pointers with `__builtin_types_compatible_p`.)
- What does `sizeof('A')` evaluate to in C, and in C++? (4 in C, because a character constant has type `int`; 1 in C++.)
