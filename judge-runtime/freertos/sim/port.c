/*
 * port.c - deterministic virtual-time FreeRTOS port for the judge.
 *
 * Model
 *  - Each task runs on its own host thread (pthreads; winpthreads on MinGW).
 *  - Exactly one thread owns the "CPU" at any moment; ownership is handed over
 *    with a mutex + per-thread condition variable only when the kernel switches
 *    context, so the interleaving is identical on every run and every platform.
 *  - A yield requested inside a critical section / with interrupts masked / from
 *    an ISR is held pending and performed when it becomes legal (like PendSV).
 *  - Time is virtual: the idle task advances the tick (sim.c), so code takes
 *    zero simulated time and delays complete instantly in wall-clock time.
 */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "FreeRTOS.h"
#include "task.h"
#include "sim_internal.h"

#define SIM_THREAD_STACK_BYTES    ( 512u * 1024u )

typedef struct SimThread
{
    pthread_t xThread;
    pthread_cond_t xCond;
    int iRun;          /* 1 while this thread owns the CPU */
    int iExit;         /* 1 when the task was deleted: the thread parks forever */
    TaskFunction_t pxCode;
    void * pvParams;
} SimThread_t;

static pthread_mutex_t xLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t xMainCond = PTHREAD_COND_INITIALIZER;
static volatile int iSchedulerStarted = 0;
static volatile int iSchedulerEnded = 0;
static UBaseType_t uxCriticalNesting = 0;
static int iInterruptsMasked = 0;
static int iInISR = 0;
static int iYieldPending = 0;

/* The TCB's first member is pxTopOfStack; the slot it points to holds our SimThread_t*. */
static SimThread_t * prvThreadOf( TaskHandle_t xTask )
{
    StackType_t * pxTop = *( StackType_t ** ) xTask;
    return ( SimThread_t * ) ( uintptr_t ) *pxTop;
}

static void * prvThreadMain( void * pvArg )
{
    SimThread_t * pxThread = ( SimThread_t * ) pvArg;
    int iExit;

    pthread_mutex_lock( &xLock );
    while( !pxThread->iRun && !pxThread->iExit )
    {
        pthread_cond_wait( &pxThread->xCond, &xLock );
    }
    iExit = pxThread->iExit;

    while( iExit ) /* deleted before it ever ran: park (see prvParkForever) */
    {
        pthread_cond_wait( &pxThread->xCond, &xLock );
    }

    pthread_mutex_unlock( &xLock );

    pxThread->pxCode( pxThread->pvParams );

    /* Real ports trap here too (prvTaskExitError). */
    vSimFatal( "a task function returned. FreeRTOS tasks must never return: loop forever or call vTaskDelete( NULL )" );
    return NULL;
}

StackType_t * pxPortInitialiseStack( StackType_t * pxTopOfStack,
                                     TaskFunction_t pxCode,
                                     void * pvParameters )
{
    pthread_attr_t xAttr;
    SimThread_t * pxThread = ( SimThread_t * ) calloc( 1, sizeof( SimThread_t ) );

    if( pxThread == NULL )
    {
        vSimFatal( "host out of memory while creating a task thread" );
    }

    pxThread->pxCode = pxCode;
    pxThread->pvParams = pvParameters;
    pthread_cond_init( &pxThread->xCond, NULL );
    pthread_attr_init( &xAttr );
    pthread_attr_setstacksize( &xAttr, SIM_THREAD_STACK_BYTES );

    if( pthread_create( &pxThread->xThread, &xAttr, prvThreadMain, pxThread ) != 0 )
    {
        vSimFatal( "could not create a host thread for a task" );
    }

    pthread_attr_destroy( &xAttr );
    *pxTopOfStack = ( StackType_t ) ( uintptr_t ) pxThread;
    return pxTopOfStack;
}

/* A deleted task's host thread never runs again. It is parked instead of being
 * terminated: pthread_exit() from inside a blocked call breaks AddressSanitizer's
 * thread teardown. Parked threads cost only virtual memory and end with the process. */
static void prvParkForever( SimThread_t * pxThread )
{
    pthread_mutex_lock( &xLock );

    for( ; ; )
    {
        pthread_cond_wait( &pxThread->xCond, &xLock );
    }
}

/* Hand the CPU from pxPrev to whatever task the kernel selected as current. */
static void prvSwitchFrom( SimThread_t * pxPrev )
{
    SimThread_t * pxNext = prvThreadOf( xTaskGetCurrentTaskHandle() );
    int iExit;

    if( pxNext == pxPrev )
    {
        return;
    }

    pthread_mutex_lock( &xLock );
    pxPrev->iRun = 0;
    pxNext->iRun = 1;
    pthread_cond_signal( &pxNext->xCond );

    while( !pxPrev->iRun && !pxPrev->iExit )
    {
        pthread_cond_wait( &pxPrev->xCond, &xLock );
    }

    iExit = pxPrev->iExit;
    pthread_mutex_unlock( &xLock );

    if( iExit )
    {
        prvParkForever( pxPrev );
    }
}

static void prvContextSwitch( void )
{
    SimThread_t * pxPrev = prvThreadOf( xTaskGetCurrentTaskHandle() );

    vTaskSwitchContext();
    prvSwitchFrom( pxPrev );
}

void vPortYield( void )
{
    if( !iSchedulerStarted || iSchedulerEnded )
    {
        return;
    }

    if( iInISR )
    {
        vSimFatal( "a blocking FreeRTOS API (one without the FromISR suffix) was called from an interrupt handler" );
    }

    if( ( uxCriticalNesting > 0 ) || iInterruptsMasked )
    {
        iYieldPending = 1; /* performed when the critical section ends, like PendSV */
        return;
    }

    iYieldPending = 0;
    prvContextSwitch();
}

void vPortYieldFromISR( BaseType_t xSwitchRequired )
{
    if( xSwitchRequired == pdFALSE )
    {
        return;
    }

    if( iInISR )
    {
        iYieldPending = 1; /* switch happens when the simulated interrupt returns */
    }
    else
    {
        vPortYield();
    }
}

static void prvRunPendingYield( void )
{
    if( iYieldPending && ( uxCriticalNesting == 0 ) && !iInterruptsMasked && !iInISR && iSchedulerStarted && !iSchedulerEnded )
    {
        iYieldPending = 0;
        prvContextSwitch();
    }
}

void vPortEnterCritical( void )
{
    uxCriticalNesting++;
}

void vPortExitCritical( void )
{
    if( uxCriticalNesting == 0 )
    {
        vSimFatal( "taskEXIT_CRITICAL() called without a matching taskENTER_CRITICAL()" );
    }

    uxCriticalNesting--;
    prvRunPendingYield();
}

void vPortDisableInterrupts( void )
{
    iInterruptsMasked = 1;
}

void vPortEnableInterrupts( void )
{
    iInterruptsMasked = 0;
    prvRunPendingYield();
}

UBaseType_t uxPortSetInterruptMask( void )
{
    UBaseType_t uxOld = ( UBaseType_t ) iInterruptsMasked;

    iInterruptsMasked = 1;
    return uxOld;
}

void vPortClearInterruptMask( UBaseType_t uxMask )
{
    iInterruptsMasked = ( int ) uxMask;
    prvRunPendingYield(); /* a pended switch fires once interrupts are unmasked (task context only) */
}

BaseType_t xPortIsInsideInterrupt( void )
{
    return ( BaseType_t ) iInISR;
}

void vSimCheckNotInISR( const char * pcApi )
{
    char cMessage[ 200 ];

    if( iInISR )
    {
        snprintf( cMessage, sizeof( cMessage ),
                  "%s() was called from an interrupt handler. Use the ...FromISR() version and portYIELD_FROM_ISR()", pcApi );
        vSimFatal( cMessage );
    }
}

/* One tick interrupt plus any simulated peripheral interrupts scheduled for the
 * new tick value. Called by the idle task (time passes while the CPU is idle) and
 * by vSimBusyWork() (time passes while a task computes, so it can be preempted
 * or time-sliced exactly like on real hardware). */
void vPortSimTick( void )
{
    BaseType_t xSwitch;

    if( iInISR )
    {
        vSimFatal( "vSimBusyWork() cannot be used inside an interrupt handler" );
    }

    if( ( uxCriticalNesting > 0 ) || iInterruptsMasked )
    {
        vSimFatal( "vSimBusyWork() inside a critical section / with interrupts disabled: the tick interrupt is masked there, keep critical sections short" );
    }

    iInISR = 1;
    xSwitch = xTaskIncrementTick();
    vSimRunInterrupts();
    iInISR = 0;

    if( xSwitch != pdFALSE )
    {
        iYieldPending = 1;
    }

    prvRunPendingYield(); /* deferred if the task is inside a critical section */
}

BaseType_t xPortStartScheduler( void )
{
    SimThread_t * pxFirst = prvThreadOf( xTaskGetCurrentTaskHandle() );

    uxCriticalNesting = 0;
    iInterruptsMasked = 0;
    iSchedulerStarted = 1;

    pthread_mutex_lock( &xLock );
    pxFirst->iRun = 1;
    pthread_cond_signal( &pxFirst->xCond );

    while( !iSchedulerEnded )
    {
        pthread_cond_wait( &xMainCond, &xLock );
    }

    pthread_mutex_unlock( &xLock );
    return pdFALSE; /* vTaskStartScheduler() returns to main() */
}

/* End of simulation: wake main() (returning from vTaskStartScheduler) and park
 * the calling task thread forever. */
void vPortSimEnd( void )
{
    SimThread_t * pxSelf = prvThreadOf( xTaskGetCurrentTaskHandle() );

    fflush( stdout );
    pthread_mutex_lock( &xLock );
    iSchedulerEnded = 1;
    pxSelf->iRun = 0;
    pthread_cond_signal( &xMainCond );

    pthread_mutex_unlock( &xLock );
    prvParkForever( pxSelf ); /* main() returns and the process exits */
}

void vPortEndScheduler( void )
{
    vPortSimEnd();
}

/* The kernel frees a deleted task's TCB. Its host thread is (or will be) parked in
 * prvSwitchFrom(); mark it so it never takes the CPU again. The SimThread_t stays
 * allocated because the parked thread still uses its condition variable. */
void vPortCleanUpTCB( void * pxTCB )
{
    SimThread_t * pxThread = prvThreadOf( ( TaskHandle_t ) pxTCB );

    pthread_mutex_lock( &xLock );
    pxThread->iExit = 1;
    pthread_cond_signal( &pxThread->xCond );
    pthread_mutex_unlock( &xLock );
}
