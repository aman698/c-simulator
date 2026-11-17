@@@ meta
id: STR-M-06
topic: Strings
difficulty: Medium
type: FUNCTION
title: Implement my_strtok with Hidden Static State
tags: strtok, tokenizer, static-state, in-place, delimiters
@@@ statement_md
Implement the standard tokenizer:

```c
char *my_strtok(char *str, const char *delim);
```

It must behave exactly like ISO C `strtok`:

1. If `str != NULL`, a **new** scan starts at `str`. If `str == NULL`, the scan continues where the previous call stopped. The position is kept in a `static` variable inside your function.
2. Skip leading characters that occur in `delim`. If the end of the string is reached, return `NULL`. Every further `NULL` call also returns `NULL`.
3. Otherwise the token starts here. Find the next character that is in `delim`. If there is one, overwrite it with `'\0'` and continue the next scan **after** it. If the string ends first, the next scan starts at the terminating `'\0'`.
4. `delim` may be **different on every call**. An empty `delim` makes the rest of the string one token.
5. If the very first call passes `NULL` (no scan was ever started), return `NULL`.

Consequences to keep in mind: consecutive delimiters are treated as one, so `"a,,b"` gives `a`, `b` and never an empty token. The input string is **modified**, and the returned pointers point **into** it.

**How it is tested.** A hidden `main()` runs one or more scenarios in a single process, so your static state carries over between them. Each scenario either starts a new string (the first call passes the buffer) or is `NULL` (every call passes `NULL`, continuing the previous scan). For every call it prints `tok@offset [token]` (the offset from the start of the current buffer) or `NULL`. After each scenario it prints the buffer, showing every `'\0'` as `|`.

**Input (read by the hidden harness)**
- Line 1: `S`, the number of scenarios.
- Each scenario:
  - a line with the string in double quotes, or the word `NULL`;
  - a line with `k`, the number of calls;
  - `k` lines, each with the delimiter set for that call in double quotes.

**Output**
- One line per call, then `buf=[...]` (or `buf=(none)` if no string was ever given).

**Example**
```
Input:
1
"AT+CSQ=23,99"
3
"="
","
","

Output:
tok@0 [AT+CSQ]
tok@7 [23]
tok@10 [99]
buf=[AT+CSQ|23|99]
```
@@@ constraints_md
- `1 <= S <= 8`, `1 <= k <= 600` per scenario.
- Strings have at most 3000 printable ASCII characters and never contain `"` or `|`.
- Do not use `strtok`, `strspn`, `strcspn`, `strpbrk`, `strchr`, `strrchr`, `strstr` or `memchr` (rejected at compile time).
@@@ starter_code
#include <stddef.h>

char *my_strtok(char *str, const char *delim)
{
    /* TODO: keep the scan position in a static variable */
    return NULL;
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

#define strtok(s, d) strtok_is_not_allowed_in_this_exercise
#define strspn(s, d) strspn_is_not_allowed_in_this_exercise
#define strcspn(s, d) strcspn_is_not_allowed_in_this_exercise
#define strpbrk(s, d) strpbrk_is_not_allowed_in_this_exercise
#define strchr(s, c) strchr_is_not_allowed_in_this_exercise
#define strrchr(s, c) strrchr_is_not_allowed_in_this_exercise
#define strstr(s, d) strstr_is_not_allowed_in_this_exercise
#define memchr(s, c, n) memchr_is_not_allowed_in_this_exercise

/*USER_CODE*/

#undef strtok
#undef strspn
#undef strcspn
#undef strpbrk
#undef strchr
#undef strrchr
#undef strstr
#undef memchr

#define CAP 3100

static char bufs[8][CAP];
static char line[CAP + 64];

static int read_line(void)
{
    if (!fgets(line, sizeof line, stdin)) return 0;
    line[strcspn(line, "\r\n")] = '\0';
    return 1;
}

/* copy the text between the first and last '"' of line into out */
static size_t unquote(char *out, size_t cap)
{
    const char *a = strchr(line, '"');
    const char *b = strrchr(line, '"');
    size_t n = (a && b > a) ? (size_t)(b - a - 1) : 0;
    if (n >= cap) n = cap - 1;
    if (n) memcpy(out, a + 1, n);
    out[n] = '\0';
    return n;
}

int main(void)
{
    int S;
    char *cur = NULL;
    size_t cur_len = 0;
    if (!read_line() || sscanf(line, "%d", &S) != 1) return 0;
    for (int sc = 0; sc < S && sc < 8; sc++) {
        if (!read_line()) return 0;
        int fresh = strncmp(line, "NULL", 4) != 0;
        if (fresh) {
            cur = bufs[sc];
            cur_len = unquote(cur, CAP);
        }
        int k;
        if (!read_line() || sscanf(line, "%d", &k) != 1) return 0;
        for (int c = 0; c < k; c++) {
            char delim[256];
            if (!read_line()) return 0;
            unquote(delim, sizeof delim);
            char *tok = my_strtok((fresh && c == 0) ? cur : NULL, delim);
            if (tok == NULL) {
                printf("NULL\n");
            } else if (cur && tok >= cur && tok <= cur + cur_len) {
                printf("tok@%d [%s]\n", (int)(tok - cur), tok);
            } else {
                printf("tok@? (pointer outside the buffer)\n");
            }
        }
        if (cur == NULL) {
            printf("buf=(none)\n");
        } else {
            printf("buf=[");
            for (size_t i = 0; i < cur_len; i++) putchar(cur[i] == '\0' ? '|' : cur[i]);
            printf("]\n");
        }
    }
    return 0;
}
@@@ sample_input
1
"AT+CSQ=23,99"
3
"="
","
","
@@@ sample_output
tok@0 [AT+CSQ]
tok@7 [23]
tok@10 [99]
buf=[AT+CSQ|23|99]

@@@ sample_input
1
"  can   lin  "
4
" "
" "
" "
" "
@@@ sample_output
tok@2 [can]
tok@8 [lin]
NULL
NULL
buf=[  can|  lin| ]

@@@ hidden_input
2
""
2
","
","
",,,,"
2
","
","
@@@ hidden_output
NULL
NULL
buf=[]
NULL
NULL
buf=[,,,,]

@@@ hidden_input
1
"a,b"
2
""
""
@@@ hidden_output
tok@0 [a,b]
NULL
buf=[a,b]

@@@ hidden_input
1
"key=val;k2=v2"
5
"="
";"
"="
";"
"="
@@@ hidden_output
tok@0 [key]
tok@4 [val]
tok@8 [k2]
tok@11 [v2]
NULL
buf=[key|val|k2|v2]

@@@ hidden_input
2
"a,b,c"
1
","
"x;y"
2
";"
";"
@@@ hidden_output
tok@0 [a]
buf=[a|b,c]
tok@0 [x]
tok@2 [y]
buf=[x|y]

@@@ hidden_input
3
NULL
1
","
"a,b,c"
1
","
NULL
3
","
","
","
@@@ hidden_output
NULL
buf=(none)
tok@0 [a]
buf=[a|b,c]
tok@2 [b]
tok@4 [c]
NULL
buf=[a|b|c]

@@@ hidden_input
1
"$GPGGA,123519,,N*47"
5
","
","
",*"
",*"
"*"
@@@ hidden_output
tok@0 [$GPGGA]
tok@7 [123519]
tok@15 [N]
tok@17 [47]
NULL
buf=[$GPGGA|123519|,N|47]

@@@ hidden_input
1
"  d=i .Kdc2  ,fi6fLaL8 i;5hPcd6b8,49,3Kg75j;e29 =5:b36d.,;c.i,9i00.O,,=Pa-86g;;,=; 4fceMe=;,igObM;8--84e0K5N ;75i-i.3NMc;,01agd7Pc44;09Pd2dK4K  ;hOjj6hf;,.NMb28;;;0ebehic,3 hg=852,;g9, 3fMLN:cLh- ;,85-Ng0j;  1j5ONgh ,Nji0b1;2eL7 ,;2e-2.ecPic, KM6=6;  8e  h520M;Pb5c:,; ffP8g ,,bid2,;;.9d:70O- ;0h4hd ;;2L7cP497a,, ed95 ,,-5N30b9;  8,,O7je49gP.6,;1bfb;;b4;i=.N7:46=0;;,ch8hgd; ;O0d4aa3:, 6i4,, -23aMb;  Ka.2j=,;;MjbKK2i  ff:c.Ph4j,,Lja;2-.082ce,,,e-9P-h89,j-Kgg2=-2 c,;4M3:N=c ;,7. h-bfO;1gMO.6P   g6gf,;,Pbc3f6,;,17=2=6;,M, 2.9; ,c6-; ;4g=9Of;:OP.i;NP4 .:2a ;;Ma5KLKfa7L, O4fdO5.P4;Oe.6=b0:1 ; 4;;1048, ee,  1hMa=Oj:f, ,6g;6375g=L= ,P ,;48g:L;;ifgig8 0=477 ;K0iO=; 1 3fPOji=9;,M4gd;MPO7,, d9:6;00;,,LdjKej 2;,O.1;;cLj=,Kg10a6aa ;;cLK;,,cf8,;;P9PfMKKPab;;N6cjN7d;;d3dO;; fc8=:cg,;2eMK.KO,;6-7i3McMeb , MMi5e5 ;;4929O,,,df0b64f,,g=b=g0c-=6 ,,=6Kd4b, 29bjc5  NN1g,KK=5j , eOifgad 17M:b54 97;,1eja48iNbe,,,O,K6NL55; ,4gM;,Nd8N58f 0=66cg;,,jjPj4M;; 8O-c0;caf ;fb4 jchMM6P; 86L:cP,;L97:3ha2;KOOK ;=5giNP5c; ;=e:gh;,b4-,4O.hh=6,,,9-ag1-La51 8i47K39:O,, e8P42aO  ,Mi2Ld:1ga,;;KhN=LjKLd,f4P-3gcdce; ,j-; ;d=.cdfL1, 5i0a1,6jc2jNM.O,,28O0P1ce7,;80 ;:KL:a2d5j:  ;j:O9aPPdL ,Kba48,gP213ObNa;6P4Nf6 ,;iM- ,,P K8b7i41243  ,PPOg5L-;d.=iO0,,5:b;,MPj1fhfgM;, 7f;,g5.i6=1K  ;L,e -id, ,6:Ped,; iLj1N ;-76P:,;31MM=;4..5,  1i, ;=i  8:=,,;i4Lf23,;;10h-eej,,;Od3L5j-NN;,,:9O; eN,gba:-ef; a91dPOKcP2;,,PjOd4 8i131:gK,,15iehg8d9,g;1i 66,c9hj=L58g  ;K:L.=i..j4;bd0j49NP,;4jN-;,;51fig, gac;N3e:i;; N.Oj.ic;7h.O5g:g,; 2MeN  ;d:; ;fc ,O6K5c,;b=dd.d ; KL8K;9K-L9O1,;,e;;;5:9-PcNc 1:;,b0e3a1L;;M:hLeb934i,90O,,1j=b5PL80K; ,d01 ,f20,==d179hM j=6K2i 40d43Nj1;  MKNbd3iba, ;07c275f ;;fa,5KL6=Ne-,;:4, 2bg PbjfL,,,i34cad,;,dMe; 6, fb9172j22 O10,gjggc5: ,,72-M5j0bj0 ;;jM,,,3eO354hdjj   =M82Ka=4c  ,L 193bPged25;  9dgLi5d:1h,;-50 f721Na4de, ;jNdefOL:, ,j627Ph,;7bNN;8Pa;,339ad;,g4=;MO25i-.fL ; 09;O5e-e0f1, ;0ah=49f,; Lh-K46eb,P ;b.0.di ,,2Mh0,ggg9-8;;0f,;,dPf=7Kj;,N,,,=Ojf8822K ,,=,;1af;-3OLe87  N9853cKjch;-43fb9fed3 i17:8 ;;3d7ePbd6., ;04O   1-L; ,j;KPd=.g8i,56522bh0L; bh=84f5bi;  8gKPbi22O6,fP   :3bM.4iP,  ed3c8:2aa,,,-:L-g2,; 6OaL;P93 dc5i.1dP,;=3.2OMj13, K;75K8:Oef;5j; P02hcK8fee gihi3,.c68=36:0,.hg5348;;;i3Lg8bb081, ;N3P3;;7  44,2 16j9e3K;;;bKMKM31 ; 5==a;;,hP8:hcd48;,,i;12i ; P,;841j28bhd- 1K1aMN Mhc;7=7KaK5;; b8 ;,9fa-M;,8.M-6jg5gd; Ke;a1j7,;-b,2e474O7M4;;94MM8hbj ; i7:12bj-aN  3Lf98ai;,1Mb9b;c.if4.810,;,N:0N493g,, - ;i:j4.hf ;g ;8LN1MP  f=3 ,O5a.9;gK:36a-g6b;;.-e=,6=7ea2LP4=,:4c,44P.=M=1-;;,:ieM,470MOhbK0, ,3e26,,443h ; j;,11 ,,1;Ljg ;,:ei-,j595,MPjgLd-1;; 5bdai5=3;;,hg2O2g6d; ;dc53P: gh;;h9Nj,;99hNO3N=;;O5c-69=b,ghMN.,, KKg8,;,O-27c4Mh,,7K:d5NOf66;N;,:6159cff;,3O9:ai Kj-9d8h,,,bPc;9K:44cKdj P iK;8.2h=-Ph,6=bb-2hg.,49f3d5,; O.1=a9;jaijeN40, ,=5;,47=jd,,-L,, 67i8g6M3;,c.44eON N8e3hN;i.d9,;..191,, jOPM=L98L;4h04b;,;h98KfaM=5;,,c2NP2:5b4j;  L=; ;e9,;M6;,;8j814f;7,4OLM: ,;L;L7:1g-8e; 7h0 , 1g ;,561c3. ,;-cabhjPa;"
560
";, "
";, "
" ,"
";, "
" ,"
";, "
";, "
" ;"
" ,;"
",;"
",;"
";, "
",;"
";, "
" ,"
";, "
";, "
",;"
";, "
" ;"
";, "
" ;"
" ,"
",;"
" ;"
",;"
" ;"
" ;"
",;"
" ;"
" ,;"
",;"
";, "
";, "
" ,;"
";, "
" ;"
" ;"
";, "
" ,"
";, "
" ,;"
",;"
" ,"
" ,"
" ,;"
" ;"
";, "
" ,;"
" ,"
";, "
",;"
" ;"
";, "
" ;"
";, "
" ,;"
";, "
" ,"
" ,"
" ;"
" ;"
";, "
" ;"
",;"
" ,"
" ,;"
" ,;"
" ,;"
" ,;"
" ;"
" ,;"
",;"
",;"
" ,;"
" ;"
" ,"
" ,;"
",;"
" ,"
";, "
";, "
" ;"
",;"
" ,;"
" ;"
" ;"
",;"
",;"
";, "
" ;"
" ,"
" ,"
" ,"
",;"
" ,"
" ,;"
" ,;"
" ;"
";, "
" ,"
";, "
" ,;"
";, "
";, "
" ,"
" ;"
",;"
",;"
" ;"
" ;"
";, "
";, "
" ,"
";, "
" ;"
" ,;"
" ,;"
",;"
" ,"
",;"
" ;"
" ,;"
" ,"
",;"
" ,;"
";, "
" ,"
" ,;"
",;"
" ;"
" ;"
",;"
" ,"
" ,;"
" ,"
" ,"
",;"
",;"
" ,"
",;"
";, "
" ,"
" ,;"
",;"
",;"
";, "
" ;"
" ,;"
";, "
" ,"
";, "
" ,"
" ;"
" ;"
" ,"
" ,"
";, "
" ;"
" ;"
",;"
";, "
";, "
";, "
";, "
";, "
";, "
";, "
" ,;"
",;"
" ,;"
" ,"
";, "
",;"
" ,;"
";, "
" ;"
" ,"
",;"
" ,"
" ;"
" ,;"
" ,"
" ;"
" ,"
" ,;"
",;"
";, "
" ,"
",;"
";, "
" ;"
" ,;"
" ,"
" ;"
" ;"
";, "
" ;"
",;"
" ,;"
";, "
" ,"
",;"
" ;"
" ,"
",;"
";, "
" ;"
" ,"
" ,"
" ,;"
" ;"
" ,;"
" ,"
" ;"
" ,"
",;"
",;"
" ;"
" ;"
" ,"
",;"
" ,;"
" ;"
",;"
",;"
" ;"
" ,"
";, "
" ;"
";, "
" ,"
" ,;"
";, "
";, "
" ,"
" ,"
";, "
";, "
" ;"
";, "
" ;"
";, "
";, "
" ;"
" ,"
",;"
" ,"
" ;"
" ,"
" ,;"
" ,;"
",;"
",;"
";, "
" ,"
" ,;"
" ;"
" ,"
" ;"
";, "
" ,"
" ,"
" ,"
",;"
";, "
",;"
" ,"
" ;"
" ,;"
" ,"
" ,"
" ,;"
" ,"
" ,"
",;"
";, "
";, "
" ,;"
" ,"
";, "
" ,;"
" ,"
" ;"
",;"
",;"
" ,"
" ,;"
" ,;"
",;"
",;"
" ,"
";, "
" ,"
" ,;"
";, "
";, "
" ;"
" ;"
",;"
",;"
";, "
" ;"
";, "
" ,;"
",;"
" ,;"
" ,"
",;"
" ,"
" ;"
" ,;"
",;"
" ,"
";, "
" ,;"
" ,;"
";, "
" ,"
",;"
" ,;"
" ;"
" ,;"
" ;"
" ,"
" ,;"
" ,"
" ,"
" ;"
" ,"
";, "
" ,"
" ,"
",;"
" ;"
" ,"
" ,"
";, "
",;"
" ;"
";, "
" ;"
",;"
" ,"
" ,;"
" ,;"
",;"
" ,;"
",;"
" ,"
" ,"
",;"
";, "
";, "
" ;"
" ,;"
" ;"
" ,;"
" ;"
";, "
" ;"
",;"
" ;"
" ,"
" ;"
" ;"
",;"
" ,;"
" ,"
";, "
";, "
" ,;"
",;"
" ,"
" ;"
" ,"
" ,"
";, "
" ,"
",;"
" ;"
" ;"
";, "
" ,;"
" ,"
" ;"
" ,;"
" ,;"
" ,"
" ,"
" ;"
";, "
" ;"
" ,"
";, "
",;"
" ,;"
",;"
",;"
" ,"
" ,"
" ,"
" ,;"
" ;"
" ,;"
" ,;"
" ,;"
";, "
" ;"
" ,"
",;"
" ,"
" ,"
" ,"
" ,"
" ;"
" ,"
";, "
" ,"
" ;"
",;"
" ,;"
" ,;"
" ,;"
",;"
" ,;"
" ,"
" ,"
";, "
";, "
";, "
" ,;"
" ,"
",;"
" ,;"
",;"
" ;"
" ,"
" ,;"
" ,"
";, "
" ,;"
" ,;"
" ,"
";, "
" ;"
" ,;"
" ,"
",;"
";, "
",;"
";, "
" ,"
";, "
" ,;"
" ,;"
" ,"
" ;"
" ,;"
" ,"
" ,"
";, "
";, "
" ,;"
",;"
" ;"
";, "
" ;"
" ,"
";, "
" ,"
" ;"
" ;"
" ,;"
" ;"
" ;"
";, "
" ,;"
",;"
" ,"
",;"
" ,"
";, "
";, "
" ,;"
";, "
" ;"
",;"
",;"
" ,"
" ;"
";, "
";, "
";, "
",;"
" ,;"
" ;"
" ,"
" ,"
" ,;"
" ;"
";, "
" ;"
" ,"
";, "
",;"
" ,"
" ,;"
" ,"
",;"
" ,;"
" ;"
" ;"
",;"
" ,;"
",;"
" ,"
" ,;"
";, "
";, "
",;"
" ;"
" ,;"
" ,"
" ,"
",;"
",;"
";, "
";, "
";, "
" ;"
" ;"
",;"
" ,;"
" ;"
" ,"
",;"
" ,;"
" ,"
" ,"
",;"
";, "
";, "
" ,;"
";, "
" ,;"
" ;"
" ,;"
";, "
" ,;"
" ;"
",;"
" ,;"
" ,;"
" ,;"
" ,;"
" ,"
" ,"
" ,"
" ;"
@@@ hidden_output
tok@2 [d=i]
tok@6 [.Kdc2]
tok@14 [fi6fLaL8]
tok@23 [i]
tok@25 [5hPcd6b8]
tok@34 [49]
tok@37 [3Kg75j]
tok@44 [e29]
tok@48 [=5:b36d.]
tok@58 [c.i]
tok@62 [9i00.O]
tok@70 [=Pa-86g]
tok@80 [=]
tok@83 [4fceMe=]
tok@92 [igObM;8--84e0K5N]
tok@110 [75i-i.3NMc]
tok@122 [01agd7Pc44]
tok@133 [09Pd2dK4K  ]
tok@145 [hOjj6hf]
tok@153 [,.NMb28]
tok@163 [0ebehic]
tok@171 [3]
tok@173 [hg=852]
tok@181 [g9]
tok@185 [3fMLN:cLh-]
tok@198 [85-Ng0j]
tok@208 [1j5ONgh]
tok@216 [,Nji0b1]
tok@224 [2eL7 ]
tok@231 [2e-2.ecPic,]
tok@243 [KM6=6]
tok@249 [  8e  h520M]
tok@261 [Pb5c:]
tok@269 [ffP8g]
tok@277 [bid2]
tok@284 [.9d:70O-]
tok@294 [0h4hd]
tok@302 [2L7cP497a,,]
tok@314 [ed95]
tok@321 [-5N30b9;]
tok@331 [8]
tok@334 [O7je49gP.6]
tok@346 [1bfb]
tok@351 [;b4;i=.N7:46=0;;]
tok@368 [ch8hgd;]
tok@377 [O0d4aa3:]
tok@387 [6i4,,]
tok@393 [-23aMb]
tok@402 [Ka.2j=]
tok@409 [;;MjbKK2i]
tok@420 [ff:c.Ph4j]
tok@431 [Lja]
tok@435 [2-.082ce,,,e-9P-h89,j-Kgg2=-2]
tok@465 [c]
tok@468 [4M3:N=c]
tok@478 [7.]
tok@481 [h-bfO]
tok@487 [1gMO.6P]
tok@497 [g6gf]
tok@502 [;]
tok@504 [Pbc3f6,]
tok@512 [,17=2=6]
tok@521 [M]
tok@524 [2.9]
tok@528 [ ]
tok@530 [c6-;]
tok@536 [4g=9Of]
tok@543 [:OP.i]
tok@549 [NP4]
tok@553 [.:2a]
tok@560 [Ma5KLKfa7L,]
tok@572 [O4fdO5.P4]
tok@582 [Oe.6=b0:1 ]
tok@593 [ 4]
tok@597 [1048]
tok@603 [ee,]
tok@608 [1hMa=Oj:f]
tok@620 [6g]
tok@623 [6375g=L= ]
tok@633 [P]
tok@637 [48g:L]
tok@644 [ifgig8]
tok@651 [0=477]
tok@658 [K0iO=]
tok@665 [1]
tok@667 [3fPOji=9]
tok@676 [,M4gd]
tok@682 [MPO7]
tok@688 [ d9:6]
tok@694 [00]
tok@697 [,,LdjKej]
tok@706 [2;]
tok@709 [O.1;;cLj=]
tok@719 [Kg10a6aa]
tok@730 [cLK]
tok@736 [cf8]
tok@742 [P9PfMKKPab]
tok@754 [N6cjN7d]
tok@763 [d3dO]
tok@770 [fc8=:cg]
tok@778 [;2eMK.KO]
tok@788 [6-7i3McMeb]
tok@801 [MMi5e5]
tok@810 [4929O]
tok@818 [df0b64f]
tok@827 [g=b=g0c-=6]
tok@838 [,,=6Kd4b,]
tok@848 [29bjc5  NN1g]
tok@861 [KK=5j ]
tok@869 [eOifgad]
tok@877 [17M:b54]
tok@885 [97]
tok@889 [1eja48iNbe]
tok@902 [O]
tok@904 [K6NL55]
tok@912 [,4gM]
tok@918 [Nd8N58f]
tok@926 [0=66cg]
tok@935 [jjPj4M]
tok@942 [;]
tok@944 [8O-c0]
tok@950 [caf]
tok@955 [fb4]
tok@959 [jchMM6P;]
tok@968 [86L:cP]
tok@976 [L97:3ha2]
tok@985 [KOOK]
tok@990 [;=5giNP5c;]
tok@1002 [=e:gh]
tok@1009 [b4-]
tok@1013 [4O.hh=6,,,9-ag1-La51]
tok@1034 [8i47K39:O,,]
tok@1046 [e8P42aO  ]
tok@1056 [Mi2Ld:1ga]
tok@1068 [KhN=LjKLd]
tok@1078 [f4P-3gcdce;]
tok@1091 [j-;]
tok@1096 [d=.cdfL1]
tok@1105 [ 5i0a1]
tok@1112 [6jc2jNM.O]
tok@1123 [28O0P1ce7]
tok@1134 [80]
tok@1137 [;:KL:a2d5j:]
tok@1151 [j:O9aPPdL]
tok@1162 [Kba48]
tok@1168 [gP213ObNa]
tok@1178 [6P4Nf6]
tok@1185 [,]
tok@1187 [iM-]
tok@1193 [P]
tok@1195 [K8b7i41243]
tok@1208 [PPOg5L-]
tok@1216 [d.=iO0]
tok@1223 [,5:b]
tok@1228 [,MPj1fhfgM]
tok@1241 [7f;]
tok@1245 [g5.i6=1K]
tok@1256 [L]
tok@1258 [e]
tok@1260 [-id,]
tok@1266 [6:Ped]
tok@1274 [iLj1N]
tok@1281 [-76P:]
tok@1288 [31MM=]
tok@1294 [4..5]
tok@1301 [1i]
tok@1306 [=i]
tok@1310 [8:=]
tok@1316 [i4Lf23]
tok@1325 [10h-eej]
tok@1335 [Od3L5j-NN]
tok@1347 [:9O;]
tok@1352 [eN]
tok@1355 [gba:-ef]
tok@1364 [a91dPOKcP2]
tok@1377 [PjOd4]
tok@1383 [8i131:gK,,15iehg8d9,g]
tok@1405 [1i]
tok@1408 [66]
tok@1411 [c9hj=L58g]
tok@1423 [K:L.=i..j4]
tok@1434 [bd0j49NP]
tok@1443 [;4jN-;]
tok@1451 [51fig,]
tok@1458 [gac;N3e:i;;]
tok@1470 [N.Oj.ic]
tok@1478 [7h.O5g:g]
tok@1489 [2MeN]
tok@1495 [;d:;]
tok@1501 [fc ]
tok@1505 [O6K5c]
tok@1512 [b=dd.d]
tok@1521 [KL8K]
tok@1526 [9K-L9O1]
tok@1535 [,e]
tok@1540 [5:9-PcNc]
tok@1549 [1:]
tok@1552 [,b0e3a1L]
tok@1562 [M:hLeb934i]
tok@1573 [90O]
tok@1578 [1j=b5PL80K]
tok@1591 [d01]
tok@1596 [f20]
tok@1600 [==d179hM]
tok@1609 [j=6K2i]
tok@1616 [40d43Nj1]
tok@1627 [MKNbd3iba]
tok@1639 [07c275f]
tok@1647 [;;fa]
tok@1652 [5KL6=Ne-]
tok@1662 [:4]
tok@1666 [2bg]
tok@1670 [PbjfL]
tok@1678 [i34cad]
tok@1686 [,dMe]
tok@1692 [6]
tok@1694 [ fb9172j22 O10]
tok@1709 [gjggc5: ]
tok@1718 [,72-M5j0bj0]
tok@1732 [jM,,,3eO354hdjj]
tok@1750 [=M82Ka=4c]
tok@1760 [ ]
tok@1762 [L]
tok@1764 [193bPged25]
tok@1775 [  9dgLi5d:1h]
tok@1789 [-50 f721Na4de]
tok@1805 [jNdefOL:,]
tok@1816 [j627Ph]
tok@1824 [7bNN]
tok@1829 [8Pa]
tok@1834 [339ad]
tok@1841 [g4=;MO25i-.fL]
tok@1857 [09]
tok@1860 [O5e-e0f1]
tok@1871 [0ah=49f]
tok@1879 [;]
tok@1881 [Lh-K46eb]
tok@1890 [P]
tok@1893 [b.0.di]
tok@1900 [,,2Mh0,ggg9-8]
tok@1915 [0f]
tok@1919 [,dPf=7Kj]
tok@1929 [N]
tok@1933 [=Ojf8822K]
tok@1943 [,,=,]
tok@1948 [1af;-3OLe87]
tok@1960 [ N9853cKjch]
tok@1972 [-43fb9fed3]
tok@1983 [i17:8]
tok@1989 [;;3d7ePbd6.]
tok@2003 [04O]
tok@2009 [1-L]
tok@2013 [ ]
tok@2015 [j]
tok@2017 [KPd=.g8i]
tok@2026 [56522bh0L;]
tok@2037 [bh=84f5bi]
tok@2049 [8gKPbi22O6,fP]
tok@2065 [:3bM.4iP]
tok@2076 [ed3c8:2aa,,,-:L-g2,]
tok@2097 [6OaL]
tok@2102 [P93]
tok@2106 [dc5i.1dP]
tok@2115 [;=3.2OMj13]
tok@2126 [ K]
tok@2129 [75K8:Oef]
tok@2138 [5j]
tok@2142 [P02hcK8fee]
tok@2153 [gihi3,.c68=36:0,.hg5348]
tok@2179 [i3Lg8bb081]
tok@2191 [;N3P3;;7]
tok@2201 [44]
tok@2204 [2]
tok@2206 [16j9e3K;;;bKMKM31]
tok@2224 [;]
tok@2226 [5==a]
tok@2233 [hP8:hcd48]
tok@2245 [i]
tok@2247 [12i]
tok@2251 [;]
tok@2253 [P]
tok@2256 [841j28bhd-]
tok@2267 [1K1aMN]
tok@2274 [Mhc]
tok@2278 [7=7KaK5]
tok@2287 [ b8 ]
tok@2293 [9fa-M;]
tok@2300 [8.M-6jg5gd]
tok@2312 [Ke]
tok@2315 [a1j7]
tok@2321 [-b]
tok@2324 [2e474O7M4;;94MM8hbj]
tok@2346 [i7:12bj-aN]
tok@2358 [3Lf98ai;]
tok@2367 [1Mb9b]
tok@2373 [c.if4.810]
tok@2385 [N:0N493g]
tok@2394 [,]
tok@2396 [-]
tok@2399 [i:j4.hf ]
tok@2408 [g ]
tok@2411 [8LN1MP]
tok@2419 [f=3]
tok@2424 [O5a.9]
tok@2430 [gK:36a-g6b]
tok@2442 [.-e=]
tok@2447 [6=7ea2LP4=]
tok@2458 [:4c]
tok@2462 [44P.=M=1-]
tok@2472 [;]
tok@2474 [:ieM,470MOhbK0,]
tok@2491 [3e26]
tok@2497 [443h ]
tok@2504 [j;]
tok@2507 [11]
tok@2512 [1]
tok@2514 [Ljg]
tok@2520 [:ei-]
tok@2525 [j595]
tok@2530 [MPjgLd-1]
tok@2541 [5bdai5=3]
tok@2551 [,hg2O2g6d]
tok@2563 [dc53P:]
tok@2570 [gh]
tok@2573 [;h9Nj]
tok@2580 [99hNO3N=]
tok@2589 [;O5c-69=b]
tok@2599 [ghMN.]
tok@2605 [,]
tok@2607 [KKg8]
tok@2614 [O-27c4Mh]
tok@2624 [7K:d5NOf66;N;]
tok@2638 [:6159cff;]
tok@2648 [3O9:ai Kj-9d8h]
tok@2663 [,,bPc]
tok@2669 [9K:44cKdj]
tok@2679 [P]
tok@2681 [iK]
tok@2684 [8.2h=-Ph]
tok@2693 [6=bb-2hg.,49f3d5,]
tok@2712 [O.1=a9]
tok@2719 [jaijeN40,]
tok@2730 [=5]
tok@2734 [47=jd]
tok@2741 [-L]
tok@2746 [67i8g6M3]
tok@2756 [c.44eON N8e3hN]
tok@2771 [i.d9]
tok@2777 [..191]
tok@2785 [jOPM=L98L;4h04b;]
tok@2802 [;h98KfaM=5;]
tok@2815 [c2NP2:5b4j]
tok@2828 [L=]
tok@2833 [e9]
tok@2837 [M6]
tok@2842 [8j814f]
tok@2849 [7,4OLM:]
tok@2859 [L]
tok@2861 [L7:1g-8e]
tok@2871 [7h0]
tok@2875 [,]
tok@2877 [1g ]
tok@2881 [,561c3.]
tok@2890 [;-cabhjPa;]
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
NULL
buf=[  d=i|.Kdc2| ,fi6fLaL8|i|5hPcd6b8|49|3Kg75j|e29|=5:b36d.|;c.i|9i00.O|,=Pa-86g|;,=| 4fceMe=|,igObM;8--84e0K5N|;75i-i.3NMc|,01agd7Pc44|09Pd2dK4K  |hOjj6hf|,.NMb28|;;0ebehic|3|hg=852|;g9| 3fMLN:cLh-|;,85-Ng0j|  1j5ONgh|,Nji0b1|2eL7 |;2e-2.ecPic,|KM6=6|  8e  h520M|Pb5c:|; ffP8g|,,bid2|;;.9d:70O-|;0h4hd|;;2L7cP497a,,|ed95|,,-5N30b9;| 8|,O7je49gP.6|;1bfb|;b4;i=.N7:46=0;;|ch8hgd;|;O0d4aa3:| 6i4,,|-23aMb|  Ka.2j=|;;MjbKK2i| ff:c.Ph4j|,Lja|2-.082ce,,,e-9P-h89,j-Kgg2=-2|c|;4M3:N=c|;,7.|h-bfO|1gMO.6P|  g6gf|;|Pbc3f6,|,17=2=6|,M| 2.9| |c6-;|;4g=9Of|:OP.i|NP4|.:2a|;;Ma5KLKfa7L,|O4fdO5.P4|Oe.6=b0:1 | 4|;1048| ee,| 1hMa=Oj:f| ,6g|6375g=L= |P|,;48g:L|;ifgig8|0=477|;K0iO=| 1|3fPOji=9|,M4gd|MPO7|, d9:6|00|,,LdjKej|2;|O.1;;cLj=|Kg10a6aa|;;cLK|,,cf8|;;P9PfMKKPab|;N6cjN7d|;d3dO|; fc8=:cg|;2eMK.KO|;6-7i3McMeb|, MMi5e5|;;4929O|,,df0b64f|,g=b=g0c-=6|,,=6Kd4b,|29bjc5  NN1g|KK=5j | eOifgad|17M:b54|97|,1eja48iNbe|,,O|K6NL55| ,4gM|,Nd8N58f|0=66cg|,,jjPj4M|;|8O-c0|caf|;fb4|jchMM6P;|86L:cP|;L97:3ha2|KOOK|;=5giNP5c;|;=e:gh|,b4-|4O.hh=6,,,9-ag1-La51|8i47K39:O,,|e8P42aO  |Mi2Ld:1ga|;;KhN=LjKLd|f4P-3gcdce;|,j-;|;d=.cdfL1| 5i0a1|6jc2jNM.O|,28O0P1ce7|;80|;:KL:a2d5j:| ;j:O9aPPdL|,Kba48|gP213ObNa|6P4Nf6|,|iM-|,,P|K8b7i41243| ,PPOg5L-|d.=iO0|,5:b|,MPj1fhfgM|, 7f;|g5.i6=1K| ;L|e|-id,|,6:Ped|; iLj1N|;-76P:|;31MM=|4..5|  1i| ;=i| 8:=|,;i4Lf23|;;10h-eej|,;Od3L5j-NN|,,:9O;|eN|gba:-ef| a91dPOKcP2|,,PjOd4|8i131:gK,,15iehg8d9,g|1i|66|c9hj=L58g| ;K:L.=i..j4|bd0j49NP|;4jN-;|;51fig,|gac;N3e:i;;|N.Oj.ic|7h.O5g:g|; 2MeN| ;d:;|;fc |O6K5c|;b=dd.d|; KL8K|9K-L9O1|;,e|;;5:9-PcNc|1:|,b0e3a1L|;M:hLeb934i|90O|,1j=b5PL80K| ,d01|,f20|==d179hM|j=6K2i|40d43Nj1|  MKNbd3iba| ;07c275f|;;fa|5KL6=Ne-|;:4| 2bg|PbjfL|,,i34cad|;,dMe| 6| fb9172j22 O10|gjggc5: |,72-M5j0bj0|;;jM,,,3eO354hdjj|  =M82Ka=4c| |L|193bPged25|  9dgLi5d:1h|;-50 f721Na4de| ;jNdefOL:,|,j627Ph|;7bNN|8Pa|,339ad|,g4=;MO25i-.fL|; 09|O5e-e0f1| ;0ah=49f|;|Lh-K46eb|P|;b.0.di|,,2Mh0,ggg9-8|;0f|;,dPf=7Kj|,N|,,=Ojf8822K|,,=,|1af;-3OLe87| N9853cKjch|-43fb9fed3|i17:8|;;3d7ePbd6.| ;04O|  1-L| |j|KPd=.g8i|56522bh0L;|bh=84f5bi|  8gKPbi22O6,fP|  :3bM.4iP|  ed3c8:2aa,,,-:L-g2,| 6OaL|P93|dc5i.1dP|;=3.2OMj13| K|75K8:Oef|5j| P02hcK8fee|gihi3,.c68=36:0,.hg5348|;;i3Lg8bb081| ;N3P3;;7| 44|2|16j9e3K;;;bKMKM31|;|5==a|;,hP8:hcd48|,,i|12i|;|P|;841j28bhd-|1K1aMN|Mhc|7=7KaK5|; b8 |,9fa-M;|8.M-6jg5gd| Ke|a1j7|;-b|2e474O7M4;;94MM8hbj|; i7:12bj-aN| 3Lf98ai;|1Mb9b|c.if4.810|;,N:0N493g|,|-|;i:j4.hf |g |8LN1MP| f=3|,O5a.9|gK:36a-g6b|;.-e=|6=7ea2LP4=|:4c|44P.=M=1-|;|:ieM,470MOhbK0,|,3e26|,443h | j;|11|,,1|Ljg|;,:ei-|j595|MPjgLd-1|; 5bdai5=3|;,hg2O2g6d| ;dc53P:|gh|;h9Nj|;99hNO3N=|;O5c-69=b|ghMN.|,|KKg8|;,O-27c4Mh|,7K:d5NOf66;N;|:6159cff;|3O9:ai Kj-9d8h|,,bPc|9K:44cKdj|P|iK|8.2h=-Ph|6=bb-2hg.,49f3d5,| O.1=a9|jaijeN40,|,=5|,47=jd|,-L|, 67i8g6M3|,c.44eON N8e3hN|i.d9|;..191|, jOPM=L98L;4h04b;|;h98KfaM=5;|,c2NP2:5b4j|  L=| ;e9|;M6|,;8j814f|7,4OLM:|,;L|L7:1g-8e| 7h0|,|1g |,561c3.|,;-cabhjPa;]

@@@ hint
Keep `static char *next = NULL;`. At the start, `if (str) next = str;`, and `if (next == NULL) return NULL;`. Write a tiny helper `is_delim(char c, const char *delim)` that loops over `delim`.
@@@ hint
Skip delimiters; if you hit `'\0'`, save that position and return `NULL`. Otherwise remember the token start, advance to the next delimiter or `'\0'`. If it is a delimiter, write `'\0'` there and set `next` to the character after it. If it is the end, set `next` to the `'\0'` itself.
@@@ solution_code
#include <stddef.h>

static int is_delim(char c, const char *delim)
{
    for (; *delim != '\0'; delim++)
        if (*delim == c)
            return 1;
    return 0;
}

char *my_strtok(char *str, const char *delim)
{
    static char *next = NULL;       /* the hidden state that makes strtok non-reentrant */
    char *tok;

    if (str != NULL)
        next = str;
    if (next == NULL)
        return NULL;                /* first call ever with NULL */

    while (*next != '\0' && is_delim(*next, delim))
        next++;                     /* skip leading delimiters */
    if (*next == '\0')
        return NULL;                /* next stays at '\0': later calls return NULL too */

    tok = next;
    while (*next != '\0' && !is_delim(*next, delim))
        next++;
    if (*next != '\0')
        *next++ = '\0';             /* terminate the token, resume after it */
    return tok;
}
@@@ explanation_md
**Approach.** The whole trick of `strtok` is a `static char *` that remembers where the previous call stopped. Each call:
1. resets that pointer if a new string is passed;
2. skips any delimiter characters;
3. marks the token start, runs to the next delimiter, overwrites it with `'\0'`, and saves the position after it.

Because the delimiter is overwritten **in place**, the returned token is a normal C string inside the caller's buffer. No memory is allocated.

```
"AT+CSQ=23,99"  -> "AT+CSQ\023\099"   (shown by the harness as AT+CSQ|23|99)
 tok@0 ^       tok@7 ^  tok@10 ^
```

**Complexity.** Each call is O(t * d), where `t` is the number of characters scanned and `d = strlen(delim)`. Tokenizing a whole string is O(n * d) in total. A 256-entry lookup table built per call reduces that to O(n + d). Space O(1).

**Common mistakes**
- Not stopping at the end. After the last token, `next` must point at the `'\0'`, not one past it. Otherwise the next call reads beyond the string.
- Returning an empty token for `",,"`. `strtok` collapses delimiter runs, so if empty fields matter (NMEA, CSV), `strtok` is the **wrong** tool.
- Calling it on a string literal (`my_strtok("a,b", ",")`), which writes into read-only memory.
- Forgetting that the static state makes it **non-reentrant**. A nested tokenizer loop, or a call from an ISR or a second RTOS task, silently corrupts the outer scan.

**Interview follow-ups**
- Write a reentrant version `my_strtok_r(char *str, const char *delim, char **saveptr)` (POSIX `strtok_r`, C11 Annex K `strtok_s`). Why is the caller-owned state better?
- Write a tokenizer that **keeps** empty fields (`"a,,b"` -> `"a"`, `""`, `"b"`), as NMEA parsing needs.
- How would you tokenize a `const char *` (for example a string in flash) without modifying it? (Return start and length pairs, or copy each token into a bounded buffer.)
