/*
 * FreeRTOSConfig.h - fixed kernel configuration used by the judge for every
 * FreeRTOS question (deterministic virtual-time simulator port).
 *
 *  - 1 tick = 1 ms (configTICK_RATE_HZ 1000), priorities 0..7, preemption + time slicing
 *  - heap_4 with 128 KB, static and dynamic allocation
 *  - queues, mutexes (+recursive), counting semaphores, queue sets, event groups,
 *    task notifications (3 per task), stream/message buffers, software timers
 *  - the timer service task runs at priority 7 (configMAX_PRIORITIES - 1)
 *
 * Do not edit: question harnesses and expected outputs depend on these values.
 */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#define configUSE_PREEMPTION                     1
#define configUSE_TIME_SLICING                   1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION  0
#define configUSE_TICKLESS_IDLE                  0
#define configCPU_CLOCK_HZ                       ( 100000000UL )
#define configTICK_RATE_HZ                       1000
#define configMAX_PRIORITIES                     8
#define configMINIMAL_STACK_SIZE                 256
#define configMAX_TASK_NAME_LEN                  16
#define configTICK_TYPE_WIDTH_IN_BITS            TICK_TYPE_WIDTH_32_BITS
#define configIDLE_SHOULD_YIELD                  1
#define configTASK_NOTIFICATION_ARRAY_ENTRIES    3
#define configQUEUE_REGISTRY_SIZE                0
#define configENABLE_BACKWARD_COMPATIBILITY      0
#define configNUM_THREAD_LOCAL_STORAGE_POINTERS  2
#define configUSE_MINI_LIST_ITEM                 1
#define configSTACK_DEPTH_TYPE                   uint32_t
#define configMESSAGE_BUFFER_LENGTH_TYPE         size_t
#define configHEAP_CLEAR_MEMORY_ON_FREE          0
#define configUSE_NEWLIB_REENTRANT               0
#define configNUMBER_OF_CORES                    1

/* Memory */
#define configSUPPORT_STATIC_ALLOCATION          1
#define configSUPPORT_DYNAMIC_ALLOCATION         1
#define configKERNEL_PROVIDED_STATIC_MEMORY      1
#define configTOTAL_HEAP_SIZE                    ( ( size_t ) ( 128 * 1024 ) )
#define configAPPLICATION_ALLOCATED_HEAP         0

/* Hooks: the idle hook and malloc-failed hook are provided by the simulator (sim.c). */
#define configUSE_IDLE_HOOK                      1
#define configUSE_TICK_HOOK                      0
#define configCHECK_FOR_STACK_OVERFLOW           0
#define configUSE_MALLOC_FAILED_HOOK             1
#define configUSE_DAEMON_TASK_STARTUP_HOOK       0
#define configUSE_SB_COMPLETED_CALLBACK          0

/* Run-time stats / trace */
#define configGENERATE_RUN_TIME_STATS            0
#define configUSE_TRACE_FACILITY                 1
#define configUSE_STATS_FORMATTING_FUNCTIONS     0

/* Features */
#define configUSE_CO_ROUTINES                    0
#define configUSE_TIMERS                         1
#define configTIMER_TASK_PRIORITY                ( configMAX_PRIORITIES - 1 )
#define configTIMER_QUEUE_LENGTH                 16
#define configTIMER_TASK_STACK_DEPTH             ( configMINIMAL_STACK_SIZE * 2 )
#define configUSE_MUTEXES                        1
#define configUSE_RECURSIVE_MUTEXES              1
#define configUSE_COUNTING_SEMAPHORES            1
#define configUSE_QUEUE_SETS                     1
#define configUSE_TASK_NOTIFICATIONS             1
#define configUSE_EVENT_GROUPS                   1
#define configUSE_STREAM_BUFFERS                 1
#define configUSE_APPLICATION_TASK_TAG           0
#define configUSE_POSIX_ERRNO                    0

/* API inclusion */
#define INCLUDE_vTaskPrioritySet                 1
#define INCLUDE_uxTaskPriorityGet                1
#define INCLUDE_vTaskDelete                      1
#define INCLUDE_vTaskSuspend                     1
#define INCLUDE_xResumeFromISR                   1
#define INCLUDE_xTaskDelayUntil                  1
#define INCLUDE_vTaskDelay                       1
#define INCLUDE_xTaskGetSchedulerState           1
#define INCLUDE_xTaskGetCurrentTaskHandle        1
#define INCLUDE_uxTaskGetStackHighWaterMark      1
#define INCLUDE_xTaskGetIdleTaskHandle           1
#define INCLUDE_eTaskGetState                    1
#define INCLUDE_xEventGroupSetBitFromISR         1
#define INCLUDE_xTimerPendFunctionCall           1
#define INCLUDE_xTaskAbortDelay                  1
#define INCLUDE_xTaskGetHandle                   1
#define INCLUDE_xTaskResumeFromISR               1
#define INCLUDE_xSemaphoreGetMutexHolder         1

/* Kernel assertions abort the program with a readable message (Runtime Error in the judge). */
void vSimAssertFailed( const char * pcExpr, const char * pcFile, int iLine );
#define configASSERT( x )    do { if( !( x ) ) vSimAssertFailed( #x, __FILE__, __LINE__ ); } while( 0 )

#endif /* FREERTOS_CONFIG_H */
