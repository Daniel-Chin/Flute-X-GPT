#ifndef FILE_circular_queue_with_time_SEEN
#define FILE_circular_queue_with_time_SEEN

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "circular_queue.h"
#include "time_keep.h"

// Avoid using this macro in callers. Abbr. can be confusing.  
#define CQT CircularQueueWithTime

typedef void (* cqtCallback_t)(
    microsec_t*, uint8_t*
);

typedef struct CircularQueueWithTime {
    CircularQueue* cq;
    size_t ELEMENT_SIZE_EXCLUDING_TIME;
    cqtCallback_t CALLBACK;

    TaskHandle_t task;
} CircularQueueWithTime;

void cqt_init(
  CQT* this,
  char* name, size_t element_size_excluding_time, 
  size_t n_elements, cqtCallback_t callback
);
void cqt_free(CQT* this);
void cqt_push(CQT* this, microsec_t* time, uint8_t* element);
void cqt_service(void* args);

#endif
