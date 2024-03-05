#ifndef FILE_shared_SEEN
#define FILE_shared_SEEN

#include <string.h>
#include <stdint.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#ifndef portTICK_RATE_MS
#define portTICK_RATE_MS portTICK_PERIOD_MS
// I don't understand this issue.  
#endif

#define FORCE_CLOCK_MONOTONOUS 1
#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))
#define MAX(X, Y) (((X) > (Y)) ? (X) : (Y))

#ifndef configTASK_NOTIFICATION_ARRAY_ENTRIES
    I am using syntax error to denote undefined macro here!
#endif
#if configTASK_NOTIFICATION_ARRAY_ENTRIES == 1
    // esp32 only has 1
    #define TASK_NOTIFICATION_INDEX 0
#else
    #define TASK_NOTIFICATION_INDEX 1
#endif

extern char const * PROJECT_TAG;

// inline int64_t parseUInt63(
//     uint8_t* buffer
// ) {
//     // parse 8 bytes in buffer into int64_t.  
//     // big endian.  
//     // the sign bit is assumed to be +, hence the name "UInt63".  
//     return (
//         ((int64_t) *(buffer++)) << 56 + 
//         ((int64_t) *(buffer++)) << 48 + 
//         ((int64_t) *(buffer++)) << 40 + 
//         ((int64_t) *(buffer++)) << 32 + 
//         ((int64_t) *(buffer++)) << 24 + 
//         ((int64_t) *(buffer++)) << 16 + 
//         ((int64_t) *(buffer++)) <<  8 + 
//         ((int64_t) *(buffer++))
//     );
// }

void delayTaskMs(int ms);

#endif
