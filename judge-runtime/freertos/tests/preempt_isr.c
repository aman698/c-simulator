/* Preemption by priority, vTaskDelayUntil, ISR -> queue -> task with portYIELD_FROM_ISR. */
#include <stdint.h>
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static QueueHandle_t q;

static void isr(void *a)
{
    BaseType_t w = pdFALSE;
    int v = (int)(intptr_t)a;
    xQueueSendFromISR(q, &v, &w);
    portYIELD_FROM_ISR(w);
}

static void cons(void *p)
{
    int v;
    (void)p;
    for (;;) {
        xQueueReceive(q, &v, portMAX_DELAY);
        printf("[t=%u] got %d\n", (unsigned)xTaskGetTickCount(), v);
    }
}

static void per(void *p)
{
    TickType_t l = xTaskGetTickCount();
    (void)p;
    for (;;) {
        vTaskDelayUntil(&l, 10);
        printf("[t=%u] tick\n", (unsigned)xTaskGetTickCount());
        vSimBusyWork(3);
    }
}

static void lo(void *p)
{
    (void)p;
    for (;;) {
        vSimBusyWork(5);
        printf("[t=%u] lo\n", (unsigned)xTaskGetTickCount());
        vTaskDelay(7);
    }
}

int main(void)
{
    q = xQueueCreate(4, sizeof(int));
    xTaskCreate(cons, "c", 256, NULL, 3, NULL);
    xTaskCreate(per, "p", 256, NULL, 2, NULL);
    xTaskCreate(lo, "l", 256, NULL, 1, NULL);
    xSimScheduleInterrupt(5, isr, (void *)7);
    xSimScheduleInterrupt(12, isr, (void *)9);
    vSimSetTickLimit(40);
    vTaskStartScheduler();
    printf("done t=%u\n", (unsigned)xTaskGetTickCount());
    return 0;
}
