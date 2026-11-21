/* Wake-up latency: with portYIELD_FROM_ISR the task runs at the ISR tick, without it at the next tick
 * (here a low-priority task is busy, so nothing else forces a context switch earlier). */
#include <stdint.h>
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "sim.h"

static SemaphoreHandle_t sem;

static void isr(void *a)
{
    BaseType_t w = pdFALSE;
    xSemaphoreGiveFromISR(sem, &w);
    if (a) portYIELD_FROM_ISR(w);
}

static void handler(void *p)
{
    (void)p;
    for (;;) {
        xSemaphoreTake(sem, portMAX_DELAY);
        printf("[t=%u] handled\n", (unsigned)xTaskGetTickCount());
    }
}

static void background(void *p)
{
    (void)p;
    for (;;) vSimBusyWork(1);
}

int main(void)
{
    sem = xSemaphoreCreateBinary();
    xTaskCreate(handler, "h", 256, NULL, 3, NULL);
    xTaskCreate(background, "bg", 256, NULL, 1, NULL);
    xSimScheduleInterrupt(5, isr, (void *)1);  /* yields */
    xSimScheduleInterrupt(10, isr, NULL);      /* forgets portYIELD_FROM_ISR */
    vSimSetTickLimit(15);
    vTaskStartScheduler();
    printf("end\n");
    return 0;
}
