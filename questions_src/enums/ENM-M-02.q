@@@ meta
id: ENM-M-02
topic: Enums
difficulty: Medium
type: PREDICT_OUTPUT
title: Enum vs #define vs const - Scope and Redefinition
tags: enum-vs-define, macro-scope, block-scope, shadowing, misra
@@@ statement_md
A code review argues about `#define`, `enum` and `const int` for configuration constants. What does this program print?

Assume **x86-64 Linux, gcc, little-endian, `int` = 4 bytes, pointer = 8 bytes**.

```c
#include <stdio.h>

enum { MAX_RETRY = 3 };
#define BUF_LEN 8

static int file_level(void)
{
    return MAX_RETRY + BUF_LEN;
}

static int later(void);

int main(void)
{
    enum { MAX_RETRY = 5 };
#undef BUF_LEN
#define BUF_LEN 32
    char buf[BUF_LEN];
    static const int TIMEOUT = 10;

    printf("%d %zu\n", MAX_RETRY, sizeof buf);
    printf("%d\n", file_level());
    {
        enum { MAX_RETRY = 7 };
        printf("%d\n", MAX_RETRY + TIMEOUT);
    }
    printf("%d %d\n", MAX_RETRY, later());
    return 0;
}

static int later(void)
{
    return BUF_LEN + MAX_RETRY;
}
```

Type the exact output, or choose **Undefined Behavior** / **Compile Error**.
@@@ constraints_md
- Platform: x86-64 Linux, gcc, `char` = 1 byte.
- Preprocessing happens before compilation, top to bottom through the file.
@@@ starter_code
#include <stdio.h>

enum { MAX_RETRY = 3 };
#define BUF_LEN 8

static int file_level(void)
{
    return MAX_RETRY + BUF_LEN;
}

static int later(void);

int main(void)
{
    enum { MAX_RETRY = 5 };
#undef BUF_LEN
#define BUF_LEN 32
    char buf[BUF_LEN];
    static const int TIMEOUT = 10;

    printf("%d %zu\n", MAX_RETRY, sizeof buf);
    printf("%d\n", file_level());
    {
        enum { MAX_RETRY = 7 };
        printf("%d\n", MAX_RETRY + TIMEOUT);
    }
    printf("%d %d\n", MAX_RETRY, later());
    return 0;
}

static int later(void)
{
    return BUF_LEN + MAX_RETRY;
}
@@@ predict_answer
5 32
11
17
5 35
@@@ hint
An enumerator obeys C's normal **block scope**, like a variable: an inner declaration hides an outer one until the end of its block. A macro has no scope at all. The preprocessor replaces it **textually**, using whichever definition is active at that point in the file.
@@@ hint
`file_level` is above the `#define BUF_LEN 32` line, so it was expanded with 8. `later` is below it, so it sees 32. `later` is at file scope, so `main`'s local `MAX_RETRY` is not visible there.
@@@ solution_code
#include <stdio.h>

enum { MAX_RETRY = 3 };          /* file-scope enumerator: 3 */
#define BUF_LEN 8                /* macro: text "8" from here on */

static int file_level(void)
{
    return MAX_RETRY + BUF_LEN;  /* preprocessed as 3 + 8 = 11 */
}

static int later(void);

int main(void)
{
    enum { MAX_RETRY = 5 };      /* block scope: hides the file-scope 3 inside main */
#undef BUF_LEN
#define BUF_LEN 32               /* NOT local to main: active until the end of the file */
    char buf[BUF_LEN];           /* char buf[32] */
    static const int TIMEOUT = 10;   /* a read-only variable, not a constant expression */

    printf("%d %zu\n", MAX_RETRY, sizeof buf);       /* 5 32 */
    printf("%d\n", file_level());                    /* 11  */
    {
        enum { MAX_RETRY = 7 };                      /* hides main's 5 in this block */
        printf("%d\n", MAX_RETRY + TIMEOUT);         /* 7 + 10 = 17 */
    }
    printf("%d %d\n", MAX_RETRY, later());           /* back to 5; later() = 35 */
    return 0;
}

static int later(void)
{
    return BUF_LEN + MAX_RETRY;  /* 32 (macro still defined) + 3 (file-scope enum) = 35 */
}
@@@ explanation_md
**Answer**
```
5 32
11
17
5 35
```

**Approach.** Each kind of constant has different rules.

| | `#define` | `enum` constant | `const int` |
|---|---|---|---|
| Who handles it | preprocessor (text) | compiler | compiler |
| Scope | none, from `#define` to `#undef`/end of file | normal block scope | normal block scope |
| Type | whatever the text becomes | `int` | `const int` |
| Constant expression (array size, `case` label, `_Static_assert`) | yes | yes | **no** in C |
| Visible in a debugger | no | yes | yes |
| Uses storage | no | no | may |

- `MAX_RETRY` is declared three times in nested scopes. Each inner declaration hides the outer one only inside its own block: 5 in `main`, 7 in the inner block, 5 again after it, and 3 in `file_level`/`later`.
- `BUF_LEN` is replaced textually, top to bottom. `file_level` was already expanded with `8`. The `#define` inside `main` does not end at `main`'s closing brace, so `later` (below it) gets `32`.

**Complexity.** N/A. All of this happens at compile time.

**Common mistakes**
- Expecting a `#define` written inside a function to be local to that function.
- Expecting `file_level` to see the new `BUF_LEN`. Macros are expanded where they are **used**, at the moment the preprocessor reaches that line.
- Assuming `const int` works everywhere a constant is needed. In C (unlike C++), `case TIMEOUT:` or a file-scope `static int a[TIMEOUT];` is a compile error. Inside a function, `int a[TIMEOUT];` silently becomes a variable-length array.
- Shadowing names in real code. gcc's `-Wshadow` flags the block-scope enum, and MISRA C:2012 Rule 5.3 forbids inner declarations that hide outer ones.

**Interview follow-ups**
- When would you still choose `#define` for a constant? (`#if` conditional compilation, values needed in assembler or linker scripts, and string or float constants.)
- Why do many embedded style guides prefer `enum { RX_BUF_LEN = 64 };` over `#define RX_BUF_LEN 64` for integer constants?
- What is the problem with `#define SQUARE(x) x*x`, and why can an enum or an `inline` function never have it?
