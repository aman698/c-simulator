@@@ meta
id: STC-E-03
topic: Structures
difficulty: Easy
type: FUNCTION
title: ADC Sample Statistics Returned as a Struct
tags: embedded, return-struct, adc, int16, saturation
@@@ statement_md
A sensor task collects a block of signed 16-bit ADC samples and needs several statistics at once. Instead of five output pointers, the function returns them **in one struct, by value**:

```c
struct AdcStats {
    int16_t  min;      /* smallest sample                          */
    int16_t  max;      /* largest sample                           */
    int16_t  avg;      /* sum / count, C integer division          */
    int32_t  sum;      /* sum of all samples                       */
    int32_t  range;    /* max - min                                */
    uint16_t count;    /* number of samples                        */
    uint16_t clipped;  /* samples stuck at a rail: -32768 or 32767 */
};

struct AdcStats adc_stats(const int16_t *samples, size_t n);
```

The struct is already defined by the judge. Do not redefine it.

Rules:
- `avg` is `sum / count` with C integer division, so it is **truncated toward zero** (`-11 / 2 == -5`).
- `clipped` counts samples equal to `INT16_MIN` (-32768) or `INT16_MAX` (32767). These mean the sensor hit the end of its range.
- If `n == 0`, `samples` may be `NULL` and **every** field must be `0`.

**How it is tested.** A hidden `main()` reads the samples, calls `adc_stats` once, and prints every field.

**Input (read by the hidden harness)**
- Line 1: `n`.
- Line 2: `n` integers (absent when `n = 0`).

**Output (printed by the harness)**
```
min=<min> max=<max> avg=<avg> sum=<sum> range=<range> count=<count> clipped=<clipped>
```

**Example**
```
Input:
5
120 -40 300 15 -95

Output:
min=-95 max=300 avg=60 sum=300 range=395 count=5 clipped=0
```
@@@ constraints_md
- `0 <= n <= 1000`
- Every sample fits in `int16_t` (`-32768 .. 32767`).
- `range` can be as large as 65535, which does not fit in `int16_t`. That is why `range` is `int32_t`.
- Single pass over the data, O(1) extra memory.
@@@ starter_code
#include <stdint.h>
#include <stddef.h>

/* Already defined by the judge:
 *
 * struct AdcStats {
 *     int16_t  min, max, avg;
 *     int32_t  sum, range;
 *     uint16_t count, clipped;
 * };
 */

struct AdcStats adc_stats(const int16_t *samples, size_t n)
{
    struct AdcStats st = { 0 };
    /* TODO */
    (void)samples;
    (void)n;
    return st;
}
@@@ harness_code
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

struct AdcStats {
    int16_t  min;
    int16_t  max;
    int16_t  avg;
    int32_t  sum;
    int32_t  range;
    uint16_t count;
    uint16_t clipped;
};

/*USER_CODE*/

static int16_t samples[1000];

int main(void)
{
    int n;
    if (scanf("%d", &n) != 1 || n < 0 || n > 1000) return 0;
    for (int i = 0; i < n; i++) {
        int v;
        if (scanf("%d", &v) != 1) return 0;
        samples[i] = (int16_t)v;
    }
    struct AdcStats s = adc_stats(n ? samples : NULL, (size_t)n);
    printf("min=%d max=%d avg=%d sum=%d range=%d count=%u clipped=%u\n",
           s.min, s.max, s.avg, (int)s.sum, (int)s.range,
           (unsigned)s.count, (unsigned)s.clipped);
    return 0;
}
@@@ sample_input
5
120 -40 300 15 -95
@@@ sample_output
min=-95 max=300 avg=60 sum=300 range=395 count=5 clipped=0

@@@ sample_input
0
@@@ sample_output
min=0 max=0 avg=0 sum=0 range=0 count=0 clipped=0

@@@ hidden_input
1
-7
@@@ hidden_output
min=-7 max=-7 avg=-7 sum=-7 range=0 count=1 clipped=0

@@@ hidden_input
4
1000 1000 1000 1000
@@@ hidden_output
min=1000 max=1000 avg=1000 sum=4000 range=0 count=4 clipped=0

@@@ hidden_input
3
-32768 32767 0
@@@ hidden_output
min=-32768 max=32767 avg=0 sum=-1 range=65535 count=3 clipped=2

@@@ hidden_input
2
-5 -6
@@@ hidden_output
min=-6 max=-5 avg=-5 sum=-11 range=1 count=2 clipped=0

@@@ hidden_input
3
-100 -200 -300
@@@ hidden_output
min=-300 max=-100 avg=-200 sum=-600 range=200 count=3 clipped=0

@@@ hidden_input
6
32767 32767 32767 32767 32767 32767
@@@ hidden_output
min=32767 max=32767 avg=32767 sum=196602 range=0 count=6 clipped=6

@@@ hidden_input
1000
-32768 -24849 -16930 -9011 -1092 6827 14746 22665 30584 -27033 -19114 -11195 -3276 4643 12562 20481 28400 -29217 -21298 -13379 -5460 2459 10378 18297 26216 -31401 -23482 -15563 -7644 275 8194 16113 24032 31951 -25666 -17747 -9828 -1909 6010 13929 21848 29767 -27850 -19931 -12012 -4093 3826 11745 19664 27583 -30034 -22115 -14196 -6277 1642 9561 17480 25399 -32218 -24299 -16380 -8461 -542 7377 15296 23215 31134 -26483 -18564 -10645 -2726 5193 13112 21031 28950 -28667 -20748 -12829 -4910 3009 10928 18847 26766 -30851 -22932 -15013 -7094 825 8744 16663 24582 32501 -25116 -17197 -9278 -1359 6560 14479 22398 30317 -27300 -19381 -11462 -3543 4376 12295 20214 28133 -29484 -21565 -13646 -5727 2192 10111 18030 25949 -31668 -23749 -15830 -7911 8 7927 15846 23765 31684 -25933 -18014 -10095 -2176 5743 13662 21581 29500 -28117 -20198 -12279 -4360 3559 11478 19397 27316 -30301 -22382 -14463 -6544 1375 9294 17213 25132 -32485 -24566 -16647 -8728 -809 7110 15029 22948 30867 -26750 -18831 -10912 -2993 4926 12845 20764 28683 -28934 -21015 -13096 -5177 2742 10661 18580 26499 -31118 -23199 -15280 -7361 558 8477 16396 24315 32234 -25383 -17464 -9545 -1626 6293 14212 22131 30050 -27567 -19648 -11729 -3810 4109 12028 19947 27866 -29751 -21832 -13913 -5994 1925 9844 17763 25682 -31935 -24016 -16097 -8178 -259 7660 15579 23498 31417 -26200 -18281 -10362 -2443 5476 13395 21314 29233 -28384 -20465 -12546 -4627 3292 11211 19130 27049 -30568 -22649 -14730 -6811 1108 9027 16946 24865 -32752 -24833 -16914 -8995 -1076 6843 14762 22681 30600 -27017 -19098 -11179 -3260 4659 12578 20497 28416 -29201 -21282 -13363 -5444 2475 10394 18313 26232 -31385 -23466 -15547 -7628 291 8210 16129 24048 31967 -25650 -17731 -9812 -1893 6026 13945 21864 29783 -27834 -19915 -11996 -4077 3842 11761 19680 27599 -30018 -22099 -14180 -6261 1658 9577 17496 25415 -32202 -24283 -16364 -8445 -526 7393 15312 23231 31150 -26467 -18548 -10629 -2710 5209 13128 21047 28966 -28651 -20732 -12813 -4894 3025 10944 18863 26782 -30835 -22916 -14997 -7078 841 8760 16679 24598 32517 -25100 -17181 -9262 -1343 6576 14495 22414 30333 -27284 -19365 -11446 -3527 4392 12311 20230 28149 -29468 -21549 -13630 -5711 2208 10127 18046 25965 -31652 -23733 -15814 -7895 24 7943 15862 23781 31700 -25917 -17998 -10079 -2160 5759 13678 21597 29516 -28101 -20182 -12263 -4344 3575 11494 19413 27332 -30285 -22366 -14447 -6528 1391 9310 17229 25148 -32469 -24550 -16631 -8712 -793 7126 15045 22964 30883 -26734 -18815 -10896 -2977 4942 12861 20780 28699 -28918 -20999 -13080 -5161 2758 10677 18596 26515 -31102 -23183 -15264 -7345 574 8493 16412 24331 32250 -25367 -17448 -9529 -1610 6309 14228 22147 30066 -27551 -19632 -11713 -3794 4125 12044 19963 27882 -29735 -21816 -13897 -5978 1941 9860 17779 25698 -31919 -24000 -16081 -8162 -243 7676 15595 23514 31433 -26184 -18265 -10346 -2427 5492 13411 21330 29249 -28368 -20449 -12530 -4611 3308 11227 19146 27065 -30552 -22633 -14714 -6795 1124 9043 16962 24881 -32736 -24817 -16898 -8979 -1060 6859 14778 22697 30616 -27001 -19082 -11163 -3244 4675 12594 20513 28432 -29185 -21266 -13347 -5428 2491 10410 18329 26248 -31369 -23450 -15531 -7612 307 8226 16145 24064 31983 -25634 -17715 -9796 -1877 6042 13961 21880 29799 -27818 -19899 -11980 -4061 3858 11777 19696 27615 -30002 -22083 -14164 -6245 1674 9593 17512 25431 -32186 -24267 -16348 -8429 -510 7409 15328 23247 31166 -26451 -18532 -10613 -2694 5225 13144 21063 28982 -28635 -20716 -12797 -4878 3041 10960 18879 26798 -30819 -22900 -14981 -7062 857 8776 16695 24614 32533 -25084 -17165 -9246 -1327 6592 14511 22430 30349 -27268 -19349 -11430 -3511 4408 12327 20246 28165 -29452 -21533 -13614 -5695 2224 10143 18062 25981 -31636 -23717 -15798 -7879 40 7959 15878 23797 31716 -25901 -17982 -10063 -2144 5775 13694 21613 29532 -28085 -20166 -12247 -4328 3591 11510 19429 27348 -30269 -22350 -14431 -6512 1407 9326 17245 25164 -32453 -24534 -16615 -8696 -777 7142 15061 22980 30899 -26718 -18799 -10880 -2961 4958 12877 20796 28715 -28902 -20983 -13064 -5145 2774 10693 18612 26531 -31086 -23167 -15248 -7329 590 8509 16428 24347 32266 -25351 -17432 -9513 -1594 6325 14244 22163 30082 -27535 -19616 -11697 -3778 4141 12060 19979 27898 -29719 -21800 -13881 -5962 1957 9876 17795 25714 -31903 -23984 -16065 -8146 -227 7692 15611 23530 31449 -26168 -18249 -10330 -2411 5508 13427 21346 29265 -28352 -20433 -12514 -4595 3324 11243 19162 27081 -30536 -22617 -14698 -6779 1140 9059 16978 24897 -32720 -24801 -16882 -8963 -1044 6875 14794 22713 30632 -26985 -19066 -11147 -3228 4691 12610 20529 28448 -29169 -21250 -13331 -5412 2507 10426 18345 26264 -31353 -23434 -15515 -7596 323 8242 16161 24080 31999 -25618 -17699 -9780 -1861 6058 13977 21896 29815 -27802 -19883 -11964 -4045 3874 11793 19712 27631 -29986 -22067 -14148 -6229 1690 9609 17528 25447 -32170 -24251 -16332 -8413 -494 7425 15344 23263 31182 -26435 -18516 -10597 -2678 5241 13160 21079 28998 -28619 -20700 -12781 -4862 3057 10976 18895 26814 -30803 -22884 -14965 -7046 873 8792 16711 24630 32549 -25068 -17149 -9230 -1311 6608 14527 22446 30365 -27252 -19333 -11414 -3495 4424 12343 20262 28181 -29436 -21517 -13598 -5679 2240 10159 18078 25997 -31620 -23701 -15782 -7863 56 7975 15894 23813 31732 -25885 -17966 -10047 -2128 5791 13710 21629 29548 -28069 -20150 -12231 -4312 3607 11526 19445 27364 -30253 -22334 -14415 -6496 1423 9342 17261 25180 -32437 -24518 -16599 -8680 -761 7158 15077 22996 30915 -26702 -18783 -10864 -2945 4974 12893 20812 28731 -28886 -20967 -13048 -5129 2790 10709 18628 26547 -31070 -23151 -15232 -7313 606 8525 16444 24363 32282 -25335 -17416 -9497 -1578 6341 14260 22179 30098 -27519 -19600 -11681 -3762 4157 12076 19995 27914 -29703 -21784 -13865 -5946 1973 9892 17811 25730 -31887 -23968 -16049 -8130 -211 7708 15627 23546 31465 -26152 -18233 -10314 -2395 5524 13443 21362 29281 -28336 -20417 -12498 -4579 3340 11259 19178 27097 -30520 -22601 -14682 -6763 1156 9075 16994 24913 -32704 -24785 -16866 -8947 -1028 6891 14810 22729 30648 -26969 -19050 -11131 -3212 4707 12626 20545 28464 -29153 -21234 -13315 -5396 2523 10442 18361 26280 -31337 -23418 -15499 -7580 339 8258 16177 24096 32015 -25602 -17683 -9764 -1845 6074 13993
@@@ hidden_output
min=-32768 max=32549 avg=-146 sum=-146924 range=65317 count=1000 clipped=1

@@@ hint
Initialise `min` and `max` from the **first sample**, not from 0. Otherwise an all-negative block reports `max = 0`, and an all-positive block reports `min = 0`.
@@@ hint
Accumulate the sum in a 32-bit variable, and compute `range` as `(int32_t)max - min`. Handle `n == 0` before you touch `samples[0]`, because `samples` may be `NULL`.
@@@ solution_code
#include <stdint.h>
#include <stddef.h>

struct AdcStats adc_stats(const int16_t *samples, size_t n)
{
    struct AdcStats st = { 0 };      /* all fields 0: covers n == 0 */
    if (n == 0 || samples == NULL)
        return st;

    int16_t mn = samples[0];
    int16_t mx = samples[0];
    int32_t sum = 0;                 /* 1000 * 32767 fits easily in 32 bits */
    uint16_t clipped = 0;

    for (size_t i = 0; i < n; i++) {
        int16_t v = samples[i];
        if (v < mn) mn = v;
        if (v > mx) mx = v;
        sum += v;
        if (v == INT16_MIN || v == INT16_MAX)
            clipped++;
    }

    st.min = mn;
    st.max = mx;
    st.sum = sum;
    st.count = (uint16_t)n;
    st.avg = (int16_t)(sum / (int32_t)n);   /* truncates toward zero; always in int16_t range */
    st.range = (int32_t)mx - (int32_t)mn;   /* up to 65535: needs 32 bits */
    st.clipped = clipped;
    return st;                              /* returned by value (hidden pointer on x86-64) */
}
@@@ explanation_md
**Approach.** One pass. Track min, max, sum and the clipped count, then fill a local `struct AdcStats` and `return` it. Returning a struct by value is legal and well defined in C. The caller receives a full copy, so you do not need output pointers or a global.

```
samples: 120 -40 300 15 -95
min=-95 max=300 sum=300 avg=300/5=60 range=300-(-95)=395
```

How the struct is returned depends on the ABI. On x86-64 System V this 20-byte struct does not fit in two registers, so the caller passes a hidden pointer to its own result slot, and the callee writes there. On ARM AAPCS, a struct larger than 4 bytes is also returned through memory. This is invisible in C, but it matters when you read disassembly or call C from assembly.

**Complexity.** Time O(n), space O(1).

**Common mistakes**
- Starting `min`/`max` at 0. The `-100 -200 -300` test then reports `max=0`.
- Summing into an `int16_t`. Six samples of 32767 already overflow it.
- Storing `range` in `int16_t`. `32767 - (-32768) = 65535` wraps to `-1`.
- Reading `samples[0]` when `n == 0`, where the pointer is `NULL`.
- Expecting `avg` of `-5 -6` to be `-6` (floor). C99 and later truncate toward zero, so the result is `-5`.

**Interview follow-ups**
- How does the compiler return a struct that does not fit in registers? What is the "hidden pointer" (sret) argument?
- Your RTOS task has a 512-byte stack. Would you still return a 200-byte struct by value? What would you use instead?
- How would you compute a running average over a sliding window of the last 16 samples without storing a sum that can overflow?
- Should `clipped` saturate at 65535 instead of wrapping if `n` could exceed 65535? How would you write that?
