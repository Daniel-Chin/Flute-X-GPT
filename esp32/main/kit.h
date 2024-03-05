#ifndef FILE_kit_buffer_SEEN
#define FILE_kit_buffer_SEEN

#include "freertos/FreeRTOS.h"

typedef void (* callbackVoidVoid_t)(void);

void printArray(uint8_t* array, int len);
void ellipses(char* buf, int capacity, int should);
void assert_pdPASS(BaseType_t value);
void swap(int* a, int* b);
char hexOf(uint8_t x);

#endif
