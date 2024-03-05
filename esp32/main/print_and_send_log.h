#ifndef FILE_print_and_send_log_SEEN
#define FILE_print_and_send_log_SEEN

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

typedef enum {
    INFO = (int) 'I', 
    WARNING = (int) 'W', 
    ERROR = (int) 'E', 
    // respecting char type range for comm
} LogLevel;

// typedef enum {
//     RECVFROM_FAILED, 
//     COMMSEND_WHEN_UNREADY,
//     SENDTO_ERROR, 
// } ExceptionCode;

// void bufferExceptionForLater(ExceptionCode code, int param);
void printAndSendInfo(const char* msg);
void printAndSendError(const char* msg);
void printAndSendWarning(const char* msg);
void printWaitAndSendError(SemaphoreHandle_t waitSemaphore, const char* msg);

#endif
