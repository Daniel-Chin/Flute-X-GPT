#include "esp_log.h"
#include "freertos/FreeRTOS.h"

#include "shared.h"
#include "startup_barrier.h"

static SemaphoreHandle_t sema;

void initStartupBarrier(void) {
    sema = xSemaphoreCreateBinary();
    if (sema == NULL) {
        ESP_LOGE(PROJECT_TAG, "xSemaphoreCreateBinary failed");
        abort();
    }
}

inline SemaphoreHandle_t startupBarrierGetSema(void) {
    return sema;
}
