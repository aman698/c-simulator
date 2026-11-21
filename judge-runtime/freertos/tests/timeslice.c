/* Equal priorities are time-sliced one tick at a time inside vSimBusyWork(). */
#include <stdint.h>
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static void worker(void *p)
{
    const char *name = (const char *)p;
    for (;;) {
        printf("[t=%u] %s start\n", (unsigned)xTaskGetTickCount(), name);
        vSimBusyWork(3);
        printf("[t=%u] %s done\n", (unsigned)xTaskGetTickCount(), name);
        vTaskDelay(100);
    }
}

int main(void)
{
    xTaskCreate(worker, "A", 256, "A", 2, NULL);
    xTaskCreate(worker, "B", 256, "B", 2, NULL);
    vSimSetTickLimit(20);
    vTaskStartScheduler();
    printf("end\n");
    return 0;
}
