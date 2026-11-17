@@@ meta
id: PTR-H-02
topic: Pointers
difficulty: Hard
type: FUNCTION
title: Debug-Shell Command Dispatcher with a Function-Pointer Table
tags: embedded, function-pointer, dispatch-table, argv, in-place-tokenizer, uart-shell
@@@ statement_md
Most ECUs and bootloaders (U-Boot, for example) have a small **debug shell** on a UART: a line such as `led 1 on` is split into `argc`/`argv` and dispatched through a **table of function pointers**. Implement the dispatcher:

```c
typedef int (*cmd_fn)(int argc, char *argv[]);
int dispatch(char *line);
```

The command handlers are provided (declared before your code). Build a `static const` table with this content:

| name | arguments after the name (min..max) | handler |
|---|---|---|
| `led` | 2..2 | `cmd_led` |
| `read` | 1..1 | `cmd_read` |
| `reset` | 0..0 | `cmd_reset` |
| `stat` | 0..0 | `cmd_stat` |
| `status` | 0..1 | `cmd_status` |
| `ver` | 0..0 | `cmd_ver` |
| `write` | 2..2 | `cmd_write` |

`dispatch(line)` must:
1. **Tokenize `line` in place.** Tokens are separated by one or more spaces (`' '` only). Overwrite separators with `'\0'` and store pointers **into `line`** in `argv` (no copies). Set `argv[argc] = NULL`, as the C standard guarantees for `main`. At most `MAX_ARGS = 8` tokens including the command name. If there are more, return `-3` and call nothing.
2. An empty or all-space line returns `0`.
3. **Look up `argv[0]`** (case-sensitive):
   - An exact name match wins.
   - Otherwise, if `argv[0]` is a prefix of exactly one name, use that command (`rea` means `read`, `statu` means `status`).
   - If it is a prefix of two or more names, return `-4` (ambiguous; `re`, `sta`).
   - No match at all returns `-1`.
4. If the number of arguments `argc - 1` is outside the command's range, return `-2`.
5. Otherwise call the handler with `(argc, argv)` and return its result. `argv[0]` is the token exactly as typed.

**How it is tested.** The hidden harness reads lines, calls `dispatch`, and prints `=> <result>`. Each handler prints `  <name> argc=<argc>: <argv joined by spaces>` and returns a distinct value (`led` 10, `read` 20, `reset` 30, `stat` 40, `status` 50, `ver` 60, `write` 70). The handlers also check that `argv` is NULL-terminated and that every `argv[i]` points into the original line buffer.

**Example**
```
Input:
led 1 on
rea 7
re
ver

Output:
  led argc=3: led 1 on
=> 10
  read argc=2: rea 7
=> 20
=> -4
  ver argc=1: ver
=> 60
```
@@@ constraints_md
- Lines are at most 100 characters and contain printable ASCII only (no tabs).
- At most 50 lines.
- No dynamic memory; the table must be `static const`.
@@@ starter_code
#include <stddef.h>
#include <string.h>

#define MAX_ARGS 8

typedef int (*cmd_fn)(int argc, char *argv[]);

struct command {
    const char *name;
    int min_args;
    int max_args;
    cmd_fn fn;
};

/* TODO: complete the table (cmd_led, cmd_read, ... are provided) */
static const struct command commands[] = {
    { "ver", 0, 0, cmd_ver },
};

int dispatch(char *line)
{
    /* TODO: tokenize in place, look up the command, check argc, call it */
    (void)commands;
    (void)line;
    return -1;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

int cmd_led(int argc, char *argv[]);
int cmd_read(int argc, char *argv[]);
int cmd_reset(int argc, char *argv[]);
int cmd_stat(int argc, char *argv[]);
int cmd_status(int argc, char *argv[]);
int cmd_ver(int argc, char *argv[]);
int cmd_write(int argc, char *argv[]);

/*USER_CODE*/

static char line_buf[128];
static size_t line_len;

static int show(const char *name, int argc, char *argv[], int ret)
{
    if (argv[argc] != NULL) {
        printf("  ARGV NOT NULL-TERMINATED\n");
        return -100;
    }
    for (int i = 0; i < argc; i++) {
        if (argv[i] < line_buf || argv[i] >= line_buf + line_len) {
            printf("  ARGV NOT IN LINE BUFFER\n");
            return -100;
        }
    }
    printf("  %s argc=%d:", name, argc);
    for (int i = 0; i < argc; i++) printf(" %s", argv[i]);
    printf("\n");
    return ret;
}

int cmd_led(int argc, char *argv[]) { return show("led", argc, argv, 10); }
int cmd_read(int argc, char *argv[]) { return show("read", argc, argv, 20); }
int cmd_reset(int argc, char *argv[]) { return show("reset", argc, argv, 30); }
int cmd_stat(int argc, char *argv[]) { return show("stat", argc, argv, 40); }
int cmd_status(int argc, char *argv[]) { return show("status", argc, argv, 50); }
int cmd_ver(int argc, char *argv[]) { return show("ver", argc, argv, 60); }
int cmd_write(int argc, char *argv[]) { return show("write", argc, argv, 70); }

int main(void)
{
    while (fgets(line_buf, sizeof line_buf, stdin) != NULL) {
        line_len = strcspn(line_buf, "\r\n");
        line_buf[line_len] = '\0';
        int r = dispatch(line_buf);
        printf("=> %d\n", r);
    }
    return 0;
}
@@@ sample_input
led 1 on
rea 7
re
ver
@@@ sample_output
  led argc=3: led 1 on
=> 10
  read argc=2: rea 7
=> 20
=> -4
  ver argc=1: ver
=> 60

@@@ sample_input
<<BLANK>>
   stat   
status   x
blink 1
write 5
@@@ sample_output
=> 0
  stat argc=1: stat
=> 40
  status argc=2: status x
=> 50
=> -1
=> -2

@@@ hidden_input
led 1 2 3 4 5 6 7 8
status a b c d e f g
led 1 2 3 4 5 6 7
@@@ hidden_output
=> -3
=> -2
=> -2

@@@ hidden_input
l 3 off
w 1 2
s
sta
statu
r 5
res
v
@@@ hidden_output
  led argc=3: l 3 off
=> 10
  write argc=3: w 1 2
=> 70
=> -4
=> -4
  status argc=1: statu
=> 50
=> -4
  reset argc=1: res
=> 30
  ver argc=1: v
=> 60

@@@ hidden_input
LED 1 on
led
ledx 1 on
res now
@@@ hidden_output
=> -1
=> -2
=> -1
=> -2

@@@ hidden_input
     
write   0x10   0xFF
read 0x4000
@@@ hidden_output
=> 0
  write argc=3: write 0x10 0xFF
=> 70
  read argc=2: read 0x4000
=> 20

@@@ hidden_input
@@@ hidden_output

@@@ hidden_input
status
reset
stat x
version
@@@ hidden_output
  status argc=1: status
=> 50
  reset argc=1: reset
=> 30
=> -2
=> -1

@@@ hint
Tokenize with a single pointer: skip spaces; if not at `'\0'`, record `argv[argc++] = p`; advance to the next space or `'\0'`; if it is a space, write `'\0'` there and step past it. Check `argc == MAX_ARGS` **before** storing a new token, so `argv` (size `MAX_ARGS + 1`) never overflows.
@@@ hint
Lookup in one pass over the table: return immediately on `strcmp(name, argv[0]) == 0`. Otherwise count the entries where `strncmp(name, argv[0], strlen(argv[0])) == 0` and remember the last one. Exactly one match: use it; two or more: `-4`; zero: `-1`. Then call through the table entry: `return c->fn(argc, argv);`.
@@@ solution_code
#include <stddef.h>
#include <string.h>

#define MAX_ARGS 8

typedef int (*cmd_fn)(int argc, char *argv[]);

struct command {
    const char *name;
    int min_args;
    int max_args;
    cmd_fn fn;
};

static const struct command commands[] = {
    { "led",    2, 2, cmd_led    },
    { "read",   1, 1, cmd_read   },
    { "reset",  0, 0, cmd_reset  },
    { "stat",   0, 0, cmd_stat   },
    { "status", 0, 1, cmd_status },
    { "ver",    0, 0, cmd_ver    },
    { "write",  2, 2, cmd_write  },
};
#define NUM_COMMANDS (sizeof commands / sizeof commands[0])

/* Split line in place; returns argc, or -1 if there are more than max tokens. */
static int tokenize(char *line, char *argv[], int max)
{
    int argc = 0;
    char *p = line;

    for (;;) {
        while (*p == ' ')
            p++;
        if (*p == '\0')
            break;
        if (argc == max)
            return -1;
        argv[argc++] = p;                 /* pointer INTO the caller's buffer */
        while (*p != '\0' && *p != ' ')
            p++;
        if (*p == ' ')
            *p++ = '\0';                  /* terminate the token in place */
    }
    argv[argc] = NULL;
    return argc;
}

static const struct command *lookup(const char *name, int *ambiguous)
{
    const struct command *hit = NULL;
    size_t len = strlen(name);
    int matches = 0;

    *ambiguous = 0;
    for (size_t i = 0; i < NUM_COMMANDS; i++) {
        if (strcmp(commands[i].name, name) == 0)
            return &commands[i];          /* exact match always wins */
        if (strncmp(commands[i].name, name, len) == 0) {
            hit = &commands[i];
            matches++;
        }
    }
    if (matches > 1) {
        *ambiguous = 1;
        return NULL;
    }
    return hit;
}

int dispatch(char *line)
{
    char *argv[MAX_ARGS + 1];
    int argc = tokenize(line, argv, MAX_ARGS);
    int ambiguous;

    if (argc < 0)
        return -3;
    if (argc == 0)
        return 0;

    const struct command *c = lookup(argv[0], &ambiguous);
    if (ambiguous)
        return -4;
    if (c == NULL)
        return -1;
    if (argc - 1 < c->min_args || argc - 1 > c->max_args)
        return -2;
    return c->fn(argc, argv);             /* indirect call through the table */
}
@@@ explanation_md
**Approach.** Two pointer techniques do all the work.

*In-place tokenizing (array of pointers into one buffer).* Instead of copying each word, the tokenizer writes `'\0'` over the separators and records where each word starts:

```
line: "led··1·on\0"  ->  "led\0·1\0on\0"
argv: [ptr "led"][ptr "1"][ptr "on"][NULL]
```

This needs no allocation and O(1) extra memory besides `argv`. It is exactly how a C runtime builds `argv` for `main`. The `argc == max` check before storing protects `argv[MAX_ARGS + 1]`.

*Table-driven dispatch.* A `static const` array of `{name, min, max, handler}` structs replaces a long `if/else strcmp` chain. Adding a command is one line, the table lives in flash, and the call `c->fn(argc, argv)` is an indirect call through a function pointer. Argument-count validation is data-driven too, so the handlers stay simple.

The prefix rule is a "unique abbreviation" lookup, as in U-Boot. An exact match is checked first, otherwise `stat` would be ambiguous with `status`.

**Complexity.** Tokenizing is O(L) for a line of length L. Lookup is O(C * L) for C commands. Space O(MAX_ARGS).

**Common mistakes**
- Copying tokens into a local `char tok[8][32]`. That is extra memory, and the handlers receive pointers that are not in the line buffer.
- Forgetting `argv[argc] = NULL`, or writing it at `argv[9]` when 9 tokens arrive (a stack overflow by one pointer).
- Treating a prefix match as final before checking for an exact match, which makes `stat` ambiguous.
- Using `strtok`. It is not reentrant (a hidden static pointer), so it is unsafe if two shells (UART + USB) share the code, and many embedded coding standards ban it.
- Declaring the table without `const`. It then lands in RAM, where a stray write can redirect a function pointer, which is also a classic security hole.

**Interview follow-ups**
- How would you sort the table and use `bsearch` for the exact match? What happens to prefix matching then?
- Add quoted arguments (`echo "a b"`). How does the in-place tokenizer change?
- On Cortex-M, why is it a good idea to place the command table in a dedicated linker section and let each module register its commands there (like Zephyr's `SHELL_CMD_REGISTER`)?
- What is the type of `commands[i].fn`, written **without** the `cmd_fn` typedef?
