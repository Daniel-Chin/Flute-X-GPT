#ifndef FILE_startup_barrier_SEEN
#define FILE_startup_barrier_SEEN

#include "freertos/semphr.h"

void initStartupBarrier(void);
SemaphoreHandle_t startupBarrierGetSema(void);

#endif
