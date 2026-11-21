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

/* Simulated time never passes xLimit (default 10000): vTaskStartScheduler()
 * returns to main() at the first moment the tick count would advance beyond it,
 * i.e. when every task is blocked at tick xLimit, or when a task is still inside
 * vSimBusyWork() at tick xLimit. Work that the CPU reaches at tick xLimit runs;
 * work that is still waiting for the CPU then does not. Only non-blocking FreeRTOS
 * calls are allowed in main() after that. */
void vSimSetTickLimit( TickType_t xLimit );

/* Simulated peripheral interrupt: pxHandler( pvArg ) runs in interrupt context
 * right after the tick count becomes xTick (xTick >= 1). Handlers must use the
 * ...FromISR() APIs and request a context switch with portYIELD_FROM_ISR().
 * Several interrupts at the same tick run in the order they were scheduled.
 * May also be called from tasks/ISRs while the scheduler runs, for a future tick.
 * Misuse (NULL handler, tick 0, a tick that is not in the future, more than 4096
 * interrupts) is a fatal Runtime Error. Returns pdPASS. */
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
