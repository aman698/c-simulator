/* Internal glue between port.c and sim.c (not for question code). */
#ifndef SIM_INTERNAL_H
#define SIM_INTERNAL_H

#include "FreeRTOS.h"

void vPortSimTick( void );
void vPortSimEnd( void );
void vSimRunInterrupts( TickType_t xNow );
void vSimFatal( const char * pcMessage );

#endif
