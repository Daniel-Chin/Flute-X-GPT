#include "esp_log.h"

#include "shared.h"

__attribute__((noinline)) int getStackPointer(void) {
  void* value = NULL;
  int i = (int) (&value); // without this line, compiler drops the whole function
  return i;
}

/*
void checkRAM(void* known_heap_end) {
  // we can cast pointer to int because intptr_t <= int. 
  // On all arduinos, intptr_t = short <= int. 
  // On esp32, sizeof(void*) = 4U = sizeof(int). 
  extern int __heap_start, *__brkval; // these vars don't exist in esp32
  int stack_pointer = getStackPointer();
  int heap_end = MAX(
    (int) __brkval, 
    (int) &__heap_start
  );
  heap_end = MAX(
    heap_end, 
    (int) known_heap_end
  );
  int free_ram = stack_pointer - heap_end;
  if (free_ram < 300) {
    ESP_LOGW(
      PROJECT_TAG, 
      "RAM is low, %d left. Stack @ %d. Heap @ %d", 
      free_ram, stack_pointer, heap_end
    );
  }
}
*/
