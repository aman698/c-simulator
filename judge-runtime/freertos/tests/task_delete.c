/* Task deletion: self-delete, delete by another task, delete before the task ever ran,
 * 300 create/delete cycles. The heap must come back to the same value. */
#include <stdint.h>
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"

static unsigned runs;

static void once(void *p)
{
    (void)p;
    runs++;
    vTaskDelete(NULL);
}

static void forever(void *p)
{
    (void)p;
    for (;;) vTaskDelay(1000);
}

static void manager(void *p)
{
    size_t before;
    TaskHandle_t h;
    int i;
    (void)p;
    vTaskDelay(1);
    before = xPortGetFreeHeapSize();
    for (i = 0; i < 100; i++) {          /* lower priority: deleted before it ever runs */
        xTaskCreate(forever, "f", 256, NULL, 1, &h);
        vTaskDelete(h);
    }
    for (i = 0; i < 40; i++) {           /* higher priority: runs and deletes itself at once */
        xTaskCreate(once, "o", 256, NULL, 4, NULL);
    }
    for (i = 0; i < 100; i++) {          /* runs, blocks, then deleted by us */
        xTaskCreate(forever, "f", 256, NULL, 4, &h);
        vTaskDelete(h);
    }
    vTaskDelay(5);                       /* idle task frees the TCBs of self-deleted tasks */
    printf("[t=%u] self-deleted runs=%u heap delta=%d\n", (unsigned)xTaskGetTickCount(), runs,
           (int)before - (int)xPortGetFreeHeapSize());
    vTaskDelete(NULL);
}

int main(void)
{
    xTaskCreate(manager, "m", 256, NULL, 3, NULL);
    vSimSetTickLimit(50);
    vTaskStartScheduler();
    printf("end t=%u\n", (unsigned)xTaskGetTickCount());
    return 0;
}
