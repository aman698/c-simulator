/* A task that never blocks stops simulated time: the judge reports Time Limit Exceeded. */
#include "FreeRTOS.h"
#include "task.h"

static volatile unsigned spins;
static void t(void *p)
{
    (void)p;
    for (;;) spins++;
}
int main(void)
{
    xTaskCreate(t, "t", 256, NULL, 1, NULL);
    vTaskStartScheduler();
    return 0;
}
