#include <string.h>

#include "kit.h"
#include "env.h"
#include "shared.h"
#include "circular_queue_with_time.h"
#include "print_and_send_log.h"

void cqt_init(
  CQT* this,
  char* name, size_t element_size_excluding_time, 
  size_t n_elements, cqtCallback_t callback
) {
  this->ELEMENT_SIZE_EXCLUDING_TIME = element_size_excluding_time;
  this->CALLBACK = callback;
  this->task = NULL;
  this->cq = (CircularQueue*) calloc(1, sizeof(CircularQueue));
  cq_init(
    this->cq, name, 
    element_size_excluding_time + sizeof(microsec_t), 
    n_elements, true
  );
}

void cqt_free(CQT* this) {
  cq_free(this->cq);
  free(this->cq);
}

// The following three functions define the layout of a CQ element in CQT  
static inline microsec_t* cqt_extract_time(uint8_t* cq_element) {
  return (microsec_t*) (void*) cq_element;
}
static inline uint8_t* cqt_extract_content(uint8_t* cq_element) {
  return cq_element + sizeof(microsec_t);
}
static inline void cqt_write_element(
  CQT* this, uint8_t* cq_element, 
  microsec_t const * time, uint8_t const * element
) {
  memcpy((void*) cq_element, (void*) time, sizeof(microsec_t));
  memcpy(
    (void*) (cq_element + sizeof(microsec_t)), (void*) element, 
    this->ELEMENT_SIZE_EXCLUDING_TIME
  );
}

void cqt_push(CQT* this, microsec_t* time, uint8_t* element) {
  cq_acquire(this->cq);
  #ifndef MUSX_DEBUG
      I am using syntax error to denote undefined macro here!
  #endif
  #if MUSX_DEBUG == 1
    if (! cq_isEmpty(this->cq)) {
      uint8_t* last_pushed = cq_unsafeBeek(this->cq);
      microsec_t* last_time = cqt_extract_time(last_pushed);
      if (*time < *last_time) {
        char msg[(41 + (6 + 5) * 2) * 2];
        ellipses(msg, sizeof(msg), snprintf(
          msg, sizeof(msg), "cqt_push() time not monotonous: %lld -> %lld", 
          *last_time, *time
        ));
        printAndSendError(msg);
        abort();
      }
    }
  #endif
  uint8_t cq_element[this->cq->ELEMENT_SIZE];
  cqt_write_element(this, cq_element, time, element);
  cq_push(this->cq, cq_element);
  if (cq_length(this->cq) == 1) {
    // from empty to 1
    int loss = (int) (globalTime() - *time);
    if (loss >= 0) {
      char msg[22 * 2];
      ellipses(msg, sizeof(msg), snprintf(
        msg, sizeof(msg), "cqt_push() loss %d us", loss
      ));
      printAndSendWarning(msg);
    }
  }
  cq_release(this->cq);
  #ifndef MUSX_DEBUG
      I am using syntax error to denote undefined macro here!
  #endif
  #if MUSX_DEBUG == 1
    assert(this->task != NULL);
  #endif
  (void) xTaskNotifyGiveIndexed(this->task, TASK_NOTIFICATION_INDEX);
}

void cqt_service(void* args) {
  CQT* cqt = (CQT*) args;
  cqt->task = xTaskGetCurrentTaskHandle();
  while (1) {
    cq_acquire(cqt->cq);
    TickType_t wait_ticks;
    if (cq_isEmpty(cqt->cq)) {
      wait_ticks = portMAX_DELAY;
    } else {
      uint8_t* cq_element = cq_unsafePeek(cqt->cq);
      microsec_t* time = cqt_extract_time(cq_element);
      microsec_t remaining = *time - globalTime();
      if (remaining > 0) {
        wait_ticks = remaining / (portTICK_PERIOD_MS * 1000);
        wait_ticks = MAX(1, wait_ticks);
      } else {
        cqt->CALLBACK(time, cqt_extract_content(cq_element));
        cq_pop(cqt->cq);
        wait_ticks = 0;
      }
    }
    cq_release(cqt->cq);
    if (wait_ticks != 0) {
      (void) ulTaskNotifyTakeIndexed(
        TASK_NOTIFICATION_INDEX, pdTRUE, wait_ticks
      );
    }
  }
}
