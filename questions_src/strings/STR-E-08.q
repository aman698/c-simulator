@@@ meta
id: STR-E-08
topic: Strings
difficulty: Easy
type: PREDICT_OUTPUT
title: Writing Through a Pointer to a String Literal
tags: embedded, string-literal, undefined-behavior, rodata, const-correctness
@@@ statement_md
A developer wants to capitalise a gear-display message. Both variables are initialised from the same text. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

int main(void)
{
    char buf[] = "gear";
    char *msg  = "gear";

    buf[0] = 'G';
    msg[0] = 'G';

    printf("%s %s\n", buf, msg);
    return 0;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64, gcc, ELF with string literals in the read-only `.rodata` section.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    char buf[] = "gear";
    char *msg  = "gear";

    buf[0] = 'G';
    msg[0] = 'G';

    printf("%s %s\n", buf, msg);
    return 0;
}
@@@ predict_answer
Undefined Behavior
@@@ hint
The two declarations look alike but create very different objects. One is a modifiable array **copy** of the text. The other is a pointer to the literal itself.
@@@ hint
C11 6.4.5p7: "If the program attempts to modify such an array [a string literal], the behavior is undefined." The missing `const` in `char *msg` does not make the literal writable.
@@@ solution_code
#include <stdio.h>

int main(void)
{
    char buf[] = "gear";    /* char[5] on the stack, initialised with a COPY - writable   */
    char *msg  = "gear";    /* pointer to the literal itself (static storage, .rodata)   */

    buf[0] = 'G';           /* fine: modifies our own array                               */
    msg[0] = 'G';           /* UNDEFINED BEHAVIOR (C11 6.4.5p7): writes into a literal.   */
                            /* On Linux the page is read-only -> SIGSEGV. On a bare-metal */
                            /* MCU the literal lives in flash -> HardFault, or the write  */
                            /* is silently ignored.                                       */

    printf("%s %s\n", buf, msg);
    return 0;
}

/* Correct version:
 *     const char *msg = "gear";   // the compiler now rejects msg[0] = 'G'
 * or
 *     char msg[] = "gear";        // a writable copy
 */
@@@ explanation_md
**Answer: Undefined Behavior.**

- `char buf[] = "gear";` creates a **new array** of 5 chars (automatic storage) and copies the literal into it. Writing `buf[0]` is perfectly legal.
- `char *msg = "gear";` makes `msg` point **at the string literal itself**. A literal has static storage duration, and C11 6.4.5p7 says modifying it is undefined behavior. For historical reasons its type is `char[5]` and not `const char[5]`, so the compiler accepts the code without even a warning under `-Wall -Wextra`.

What happens in practice:
- Linux/gcc: literals are placed in `.rodata`, which is mapped read-only, so `msg[0] = 'G'` raises **SIGSEGV** and nothing is printed.
- Cortex-M with literals in flash: the write may cause a bus fault or HardFault, or be silently ignored. Some older toolchains put literals in RAM, where the write "works". There it can also change *every* `"gear"` in the program, because the compiler may merge identical literals into one.

**Complexity.** N/A (no algorithm). The point is where the data lives: `.rodata`/flash for literals, the stack for the array copy.

**Common mistakes**
- Assuming that, because `buf[0] = 'G'` works, `msg[0] = 'G'` works too.
- Assuming the result is defined because gcc compiles it without warnings. Use `-Wwrite-strings` (on by default in C++) to make literals `const char[]` and get a diagnostic.
- Passing a literal to a function that modifies its argument, such as `strtok("a,b", ",")` or an in-place `to_upper(char *s)`. This is the same bug, just hidden.

**Interview follow-ups**
- Where do `const char *p = "abc";`, `char a[] = "abc";` and `static char s[] = "abc";` each live in memory (`.rodata`, stack, `.data`) on an MCU? Which of them cost RAM at startup?
- Can two identical string literals have the same address? (Unspecified. Compilers usually merge them.) Why does that make writing to a literal even more dangerous?
- How does `-Wwrite-strings` change the type of a literal, and why do MISRA C:2012 Rule 7.4 and CERT STR30-C ask you to assign literals only to `const char *`?
