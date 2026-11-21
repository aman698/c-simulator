/* Time never passes the limit: work the CPU reaches at tick N runs, a busy task at N ends the run. */
#include <stdint.h>
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static void hi(void *p)
{
    (void)p;
    for (;;) {
        vTaskDelay(10);
        printf("[t=%u] hi\n", (unsigned)xTaskGetTickCount());
    }
}

static void busy(void *p)
{
    (void)p;
    vTaskDelay(18);
    printf("[t=%u] busy start\n", (unsigned)xTaskGetTickCount());
    vSimBusyWork(5);
    printf("never printed\n");
    vTaskDelete(NULL);
}

static void lo(void *p)
{
    (void)p;
    vTaskDelay(20);
    printf("never printed (CPU busy at the limit)\n");
    vTaskDelete(NULL);
}

int main(void)
{
    xTaskCreate(hi, "hi", 256, NULL, 3, NULL);
    xTaskCreate(busy, "busy", 256, NULL, 2, NULL);
    xTaskCreate(lo, "lo", 256, NULL, 1, NULL);
    vSimSetTickLimit(20);
    vTaskStartScheduler();
    printf("end t=%u\n", (unsigned)xTaskGetTickCount());
    return 0;
}
