#ifndef FILE_circular_queue_SEEN
#define FILE_circular_queue_SEEN

#include <inttypes.h>
#include <stdbool.h>

#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

/*
The owner of the CircularQueue is in charge of knowing the 
type of its elements.  
*/

typedef struct CircularQueue {
    char* NAME;
    size_t ELEMENT_SIZE;
    size_t N_ELEMENTS;
    size_t N_BYTES;
    bool IS_THREADSAFE;

    uint8_t* buffer;
    int push_i; // in terms of element index
    int pop_i;
    SemaphoreHandle_t sema;
} CircularQueue;

void cq_init(
  CircularQueue* this,
  char* name, size_t element_size, size_t n_elements, 
  bool is_threadsafe
);
void cq_acquire(CircularQueue* this);
void cq_release(CircularQueue* this);
void cq_free(CircularQueue* this);
bool cq_isEmpty(CircularQueue* this);
int cq_length(CircularQueue* this);
void cq_clear(CircularQueue* this);
void cq_push(CircularQueue* this, uint8_t* element);
uint8_t* cq_unsafePeek(CircularQueue* this);
uint8_t* cq_unsafeBeek(CircularQueue* this);
uint8_t* cq_peek(CircularQueue* this);
void cq_pop(CircularQueue* this);

#endif
