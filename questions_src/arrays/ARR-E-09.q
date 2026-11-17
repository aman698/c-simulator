@@@ meta
id: ARR-E-09
topic: Arrays
difficulty: Easy
type: FIND_THE_BUG
title: ADC Oversampling Average Collapses Near Full Scale
tags: embedded, adc, integer-overflow, accumulator, oversampling
@@@ statement_md
An ECU's ADC driver oversamples each analog channel: it takes `N` 12-bit samples (`0..4095`) per channel and reports their average, **rounded to nearest** (`(sum + N/2) / N`), to reduce noise.

The code passed bench tests with 4 and 16 samples. After oversampling was raised to 32 samples, the **throttle position channel** reads correctly at idle, but near wide-open throttle the reported value suddenly drops to roughly half and jumps around.

Find and fix the bug. Do not change the input or output format.

**Input**
- Line 1: the number of channels `C` and samples per channel `N`.
- Next `C` lines: `N` samples of that channel.

**Output**
- One line per channel: `CHk: avg`.

**Example**
```
Input:
2 4
100 200 300 400
4095 4095 4095 4095

Output:
CH0: 250
CH1: 4095
```
@@@ constraints_md
- `1 <= C <= 8`, `1 <= N <= 256`
- `0 <= sample <= 4095` (12-bit ADC)
- The result is the average rounded half up: `(sum + N/2) / N`.
@@@ starter_code
#include <stdio.h>
#include <stdint.h>

#define MAX_CH      8
#define MAX_SAMPLES 256

static uint16_t samples[MAX_CH][MAX_SAMPLES];

/* Average of n 12-bit samples, rounded to nearest. */
static uint16_t adc_average(const uint16_t *s, uint16_t n)
{
    uint16_t sum = 0;
    for (uint16_t i = 0; i < n; i++)
        sum += s[i];
    return (uint16_t)((sum + n / 2u) / n);
}

int main(void)
{
    int ch, n;
    if (scanf("%d %d", &ch, &n) != 2) return 0;
    if (ch < 1 || ch > MAX_CH || n < 1 || n > MAX_SAMPLES) return 0;

    for (int c = 0; c < ch; c++) {
        for (int i = 0; i < n; i++) {
            unsigned v;
            if (scanf("%u", &v) != 1) return 0;
            samples[c][i] = (uint16_t)v;
        }
    }
    for (int c = 0; c < ch; c++)
        printf("CH%d: %u\n", c, (unsigned)adc_average(samples[c], (uint16_t)n));
    return 0;
}
@@@ sample_input
2 4
100 200 300 400
4095 4095 4095 4095
@@@ sample_output
CH0: 250
CH1: 4095

@@@ sample_input
1 32
4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000 4000
@@@ sample_output
CH0: 4000

@@@ hidden_input
1 1
0
@@@ hidden_output
CH0: 0

@@@ hidden_input
2 1
4095
7
@@@ hidden_output
CH0: 4095
CH1: 7

@@@ hidden_input
3 64
4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095 0 4095
@@@ hidden_output
CH0: 4095
CH1: 0
CH2: 2048

@@@ hidden_input
1 256
0 16 32 48 64 80 96 112 128 144 160 176 192 208 224 240 256 272 288 304 320 336 352 368 384 400 416 432 448 464 480 496 512 528 544 560 576 592 608 624 640 656 672 688 704 720 736 752 768 784 800 816 832 848 864 880 896 912 928 944 960 976 992 1008 1024 1040 1056 1072 1088 1104 1120 1136 1152 1168 1184 1200 1216 1232 1248 1264 1280 1296 1312 1328 1344 1360 1376 1392 1408 1424 1440 1456 1472 1488 1504 1520 1536 1552 1568 1584 1600 1616 1632 1648 1664 1680 1696 1712 1728 1744 1760 1776 1792 1808 1824 1840 1856 1872 1888 1904 1920 1936 1952 1968 1984 2000 2016 2032 2048 2064 2080 2096 2112 2128 2144 2160 2176 2192 2208 2224 2240 2256 2272 2288 2304 2320 2336 2352 2368 2384 2400 2416 2432 2448 2464 2480 2496 2512 2528 2544 2560 2576 2592 2608 2624 2640 2656 2672 2688 2704 2720 2736 2752 2768 2784 2800 2816 2832 2848 2864 2880 2896 2912 2928 2944 2960 2976 2992 3008 3024 3040 3056 3072 3088 3104 3120 3136 3152 3168 3184 3200 3216 3232 3248 3264 3280 3296 3312 3328 3344 3360 3376 3392 3408 3424 3440 3456 3472 3488 3504 3520 3536 3552 3568 3584 3600 3616 3632 3648 3664 3680 3696 3712 3728 3744 3760 3776 3792 3808 3824 3840 3856 3872 3888 3904 3920 3936 3952 3968 3984 4000 4016 4032 4048 4064 4080
@@@ hidden_output
CH0: 2040

@@@ hidden_input
2 16
4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095
1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
@@@ hidden_output
CH0: 4095
CH1: 1

@@@ hidden_input
1 200
3236 3756 3725 3633 3264 3056 3426 3707 3636 3785 3588 3466 3260 3518 3458 3640 3809 3546 3633 3565 3915 3890 3384 3169 3638 3099 3806 3566 3204 3349 3032 3320 3340 3080 3930 3637 3786 3493 3401 3447 3492 3969 3326 3571 3792 3501 3399 3967 3392 3696 3453 3260 3590 3253 3953 3025 3417 3503 3318 3821 3096 3054 3615 3758 3893 3024 3477 3431 3214 3507 3047 3372 3813 3820 3552 3603 3171 3866 3246 3857 3505 3848 3596 3791 3667 3495 3933 3962 3039 3256 3511 3321 3375 3829 3689 3383 3017 3297 3046 3270 3881 3181 3695 3746 3834 3562 3173 3034 3934 3734 3710 3042 3740 3029 3256 3870 3033 3805 3985 3921 3935 3788 3147 3461 3400 3374 3050 3238 3157 3668 3857 3349 3265 3274 3399 3434 3984 3634 3796 3792 3827 3809 3704 3809 3133 3948 3716 3638 3415 3088 3142 3790 3215 3913 3822 3717 3033 3401 3481 3218 3183 3380 3207 3107 3719 3839 3759 3365 3788 3467 3758 3699 3989 3591 3652 3612 3701 3695 3212 3411 3175 3047 3951 3837 3836 3275 3646 3467 3945 3837 3332 3723 3612 3204 3943 3602 3311 3315 3018 3353
@@@ hidden_output
CH0: 3518

@@@ hidden_input
8 17
4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095 4095
4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094 4094
4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093 4093
4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092 4092
4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091 4091
4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090 4090
4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089 4089
4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088 4088
@@@ hidden_output
CH0: 4095
CH1: 4094
CH2: 4093
CH3: 4092
CH4: 4091
CH5: 4090
CH6: 4089
CH7: 4088

@@@ hint
What is the largest value `sum` can reach with 32 samples of `4095`? What is the largest value its type can hold?
@@@ hint
`uint16_t` holds at most 65535. Sixteen full-scale samples (65520) just fit; the seventeenth makes the sum wrap around modulo 65536. Unsigned wrap-around is well defined, so no sanitizer reports it. The accumulator needs at least `12 + log2(256) = 20` bits.
@@@ solution_code
#include <stdio.h>
#include <stdint.h>

#define MAX_CH      8
#define MAX_SAMPLES 256

static uint16_t samples[MAX_CH][MAX_SAMPLES];

/* Average of n 12-bit samples, rounded to nearest. */
static uint16_t adc_average(const uint16_t *s, uint16_t n)
{
    uint32_t sum = 0;          /* FIX: 12-bit * 256 samples needs 20 bits; uint16_t wrapped at 17 full-scale samples */
    for (uint16_t i = 0; i < n; i++)
        sum += s[i];
    return (uint16_t)((sum + n / 2u) / n);
}

int main(void)
{
    int ch, n;
    if (scanf("%d %d", &ch, &n) != 2) return 0;
    if (ch < 1 || ch > MAX_CH || n < 1 || n > MAX_SAMPLES) return 0;

    for (int c = 0; c < ch; c++) {
        for (int i = 0; i < n; i++) {
            unsigned v;
            if (scanf("%u", &v) != 1) return 0;
            samples[c][i] = (uint16_t)v;
        }
    }
    for (int c = 0; c < ch; c++)
        printf("CH%d: %u\n", c, (unsigned)adc_average(samples[c], (uint16_t)n));
    return 0;
}
@@@ explanation_md
**Bug.** The accumulator `uint16_t sum` is too narrow. Its maximum is 65535 = 16 * 4095 + 15, so 16 full-scale samples fit and 17 do not. With 32 samples of 4000 the real sum is 128000, but the variable holds `128000 mod 65536 = 62464`, and the "average" becomes `62464 / 32 = 1952` instead of 4000. At idle the samples are small and the sum never wraps, which is why bench tests passed.

**Fix.** Size the accumulator from the worst case: `N_max * max_sample = 256 * 4095 = 1 048 320`, which needs 20 bits. Use `uint32_t`. Write a `_Static_assert` next to the constants so that the next increase of `MAX_SAMPLES` cannot silently break it again.

**Why no tool caught it.** **Unsigned** arithmetic wraps by definition (C11 6.2.5p9). It is not undefined behavior, so UBSan stays silent. (`sum += s[i]` is computed in `int` and then converted back to `uint16_t`, which is a well-defined modulo reduction.) Only `-Wconversion` or a MISRA checker (Rule 10.3) flags the narrowing assignment.

**Complexity.** Time O(C * N), space O(1) beyond the sample buffer. The fix has no cost: a 32-bit add is a single instruction even on a Cortex-M0.

**Common mistakes**
- "Fixing" it by dividing every sample by `N` before adding. Precision is lost: 32 samples of `31` average to `0`.
- Using `int` and assuming it is 32 bits. On a 16-bit MCU (MSP430, older C166/XC16x parts) `int` is 16 bits, and the same bug returns as **signed** overflow, which is undefined behavior. Use fixed-width types.
- Changing only the return type. The overflow happens in the accumulator.

**Interview follow-ups**
- Oversampling by 4^k gains k extra bits of resolution. How would you return a 14-bit result from 16 samples of 12 bits? (Sum, then shift right by 2.)
- If the samples come from a DMA ring buffer that is written while you average, what can go wrong, and how do you take a consistent snapshot?
- Write a compile-time guard: `_Static_assert((uint64_t)MAX_SAMPLES * 4095u <= UINT32_MAX, "accumulator too small");`.
