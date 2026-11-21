#include "FreeRTOS.h"
#include "task.h"

static void t(void *p) { (void)p; }
int main(void)
{
    xTaskCreate(t, "t", 256, NULL, 1, NULL);
    vTaskStartScheduler();
    return 0;
}
