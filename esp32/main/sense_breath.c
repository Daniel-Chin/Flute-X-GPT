#include "role.h"
#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'F'

#include "esp_log.h"

#include "shared.h"
#include "env.h"
#include "sense_breath.h"
#include "bmp180.h"
#include "print_and_send_log.h"

static int filtered_pressure = 0;
static int atmos_pressure = -1;
static int measure_atmosphere_state = 20;
static long measure_atmosphere_tmp = 0;
static int measure_atmosphere_times = 0;
#ifndef DEBUG_NO_BREATH
    I am using syntax error to denote undefined macro here!
#endif
#if DEBUG_NO_BREATH == 1
  static int debug_no_breath_presure = 0;
#endif

void initSenseBreath(SemaphoreHandle_t commSemaphore) {
    ESP_LOGI(PROJECT_TAG, "initSenseBreath()...");
    #ifndef DEBUG_NO_BREATH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DEBUG_NO_BREATH == 0
        if (bmp180_init(I2C_PIN_SDA, I2C_PIN_SCL) != 0) {
            printWaitAndSendError(commSemaphore, "Could not find BMP085, check wiring!");
            abort();
        }
        // fill median filter queue
        int _;
        measureBreath();
        getBreathPressure(&_, NULL);
        vTaskDelay(1);
        measureBreath();
        getBreathPressure(&_, NULL);
    #endif
    ESP_LOGI(PROJECT_TAG, "initSenseBreath() ok");
}

void breathRecalibrate(uint16_t duration) {
    measure_atmosphere_tmp = 0;
    measure_atmosphere_times = 0;
    measure_atmosphere_state = (int) duration;
}

static inline int getMedian(int a, int b, int c) {
    if (b < a) {
        swap(&a, &b);
    }
    if (c < b) {
        swap(&b, &c);
    }
    if (b < a) {
        swap(&a, &b);
    }
    return b;
}

#ifndef DEBUG_NO_BREATH
    I am using syntax error to denote undefined macro here!
#endif
#if DEBUG_NO_BREATH == 0
static int medianFilter(int c) {
    static bool ready = false;
    static int a = 0;
    static int b = 0;
    if (! ready) {
        ready = true;
        a = c;
        b = c;
    }
    int m = getMedian(a, b, c);
    a = b;
    b = c;
    return m;
}
#endif

void measureBreath(void) {
    #ifndef DEBUG_NO_BREATH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DEBUG_NO_BREATH == 0
        uint32_t raw_pressure;
        bmp180_read_pressure(&raw_pressure);
        int offset_pressure = ((int) raw_pressure) - ATMOS_OFFSET;
        // ESP_LOGI(PROJECT_TAG, "offset_pressure = %d", offset_pressure);
        filtered_pressure = medianFilter(offset_pressure);
        // ESP_LOGI(PROJECT_TAG, "filtered_pressure = %d", filtered_pressure);
    #endif
}

bool getBreathPressure(
    int* out_pressure, callbackVoidVoid_t onCalibrateOk
) {
    #ifndef DEBUG_NO_BREATH
        I am using syntax error to denote undefined macro here!
    #endif
    #if DEBUG_NO_BREATH == 1
        if (debug_no_breath_presure > 0) {
            debug_no_breath_presure -= 1;
        }
        *out_pressure = debug_no_breath_presure;
        return true;
    #endif
    if (measure_atmosphere_state >= 0) {
        measure_atmosphere_tmp += filtered_pressure;
        measure_atmosphere_times ++;
        if (measure_atmosphere_state == 0) {
            atmos_pressure = measure_atmosphere_tmp / measure_atmosphere_times;
            if (onCalibrateOk != NULL) {
                onCalibrateOk();
            }
            ESP_LOGI(PROJECT_TAG, "atmos_pressure recalibrated: %d", atmos_pressure);
        }
        measure_atmosphere_state --;
        return false;
    }
    int p = filtered_pressure - atmos_pressure;
    p = (int) (PRESSURE_MULTIPLIER * (float) p);
    // ESP_LOGI(PROJECT_TAG, "breath pressure = %d", p);
    p = MAX(0, p);
    // ESP_LOGI(PROJECT_TAG, "abs breath pressure = %d", p);
    *out_pressure = p;
    return true;
}

#ifndef DEBUG_NO_BREATH
    I am using syntax error to denote undefined macro here!
#endif
#if DEBUG_NO_BREATH == 1
    void set_debug_no_breath_presure(int value) {
        debug_no_breath_presure = value;
    }
#endif

#endif
