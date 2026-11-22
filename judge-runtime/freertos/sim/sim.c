/*
 * sim.c - virtual time, simulated interrupts and diagnostics for the judge's
 * FreeRTOS simulator port. The judge recognises "==FREERTOS==" on stderr.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"
#include "sim.h"
#include "sim_internal.h"

#define SIM_MAX_INTERRUPTS    4096
#define SIM_EXIT_CODE         70

typedef struct
{
    TickType_t xTick;
    SimIsrHandler_t pxHandler;
    void * pvArg;
} SimEvent_t;

static SimEvent_t xEvents[ SIM_MAX_INTERRUPTS ];
static size_t uxEventCount = 0;
static size_t uxNextEvent = 0;
static TickType_t xTickLimit = 10000;

/* Hardware time: advanced once per simulated tick interrupt, even while the
 * scheduler is suspended (vTaskSuspendAll), when the kernel only pends ticks and
 * xTaskGetTickCount() lags behind. Interrupts and the tick limit follow this
 * clock, like a real timer peripheral. Outside scheduler suspension it always
 * equals the tick count. */
static TickType_t xSimTime = 0;
static void ( * pxMallocFailedHandler )( void ) = NULL;

void vSimSetTickLimit( TickType_t xLimit )
{
    xTickLimit = xLimit;
}

BaseType_t xSimScheduleInterrupt( TickType_t xTick, SimIsrHandler_t pxHandler, void * pvArg )
{
    char cMessage[ 200 ];
    size_t i;

    /* Harness bugs must not pass silently: every misuse is a readable fatal error. */
    if( pxHandler == NULL )
    {
        vSimFatal( "xSimScheduleInterrupt(): the handler is NULL" );
    }

    if( xTick == 0 )
    {
        vSimFatal( "xSimScheduleInterrupt(): tick 0 is not allowed, the first interrupt tick is 1" );
    }

    if( ( xTaskGetSchedulerState() != taskSCHEDULER_NOT_STARTED ) && ( xTick <= xSimTime ) )
    {
        snprintf( cMessage, sizeof( cMessage ),
                  "xSimScheduleInterrupt(): tick %u is not in the future (the tick count is already %u)",
                  ( unsigned ) xTick, ( unsigned ) xSimTime );
        vSimFatal( cMessage );
    }

    if( uxEventCount >= SIM_MAX_INTERRUPTS )
    {
        vSimFatal( "xSimScheduleInterrupt(): more than 4096 interrupts scheduled" );
    }

    /* keep the table sorted by tick, FIFO among equal ticks (stable insertion) */
    i = uxEventCount;
    while( ( i > uxNextEvent ) && ( xEvents[ i - 1 ].xTick > xTick ) )
    {
        xEvents[ i ] = xEvents[ i - 1 ];
        i--;
    }

    xEvents[ i ].xTick = xTick;
    xEvents[ i ].pxHandler = pxHandler;
    xEvents[ i ].pvArg = pvArg;
    uxEventCount++;
    return pdPASS;
}

void vSimRunInterrupts( void )
{
    xSimTime++;

    /* every tick is visited once, so "<=" only matters defensively */
    while( ( uxNextEvent < uxEventCount ) && ( xEvents[ uxNextEvent ].xTick <= xSimTime ) )
    {
        SimEvent_t xEv = xEvents[ uxNextEvent++ ];
        xEv.pxHandler( xEv.pvArg );
    }
}

/* The idle task runs only when every other task is blocked: that is exactly
 * when simulated time may advance by one tick. */
void vApplicationIdleHook( void )
{
    if( xSimTime >= xTickLimit )
    {
        vPortSimEnd();
    }

    vPortSimTick();
}

void vSimBusyWork( TickType_t xTicks )
{
    while( xTicks-- > 0 )
    {
        if( xSimTime >= xTickLimit )
        {
            vPortSimEnd();
        }

        vPortSimTick();
    }
}

void vSimSetMallocFailedHandler( void ( * pxHandler )( void ) )
{
    pxMallocFailedHandler = pxHandler;
}

void vApplicationMallocFailedHook( void )
{
    if( pxMallocFailedHandler != NULL )
    {
        pxMallocFailedHandler();
    }
}

static const char * prvBaseName( const char * pcPath )
{
    const char * pcSlash = strrchr( pcPath, '/' );
    const char * pcBack = strrchr( pcPath, '\\' );

    if( ( pcBack != NULL ) && ( ( pcSlash == NULL ) || ( pcBack > pcSlash ) ) )
    {
        pcSlash = pcBack;
    }

    return ( pcSlash != NULL ) ? pcSlash + 1 : pcPath;
}

void vSimAssertFailed( const char * pcExpr, const char * pcFile, int iLine )
{
    fflush( stdout );
    fprintf( stderr, "==FREERTOS== configASSERT failed: %s (%s:%d)\n", pcExpr, prvBaseName( pcFile ), iLine );
    fflush( stderr );
    _Exit( SIM_EXIT_CODE );
}

void vSimFatal( const char * pcMessage )
{
    fflush( stdout );
    fprintf( stderr, "==FREERTOS== %s\n", pcMessage );
    fflush( stderr );
    _Exit( SIM_EXIT_CODE );
}
