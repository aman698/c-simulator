@@@ meta
id: STR-M-03
topic: Strings
difficulty: Medium
type: FUNCTION
title: Reverse the Words of a Sentence In Place
tags: reverse-words, in-place, two-pointers, string-compaction
@@@ statement_md
Implement

```c
void reverse_words(char *s);
```

It reverses the **order of the words** in `s`, **in place**, and normalises the spacing:

- A word is a maximal run of non-space characters. Only `' '` (space) separates words.
- In the result, words are separated by **exactly one** space, with **no** leading or trailing spaces.
- Characters inside a word keep their order (`"CAN-FD"` stays `"CAN-FD"`).
- A string with no words becomes `""`.
- `reverse_words(NULL)` does nothing.

Use O(1) extra memory: no second buffer, no `malloc`, no VLA.

**How it is tested.** A hidden `main()` copies each test string into a buffer surrounded by guard bytes, calls your function and prints the result as `[...]`, so leading and trailing spaces are visible. It reports `OUT OF BOUNDS WRITE` if you touch bytes outside the original string (including its `'\0'`).

**Input (read by the hidden harness)**
- Line 1: `q`.
- Next `q` lines: the sentence in double quotes, or the word `NULL`.

**Output**
- One line per sentence: `[result]`, or `NULL ok` for the null pointer.

**Example**
```
Input:
3
"the sky is blue"
"  hello world  "
"a good   example"

Output:
[blue is sky the]
[world hello]
[example good a]
```
@@@ constraints_md
- `1 <= q <= 20`
- Each sentence has at most 4000 characters: printable ASCII, no `"` character.
- O(n) time, O(1) extra space.
@@@ starter_code
#include <stddef.h>

void reverse_words(char *s)
{
    /* TODO: words in reverse order, single spaces, no leading/trailing spaces */
}
@@@ harness_code
#include <stdio.h>
#include <string.h>
#include <stddef.h>

/*USER_CODE*/

#define CAP 4100
#define GUARD 16
#define CANARY 0xA5

static unsigned char arena[GUARD + CAP + GUARD];
static char line[CAP + 64];

int main(void)
{
    int q;
    if (!fgets(line, sizeof line, stdin) || sscanf(line, "%d", &q) != 1) return 0;
    for (int i = 0; i < q; i++) {
        if (!fgets(line, sizeof line, stdin)) return 0;
        if (strncmp(line, "NULL", 4) == 0) {
            reverse_words(NULL);
            printf("NULL ok\n");
            continue;
        }
        char *a = strchr(line, '"');
        char *b = strrchr(line, '"');
        if (!a || a == b) return 0;
        size_t len = (size_t)(b - a - 1);
        memset(arena, CANARY, sizeof arena);
        char *buf = (char *)arena + GUARD;
        memcpy(buf, a + 1, len);
        buf[len] = '\0';
        reverse_words(buf);
        for (size_t k = 0; k < GUARD; k++) {
            if (arena[k] != CANARY || (unsigned char)buf[len + 1 + k] != CANARY) {
                printf("OUT OF BOUNDS WRITE\n");
                return 0;
            }
        }
        if (!memchr(buf, '\0', len + 1)) {
            printf("MISSING TERMINATOR\n");
            return 0;
        }
        printf("[%s]\n", buf);
    }
    return 0;
}
@@@ sample_input
3
"the sky is blue"
"  hello world  "
"a good   example"
@@@ sample_output
[blue is sky the]
[world hello]
[example good a]

@@@ sample_input
2
""
"     "
@@@ sample_output
[]
[]

@@@ hidden_input
3
"single"
" x "
"ab"
@@@ hidden_output
[single]
[x]
[ab]

@@@ hidden_input
2
"CAN LIN FlexRay MOST Ethernet"
"   ECU-1    ECU-22  ECU-333   "
@@@ hidden_output
[Ethernet MOST FlexRay LIN CAN]
[ECU-333 ECU-22 ECU-1]

@@@ hidden_input
3
NULL
"a b"
"  a"
@@@ hidden_output
NULL ok
[b a]
[a]

@@@ hidden_input
1
"  2nA-H cR6 hDc-.nC pU  MWR0j : 1Ju  1   d0Po-1i hr  Sah2DzB  SoHKO   sGN  vyM  61  I  _e546   I7ou3   .T1Uk_a   XJBxA2   .  4KAm BQCmVqJ  IiIIIoZH  sCUaJ:dX RSUNs   -  Sv EpDg Oq  pq4349TV   fuSW0 S  POsmb5Jy  o:R  0mMgYEsF   9Dc   lsmt SnX  3xX F 03  .bA _4pCL  g RTL6vi  Hoqm1 QQGvtd.  bGsmxow   ZggJTLi   tJd-C   mAZSV8b  IM   qmACB  8AeqN 2EFUK0Px   qp:F3GN  JUSa s:bno 0ryTG9L _V8dTe.7   k09EzLZ   cNsqEq_1  bJD z:rCnXlt oWQ9   WP.V_A  Nch I4oTg   .nrfVjrZ  rw19QA  k:wNO  d7   uwAPZ.Pt  Qg:qU l..MkLmL   Xue5SVH J0_ i2  UI   3w   -j2 s96F   J:U  i36Y   aeR   sP   M:hk0 PN2.Z   3eTjDR  .9Cp BNrzJy zb EWY2I  N  BtBmp   BWTLjuI  kAh9ukK1 txu UI2f.   :qmGFSWw   EZa   iZ9d   ThoQGA 610r Jp36rs   jQof   BMcSryy  S_0Fj LjPu2D   xVG   OLF   WlZKP  yv2GU  LtrMN_ vOns5B5g   H   rrUe  vT7OOu   -O7F 1h 0QA0XaZ  84 DO  Zit   5d13 cQSucB   TTE.wGli  o   wPn63   wo9q   q3  7S-NX   Z   XSq1B1Fc aRKc.MiX   rzITZH4N   j6iGpcsp rcrZA   3   S  j KX   o_ 6TNE7B_5   R5fIXa   fdWHCe j kh ro2lfh  e:0HBshc BPn:cIL0   2O:q   rf   K  rc64XA6  -4uh kV 3fKcn  Uq:Z _dHiv cn  zT49zm  5QVWZTYj  NsU  Y  j aRc8VZz   3vT Vv6HgRH   TSly_la  O0m4xM   Kzs dgAps Yr3tvdp R  sB8  ImJaaq8S   os:   XqFLn  :sMT  C  1u6  YW  LTzlzjLK .n lZ   kl   0.8 1xyg71uo   aC:pD   4IER   tpp1pqWx   0TPIH   4wuTY   Qa. 4   B   BCKHWw sgIkKz6U .:.Jg aUVw  LT  7CNI   9  nADQtc3 R 8:rdSIlG b4XsL RxxA6ZQ  FBN2-Xx: 4J7. D   Z_e1fLq  Y39CMV6l  :  iuyV QU_F  .OxN  iCUleyx  YTRgT   -4   NxRlvz  WnGK xuZy   bCWgIRW -AY  D67ct3y5  BvE.GT:n   wDY7VtR 5fcSn  -MqP   KL-7avLH   joyj   1G3aD   77kEQ   YcdH9-   RLtEJQ BUzjNi ok3gRCR   1L7   69TG  PTn:AF 4u3f j9I5JhaB .I  53oUxm   TMEKELUO lJh fg43VCZ  K:eT  AKo0   3K3Zg6B y20qT   G4kl  yagt   v  d   Oc2LTf6 I4  brU   N0cC CdgpyCJc  j8V_I4l1   G69Oz5A   qG1N: pRwWS   k  UiODAjv Dny   qkzRk  A6X:-.M   NI6y_ M1T3E 4EGJA  GeLoJ6   X  7GcfFMR6 .YMkQj  0iIV t7T2N9h  w94L:TQC  . wd4y  8Czn6bz  uxpwM  .Kv   _  MJ1  etPEYN1  wB7ub9Ne  U 9UjFR p0- 6TRW  Ja_p   obpCeT  DdxLQ0   .PC56fWX  WyI75Ga v1H   Z-Y7GWH   FjoWt-g   K SR.oW QL_LDHht   .N  0arKUDk  jo.b-N SKEX.aD8   Fzgk   dqWJ  dD_r3l8r 8 2Fz2v  j v   IfxH4M Amf   NiEyvgp bo   E-S5   Np 8:y YG9flBjd   s-rurP  K   Mcr:k   pXv4_ov  4 kbmMfk  yIH0.Y-  9fv  bA   v40NtU_ r9   BkYUhY:g oYlmyO   TVb  LOmjeL-   pi9g HK.  TMPYy qJEr   b  ctomc  4tsrUH 0P   u TNCh2.   Yd AWabg   2pddM9u   nfyDeSI  D2ac6 Zsjla cn8  Gu   XVy  0u0pCUU 3 6XTT5t  fqpu7AW   usaW   .qqtlSb_ 6o  fdXWrgco   Rig87L Z  5sUrW3  QQ.w.   ZTc   mHwph   Qt  GdvP4CCM Fx   -60:Kr.3 KKKW eHzSHFAS   B0cye8  .6eb oMd  k_.rKfip  UGO  XVdvCn6 oG   1fn.8 :58v 7  6NZul5  w 3ayS   q6_EdOy o   VEuzN JHCFN YHwn   6MkW_R50   z6FiwplH v   P.dYP fZlQp  7017Gh47  FHv h0 o   edBpo 01iWuHe NI:Bu   rcf8  zm   lov9Unm SVsSHu CR: 1   YnJcv   r7oBjVW   A_3.lY6U  cE   :a   KbC8Bq  hquUMGU OnKJvs  _vkp  v d12Y:4 flQ  s FChm  6ve3 Z 6MVrNr  MIHb hJ  Z4Alp  jVyTkI   6NO  lpu:uXSM   VW6S1Z  m  Hf.u   Vnc96b   MBbi::u   n-g3Qb  p  v-QttEU   p ol   sBJuE:Qc  .z   s2T   sZZFW y2_0yJX   u  ynTpZ   p1F   80M1 XxV5  IWqoEO0  0K.fNUh H  6G9Em  j3M.yC1Q U2  fr aX PrBs   md8VWc b 1e:   n4UZg 45   nf65U QAn0h5e  VHO1E   xHm7f  O   VSUiN gGp6K-OQ   .Jnxb_yz n   L.ii.W  XI   LepI  ft_2   J  L   De7Z   ZIU.H umM9U  Y1mHs   d_xY MzXoaY 3_aesP  cm  y3F  h.gT 0rU5bXA   z :jB   W1 8q0I6 U3-j k 4wYuoXa  lweNH   sZnD nc.DvZ   0jjQ_G   3J RnXlUn  QqF   6yjp   CU mwei   U-  b IriP4   ME   VpmUFm   :TO   PCJj  KLtgUf4f   Hk-KAM6i  qGgBV  ei3_l  KYG0Gf78   8i2   Eg1Bym QZjjQl   hR-OAx  3k4 CZ  ExeNO oaLON6gh   U8PXUG kb  YIaa2 ThHc-PA8  EK h   _AQY   5zDud  xuOLHN  6fdcB-7   dXKO 4BY GO om  1cXmQwQ  hJL q3u   UL8Ij8   Vn:k   xvHD   gJ5  KDp9 gvP0yJA qQlcf  wqtq5  phKz8   D8OZNBo-  B   UBzrNd   _Zb CjbhZR  fZX   kg7L1H idxBU  pemYGFU  WpZO EpLw4fO   MC  vK_e  1T7Q  ol4   vXAUw8  S  G2SY8QuH  .YS9d.   qlh. P2EjaV ZlpGFyn  89:uZ_   _J cAE1s   aEYH  : z_U8vz   aTAgY   96BJS  RYzN   pYE0R   H36yhFjD      "
@@@ hidden_output
[H36yhFjD pYE0R RYzN 96BJS aTAgY z_U8vz : aEYH cAE1s _J 89:uZ_ ZlpGFyn P2EjaV qlh. .YS9d. G2SY8QuH S vXAUw8 ol4 1T7Q vK_e MC EpLw4fO WpZO pemYGFU idxBU kg7L1H fZX CjbhZR _Zb UBzrNd B D8OZNBo- phKz8 wqtq5 qQlcf gvP0yJA KDp9 gJ5 xvHD Vn:k UL8Ij8 q3u hJL 1cXmQwQ om GO 4BY dXKO 6fdcB-7 xuOLHN 5zDud _AQY h EK ThHc-PA8 YIaa2 kb U8PXUG oaLON6gh ExeNO CZ 3k4 hR-OAx QZjjQl Eg1Bym 8i2 KYG0Gf78 ei3_l qGgBV Hk-KAM6i KLtgUf4f PCJj :TO VpmUFm ME IriP4 b U- mwei CU 6yjp QqF RnXlUn 3J 0jjQ_G nc.DvZ sZnD lweNH 4wYuoXa k U3-j 8q0I6 W1 :jB z 0rU5bXA h.gT y3F cm 3_aesP MzXoaY d_xY Y1mHs umM9U ZIU.H De7Z L J ft_2 LepI XI L.ii.W n .Jnxb_yz gGp6K-OQ VSUiN O xHm7f VHO1E QAn0h5e nf65U 45 n4UZg 1e: b md8VWc PrBs aX fr U2 j3M.yC1Q 6G9Em H 0K.fNUh IWqoEO0 XxV5 80M1 p1F ynTpZ u y2_0yJX sZZFW s2T .z sBJuE:Qc ol p v-QttEU p n-g3Qb MBbi::u Vnc96b Hf.u m VW6S1Z lpu:uXSM 6NO jVyTkI Z4Alp hJ MIHb 6MVrNr Z 6ve3 FChm s flQ d12Y:4 v _vkp OnKJvs hquUMGU KbC8Bq :a cE A_3.lY6U r7oBjVW YnJcv 1 CR: SVsSHu lov9Unm zm rcf8 NI:Bu 01iWuHe edBpo o h0 FHv 7017Gh47 fZlQp P.dYP v z6FiwplH 6MkW_R50 YHwn JHCFN VEuzN o q6_EdOy 3ayS w 6NZul5 7 :58v 1fn.8 oG XVdvCn6 UGO k_.rKfip oMd .6eb B0cye8 eHzSHFAS KKKW -60:Kr.3 Fx GdvP4CCM Qt mHwph ZTc QQ.w. 5sUrW3 Z Rig87L fdXWrgco 6o .qqtlSb_ usaW fqpu7AW 6XTT5t 3 0u0pCUU XVy Gu cn8 Zsjla D2ac6 nfyDeSI 2pddM9u AWabg Yd TNCh2. u 0P 4tsrUH ctomc b qJEr TMPYy HK. pi9g LOmjeL- TVb oYlmyO BkYUhY:g r9 v40NtU_ bA 9fv yIH0.Y- kbmMfk 4 pXv4_ov Mcr:k K s-rurP YG9flBjd 8:y Np E-S5 bo NiEyvgp Amf IfxH4M v j 2Fz2v 8 dD_r3l8r dqWJ Fzgk SKEX.aD8 jo.b-N 0arKUDk .N QL_LDHht SR.oW K FjoWt-g Z-Y7GWH v1H WyI75Ga .PC56fWX DdxLQ0 obpCeT Ja_p 6TRW p0- 9UjFR U wB7ub9Ne etPEYN1 MJ1 _ .Kv uxpwM 8Czn6bz wd4y . w94L:TQC t7T2N9h 0iIV .YMkQj 7GcfFMR6 X GeLoJ6 4EGJA M1T3E NI6y_ A6X:-.M qkzRk Dny UiODAjv k pRwWS qG1N: G69Oz5A j8V_I4l1 CdgpyCJc N0cC brU I4 Oc2LTf6 d v yagt G4kl y20qT 3K3Zg6B AKo0 K:eT fg43VCZ lJh TMEKELUO 53oUxm .I j9I5JhaB 4u3f PTn:AF 69TG 1L7 ok3gRCR BUzjNi RLtEJQ YcdH9- 77kEQ 1G3aD joyj KL-7avLH -MqP 5fcSn wDY7VtR BvE.GT:n D67ct3y5 -AY bCWgIRW xuZy WnGK NxRlvz -4 YTRgT iCUleyx .OxN QU_F iuyV : Y39CMV6l Z_e1fLq D 4J7. FBN2-Xx: RxxA6ZQ b4XsL 8:rdSIlG R nADQtc3 9 7CNI LT aUVw .:.Jg sgIkKz6U BCKHWw B 4 Qa. 4wuTY 0TPIH tpp1pqWx 4IER aC:pD 1xyg71uo 0.8 kl lZ .n LTzlzjLK YW 1u6 C :sMT XqFLn os: ImJaaq8S sB8 R Yr3tvdp dgAps Kzs O0m4xM TSly_la Vv6HgRH 3vT aRc8VZz j Y NsU 5QVWZTYj zT49zm cn _dHiv Uq:Z 3fKcn kV -4uh rc64XA6 K rf 2O:q BPn:cIL0 e:0HBshc ro2lfh kh j fdWHCe R5fIXa 6TNE7B_5 o_ KX j S 3 rcrZA j6iGpcsp rzITZH4N aRKc.MiX XSq1B1Fc Z 7S-NX q3 wo9q wPn63 o TTE.wGli cQSucB 5d13 Zit DO 84 0QA0XaZ 1h -O7F vT7OOu rrUe H vOns5B5g LtrMN_ yv2GU WlZKP OLF xVG LjPu2D S_0Fj BMcSryy jQof Jp36rs 610r ThoQGA iZ9d EZa :qmGFSWw UI2f. txu kAh9ukK1 BWTLjuI BtBmp N EWY2I zb BNrzJy .9Cp 3eTjDR PN2.Z M:hk0 sP aeR i36Y J:U s96F -j2 3w UI i2 J0_ Xue5SVH l..MkLmL Qg:qU uwAPZ.Pt d7 k:wNO rw19QA .nrfVjrZ I4oTg Nch WP.V_A oWQ9 z:rCnXlt bJD cNsqEq_1 k09EzLZ _V8dTe.7 0ryTG9L s:bno JUSa qp:F3GN 2EFUK0Px 8AeqN qmACB IM mAZSV8b tJd-C ZggJTLi bGsmxow QQGvtd. Hoqm1 RTL6vi g _4pCL .bA 03 F 3xX SnX lsmt 9Dc 0mMgYEsF o:R POsmb5Jy S fuSW0 pq4349TV Oq EpDg Sv - RSUNs sCUaJ:dX IiIIIoZH BQCmVqJ 4KAm . XJBxA2 .T1Uk_a I7ou3 _e546 I 61 vyM sGN SoHKO Sah2DzB hr d0Po-1i 1 1Ju : MWR0j pU hDc-.nC cR6 2nA-H]

@@@ hidden_input
1
" AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29"
@@@ hidden_output
[AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29CJQXelsz6:GNUbipw3_DKRYfmt07AHOVcjqx4-ELSZgnu18BIPWdkry5.FMTahov29]

@@@ hint
Reversing the whole string puts the words in the right order, but each word is now spelled backwards. Reversing every word a second time fixes the spelling. Both steps are in place.
@@@ hint
Handle the spacing first with a read/write compaction pass. Copy characters from `r` to `w`, write a single `' '` only **between** words, and drop leading and trailing spaces. Then do "reverse all, reverse each word" on the compacted string of length `w`.
@@@ solution_code
#include <stddef.h>

static void reverse_range(char *s, size_t i, size_t j)   /* reverse s[i..j-1] */
{
    while (i + 1 < j) {
        char t = s[i];
        s[i++] = s[--j];
        s[j] = t;
    }
}

void reverse_words(char *s)
{
    size_t r = 0, w = 0;

    if (s == NULL)
        return;

    /* 1. compact: single spaces between words, none at the ends */
    while (s[r] != '\0') {
        while (s[r] == ' ')
            r++;
        if (s[r] == '\0')
            break;
        if (w > 0)
            s[w++] = ' ';
        while (s[r] != '\0' && s[r] != ' ')
            s[w++] = s[r++];        /* w <= r always: safe in place */
    }
    s[w] = '\0';

    /* 2. reverse the whole sentence */
    reverse_range(s, 0, w);

    /* 3. reverse each word back */
    for (size_t start = 0; start < w; ) {
        size_t end = start;
        while (end < w && s[end] != ' ')
            end++;
        reverse_range(s, start, end);
        start = end + 1;
    }
}
@@@ explanation_md
**Approach: compact, reverse all, reverse each word.**

```
"  hello world  "
compact      -> "hello world"
reverse all  -> "dlrow olleh"
reverse each -> "world hello"
```

1. **Compaction** uses a read index `r` and a write index `w <= r`. It skips space runs and emits one `' '` before every word except the first. This removes leading, trailing and repeated spaces in one pass.
2. Reversing the whole string moves the last word to the front, but spells every word backwards.
3. Reversing each word again restores its spelling.

**Complexity.** Time O(n): every character is moved a constant number of times (compaction, plus two reversals). Space O(1): only indices.

**Common mistakes**
- Using `strtok` to split into a pointer array and then rebuilding the string in a second buffer. That is O(n) extra memory, and `strtok` modifies the input in ways that are hard to undo.
- Leaving a trailing space when the input ends in spaces, or writing a separator before the first word.
- `size_t` underflow in `reverse(s, i, j)` written as `j = len - 1` with `len == 0`. That gives `j = SIZE_MAX`, and the loop scribbles over memory. The half-open range `[i, j)` used above avoids this.
- Forgetting to write the new `'\0'` after compaction, so the old tail of the string survives.

**Interview follow-ups**
- Reverse the words but **keep** the original spacing pattern. (Skip the compaction step: reverse all, then reverse each maximal non-space run.)
- Rotate a string left by `k` characters in place. (The same three-reversal trick: reverse `[0,k)`, reverse `[k,n)`, reverse all.)
- The sentence is UTF-8. Why does reversing bytes break multi-byte characters, and how do the two reversal passes interact with that? (Within a word, the second reversal restores byte order, so UTF-8 survives; reversing only once would not.)
