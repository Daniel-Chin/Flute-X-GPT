#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "esp_log.h"

#include "shared.h"
#include "kit.h"
#include "circular_queue.h"
#include "print_and_send_log.h"

void cq_init(
  CircularQueue* this,
  char* name, size_t element_size, size_t n_elements, 
  bool is_threadsafe
) {
  size_t name_len = strlen(name) + 1;
  this->NAME = (char*) malloc(name_len);
  strncpy(this->NAME, name, name_len);
  this->ELEMENT_SIZE = element_size;
  this->N_ELEMENTS = n_elements;
  this->N_BYTES = n_elements * element_size;
  this->IS_THREADSAFE = is_threadsafe;
  this->buffer = calloc(n_elements, element_size);
  if (this->buffer == NULL) {
    char msg[30 * 2];
    ellipses(msg, sizeof(msg), snprintf(
      msg, sizeof(msg), "out of RAM when allocating %s", name
    ));
    printAndSendError(msg);
    abort();
  }
  this->push_i = 0;
  this->pop_i = 0;

  if (is_threadsafe) {
    this->sema = xSemaphoreCreateRecursiveMutex();
  }
}

inline void cq_acquire(CircularQueue* this) {
  if (this->IS_THREADSAFE) {
    (void) xSemaphoreTakeRecursive(this->sema, portMAX_DELAY);
  }
}

inline void cq_release(CircularQueue* this) {
  if (this->IS_THREADSAFE) {
    (void) xSemaphoreGiveRecursive(this->sema);
  }
}

void cq_free(CircularQueue* this) {
  cq_acquire(this);
  free(this->buffer);
  free(this->NAME);
  cq_release(this);
}

bool cq_isEmpty(CircularQueue* this) {
  cq_acquire(this);
  bool result = this->push_i == this->pop_i;
  cq_release(this);
  return result;
}

int cq_length(CircularQueue* this) {
  cq_acquire(this);
  int result;
  if (this->push_i >= this->pop_i) {
    result = this->push_i - this->pop_i;
  } else {
    result = this->N_ELEMENTS - this->pop_i + this->push_i;
  }
  cq_release(this);
  return result;
}

void cq_clear(CircularQueue* this) {
  cq_acquire(this);
  this->push_i = this->pop_i;
  cq_release(this);
}

static uint8_t* cq_at(CircularQueue* this, size_t index) {
  return this->buffer + index * this->ELEMENT_SIZE;
}

static void cq_printableBuffer(CircularQueue* this, char* buf) {
  int j = 0;
  uint8_t* byte_buffer = (uint8_t*) this->buffer;
  for (size_t i = 0; i < this->N_BYTES; i ++) {
    uint8_t b = byte_buffer[i];
    if (65 <= b && b <= 122) {
      // letters
      buf[j] = ' ';
      buf[j + 1] = (char) b;
    } else {
      buf[j    ] = hexOf(b >> 4);
      buf[j + 1] = hexOf(b && 0b1111);
    }
    j += 2;
  }
  buf[this->N_BYTES * 2] = '\0';
}

void cq_push(CircularQueue* this, uint8_t* element) {
  cq_acquire(this);
  memcpy(
    (void*) cq_at(this, this->push_i), (void*) element, 
    this->ELEMENT_SIZE
  );
  this->push_i = (this->push_i + 1) % this->N_ELEMENTS;
  if (cq_isEmpty(this)) {
    ESP_LOGE(PROJECT_TAG, "Circular queue overflow: %s", this->NAME);
    char buf[this->N_BYTES * 2 + 1];
    cq_printableBuffer(this, buf);
    ESP_LOGE(PROJECT_TAG, "buffer: \n%s", buf);
    abort();
  }
  cq_release(this);
}

uint8_t* cq_unsafePeek(CircularQueue* this) {
  cq_acquire(this);
  uint8_t* result = cq_at(this, this->pop_i);
  cq_release(this);
  return result;
}

uint8_t* cq_unsafeBeek(CircularQueue* this) {
  // beek is reversed peek
  cq_acquire(this);
  uint8_t* result = cq_at(this, (this->push_i - 1) % this->N_ELEMENTS);
  cq_release(this);
  return result;
}

uint8_t* cq_peek(CircularQueue* this) {
  cq_acquire(this);
  if (cq_isEmpty(this)) {
    char msg[29 * 2];
    ellipses(msg, sizeof(msg), snprintf(
      msg, sizeof(msg), "Circular queue underflow: %s", this->NAME
    ));
    printAndSendError(msg);
    abort();
  }
  uint8_t* result = cq_unsafePeek(this);
  cq_release(this);
  return result;
}

void cq_pop(CircularQueue* this) {
  cq_acquire(this);
  this->pop_i = (this->pop_i + 1) % this->N_ELEMENTS;
  cq_release(this);
}
