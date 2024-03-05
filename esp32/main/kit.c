#include <stdio.h>
#include <string.h>

#include "kit.h"

void printArray(uint8_t* array, int len) {
    printf("[");
    for (int i = 0; i < len; i ++) {
        printf("%d", array[i]);
        printf(", ");
    }
    printf("]");
}

void ellipses(char* buf, int capacity, int should) {
    assert(capacity >= 3 + 1);
    if (should < capacity)
        return;
    memset(buf + capacity - 3 - 1, '.', 3);
}

inline void assert_pdPASS(BaseType_t value) {
    assert(value == pdPASS);
}

inline void swap(int* a, int* b){
    int temp = *a;
    *a = *b;
    *b = temp;
}

char hexOf(uint8_t x) {
  if (x < 10) {
    return (char)(x      + (uint8_t)'0');
  } else {
    return (char)(x - 10 + (uint8_t)'a');
  }
}
