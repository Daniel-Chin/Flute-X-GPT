#ifndef FILE_bootup_jingle_SEEN
#define FILE_bootup_jingle_SEEN

#define JINGLE_AMP 0.5f

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

void bootupJingle(SemaphoreHandle_t doneSema);

#endif
