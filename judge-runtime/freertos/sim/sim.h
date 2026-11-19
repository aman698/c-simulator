/*
 * sim.h - control API of the judge's FreeRTOS simulator (used by hidden harnesses).
 *
 * Virtual time: tasks execute in zero simulated time. The tick count advances
 * (1 tick = 1 ms) only when every application task is blocked, so a run is
 * deterministic and vTaskDelay(1000) finishes instantly in wall-clock time.
 * A task that never blocks starves the idle task: time stops and the test hits
 * the time limit.
 */
#ifndef SIM_H
#define SIM_H

#include "FreeRTOS.h"

/* vTaskStartScheduler() returns to main() once the tick count reaches xLimit
 * (default 10000). Only non-blocking FreeRTOS calls are allowed after that. */
void vSimSetTickLimit( TickType_t xLimit );

/* Simulated peripheral interrupt: pxHandler( pvArg ) runs in interrupt context
 * right after the tick count becomes xTick (xTick >= 1). Handlers must use the
 * ...FromISR() APIs and request a context switch with portYIELD_FROM_ISR().
 * Several interrupts at the same tick run in the order they were scheduled.
 * Returns pdFAIL if the interrupt table (4096 entries) is full or xTick is 0. */
typedef void ( * SimIsrHandler_t )( void * pvArg );
BaseType_t xSimScheduleInterrupt( TickType_t xTick, SimIsrHandler_t pxHandler, void * pvArg );

/* Simulate CPU-bound work that takes xTicks ms in the calling task. Tick and
 * peripheral interrupts keep firing while it runs, so higher-priority tasks
 * preempt it and equal-priority tasks are time-sliced (one tick each), exactly
 * as on a real MCU. Ordinary code runs in zero simulated time. Not for ISRs. */
void vSimBusyWork( TickType_t xTicks );

/* Optional callback for vApplicationMallocFailedHook (pvPortMalloc returned NULL). */
void vSimSetMallocFailedHandler( void ( * pxHandler )( void ) );

#endif /* SIM_H */
