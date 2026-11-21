#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static void t(void *p)
{
    (void)p;
    taskENTER_CRITICAL();
    vSimBusyWork(2);
    taskEXIT_CRITICAL();
    for (;;) vTaskDelay(100);
}
int main(void)
{
    xTaskCreate(t, "t", 256, NULL, 1, NULL);
    vTaskStartScheduler();
    return 0;
}
