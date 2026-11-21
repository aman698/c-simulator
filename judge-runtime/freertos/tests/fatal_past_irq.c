#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static void isr(void *a) { (void)a; }
static void t(void *p)
{
    (void)p;
    vTaskDelay(5);
    xSimScheduleInterrupt(5, isr, NULL); /* tick 5 is now, not the future */
    for (;;) vTaskDelay(100);
}
int main(void)
{
    xTaskCreate(t, "t", 256, NULL, 1, NULL);
    vTaskStartScheduler();
    return 0;
}
