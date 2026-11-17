@@@ meta
id: PAT-H-01
topic: C Patterns
difficulty: Hard
type: CODE
title: Window into a Huge Spiral Matrix
tags: spiral-matrix, closed-form, long-long, column-width, asked-in-product-companies
@@@ statement_md
The **spiral matrix** of size `R x C` contains `1, 2, ..., R*C`, filled **clockwise** starting at the top-left corner: along the top row to the right, down the right column, along the bottom row to the left, up the left column, and then the same for the inner rectangle, and so on.

```
R = 3, C = 4:
 1  2  3 4
10 11 12 5
 9  8  7 6
```

`R` and `C` can be up to `10^9`, so the matrix can never be stored or simulated. Print only the **window** of rows `r1..r2` and columns `c1..c2` (0-based, inclusive).

**Formatting.** Each column of the window is right-aligned to its **own** width: the number of digits of the largest value **in that window column**. Columns are separated by **one space**.

**Validation.** Print exactly `INVALID` if any of these holds: `R < 1`, `C < 1`, `r1 < 0`, `c1 < 0`, `r1 > r2`, `c1 > c2`, `r2 >= R`, `c2 >= C`, or the window has more than 40 rows or more than 40 columns.

**Input**
- One line: `R C r1 c1 r2 c2`.

**Output**
- `r2 - r1 + 1` lines, or `INVALID`.
- Leading spaces are significant. The judge ignores trailing spaces and trailing blank lines.

**Example 1**
```
Input:
3 4 0 0 2 3

Output:
 1  2  3 4
10 11 12 5
 9  8  7 6
```
The last column holds only `4, 5, 6`, so it is 1 character wide.

**Example 2**
```
Input:
1000000000 1000000000 499999999 499999999 500000000 500000000

Output:
 999999999999999997 999999999999999998
1000000000000000000 999999999999999999
```
This is the 2x2 center of a `10^9 x 10^9` spiral. The values need 64-bit arithmetic.
@@@ constraints_md
- All six input numbers fit in a 32-bit `int`; a valid input has `1 <= R, C <= 10^9`.
- The window has at most `40 x 40` cells.
- Values go up to `R*C <= 10^18`: use `long long` (never `long`).
- Expected: O(1) work per printed cell.
@@@ starter_code
#include <stdio.h>

int main(void)
{
    long long R, C, r1, c1, r2, c2;
    if (scanf("%lld %lld %lld %lld %lld %lld", &R, &C, &r1, &c1, &r2, &c2) != 6) return 0;

    /* TODO: validate, compute every window cell in O(1),
       find the width of each window column, print */

    return 0;
}
@@@ sample_input
3 4 0 0 2 3
@@@ sample_output
 1  2  3 4
10 11 12 5
 9  8  7 6

@@@ sample_input
1000000000 1000000000 499999999 499999999 500000000 500000000
@@@ sample_output
 999999999999999997 999999999999999998
1000000000000000000 999999999999999999

@@@ hidden_input
5 5 1 1 3 3
@@@ hidden_output
17 18 19
24 25 20
23 22 21

@@@ hidden_input
1 1 0 0 0 0
@@@ hidden_output
1

@@@ hidden_input
1 6 0 0 0 5
@@@ hidden_output
1 2 3 4 5 6

@@@ hidden_input
6 1 0 0 5 0
@@@ hidden_output
1
2
3
4
5
6

@@@ hidden_input
3 3 2 0 1 2
@@@ hidden_output
INVALID

@@@ hidden_input
3 3 0 0 3 0
@@@ hidden_output
INVALID

@@@ hidden_input
0 5 0 0 0 0
@@@ hidden_output
INVALID

@@@ hidden_input
100 100 0 0 40 0
@@@ hidden_output
INVALID

@@@ hidden_input
1000000000 1000000000 0 0 2 3
@@@ hidden_output
         1          2          3          4
3999999996 3999999997 3999999998 3999999999
3999999995 7999999984 7999999985 7999999986

@@@ hidden_input
3 7 0 0 2 6
@@@ hidden_output
 1  2  3  4  5  6 7
16 17 18 19 20 21 8
15 14 13 12 11 10 9

@@@ hidden_input
7 3 0 0 6 2
@@@ hidden_output
 1  2 3
16 17 4
15 18 5
14 19 6
13 20 7
12 21 8
11 10 9

@@@ hidden_input
4 10 1 2 3 8
@@@ hidden_output
26 27 28 29 30 31 32
39 38 37 36 35 34 33
20 19 18 17 16 15 14

@@@ hidden_input
2 1000000000 0 999999990 1 999999999
@@@ hidden_output
 999999991  999999992  999999993  999999994  999999995  999999996  999999997  999999998  999999999 1000000000
1000000010 1000000009 1000000008 1000000007 1000000006 1000000005 1000000004 1000000003 1000000002 1000000001

@@@ hidden_input
40 40 0 0 39 39
@@@ hidden_output
  1   2   3   4   5   6   7    8    9   10   11   12   13   14   15   16   17   18   19   20   21   22   23   24   25   26   27   28   29   30   31   32  33  34  35  36  37  38  39 40
156 157 158 159 160 161 162  163  164  165  166  167  168  169  170  171  172  173  174  175  176  177  178  179  180  181  182  183  184  185  186  187 188 189 190 191 192 193 194 41
155 304 305 306 307 308 309  310  311  312  313  314  315  316  317  318  319  320  321  322  323  324  325  326  327  328  329  330  331  332  333  334 335 336 337 338 339 340 195 42
154 303 444 445 446 447 448  449  450  451  452  453  454  455  456  457  458  459  460  461  462  463  464  465  466  467  468  469  470  471  472  473 474 475 476 477 478 341 196 43
153 302 443 576 577 578 579  580  581  582  583  584  585  586  587  588  589  590  591  592  593  594  595  596  597  598  599  600  601  602  603  604 605 606 607 608 479 342 197 44
152 301 442 575 700 701 702  703  704  705  706  707  708  709  710  711  712  713  714  715  716  717  718  719  720  721  722  723  724  725  726  727 728 729 730 609 480 343 198 45
151 300 441 574 699 816 817  818  819  820  821  822  823  824  825  826  827  828  829  830  831  832  833  834  835  836  837  838  839  840  841  842 843 844 731 610 481 344 199 46
150 299 440 573 698 815 924  925  926  927  928  929  930  931  932  933  934  935  936  937  938  939  940  941  942  943  944  945  946  947  948  949 950 845 732 611 482 345 200 47
149 298 439 572 697 814 923 1024 1025 1026 1027 1028 1029 1030 1031 1032 1033 1034 1035 1036 1037 1038 1039 1040 1041 1042 1043 1044 1045 1046 1047 1048 951 846 733 612 483 346 201 48
148 297 438 571 696 813 922 1023 1116 1117 1118 1119 1120 1121 1122 1123 1124 1125 1126 1127 1128 1129 1130 1131 1132 1133 1134 1135 1136 1137 1138 1049 952 847 734 613 484 347 202 49
147 296 437 570 695 812 921 1022 1115 1200 1201 1202 1203 1204 1205 1206 1207 1208 1209 1210 1211 1212 1213 1214 1215 1216 1217 1218 1219 1220 1139 1050 953 848 735 614 485 348 203 50
146 295 436 569 694 811 920 1021 1114 1199 1276 1277 1278 1279 1280 1281 1282 1283 1284 1285 1286 1287 1288 1289 1290 1291 1292 1293 1294 1221 1140 1051 954 849 736 615 486 349 204 51
145 294 435 568 693 810 919 1020 1113 1198 1275 1344 1345 1346 1347 1348 1349 1350 1351 1352 1353 1354 1355 1356 1357 1358 1359 1360 1295 1222 1141 1052 955 850 737 616 487 350 205 52
144 293 434 567 692 809 918 1019 1112 1197 1274 1343 1404 1405 1406 1407 1408 1409 1410 1411 1412 1413 1414 1415 1416 1417 1418 1361 1296 1223 1142 1053 956 851 738 617 488 351 206 53
143 292 433 566 691 808 917 1018 1111 1196 1273 1342 1403 1456 1457 1458 1459 1460 1461 1462 1463 1464 1465 1466 1467 1468 1419 1362 1297 1224 1143 1054 957 852 739 618 489 352 207 54
142 291 432 565 690 807 916 1017 1110 1195 1272 1341 1402 1455 1500 1501 1502 1503 1504 1505 1506 1507 1508 1509 1510 1469 1420 1363 1298 1225 1144 1055 958 853 740 619 490 353 208 55
141 290 431 564 689 806 915 1016 1109 1194 1271 1340 1401 1454 1499 1536 1537 1538 1539 1540 1541 1542 1543 1544 1511 1470 1421 1364 1299 1226 1145 1056 959 854 741 620 491 354 209 56
140 289 430 563 688 805 914 1015 1108 1193 1270 1339 1400 1453 1498 1535 1564 1565 1566 1567 1568 1569 1570 1545 1512 1471 1422 1365 1300 1227 1146 1057 960 855 742 621 492 355 210 57
139 288 429 562 687 804 913 1014 1107 1192 1269 1338 1399 1452 1497 1534 1563 1584 1585 1586 1587 1588 1571 1546 1513 1472 1423 1366 1301 1228 1147 1058 961 856 743 622 493 356 211 58
138 287 428 561 686 803 912 1013 1106 1191 1268 1337 1398 1451 1496 1533 1562 1583 1596 1597 1598 1589 1572 1547 1514 1473 1424 1367 1302 1229 1148 1059 962 857 744 623 494 357 212 59
137 286 427 560 685 802 911 1012 1105 1190 1267 1336 1397 1450 1495 1532 1561 1582 1595 1600 1599 1590 1573 1548 1515 1474 1425 1368 1303 1230 1149 1060 963 858 745 624 495 358 213 60
136 285 426 559 684 801 910 1011 1104 1189 1266 1335 1396 1449 1494 1531 1560 1581 1594 1593 1592 1591 1574 1549 1516 1475 1426 1369 1304 1231 1150 1061 964 859 746 625 496 359 214 61
135 284 425 558 683 800 909 1010 1103 1188 1265 1334 1395 1448 1493 1530 1559 1580 1579 1578 1577 1576 1575 1550 1517 1476 1427 1370 1305 1232 1151 1062 965 860 747 626 497 360 215 62
134 283 424 557 682 799 908 1009 1102 1187 1264 1333 1394 1447 1492 1529 1558 1557 1556 1555 1554 1553 1552 1551 1518 1477 1428 1371 1306 1233 1152 1063 966 861 748 627 498 361 216 63
133 282 423 556 681 798 907 1008 1101 1186 1263 1332 1393 1446 1491 1528 1527 1526 1525 1524 1523 1522 1521 1520 1519 1478 1429 1372 1307 1234 1153 1064 967 862 749 628 499 362 217 64
132 281 422 555 680 797 906 1007 1100 1185 1262 1331 1392 1445 1490 1489 1488 1487 1486 1485 1484 1483 1482 1481 1480 1479 1430 1373 1308 1235 1154 1065 968 863 750 629 500 363 218 65
131 280 421 554 679 796 905 1006 1099 1184 1261 1330 1391 1444 1443 1442 1441 1440 1439 1438 1437 1436 1435 1434 1433 1432 1431 1374 1309 1236 1155 1066 969 864 751 630 501 364 219 66
130 279 420 553 678 795 904 1005 1098 1183 1260 1329 1390 1389 1388 1387 1386 1385 1384 1383 1382 1381 1380 1379 1378 1377 1376 1375 1310 1237 1156 1067 970 865 752 631 502 365 220 67
129 278 419 552 677 794 903 1004 1097 1182 1259 1328 1327 1326 1325 1324 1323 1322 1321 1320 1319 1318 1317 1316 1315 1314 1313 1312 1311 1238 1157 1068 971 866 753 632 503 366 221 68
128 277 418 551 676 793 902 1003 1096 1181 1258 1257 1256 1255 1254 1253 1252 1251 1250 1249 1248 1247 1246 1245 1244 1243 1242 1241 1240 1239 1158 1069 972 867 754 633 504 367 222 69
127 276 417 550 675 792 901 1002 1095 1180 1179 1178 1177 1176 1175 1174 1173 1172 1171 1170 1169 1168 1167 1166 1165 1164 1163 1162 1161 1160 1159 1070 973 868 755 634 505 368 223 70
126 275 416 549 674 791 900 1001 1094 1093 1092 1091 1090 1089 1088 1087 1086 1085 1084 1083 1082 1081 1080 1079 1078 1077 1076 1075 1074 1073 1072 1071 974 869 756 635 506 369 224 71
125 274 415 548 673 790 899 1000  999  998  997  996  995  994  993  992  991  990  989  988  987  986  985  984  983  982  981  980  979  978  977  976 975 870 757 636 507 370 225 72
124 273 414 547 672 789 898  897  896  895  894  893  892  891  890  889  888  887  886  885  884  883  882  881  880  879  878  877  876  875  874  873 872 871 758 637 508 371 226 73
123 272 413 546 671 788 787  786  785  784  783  782  781  780  779  778  777  776  775  774  773  772  771  770  769  768  767  766  765  764  763  762 761 760 759 638 509 372 227 74
122 271 412 545 670 669 668  667  666  665  664  663  662  661  660  659  658  657  656  655  654  653  652  651  650  649  648  647  646  645  644  643 642 641 640 639 510 373 228 75
121 270 411 544 543 542 541  540  539  538  537  536  535  534  533  532  531  530  529  528  527  526  525  524  523  522  521  520  519  518  517  516 515 514 513 512 511 374 229 76
120 269 410 409 408 407 406  405  404  403  402  401  400  399  398  397  396  395  394  393  392  391  390  389  388  387  386  385  384  383  382  381 380 379 378 377 376 375 230 77
119 268 267 266 265 264 263  262  261  260  259  258  257  256  255  254  253  252  251  250  249  248  247  246  245  244  243  242  241  240  239  238 237 236 235 234 233 232 231 78
118 117 116 115 114 113 112  111  110  109  108  107  106  105  104  103  102  101  100   99   98   97   96   95   94   93   92   91   90   89   88   87  86  85  84  83  82  81  80 79

@@@ hidden_input
999999999 7 499999990 0 499999999 6
@@@ hidden_output
1500000019 3500000020 5500000013 6499999988 4499999999 2500000002 499999997
1500000018 3500000019 5500000012 6499999989 4500000000 2500000003 499999998
1500000017 3500000018 5500000011 6499999990 4500000001 2500000004 499999999
1500000016 3500000017 5500000010 6499999991 4500000002 2500000005 500000000
1500000015 3500000016 5500000009 6499999992 4500000003 2500000006 500000001
1500000014 3500000015 5500000008 6499999993 4500000004 2500000007 500000002
1500000013 3500000014 5500000007 6499999994 4500000005 2500000008 500000003
1500000012 3500000013 5500000006 6499999995 4500000006 2500000009 500000004
1500000011 3500000012 5500000005 6499999996 4500000007 2500000010 500000005
1500000010 3500000011 5500000004 6499999997 4500000008 2500000011 500000006

@@@ hint
Cell `(i, j)` lies on ring `k = min(i, j, R-1-i, C-1-j)`. The `k` outer rings contain `R*C - (R-2k)*(C-2k)` cells, so every value on ring `k` starts after that count.
@@@ hint
On ring `k` the inner rectangle has `h = R-2k` rows and `w = C-2k` columns. Check the four sides **in this order**: top row (`i == k`), right column (`j == C-1-k`), bottom row (`i == R-1-k`), left column. The offsets along the ring are `j-k`, then `w + (i-k-1)`, then `w + (h-1) + (C-1-k-j-1)`, then `w + (h-1) + (w-1) + (R-1-k-i-1)`. Testing the top row first handles single-row and single-column rings automatically.
@@@ solution_code
#include <stdio.h>

static long long min_ll(long long a, long long b) { return a < b ? a : b; }

/* value at (i, j) of the R x C clockwise spiral, 1-based values, O(1) */
static long long spiral_at(long long R, long long C, long long i, long long j)
{
    long long k = min_ll(min_ll(i, j), min_ll(R - 1 - i, C - 1 - j)); /* ring index */
    long long h = R - 2 * k, w = C - 2 * k;     /* size of the rectangle of ring k */
    long long before = R * C - h * w;           /* cells on the k outer rings */
    long long top = k, left = k, bottom = R - 1 - k, right = C - 1 - k;
    long long off;

    if (i == top)                               /* top row, left to right */
        off = j - left;
    else if (j == right)                        /* right column, downwards */
        off = w + (i - top - 1);
    else if (i == bottom)                       /* bottom row, right to left */
        off = w + (h - 1) + (right - j - 1);
    else                                        /* left column, upwards */
        off = w + (h - 1) + (w - 1) + (bottom - i - 1);
    return before + off + 1;
}

static int digits(long long v)
{
    int d = 1;
    while (v >= 10) {
        v /= 10;
        d++;
    }
    return d;
}

static long long win[40][40];

int main(void)
{
    long long R, C, r1, c1, r2, c2;
    if (scanf("%lld %lld %lld %lld %lld %lld", &R, &C, &r1, &c1, &r2, &c2) != 6) return 0;

    if (R < 1 || C < 1 || r1 < 0 || c1 < 0 || r1 > r2 || c1 > c2 ||
        r2 >= R || c2 >= C || r2 - r1 >= 40 || c2 - c1 >= 40) {
        printf("INVALID\n");
        return 0;
    }
    int nr = (int)(r2 - r1 + 1), nc = (int)(c2 - c1 + 1);
    int width[40];

    for (int b = 0; b < nc; b++) {
        width[b] = 1;
        for (int a = 0; a < nr; a++) {
            win[a][b] = spiral_at(R, C, r1 + a, c1 + b);
            int d = digits(win[a][b]);
            if (d > width[b])
                width[b] = d;                   /* per-column width */
        }
    }
    for (int a = 0; a < nr; a++) {
        for (int b = 0; b < nc; b++) {
            if (b > 0)
                putchar(' ');
            printf("%*lld", width[b], win[a][b]);
        }
        putchar('\n');
    }
    return 0;
}
@@@ explanation_md
**Approach.** Classify each cell by its **ring** `k = min(i, j, R-1-i, C-1-j)`, its distance to the nearest border. All cells of the `k` outer rings come first in the spiral. Their count is the full area minus the inner rectangle: `before = R*C - (R-2k)(C-2k)`. On ring `k` (an `h x w` rectangle with `h = R-2k`, `w = C-2k`) the spiral walks the top row (`w` cells), the right column (`h-1` cells), the bottom row (`w-1` cells) and the left column (`h-2` cells). The position on the ring is a simple offset along whichever side the cell is on.

```
R=3, C=4, cell (1,1): k = 1, before = 12 - 1*2 = 10, top row, off = 0  -> 11
R=3, C=4, cell (2,0): k = 0, before = 0, bottom row, off = 4 + 2 + (3-0-1) = 8 -> 9
```

**Degenerate rings.** When the innermost ring is a single row (`h = 1`) or a single column (`w = 1`), the bottom row coincides with the top row (or the left column with the right one). Testing the sides in the order top, right, bottom, left assigns each cell exactly once. The checks for "bottom" and "left" are never reached for those cells. A simulation has the same trap: it must not walk back along a row it has already filled.

**Widths.** Compute all window values first (at most 1600), take the maximum digit count per column, then print with `%*lld`.

**Complexity.** O(1) per cell, so O(rows x cols) for the window, independent of `R` and `C`. Space O(window). Simulating the spiral would be O(R*C), about `10^18` steps here.

**Common mistakes**
- `int` arithmetic. `R*C` and even `before` overflow 32 bits; everything must be `long long` (and not `long`, which is 32-bit on Windows).
- Checking the left column before the bottom row. The bottom-left corner then gets the wrong offset.
- Using one global width (digits of `R*C`) instead of per-column widths. Example 2 shows the difference: the first column is 19 wide, the second 18.
- Off-by-one in the side lengths: the right column has `h - 1` cells, not `h`, because its top cell belongs to the top row.

**Interview follow-ups**
- Invert the mapping: given a value `v`, find its `(i, j)` in O(1) or O(log) time. (Find the ring by solving `before(k) < v` with binary search or the quadratic formula.)
- Produce the **counter-clockwise** spiral, or one that starts in the center (the Ulam spiral), using the same ring idea.
- Simulation version: print a full `n x n` spiral with four boundaries `top/bottom/left/right`. Why does it need the checks `if (top <= bottom)` and `if (left <= right)` inside the loop?
