#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "sim.h"

static QueueHandle_t q;
static void isr(void *a)
{
    int v = 1;
    (void)a;
    xQueueSend(q, &v, 0); /* wrong: must be xQueueSendFromISR */
}
static void idle_task(void *p)
{
    (void)p;
    for (;;) vTaskDelay(100);
}
int main(void)
{
    q = xQueueCreate(2, sizeof(int));
    xTaskCreate(idle_task, "t", 256, NULL, 1, NULL);
    xSimScheduleInterrupt(3, isr, NULL);
    vTaskStartScheduler();
    return 0;
}
