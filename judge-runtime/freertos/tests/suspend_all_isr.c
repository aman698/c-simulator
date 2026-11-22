/* Interrupts keep firing while the scheduler is suspended (vTaskSuspendAll): the kernel only
 * pends the ticks, so xTaskGetTickCountFromISR() lags (1) until xTaskResumeAll() catches up.
 * Later interrupts must not be lost either. */
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static void isr(void *a) { (void)a; printf("isr at t=%u\n", (unsigned)xTaskGetTickCountFromISR()); }

static void t1(void *p)
{
    (void)p;
    vTaskDelay(1);
    vTaskSuspendAll();
    vSimBusyWork(5);           /* 5 ticks pass with the scheduler suspended */
    xTaskResumeAll();
    printf("resumed at t=%u\n", (unsigned)xTaskGetTickCount());
    for (;;) vTaskDelay(100);
}

int main(void)
{
    xTaskCreate(t1, "t1", 256, NULL, 2, NULL);
    xSimScheduleInterrupt(3, isr, NULL);
    xSimScheduleInterrupt(20, isr, NULL);
    vSimSetTickLimit(30);
    vTaskStartScheduler();
    printf("end t=%u\n", (unsigned)xTaskGetTickCount());
    return 0;
}
