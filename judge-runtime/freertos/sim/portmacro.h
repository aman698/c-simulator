/*
 * portmacro.h - deterministic virtual-time simulator port (C Practice Simulator).
 *
 * Every FreeRTOS task runs on its own host thread, but exactly ONE thread runs at
 * a time and control is handed over only at kernel scheduling points, so a run is
 * fully deterministic. Code executes in zero simulated time: the tick count only
 * advances when every application task is blocked (from the idle task), and
 * simulated interrupts fire at exact ticks (see sim.h).
 *
 * Types are fixed-width so that sizes are identical on Linux and Windows.
 */
#ifndef PORTMACRO_H
#define PORTMACRO_H

#include <stdint.h>
#include <stddef.h>

#define portCHAR          char
#define portFLOAT         float
#define portDOUBLE        double
#define portLONG          int32_t
#define portSHORT         int16_t
#define portSTACK_TYPE    uint64_t
#define portBASE_TYPE     int64_t

typedef portSTACK_TYPE   StackType_t;
typedef int64_t          BaseType_t;
typedef uint64_t         UBaseType_t;

#if ( configTICK_TYPE_WIDTH_IN_BITS == TICK_TYPE_WIDTH_32_BITS )
    typedef uint32_t     TickType_t;
    #define portMAX_DELAY              ( TickType_t ) 0xffffffffUL
    #define portTICK_TYPE_IS_ATOMIC    1
#else
    #error "The simulator port expects 32-bit ticks"
#endif

#define portSTACK_GROWTH          ( -1 )
#define portTICK_PERIOD_MS        ( ( TickType_t ) 1000 / configTICK_RATE_HZ )
#define portBYTE_ALIGNMENT        16
#define portPOINTER_SIZE_TYPE     uintptr_t
#define portNOP()

/* ---- scheduling -------------------------------------------------------- */
void vPortYield( void );
void vPortYieldFromISR( BaseType_t xSwitchRequired );
#define portYIELD()                                   vPortYield()
#define portEND_SWITCHING_ISR( xSwitchRequired )      vPortYieldFromISR( ( BaseType_t ) ( xSwitchRequired ) )
#define portYIELD_FROM_ISR( x )                       portEND_SWITCHING_ISR( x )

/* ---- interrupt masking / critical sections ---------------------------- */
void vPortDisableInterrupts( void );
void vPortEnableInterrupts( void );
void vPortEnterCritical( void );
void vPortExitCritical( void );
UBaseType_t uxPortSetInterruptMask( void );
void vPortClearInterruptMask( UBaseType_t uxMask );
BaseType_t xPortIsInsideInterrupt( void );

#define portDISABLE_INTERRUPTS()                      vPortDisableInterrupts()
#define portENABLE_INTERRUPTS()                       vPortEnableInterrupts()
#define portENTER_CRITICAL()                          vPortEnterCritical()
#define portEXIT_CRITICAL()                           vPortExitCritical()
#define portSET_INTERRUPT_MASK_FROM_ISR()             uxPortSetInterruptMask()
#define portCLEAR_INTERRUPT_MASK_FROM_ISR( x )        vPortClearInterruptMask( x )

/* Blocking (non-FromISR) APIs must never be called from an ISR. */
#define portASSERT_IF_IN_ISR()                        configASSERT( xPortIsInsideInterrupt() == 0 )

/* ---- task functions / lifecycle ---------------------------------------- */
#define portTASK_FUNCTION_PROTO( vFunction, pvParameters )    void vFunction( void * pvParameters )
#define portTASK_FUNCTION( vFunction, pvParameters )          void vFunction( void * pvParameters )

void vPortCleanUpTCB( void * pxTCB );
#define portCLEAN_UP_TCB( pxTCB )                     vPortCleanUpTCB( pxTCB )

#endif /* PORTMACRO_H */
