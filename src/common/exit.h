/***********************************************************************************************************************************
Exit Routines
***********************************************************************************************************************************/
#ifndef COMMON_EXIT_H
#define COMMON_EXIT_H

#include <signal.h>

/***********************************************************************************************************************************
Signal type
***********************************************************************************************************************************/
typedef enum
{
    signalTypeNone = 0,
    signalTypeHup = SIGHUP,
    signalTypeInt = SIGINT,
    signalTypeTerm = SIGTERM,
} SignalType;

/***********************************************************************************************************************************
Functions
***********************************************************************************************************************************/
void exitInit(void);
int exitSafe(int result, bool error, SignalType signalType);

#endif
